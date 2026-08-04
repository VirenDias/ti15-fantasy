source("config.R")
source("src/get-player-data.R")
source("src/get-team-data.R")
source("src/get-match-data.R")
source("src/calc-exp-summary.R")

library(tidyverse)
library(progress)
library(googlesheets4)

# Get data
teams_elim <- scan("data/teams_elim.csv", quiet = TRUE)
players <- get_player_data(league_id) %>% filter(!(team_id %in% teams_elim))
teams <- get_team_data(league_id)
top_players <- scan("data/top_players.csv", quiet = TRUE)
suffixes <- read_csv("data/suffixes.csv", show_col_types = FALSE)

match_ids <- get_match_ids(league_id)
match_ids_black <- scan(
  "data/matches/match_ids_black.csv", 
  quiet = TRUE
)
match_ids <- setdiff(match_ids, match_ids_black)
matches_odota <- get_match_odota_data(match_ids)

# Determine whether a match is the last possible in a series
series <- data.frame(
  series_id = as.numeric(),
  best_of = as.numeric(),
  match_id = as.numeric(),
  time = as.numeric()
)
for (match in matches_odota) {
  series <- series %>%
    add_row(
      series_id = match$series_id,
      best_of = switch(
        as.character(match$series_type),
        "0" = 1,
        "1" = 3,
        "2" = 5,
        "3" = 2
      ),
      match_id = match$match_id,
      time = match$start_time
    )
}
series <- series %>%
  group_by(series_id) %>%
  mutate(clutch = rank(time) == best_of) %>%
  ungroup()

# Calculate suffix incidences
suffix_incids <- data.frame(
  player_id = as.numeric(),
  suffix_name = as.character(),
  time = as.numeric(),
  cond = as.logical()
)

progress <- progress_bar$new(
  format = "(:spin) [:bar] :percent | ETA: :eta",
  total = length(match_ids),
  complete = "=",
  incomplete = "-",
  current = ">",
  clear = FALSE
)
for (match in matches_odota) {
  for (player in match$players) {
    if (player$account_id %in% players$player_id) {
      base_row <- list2(
        player_id = player$account_id,
        time = match$start_time,
      )
      
      # the Clutch
      ## +16% when playing the last possible match of a series
      suffix_incids <- suffix_incids %>%
        add_row(
          !!!base_row,
          suffix_name = "the Clutch",
          cond = series %>% filter(match_id == match$match_id) %>% pull(clutch)
        )

      # the Decisive
      ## +24% in games that last less than 25 minutes
      suffix_incids <- suffix_incids %>% 
        add_row(
          !!!base_row,
          suffix_name = "the Decisive",
          cond = match$objectives[[length(match$objectives)]]$time <= 1500
        )
      
      # the Flayed Twins Acolyte
      ## +9% if any player gets first blood before the starting horn
      suffix_incids <- suffix_incids %>% 
        add_row(
          !!!base_row,
          suffix_name = "the Flayed Twins Acolyte",
          cond = match$first_blood_time <= 0
        )
      
      # the Lucky
      ## +21% if the match time ends with an 8
      suffix_incids <- suffix_incids %>%
        add_row(
          !!!base_row,
          suffix_name = "the Lucky",
          cond = match$duration %% 10 == 8
        )

      # the Patient
      ## +23% if first blood does not happen until after 10 minutes
      suffix_incids <- suffix_incids %>% 
        add_row(
          !!!base_row,
          suffix_name = "the Patient",
          cond = match$first_blood_time > 600
        )
      
      # the Tormented
      ## +23% if any player dies to a Tormentor
      suffix_incids <- suffix_incids %>% 
        add_row(
          !!!base_row,
          suffix_name = "the Tormented",
          cond = sapply(
            X = match$players, 
            FUN = function(x) { 
              if (!is.null(x$killed_by$npc_dota_miniboss)) {
                x$killed_by$npc_dota_miniboss
              } else {
                0
              }
            }
          ) %>%
            sum() > 0
        )
      
      # the Underdog
      ## +6% in games where the player loses
      suffix_incids <- suffix_incids %>%
        add_row(
          !!!base_row,
          suffix_name = "the Underdog",
          cond = player$lose == 1
        )
    }
  }

  progress$tick()
  rm(match, player, base_row)
}

# Calculate player-wise top suffixes
suffix_probs <- players %>% 
  select(player_id, player_role) %>%
  inner_join(suffix_incids, by = "player_id") %>%
  group_by(player_id, player_role, suffix_name) %>%
  arrange(time) %>%
  summarise(suffix_prob = calc_exp_summary(cond), .groups = "drop")

suffix_sums <- suffix_probs %>%
  left_join(suffixes, by = "suffix_name") %>%
  mutate(effective_bonus = (suffix_prob * suffix_bonus) / 100) %>%
  select(
    player_id, 
    player_role, 
    suffix_name, 
    suffix_bonus,
    suffix_prob,
    effective_bonus
  )

write_csv(x = suffix_sums, file = "results/all_suffixes.csv")

suffix_sums %>%
  left_join(players, by = c("player_id", "player_role")) %>%
  left_join(teams, by = "team_id") %>%
  pivot_wider(
    id_cols = c(player_name, team_name, player_role),
    names_from = suffix_name, 
    values_from = effective_bonus,
    names_sort = TRUE
  ) %>%
  arrange(team_name, player_role, player_name) %>%
  rename(
    "Player Name" = "player_name", 
    "Team Name" = "team_name",
    "Role" = "player_role"
  ) %>%
  write_sheet(
    ss = spreadsheet_id, 
    sheet = "Title Suffix Data"
  )

# Calculate top suffixes
top_suffixes <- suffix_probs %>%
  group_by(player_role, suffix_name) %>%
  summarise(all_player_prob = mean(suffix_prob), .groups = "drop") %>%
  left_join(
    suffix_probs %>%
      filter(player_id %in% top_players) %>%
      group_by(player_role, suffix_name) %>%
      summarise(top_player_prob = mean(suffix_prob), .groups = "drop"),
    by = c("player_role", "suffix_name")
  ) %>%
  left_join(suffixes, by = "suffix_name") %>%
  mutate(
    all_player_bonus = all_player_prob * suffix_bonus,
    top_player_bonus = top_player_prob * suffix_bonus
  ) %>%
  select(
    player_role, 
    suffix_name, 
    suffix_desc, 
    all_player_prob,
    all_player_bonus,
    top_player_prob,
    top_player_bonus
  ) %>%
  arrange(player_role, desc(top_player_bonus))

write_csv(x = top_suffixes, file = "results/top_suffixes.csv")
