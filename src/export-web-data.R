source("config.R")
source("src/summarise-matches.R")

library(tidyverse)
library(jsonlite)

# How many series a team plays in a period, and which of those to lead with
period_series <- list(
  `1` = list(name = "Group Stage", n_values = c(4L, 5L, 6L), n_median = 6L),
  `2` = list(name = "Playoffs", n_values = c(2L, 3L, 4L, 5L, 6L), n_median = 4L)
)

# The share of Bo3s that go the distance, weighted like every other statistic so
# that matches played during the tournament count for more than the qualifiers
calc_series_rate <- function(match_data, alpha = weight_alpha) {
  series <- match_data %>%
    distinct(series_id, best_of, match_id, start_time) %>%
    summarise(
      games = n(),
      start_time = min(start_time),
      .by = c(series_id, best_of)
    ) %>%
    # Only a completed Bo3 says anything about how often a Bo3 runs to three
    filter(best_of == 3, games %in% 2:3)

  stopifnot(nrow(series) > 0)
  weights <- calc_exp_weights(series$start_time, alpha)

  return(sum(weights * (series$games == 3)) / sum(weights))
}

# Role-games, kept as their individual player rows. Amplification is per player
# and the roles are scored as a whole, so a role-game's score is
# sum(base * (1 + prefix + suffix)) over its players, which cannot be recovered
# from a pair that has already been averaged.
complete_roles <- function(data) {
  return(
    data %>%
      mutate(players = n(), .by = c(team_id, player_role, match_id, is_radiant)) %>%
      filter(players == role_size[player_role]) %>%
      select(-players)
  )
}

build_role_games <- function(match_data, stat_cols, indicator_cols) {
  paired <- match_data %>%
    filter(player_role %in% names(role_size)) %>%
    complete_roles()

  return(
    paired %>%
      # A player missing a stat takes their role-mate's game with them
      drop_na(all_of(c(stat_cols, indicator_cols))) %>%
      complete_roles() %>%
      arrange(team_id, player_role, start_time, match_id, player_id) %>%
      structure(paired_games = nrow(distinct(
        paired, team_id, player_role, match_id, is_radiant
      )))
  )
}

