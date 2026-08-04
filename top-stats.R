source("src/get-player-data.R")
source("src/get-team-data.R")
source("src/get-match-data.R")
source("src/calc-exp-summary.R")

library(tidyverse)
library(progress)
library(googlesheets4)

# Get data
league_id <- 18324
teams_elim <- scan("data/teams_elim.csv", quiet = TRUE)
players <- get_player_data(league_id) %>% filter(!(team_id %in% teams_elim))
teams <- get_team_data(league_id)

match_ids <- get_match_ids(players$player_id)
match_ids_black <- scan(
  "data/matches/match_ids_black.csv", 
  quiet = TRUE
)
match_ids <- setdiff(match_ids, match_ids_black)
matches_odota <- get_match_odota_data(match_ids)
matches_replay <- get_match_replay_data(match_ids)

# Calculate fantasy points
fantasy_points <- data.frame(
  player_id = as.numeric(),
  time = as.numeric(),
  emblem_colour = as.character(),
  emblem_stat = as.character(),
  points = as.numeric()
)

progress <- progress_bar$new(
  format = "(:spin) [:bar] :percent | ETA: :eta",
  total = length(match_ids),
  complete = "=",
  incomplete = "-",
  current = ">",
  clear = FALSE
)
for (match_id in match_ids) {
  odota_data <- matches_odota[[as.character(match_id)]]
  replay_data <- matches_replay[[as.character(match_id)]]
  
  for (player_id in replay_data$player_id) {
    if (player_id %in% players$player_id) {
      base_row <- list2(
        player_id = player_id,
        time = odota_data$start_time,
      )
      
      ## Kills
      fantasy_points <- fantasy_points %>% 
        add_row(
          !!!base_row,
          emblem_colour = "Red",
          emblem_stat = "Kills",
          points = replay_data %>%
            filter(player_id == !!player_id) %>%
            pull(kills) * 121
        ) 
      
      ## Deaths
      fantasy_points <- fantasy_points %>% 
        add_row(
          !!!base_row,
          emblem_colour = "Red",
          emblem_stat = "Deaths",
          points = replay_data %>%
            filter(player_id == !!player_id) %>%
            pull(deaths) * -180 + 1800
        )
      
      ## Creep Score
      fantasy_points <- fantasy_points %>% 
        add_row(
          !!!base_row,
          emblem_colour = "Red",
          emblem_stat = "Creep Score",
          points = replay_data %>%
            filter(player_id == !!player_id) %>%
            pull(creep_score) * 3
        )
      
      ## GPM
      fantasy_points <- fantasy_points %>% 
        add_row(
          !!!base_row,
          emblem_colour = "Red",
          emblem_stat = "GPM",
          points = replay_data %>%
            filter(player_id == !!player_id) %>%
            pull(gpm) * 2
        )
      
      ## Madstone Collected
      fantasy_points <- fantasy_points %>%
        add_row(
          !!!base_row,
          emblem_colour = "Red",
          emblem_stat = "Madstone Collected",
          points = replay_data %>%
            filter(player_id == !!player_id) %>%
            pull(neutral_tokens_found) * 19
        )
      
      ## Tower Kills
      fantasy_points <- fantasy_points %>% 
        add_row(
          !!!base_row,
          emblem_colour = "Red",
          emblem_stat = "Tower Kills",
          points = replay_data %>%
            filter(player_id == !!player_id) %>%
            pull(tower_kills) * 340
        )
      
      ## Wards Placed
      fantasy_points <- fantasy_points %>% 
        add_row(
          !!!base_row,
          emblem_colour = "Blue",
          emblem_stat = "Wards Placed",
          points = replay_data %>%
            filter(player_id == !!player_id) %>%
            pull(wards_placed) * 113
        )
      
      ## Camps Stacked
      fantasy_points <- fantasy_points %>% 
        add_row(
          !!!base_row,
          emblem_colour = "Blue",
          emblem_stat = "Camps Stacked",
          points = replay_data %>%
            filter(player_id == !!player_id) %>%
            pull(camps_stacked) * 170
        )
      
      ## Runes Grabbed
      fantasy_points <- fantasy_points %>% 
        add_row(
          !!!base_row,
          emblem_colour = "Blue",
          emblem_stat = "Runes Grabbed",
          points = replay_data %>%
            filter(player_id == !!player_id) %>%
            pull(runes_grabbed) * 121
        )
      
      ## Watchers Taken
      fantasy_points <- fantasy_points %>%
        add_row(
          !!!base_row,
          emblem_colour = "Blue",
          emblem_stat = "Watchers Taken",
          points = replay_data %>%
            filter(player_id == !!player_id) %>%
            pull(watchers_taken) * 121
        )
      
      ## Smokes Used
      fantasy_points <- fantasy_points %>% 
        add_row(
          !!!base_row,
          emblem_colour = "Blue",
          emblem_stat = "Smokes Used",
          points = replay_data %>%
            filter(player_id == !!player_id) %>%
            pull(smokes_used) * 283
        )
      
      ## Lotuses Grabbed
      fantasy_points <- fantasy_points %>%
        add_row(
          !!!base_row,
          emblem_colour = "Blue",
          emblem_stat = "Lotuses Grabbed",
          points = replay_data %>%
            filter(player_id == !!player_id) %>%
            pull(lotuses_grabbed) * 213
        )
      
      ## Roshan Kills
      fantasy_points <- fantasy_points %>% 
        add_row(
          !!!base_row,
          emblem_colour = "Green",
          emblem_stat = "Roshan Kills",
          points = replay_data %>%
            filter(player_id == !!player_id) %>%
            pull(roshan_kills) * 850
        )
      
      ## Teamfight Participation
      fantasy_points <- fantasy_points %>% 
        add_row(
          !!!base_row,
          emblem_colour = "Green",
          emblem_stat = "Teamfight Participation",
          points = replay_data %>%
            filter(player_id == !!player_id) %>%
            pull(teamfight_participation) * 1895
        )
      
      ## Stuns
      fantasy_points <- fantasy_points %>% 
        add_row(
          !!!base_row,
          emblem_colour = "Green",
          emblem_stat = "Stuns",
          points = replay_data %>%
            filter(player_id == !!player_id) %>%
            pull(stuns) * 15
        )
      
      ## Tormentor Kills
      fantasy_points <- fantasy_points %>% 
        add_row(
          !!!base_row,
          emblem_colour = "Green",
          emblem_stat = "Tormentor Kills",
          points = replay_data %>%
            filter(player_id == !!player_id) %>%
            pull(tormentor_kills) * 850
        )
      
      # First Blood
      fantasy_points <- fantasy_points %>% 
        add_row(
          !!!base_row,
          emblem_colour = "Green",
          emblem_stat = "First Blood",
          points = replay_data %>%
            filter(player_id == !!player_id) %>%
            pull(first_blood) * 1700
        )
      
      ## Courier Kills
      fantasy_points <- fantasy_points %>% 
        add_row(
          !!!base_row,
          emblem_colour = "Green",
          emblem_stat = "Courier Kills",
          points = replay_data %>%
            filter(player_id == !!player_id) %>%
            pull(courier_kills) * 850
        )
    }
  }
  
  progress$tick()
  rm(match_id, player_id, odota_data, replay_data, base_row)
}

