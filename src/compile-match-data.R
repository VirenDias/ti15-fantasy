source("src/get-match-data.R")

library(tidyverse)
library(rlang)

derive_series_data <- function(matches) {
  return(
    matches %>%
      mutate(
        best_of = case_match(
          series_type,
          0 ~ 1L,
          1 ~ 3L,
          2 ~ 5L,
          3 ~ 2L,
          .default = NA_integer_
        )
      ) %>%
      mutate(
        match_no = rank(start_time, ties.method = "first"),
        .by = series_id
      ) %>%
      # OpenDota has no field for a match's position in its series
      mutate(clutch = match_no == best_of) %>%
      select(-series_type, -match_no)
  )
}

read_replay_data <- function(match_ids) {
  message("Reading replay data")

  dir_path <- "data/matches/replay"
  file_paths <- set_names(
    paste0(dir_path, "/", match_ids, ".csv"),
    match_ids
  )

  return(
    file_paths %>%
      map(read_csv, col_types = cols(.default = col_double()), progress = FALSE) %>%
      list_rbind(names_to = "match_id") %>%
      mutate(match_id = as.numeric(match_id))
  )
}

compile_match_data <- function(
    match_ids,
    players,
    heroes,
    stats,
    prefixes,
    suffixes,
    fetch_replays = TRUE,
    min_coverage = 0.95
) {
  # paste0 recycles a zero-length vector to "", turning the file checks below
  # into a single nonsensical path
  if (length(match_ids) == 0) {
    stop("No match ids to compile, check data/matches/match_ids.csv")
  }

  odota <- get_match_odota_data(match_ids)
  matches <- derive_series_data(odota$matches)

  if (fetch_replays) {
    lost <- get_match_replay_data(matches$match_id, matches$replay_url)
    if (nrow(lost) > 0) {
      message("Replays that could not be obtained:")
      lost %>%
        count(reason) %>%
        pwalk(~ message(paste0("  ", .y, " ", .x)))
    }
  }

  # A match missing either its OpenDota row or its replay is dropped rather than
  # failing the run, since the sample left behind is still sound
  parsed <- paste0("data/matches/replay/", matches$match_id, ".csv")
  usable <- matches$match_id[file.exists(parsed)]
  dropped <- setdiff(match_ids, usable)

  # A handful is attrition, but a large share means the parser or the source
  # broke, and statistics built on what survived would be worthless
  if (length(usable) < min_coverage * length(match_ids)) {
    stop(
      paste0(
        "Only ", length(usable), " of ", length(match_ids),
        " matches are usable, below the ", min_coverage * 100,
        "% needed. Check that utils/fantasy.jar still parses this patch"
      )
    )
  }
  if (length(dropped) > 0) {
    warning(
      paste0(
        length(dropped), " of ", length(match_ids), " matches were dropped: ",
        paste(head(dropped, 10), collapse = ", "),
        if (length(dropped) > 10) ", ..." else ""
      ),
      call. = FALSE
    )
  }

  match_ids <- usable
  matches <- matches %>% filter(match_id %in% match_ids)

  stat_cols <- stats$stat_column
  replay_stats <- read_replay_data(match_ids)

  missing_cols <- setdiff(stat_cols, names(replay_stats))
  if (length(missing_cols) > 0) {
    stop(
      paste0(
        "Stat columns named in data/stats.csv but absent from the replays ",
        "parsed by utils/fantasy.jar: ",
        paste(missing_cols, collapse = ", ")
      )
    )
  }

  message("Compiling match data")

  multipliers <- set_names(stats$points_multiplier, stats$stat_column)
  thresholds <- set_names(stats$points_threshold, stats$stat_column)
  hero_cols <- setdiff(names(heroes), c("hero_id", "hero_name"))

  # Hero attributes drive the prefixes, match facts drive the suffixes
  prefix_conds <- exprs(
    Cerulean = blue == 1,
    Crimson = red == 1,
    Elemental = aquatic == 1 | fiery == 1 | icy == 1,
    Emerald = green == 1,
    Golden = yellow == 1 | brown == 1,
    Heroic = cape == 1 | mask == 1,
    Otherworldly = undead == 1 | demon == 1 | spirit == 1,
    Royal = purple == 1
  )
  suffix_conds <- exprs(
    `the Clutch` = clutch,
    `the Cruel` = NA,
    `the Decisive` = duration <= 1500,
    `the Flayed Twins Acolyte` = first_blood_time <= 0,
    `the Lucky` = duration %% 10 == 8,
    `the Patient` = first_blood_time > 600,
    `the Tormented` = tormentor_death,
    `the Underdog` = lose == 1
  )

  # A renamed row would otherwise surface as a silently empty column
  stopifnot(
    setequal(names(prefix_conds), prefixes$prefix_name),
    setequal(names(suffix_conds), suffixes$suffix_name)
  )

  missing_adjectives <- setdiff(
    unique(unlist(map(prefix_conds, all.vars))),
    names(heroes)
  )
  if (length(missing_adjectives) > 0) {
    stop(
      paste0(
        "The prefixes need hero adjectives that data/heroes.txt does not have: ",
        paste(missing_adjectives, collapse = ", "),
        ". Re-extract npc_heroes.txt from dota 2 beta/game/dota/pak01_dir.vpk"
      )
    )
  }

  match_data <- odota$match_players %>%
    filter(match_id %in% match_ids) %>%
    inner_join(players, by = "player_id")

  # A missing hero means heroes.txt is stale, and its prefixes would all be NA
  unknown_heroes <- sort(setdiff(match_data$hero_id, heroes$hero_id))
  if (length(unknown_heroes) > 0) {
    stop(
      paste0(
        "Hero ids played but absent from data/heroes.txt: ",
        paste(unknown_heroes, collapse = ", "),
        ". Re-extract npc_heroes.txt from dota 2 beta/game/dota/pak01_dir.vpk"
      )
    )
  }

  match_data <- match_data %>%
    left_join(matches, by = "match_id") %>%
    left_join(
      replay_stats %>% select(match_id, player_id, all_of(stat_cols)),
      by = c("match_id", "player_id")
    ) %>%
    left_join(heroes, by = "hero_id") %>%
    mutate(!!!prefix_conds, !!!suffix_conds) %>%
    mutate(
      team_side_id = if_else(is_radiant, radiant_team_id, dire_team_id),
      same_team_in_match = team_side_id == team_id,
      across(
        all_of(stat_cols),
        ~ .x * multipliers[[cur_column()]] -
          thresholds[[cur_column()]] * multipliers[[cur_column()]]
      )
    ) %>%
    select(-all_of(hero_cols))

  stopifnot(
    !any(is.na(match_data$start_time)),
    !any(duplicated(match_data[c("match_id", "player_id")]))
  )

  return(
    match_data %>%
      select(
        match_id,
        series_id,
        best_of,
        start_time,
        duration,
        player_id,
        player_name,
        player_role,
        team_id,
        team_side_id,
        same_team_in_match,
        is_radiant,
        # A Bo3's win/loss pattern is fixed, so the resampled series needs it
        lose,
        hero_id,
        hero_name,
        all_of(stat_cols),
        all_of(prefixes$prefix_name),
        all_of(suffixes$suffix_name)
      ) %>%
      arrange(start_time, match_id, player_id)
  )
}
