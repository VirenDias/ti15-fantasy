source("config.R")
source("src/get-player-data.R")

library(tidyverse)
library(httr)

num_or_na <- function(value) {
  return(if (is.null(value)) NA_real_ else as.numeric(value))
}

query_explorer <- function(sql) {
  response <- GET(
    "https://api.opendota.com/api/explorer",
    query = list(sql = sql)
  )
  if (http_status(response)$category != "Success") {
    stop("Unsuccessful request")
  }

  result <- content(response)
  if (!is.null(result$err)) {
    stop(paste0("OpenDota rejected the query: ", result$err))
  }

  return(result$rows)
}

get_patch_start <- function(patch_name) {
  response <- GET("https://api.opendota.com/api/constants/patch")
  if (http_status(response)$category != "Success") {
    stop("Unsuccessful request")
  }

  patch <- keep(content(response), ~ identical(as.character(.x$name), patch_name))
  if (length(patch) == 0) {
    stop(
      paste0(
        "OpenDota has no patch called ", patch_name,
        ", check starting_patch in config.R"
      )
    )
  }

  return(
    as.numeric(
      as.POSIXct(patch[[1]]$date, format = "%Y-%m-%dT%H:%M:%OSZ", tz = "UTC")
    )
  )
}

get_match_ids <- function(
    player_ids,
    patch = starting_patch,
    whitelist = league_whitelist
) {
  message("Retrieving match IDs")

  dir_path <- "data/matches"
  file_path <- paste0(dir_path, "/match_ids.csv")

  if (file.exists(file_path)) {
    match_ids <- scan(file_path, quiet = TRUE)
  } else {
    # A patch is a span of time, so the window opens at its release
    patch_start <- get_patch_start(patch)
    message(
      paste0(
        "Patch ", patch, " released ",
        format(
          as.POSIXct(patch_start, origin = "1970-01-01", tz = "UTC"),
          "%Y-%m-%d"
        )
      )
    )

    # League tiers are only exposed through the sql explorer
    query <- paste0(
      "SELECT DISTINCT m.match_id ",
      "FROM matches m ",
      "JOIN player_matches pm ON pm.match_id = m.match_id ",
      "JOIN leagues l ON l.leagueid = m.leagueid ",
      "WHERE pm.account_id IN (",
      paste(format(player_ids, scientific = FALSE, trim = TRUE), collapse = ","),
      ") AND m.start_time >= ", patch_start,
      " AND (l.tier IN (\'premium\', \'professional\')",
      if (length(whitelist) > 0) {
        paste0(" OR l.leagueid IN (", paste(whitelist, collapse = ","), ")")
      } else {
        ""
      },
      ")"
    )

    match_ids <- map_dbl(query_explorer(query), ~ num_or_na(.x$match_id))

    # Caching an empty response would keep failing every later run
    if (length(match_ids) == 0) {
      stop(
        paste0(
          "OpenDota returned no matches for these players since patch ", patch
        )
      )
    }

    if (!dir.exists(dir_path)) {
      dir.create(dir_path)
    }
    match_ids <- sort(unique(match_ids))
    write_csv(x = as.data.frame(match_ids), file = file_path, col_names = FALSE)
  }

  return(match_ids)
}