# Calculate player-wise top stats
fantasy_sums <- players %>% 
  select(player_id, player_role) %>%
  inner_join(fantasy_points, by = "player_id") %>%
  group_by(player_id, player_role, emblem_colour, emblem_stat) %>%
  arrange(time) %>%
  summarise(
    average = calc_exp_summary(points, func = "average"),
    stddev = calc_exp_summary(points, func = "stddev"),
    .groups = "drop"
  )

write_csv(x = fantasy_sums, file = "results/all_stats.csv")

gs4_auth(scopes = "https://www.googleapis.com/auth/spreadsheets")

fantasy_sums %>%
  left_join(players, by = c("player_id", "player_role")) %>%
  left_join(teams, by = "team_id") %>%
  pivot_wider(
    id_cols = c(player_name, team_name, player_role),
    names_from = emblem_stat, 
    values_from = average,
    names_sort = TRUE
  ) %>%
  arrange(team_name, player_role, player_name) %>%
  rename(
    "Player Name" = "player_name", 
    "Team Name" = "team_name",
    "Role" = "player_role"
  ) %>%
  write_sheet(
    ss = "1U5X3r00hNPcafQpNTbWQwLi2Vja3JpAi42pDTBGmHHs", 
    sheet = "Emblem Stat Data (Avg)"
  )

