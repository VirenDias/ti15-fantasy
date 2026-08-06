source("config.R")
source("src/get-player-data.R")
source("src/get-team-data.R")
source("src/get-match-data.R")
source("src/get-hero-data.R")
source("src/compile-match-data.R")
source("src/summarise-matches.R")

library(tidyverse)

# Get data
teams_elim <- scan("data/teams_elim.csv", quiet = TRUE)
players <- get_player_data(league_id) %>% filter(!(team_id %in% teams_elim))
teams <- get_team_data(league_id)
heroes <- get_hero_data(python_exe)
stats <- read_csv("data/stats.csv", show_col_types = FALSE)
prefixes <- read_csv("data/prefixes.csv", show_col_types = FALSE)
suffixes <- read_csv("data/suffixes.csv", show_col_types = FALSE)
banners <- read_csv("data/banners.csv", show_col_types = FALSE)

# Nothing here consumes the banners, but a typo would only surface much later
banners <- banners %>% arrange(phase, player_role, position)
stopifnot(
  # Every colour must be one an emblem can actually hold
  all(banners$emblem_colour %in% stats$emblem_colour),
  # Positions run 1..n per role and phase, since adjacency depends on them
  banners %>%
    summarise(ok = all(position == seq_along(position)), .by = c(phase, player_role)) %>%
    pull(ok) %>%
    all(),
  # No two emblems of the same colour sit next to each other
  banners %>%
    summarise(ok = all(emblem_colour != lag(emblem_colour), na.rm = TRUE),
              .by = c(phase, player_role)) %>%
    pull(ok) %>%
    all(),
  # Phase 2 keeps the phase 1 emblems and appends to them
  banners %>%
    summarise(shape = paste(emblem_colour, collapse = ""), .by = c(phase, player_role)) %>%
    pivot_wider(names_from = phase, values_from = shape, names_prefix = "p") %>%
    mutate(ok = startsWith(p2, p1)) %>%
    pull(ok) %>%
    all(),
  # The configured phase must be one the file describes
  current_phase %in% banners$phase
)

# So a stale phase in config.R is visible on every run
phase_banners <- banners %>%
  filter(phase == current_phase) %>%
  summarise(shape = paste(emblem_colour, collapse = " "), .by = player_role)
for (i in seq_len(nrow(phase_banners))) {
  message(
    paste0(
      "Phase ", current_phase, " ", phase_banners$player_role[i], " banner: ",
      phase_banners$shape[i]
    )
  )
}

match_ids <- get_match_ids(players$player_id)
match_ids_black <- scan("data/matches/match_ids_black.csv", quiet = TRUE)
match_ids <- setdiff(match_ids, match_ids_black)

# Whichever roles are complete still yield usable data, so this warns rather
# than stops
odd_rosters <- players %>%
  count(team_id, player_role, name = "players") %>%
  # A role with nobody in it produces no row to compare
  complete(team_id, player_role = names(role_size), fill = list(players = 0)) %>%
  filter(!player_role %in% names(role_size) | players != role_size[player_role])
if (nrow(odd_rosters) > 0) {
  warning(
    paste0(
      "Unexpected roster sizes: ",
      paste0(
        odd_rosters$team_id, " ",
        coalesce(odd_rosters$player_role, "no role"), "=", odd_rosters$players,
        collapse = "; "
      )
    ),
    call. = FALSE
  )
}

match_data <- compile_match_data(
  match_ids = match_ids,
  players = players,
  heroes = heroes,
  stats = stats,
  prefixes = prefixes,
  suffixes = suffixes
)

write_csv(x = match_data, file = "data/match_data.csv")

stat_cols <- stats$stat_column
indicator_cols <- c(prefixes$prefix_name, suffixes$suffix_name)
metric_cols <- c(stat_cols, indicator_cols)

missing_stats <- sum(!complete.cases(match_data[stat_cols]))
if (missing_stats > 0) {
  warning(
    paste0(missing_stats, " player-matches are missing at least one stat"),
    call. = FALSE
  )
}

# Pairing keeps the covariance between the players a team fields in a role
role_matches <- pair_role_matches(match_data, metric_cols)
role_stats <- summarise_metrics(
  role_matches,
  metric_cols,
  c("team_id", "player_role")
) %>%
  left_join(teams %>% select(team_id, team_name), by = "team_id") %>%
  # Masked first, because if_else evaluates both branches and a stat metric
  # would be the square root of a negative
  mutate(prob = if_else(metric %in% indicator_cols, average, NA_real_)) %>%
  mutate(prob_se = sqrt(prob * (1 - prob) / ess)) %>%
  select(
    team_id,
    team_name,
    player_role,
    metric,
    n,
    ess,
    average,
    stddev,
    sem,
    prob_se
  ) %>%
  arrange(team_name, player_role, metric)

if (!dir.exists("results")) dir.create("results")
write_csv(x = role_stats, file = "results/role_stats.csv")

message(
  paste0(
    "Compiled ", n_distinct(match_data$match_id), " matches, ",
    nrow(match_data), " player-matches, ",
    n_distinct(match_data$player_id), " players"
  )
)