get_match_odota_data <- function(match_ids, chunk_size = 500) {
  message("Retrieving match OpenDota data")

  dir_path <- "data/matches"
  matches_path <- paste0(dir_path, "/matches.csv")
  players_path <- paste0(dir_path, "/match_players.csv")

  if (file.exists(matches_path) & file.exists(players_path)) {
    matches <- read_csv(matches_path, progress = FALSE, show_col_types = FALSE)
    match_players <- read_csv(
      players_path,
      progress = FALSE,
      show_col_types = FALSE
    )

    # Refetched rather than merged when the tournament adds matches, since the
    # whole set costs one request per chunk
    if (all(match_ids %in% matches$match_id)) {
      return(
        list(
          matches = matches %>% filter(match_id %in% match_ids),
          match_players = match_players %>% filter(match_id %in% match_ids)
        )
      )
    }
  }

  # Chunked to keep the query string inside any url length limit
  id_lists <- match_ids %>%
    split(ceiling(seq_along(match_ids) / chunk_size)) %>%
    map_chr(~ paste(format(.x, scientific = FALSE, trim = TRUE), collapse = ","))

  match_rows <- id_lists %>%
    map(
      ~ query_explorer(
        paste0(
          "SELECT match_id, series_id, series_type, start_time, duration, ",
          "first_blood_time, radiant_team_id, dire_team_id, radiant_win, ",
          "cluster, replay_salt FROM matches WHERE match_id IN (", .x, ")"
        )
      )
    ) %>%
    list_flatten()

  # killed_by is the only place a tormentor kill is recorded
  player_rows <- id_lists %>%
    map(
      ~ query_explorer(
        paste0(
          "SELECT match_id, account_id, hero_id, player_slot, ",
          "(killed_by->>'npc_dota_miniboss') IS NOT NULL AS tormentor ",
          "FROM player_matches WHERE match_id IN (", .x, ")"
        )
      )
    ) %>%
    list_flatten()

  matches <- tibble(
    match_id = map_dbl(match_rows, ~ num_or_na(.x$match_id)),
    series_id = map_dbl(match_rows, ~ num_or_na(.x$series_id)),
    series_type = map_dbl(match_rows, ~ num_or_na(.x$series_type)),
    start_time = map_dbl(match_rows, ~ num_or_na(.x$start_time)),
    duration = map_dbl(match_rows, ~ num_or_na(.x$duration)),
    first_blood_time = map_dbl(match_rows, ~ num_or_na(.x$first_blood_time)),
    radiant_team_id = map_dbl(match_rows, ~ num_or_na(.x$radiant_team_id)),
    dire_team_id = map_dbl(match_rows, ~ num_or_na(.x$dire_team_id)),
    radiant_win = map_lgl(match_rows, ~ isTRUE(.x$radiant_win)),
    cluster = map_dbl(match_rows, ~ num_or_na(.x$cluster)),
    replay_salt = map_dbl(match_rows, ~ num_or_na(.x$replay_salt))
  )

  missing <- setdiff(match_ids, matches$match_id)
  if (length(missing) > 0) {
    stop(
      paste0(
        length(missing), " of ", length(match_ids),
        " matches are absent from OpenDota. Blacklist them in ",
        "data/matches/match_ids_black.csv"
      )
    )
  }

  match_players <- tibble(
    match_id = map_dbl(player_rows, ~ num_or_na(.x$match_id)),
    player_id = map_dbl(player_rows, ~ num_or_na(.x$account_id)),
    hero_id = map_dbl(player_rows, ~ num_or_na(.x$hero_id)),
    player_slot = map_dbl(player_rows, ~ num_or_na(.x$player_slot)),
    tormentor = map_lgl(player_rows, ~ isTRUE(.x$tormentor))
  )

  matches <- matches %>%
    left_join(
      match_players %>% summarise(tormentor_death = any(tormentor), .by = match_id),
      by = "match_id"
    ) %>%
    # OpenDota serves a replay url but stores only the parts it is built from
    mutate(
      replay_url = if_else(
        is.na(cluster) | is.na(replay_salt),
        NA_character_,
        paste0(
          "http://replay", cluster, ".valve.net/570/",
          format(match_id, scientific = FALSE, trim = TRUE), "_",
          format(replay_salt, scientific = FALSE, trim = TRUE), ".dem.bz2"
        )
      )
    ) %>%
    select(-cluster, -replay_salt) %>%
    arrange(match_id)

  match_players <- match_players %>%
    left_join(matches %>% select(match_id, radiant_win), by = "match_id") %>%
    mutate(
      is_radiant = player_slot < 128,
      lose = as.numeric(is_radiant != radiant_win)
    ) %>%
    select(match_id, player_id, hero_id, is_radiant, lose) %>%
    arrange(match_id, player_id)

  matches <- matches %>% select(-radiant_win)

  if (!dir.exists(dir_path)) {
    dir.create(dir_path)
  }
  write_csv(x = matches, file = matches_path)
  write_csv(x = match_players, file = players_path)

  return(list(matches = matches, match_players = match_players))
}

get_match_replay_data <- function(match_ids, replay_urls, timeout = 600) {
  options(timeout = timeout)

  message("Retrieving match replay data")

  dir_path <- "data/matches/replay"
  if (!dir.exists(dir_path)) dir.create(dir_path)

  for (i in seq_along(match_ids)) {
    match_id <- match_ids[i]
    bz2_path <- paste0(dir_path, "/", match_id, ".dem.bz2")
    dem_path <- paste0(dir_path, "/", match_id, ".dem")
    csv_path <- paste0(dir_path, "/", match_id, ".csv")
    if (file.exists(csv_path)) next

    if (is.na(replay_urls[i])) {
      message(paste0("No replay URL for match ID ", match_id))
      next
    }

    message(
      paste0(
        "Retrieving replay data for match ID ",
        match_id,
        " (",
        i,
        "/",
        length(match_ids),
        ")"
      )
    )

    if (!file.exists(bz2_path) & !file.exists(dem_path)) {
      message("Downloading replay")
      download.file(url = replay_urls[i], destfile = bz2_path, mode = "wb")
      Sys.sleep(1)
    }

    if (!file.exists(dem_path)) {
      message("Decompressing replay")
      system2(
        command = "7z",
        args = c("x", bz2_path, paste0("-o", dir_path)),
        stdout = FALSE,
        stderr = FALSE
      )
    }

    message("Parsing replay")
    system2(
      command = "java",
      args = c("-jar", "utils/fantasy.jar", dem_path),
      stdout = csv_path,
      stderr = FALSE
    )
    invisible(file.remove(dem_path))
  }

  return(invisible(NULL))
}