fantasy_sums %>%
  left_join(players, by = c("player_id", "player_role")) %>%
  left_join(teams, by = "team_id") %>%
  pivot_wider(
    id_cols = c(player_name, team_name, player_role),
    names_from = emblem_stat, 
    values_from = stddev,
    names_sort = TRUE
  ) %>%
  arrange(team_name, player_role, player_name) %>%
  rename(
    "Player Name" = "player_name", 
    "Team Name" = "team_name",
    "Role" = "player_role"
  ) %>%
  write_sheet(
    ss = "1U5X3r00hNPcafQpNTbWQwLi2Vja3JpAi42pDTBGmHHs", 
    sheet = "Emblem Stat Data (Std)"
  )

# Calculate top players
top_cores <- bind_rows(
  fantasy_sums %>% 
    filter(player_role == "Core", emblem_colour == "Red") %>%
    group_by(player_id) %>%
    slice_max(order_by = average, n = 3) %>%
    ungroup(),
  fantasy_sums %>% 
    filter(player_role == "Core", emblem_colour == "Green") %>%
    group_by(player_id) %>%
    slice_max(order_by = average, n = 2) %>%
    ungroup()
) %>%
  group_by(player_id, player_role) %>%
  summarise(
    average = sum(average),
    stddev = sqrt(sum(stddev^2)),
    .groups = "drop"
  ) %>%
  arrange(desc(average))

top_mids <- bind_rows(
  fantasy_sums %>% 
    filter(player_role == "Mid", emblem_colour == "Red") %>%
    group_by(player_id) %>%
    slice_max(order_by = average, n = 2) %>%
    ungroup(),
  fantasy_sums %>% 
    filter(player_role == "Mid", emblem_colour == "Blue") %>%
    group_by(player_id) %>%
    slice_max(order_by = average, n = 1) %>%
    ungroup(),
  fantasy_sums %>% 
    filter(player_role == "Mid", emblem_colour == "Green") %>%
    group_by(player_id) %>%
    slice_max(order_by = average, n = 2) %>%
    ungroup()
) %>%
  group_by(player_id, player_role) %>%
  summarise(
    average = sum(average),
    stddev = sqrt(sum(stddev^2)),
    .groups = "drop"
  ) %>%
  arrange(desc(average))

top_supps <- bind_rows(
  fantasy_sums %>% 
    filter(player_role == "Support", emblem_colour == "Blue") %>%
    group_by(player_id) %>%
    slice_max(order_by = average, n = 3) %>%
    ungroup(),
  fantasy_sums %>% 
    filter(player_role == "Support", emblem_colour == "Green") %>%
    group_by(player_id) %>%
    slice_max(order_by = average, n = 2) %>%
    ungroup()
) %>%
  group_by(player_id, player_role) %>%
  summarise(
    average = sum(average),
    stddev = sqrt(sum(stddev^2)),
    .groups = "drop"
  ) %>%
  arrange(desc(average))

top_players <- bind_rows(
  top_cores %>% head(4),
  top_mids %>% head(3),
  top_supps %>% head(4)
)

write_csv(
  x = top_players %>% select(player_id),
  file = "data/top_players.csv",
  col_names = FALSE
)
write_csv(
  x = top_players %>%
    left_join(players, by = c("player_id", "player_role")) %>%
    left_join(teams, by = "team_id") %>%
    select(player_name, team_name, player_role, average, stddev),
  file = "results/top_players.csv"
)

# Calculate top stats
top_stats <- fantasy_sums %>%
  group_by(player_role, emblem_colour, emblem_stat) %>%
  summarise(
    all_player_average = mean(average), 
    all_player_stddev = mean(stddev), 
    .groups = "drop"
  ) %>%
  left_join(
    fantasy_sums %>%
      filter(player_id %in% (top_players %>% pull(player_id))) %>%
      group_by(player_role, emblem_colour, emblem_stat) %>%
      summarise(
        top_player_average = mean(average), 
        top_player_stddev = mean(stddev), 
        .groups = "drop"
      ),
    by = c("player_role", "emblem_colour", "emblem_stat")
  ) %>%
  filter(
    (player_role == "Core" & emblem_colour %in% c("Red", "Green")) |
      player_role == "Mid" |
      (player_role == "Support" & emblem_colour %in% c("Blue", "Green"))
  ) %>%
  arrange(player_role, emblem_colour, desc(top_player_average))

write_csv(x = top_stats, file = "results/top_stats.csv")