export_web_data <- function(match_data,
                            teams,
                            stats,
                            banners,
                            prefixes,
                            suffixes,
                            qualities,
                            traits,
                            rolls,
                            period = current_period,
                            path = file.path(web_dir, "data.json")) {
  stat_cols <- stats$stat_column

  # A suffix that describes where a match sits in its series cannot travel with a
  # resampled game, because resampling is what destroys the position. It is left
  # out of the flags entirely and applied to whichever game the draw puts last --
  # see methodology.md.
  positional <- suffixes %>%
    filter(suffix_scope != "match") %>%
    pull(suffix_name)
  indicator_cols <- setdiff(
    c(prefixes$prefix_name, suffixes$suffix_name), positional
  )

  # An indicator with nothing behind it drops out on the evidence rather than by
  # name, so it returns on its own once the parser starts supplying it
  usable <- indicator_cols[
    !map_lgl(indicator_cols, ~ all(is.na(match_data[[.x]])))
  ]
  dropped <- setdiff(indicator_cols, usable)
  if (length(dropped) > 0) {
    message("Dropping indicators with no data: ", paste(dropped, collapse = ", "))
  }

  # the Clutch rides along with the game it was measured on, like every other
  # indicator. It is the only one that describes a match's position in its
  # series rather than the match itself, so its rate carries the pool's format
  # mix with it -- see methodology.md.
  role_games <- build_role_games(match_data, stat_cols, usable)

  # One weight per role-game, shared by the players in it. The match result is
  # shared too, and a Bo3's win/loss pattern is fixed, so it travels with them.
  games <- role_games %>%
    distinct(team_id, player_role, match_id, is_radiant, start_time, lose) %>%
    mutate(
      weight = calc_exp_weights(start_time, weight_alpha),
      .by = c(team_id, player_role)
    )

  stopifnot(
    # A role's players share the match, so the result cannot differ between them
    nrow(games) == nrow(distinct(
      role_games, team_id, player_role, match_id, is_radiant
    ))
  )

  bits <- set_names(2^(seq_along(usable) - 1), usable)
  units <- role_games %>%
    nest(.by = c(team_id, player_role)) %>%
    pmap(function(team_id, player_role, data) {
      rows <- games %>%
        filter(team_id == !!team_id, player_role == !!player_role) %>%
        arrange(start_time, match_id)

      list(
        team = team_id,
        role = player_role,
        size = unname(role_size[player_role]),
        pts = round(as.matrix(data[stat_cols])),
        ind = as.vector(as.matrix(data[usable]) %*% bits),
        w = rows$weight,
        win = as.integer(rows$lose == 0)
      )
    })

  stopifnot(
    period %in% banners$period,
    map_lgl(units, ~ length(.x$w) * .x$size == nrow(.x$pts)) %>% all()
  )

  shape <- banners %>%
    filter(period == !!period) %>%
    arrange(player_role, position) %>%
    summarise(colours = list(emblem_colour), .by = player_role) %>%
    deframe()

  payload <- list(
    meta = list(
      generated = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
      period = period,
      patch = starting_patch,
      matches = n_distinct(match_data$match_id),
      p3 = calc_series_rate(match_data),
      alpha = weight_alpha,
      n_values = period_series[[as.character(period)]]$n_values,
      n_median = period_series[[as.character(period)]]$n_median,
      # Both, so the methodology can name what each period costs a team
      periods = period_series,
      role_games = length(unlist(map(units, "w"))),
      dropped_indicators = dropped
    ),
    stats = pmap(
      stats %>% select(col = stat_column, label = emblem_stat, colour = emblem_colour),
      ~ list(col = ..1, label = ..2, colour = ..3)
    ),
    banner = shape,
    prefixes = pmap(
      prefixes %>% select(name = prefix_name, bonus = prefix_bonus),
      ~ list(name = ..1, bonus = ..2, bit = unname(bits[..1]))
    ),
    # A positional suffix has no flag to carry, so it ships with a bit of zero
    # and the browser applies it by where the game lands instead
    suffixes = pmap(
      suffixes %>% filter(suffix_name %in% c(usable, positional)) %>%
        select(name = suffix_name, bonus = suffix_bonus, scope = suffix_scope),
      ~ list(name = ..1, bonus = ..2, scope = ..3,
             bit = if (..1 %in% names(bits)) unname(bits[..1]) else 0L)
    ),
    teams = pmap(
      teams %>% filter(team_id %in% map_dbl(units, "team")) %>%
        select(id = team_id, name = team_name, tag = team_tag),
      ~ list(id = ..1, name = ..2, tag = ..3)
    ),
    # The reroll helper reads these rather than holding any of it as a literal.
    # Row order in qualities is the ladder an emblem improves along.
    qualities = pmap(
      qualities %>% select(name = quality_name, bonus = quality_bonus,
                           weight = quality_weight),
      ~ list(name = ..1, bonus = ..2, weight = ..3)
    ),
    traits = pmap(
      traits %>% select(name = trait_name, desc = trait_desc,
                        bonus = trait_bonus, adjacent = trait_adjacent),
      ~ list(name = ..1, desc = ..2, bonus = ..3, adjacent = ..4)
    ),
    rolls = pmap(
      rolls %>% select(name = roll_name, colour = emblem_colour,
                       property = roll_property, scope = roll_scope),
      ~ list(name = ..1, colour = if (is.na(..2)) NULL else ..2,
             property = ..3, scope = ..4)
    ),
    units = units
  )

  dir_path <- dirname(path)
  if (!dir.exists(dir_path)) dir.create(dir_path, recursive = TRUE)
  write_json(payload, path, auto_unbox = TRUE, digits = 6, null = "null")

  incomplete <- attr(role_games, "paired_games") - payload$meta$role_games
  message(
    paste0(
      "Exported ", length(units), " team-roles, ",
      payload$meta$role_games, " role-games to ", path,
      " (", round(file.size(path) / 1e6, 1), " MB)",
      if (incomplete > 0) {
        paste0(", ", incomplete, " dropped for incomplete stats")
      } else {
        ""
      }
    )
  )

  return(invisible(payload))
}
