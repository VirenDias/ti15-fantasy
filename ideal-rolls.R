source("src/get-player-data.R")
source("src/get-team-data.R")

library(tidyverse)

# Get data
league_id <- 18324
teams_elim <- scan("data/teams_elim.csv", quiet = TRUE)
players <- get_player_data(league_id) %>% filter(!(team_id %in% teams_elim))
teams <- get_team_data(league_id)
stats <- read_csv("results/all_stats.csv")
prefixes <- read_csv("results/all_prefixes.csv")
suffixes <- read_csv("results/all_suffixes.csv")

# Calculate the player-wise ideal rolls
ideal_rolls <- data.frame(
  player_id = as.numeric(),
  player_role = as.character(),
  stat_1 = as.character(),
  stat_2 = as.character(),
  stat_3 = as.character(),
  stat_4 = as.character(),
  stat_5 = as.character(),
  prefix = as.character(),
  suffix = as.character(),
  average = as.numeric(),
  stddev = as.numeric()
)
for (player_id in players$player_id) {
  player_role <- players %>% 
    filter(player_id == !!player_id) %>%
    pull(player_role)
  player_stats <- stats %>% filter(player_id == !!player_id)
  
  player_stats <- switch (
    player_role,
    "Core" = bind_rows(
      player_stats %>%
        filter(emblem_colour == "Red") %>%
        slice_max(order_by = average, n = 3, with_ties = FALSE),
      player_stats %>%
        filter(emblem_colour == "Green") %>%
        slice_max(order_by = average, n = 2, with_ties = FALSE)
    ),
    "Mid" = bind_rows(
      player_stats %>%
        filter(emblem_colour == "Red") %>%
        slice_max(order_by = average, n = 2, with_ties = FALSE),
      player_stats %>%
        filter(emblem_colour == "Blue") %>%
        slice_max(order_by = average, n = 1, with_ties = FALSE),
      player_stats %>%
        filter(emblem_colour == "Green") %>%
        slice_max(order_by = average, n = 2, with_ties = FALSE)
    ),
    "Support" = bind_rows(
      player_stats %>%
        filter(emblem_colour == "Blue") %>%
        slice_max(order_by = average, n = 3, with_ties = FALSE),
      player_stats %>%
        filter(emblem_colour == "Green") %>%
        slice_max(order_by = average, n = 2, with_ties = FALSE)
    )
  )
  
  player_prefix <- prefixes %>%
    filter(player_id == !!player_id) %>%
    slice_max(order_by = effective_bonus, n = 1, with_ties = FALSE) %>%
    transmute(player_id, prefix_name, prefix_bonus = effective_bonus)
  player_suffix <- suffixes %>%
    filter(player_id == !!player_id) %>%
    slice_max(order_by = effective_bonus, n = 1, with_ties = FALSE) %>%
    transmute(player_id, suffix_name, suffix_bonus = effective_bonus)
  
  player_totals <- player_stats %>%
    left_join(player_prefix, by = "player_id") %>%
    left_join(player_suffix, by = "player_id") %>%
    reframe(
      average = sum(average * (1 + prefix_bonus + suffix_bonus)),
      stddev = sqrt(sum(stddev^2)) * 
        (1 + unique(prefix_bonus) + unique(suffix_bonus))
    )
  
  ideal_rolls <- ideal_rolls %>%
    add_row(
      player_id = player_id,
      player_role = player_role,
      stat_1 = paste0(
        player_stats %>% slice(1) %>% pull(emblem_colour),
        " - ",
        player_stats %>% slice(1) %>% pull(emblem_stat)
      ),
      stat_2 = paste0(
        player_stats %>% slice(2) %>% pull(emblem_colour),
        " - ",
        player_stats %>% slice(2) %>% pull(emblem_stat)
      ),
      stat_3 = paste0(
        player_stats %>% slice(3) %>% pull(emblem_colour),
        " - ",
        player_stats %>% slice(3) %>% pull(emblem_stat)
      ),
      stat_4 = paste0(
        player_stats %>% slice(4) %>% pull(emblem_colour),
        " - ",
        player_stats %>% slice(4) %>% pull(emblem_stat)
      ),
      stat_5 = paste0(
        player_stats %>% slice(5) %>% pull(emblem_colour),
        " - ",
        player_stats %>% slice(5) %>% pull(emblem_stat)
      ),
      prefix = player_prefix$prefix_name,
      suffix = player_suffix$suffix_name,
      average = player_totals$average,
      stddev = player_totals$stddev
    )
  
  rm(
    player_id,
    player_role,
    player_stats,
    player_prefix,
    player_suffix,
    player_totals
  )
}

ideal_rolls <- players %>%
  left_join(teams, by = "team_id") %>%
  select(player_id, player_name, team_name, player_role) %>%
  right_join(ideal_rolls, by = c("player_id", "player_role")) %>%
  select(-player_id) %>%
  arrange(desc(average))

write_csv(x = ideal_rolls, file = "results/ideal_rolls.csv")
