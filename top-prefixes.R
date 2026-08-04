source("config.R")
source("src/get-player-data.R")
source("src/get-team-data.R")
source("src/get-match-data.R")
source("src/get-hero-data.R")
source("src/calc-exp-summary.R")

library(tidyverse)
library(progress)
library(googlesheets4)

# Get data
teams_elim <- scan("data/teams_elim.csv", quiet = TRUE)
players <- get_player_data(league_id) %>% filter(!(team_id %in% teams_elim))
teams <- get_team_data(league_id)
top_players <- scan("data/top_players.csv", quiet = TRUE)
heroes <- get_hero_data(python_exe)
prefixes <- read_csv("data/prefixes.csv", show_col_types = FALSE)

match_ids <- get_match_ids(league_id)
match_ids_black <- scan(
  "data/matches/match_ids_black.csv", 
  quiet = TRUE
)
match_ids <- setdiff(match_ids, match_ids_black)
matches_odota <- get_match_odota_data(match_ids)

# Calculate prefix incidences
prefix_incids <- data.frame(
  player_id = as.numeric(),
  prefix_name = as.character(),
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
      
      # Cerulean
      ## +11% when playing a blue hero
      prefix_incids <- prefix_incids %>%
        add_row(
          !!!base_row,
          prefix_name = "Cerulean",
          cond = player$hero_id %in%
            (heroes %>% filter(blue == 1) %>% pull(hero_id))
        )

      # Crimson
      ## +6% when playing a red hero
      prefix_incids <- prefix_incids %>% 
        add_row(
          !!!base_row,
          prefix_name = "Crimson",
          cond = player$hero_id %in% 
            (heroes %>% filter(red == 1) %>% pull(hero_id))
        )
      
      # Elemental
      ## +8% when playing an Aquatic, Fiery, or Icy Hero
      prefix_incids <- prefix_incids %>% 
        add_row(
          !!!base_row,
          prefix_name = "Elemental",
          cond = player$hero_id %in% 
            (
              heroes %>% 
                filter(aquatic == 1 | fiery == 1 | icy == 1) %>% 
                pull(hero_id)
            )
        )
      
      # Emerald
      ## +6% when playing a green hero
      prefix_incids <- prefix_incids %>%
        add_row(
          !!!base_row,
          prefix_name = "Emerald",
          cond = player$hero_id %in%
            (heroes %>% filter(green == 1) %>% pull(hero_id))
        )

      # Golden
      ## +8% when playing a yellow or brown hero
      prefix_incids <- prefix_incids %>%
        add_row(
          !!!base_row,
          prefix_name = "Golden",
          cond = player$hero_id %in%
            (heroes %>% filter(yellow == 1 | brown == 1) %>% pull(hero_id))
        )

      # Heroic
      ## +9% when playing a Caped or Masked Hero
      prefix_incids <- prefix_incids %>%
        add_row(
          !!!base_row,
          prefix_name = "Heroic",
          cond = player$hero_id %in%
            (heroes %>% filter(cape == 1 | mask == 1) %>% pull(hero_id))
        )

      # Otherworldly
      ## +7% when playing an Undead, Demon, or Spirit Hero
      prefix_incids <- prefix_incids %>% 
        add_row(
          !!!base_row,
          prefix_name = "Otherworldly",
          cond = player$hero_id %in% 
            (
              heroes %>% filter(undead == 1 | demon == 1 | spirit == 1) %>% 
                pull(hero_id)
            )
        )
      
      # Royal
      ## +10% when playing a purple hero
      prefix_incids <- prefix_incids %>%
        add_row(
          !!!base_row,
          prefix_name = "Royal",
          cond = player$hero_id %in%
            (heroes %>% filter(purple == 1) %>% pull(hero_id))
        )
    }
  }

  progress$tick()
  rm(match, player, base_row)
}

# Calculate player-wise top prefixes
prefix_probs <- players %>% 
  select(player_id, player_role) %>%
  inner_join(prefix_incids, by = "player_id") %>%
  group_by(player_id, player_role, prefix_name) %>%
  arrange(time) %>%
  summarise(prefix_prob = calc_exp_summary(cond), .groups = "drop")

prefix_sums <- prefix_probs %>%
  left_join(prefixes, by = "prefix_name") %>%
  mutate(effective_bonus = (prefix_prob * prefix_bonus) / 100) %>%
  select(
    player_id, 
    player_role, 
    prefix_name, 
    prefix_bonus,
    prefix_prob,
    effective_bonus
  )

write_csv(x = prefix_sums, file = "results/all_prefixes.csv")

prefix_sums %>%
  left_join(players, by = c("player_id", "player_role")) %>%
  left_join(teams, by = "team_id") %>%
  pivot_wider(
    id_cols = c(player_name, team_name, player_role),
    names_from = prefix_name, 
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
    sheet = "Title Prefix Data"
  )

# Calculate top prefixes
top_prefixes <- prefix_probs %>%
  group_by(player_role, prefix_name) %>%
  summarise(all_player_prob = mean(prefix_prob), .groups = "drop") %>%
  left_join(
    prefix_probs %>%
      filter(player_id %in% top_players) %>%
      group_by(player_role, prefix_name) %>%
      summarise(top_player_prob = mean(prefix_prob), .groups = "drop"),
    by = c("player_role", "prefix_name")
  ) %>%
  left_join(prefixes, by = "prefix_name") %>%
  mutate(
    all_player_bonus = all_player_prob * prefix_bonus,
    top_player_bonus = top_player_prob * prefix_bonus
  ) %>%
  select(
    player_role, 
    prefix_name, 
    prefix_desc, 
    all_player_prob,
    all_player_bonus,
    top_player_prob,
    top_player_bonus
  ) %>%
  arrange(player_role, desc(top_player_bonus))

write_csv(x = top_prefixes, file = "results/top_prefixes.csv")
