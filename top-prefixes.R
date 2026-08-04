source("src/get-player-data.R")
source("src/get-team-data.R")
source("src/get-match-data.R")
source("src/get-hero-data.R")
source("src/calc-exp-summary.R")

library(tidyverse)
library(progress)
library(googlesheets4)

# Get data
league_id <- 18324
teams_elim <- scan("data/teams_elim.csv", quiet = TRUE)
players <- get_player_data(league_id) %>% filter(!(team_id %in% teams_elim))
teams <- get_team_data(league_id)
top_players <- scan("data/top_players.csv", quiet = TRUE)
heroes <- get_hero_data("C:/Users/Viren/.conda/envs/dota-compendium/python.exe")
prefixes <- read_csv("data/prefixes.csv", show_col_types = FALSE)

match_ids <- get_match_ids(league_id)
match_ids_black <- scan(
  "data/matches/match_ids_black.csv", 
  quiet = TRUE
)
match_ids <- setdiff(match_ids, match_ids_black)
matches_odota <- get_match_odota_data(match_ids)
matches_stratz <- get_match_stratz_data(match_ids)

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
  picks <- if (is.null(unlist(match$picks_bans))) {
    NULL
  } else {
    match$picks_bans %>% bind_rows() %>% filter(is_pick == TRUE)
  }
  
  for (player in match$players) {
    if (player$account_id %in% players$player_id) {
      base_row <- list2(
        player_id = player$account_id,
        time = match$start_time,
      )
      
      # Balanced
      ## +8% when playing a Universal Hero
      prefix_incids <- prefix_incids %>%
        add_row(
          !!!base_row,
          prefix_name = "Balanced",
          cond = player$hero_id %in%
            (heroes %>% filter(universal == 1) %>% pull(hero_id))
        )
      
      # Bestial
      ## +17% if playing a hero with Horns or Wings
      prefix_incids <- prefix_incids %>%
        add_row(
          !!!base_row,
          prefix_name = "Bestial",
          cond = player$hero_id %in%
            (heroes %>% filter(horns == 1 | wings == 1) %>% pull(hero_id))
        )
      
      # Brawny
      ## +13% when playing a Strength Hero
      prefix_incids <- prefix_incids %>% 
        add_row(
          !!!base_row,
          prefix_name = "Brawny",
          cond = player$hero_id %in% 
            (heroes %>% filter(strength == 1) %>% pull(hero_id))
        )
      
      # Canny
      ## +21% when playing an Intelligence Hero
      prefix_incids <- prefix_incids %>% 
        add_row(
          !!!base_row,
          prefix_name = "Canny",
          cond = player$hero_id %in% 
            (heroes %>% filter(intelligence == 1) %>% pull(hero_id))
        )
      
      # Cerulean
      ## +22% when playing a Blue Hero
      prefix_incids <- prefix_incids %>% 
        add_row(
          !!!base_row,
          prefix_name = "Cerulean",
          cond = player$hero_id %in% 
            (heroes %>% filter(blue == 1) %>% pull(hero_id))
        )
      
      # Clutch
      ## +10% when playing the last possible match of a series
      prefix_incids <- prefix_incids %>%
        add_row(
          !!!base_row,
          prefix_name = "Clutch",
          cond = series %>% filter(match_id == match$match_id) %>% pull(clutch)
        )
      
      # Coveted
      ## +19% when that player's hero is chosen last
      prefix_incids <- prefix_incids %>%
        add_row(
          !!!base_row,
          prefix_name = "Coveted",
          cond = if (is.null(picks)) {
            NA
          } else {
            picks %>%
              filter(team == filter(picks, hero_id == player$hero_id)$team) %>%
              slice_max(order_by = order, n = 1) %>%
              pull(hero_id) == player$hero_id
          }
        )
      
      # Crimson
      ## +6% when playing a Red Hero
      prefix_incids <- prefix_incids %>% 
        add_row(
          !!!base_row,
          prefix_name = "Crimson",
          cond = player$hero_id %in% 
            (heroes %>% filter(red == 1) %>% pull(hero_id))
        )
      
      # Dashing
      ## +16% when playing an Agility Hero
      prefix_incids <- prefix_incids %>% 
        add_row(
          !!!base_row,
          prefix_name = "Dashing",
          cond = player$hero_id %in% 
            (heroes %>% filter(agility == 1) %>% pull(hero_id))
        )
      
      # Elemental
      ## +16% when playing an Aquatic, Fiery, or Icy Hero
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
      ## +22% when playing a Green Hero
      prefix_incids <- prefix_incids %>% 
        add_row(
          !!!base_row,
          prefix_name = "Emerald",
          cond = player$hero_id %in% 
            (heroes %>% filter(green == TRUE) %>% pull(hero_id))
        )
      
      # Glamorous
      ## +25% when the player has an Arcana equipped
      prefix_incids <- prefix_incids %>%
        add_row(
          !!!base_row,
          prefix_name = "Glamorous",
          cond = if (length(player$cosmetics) == 0) {
            FALSE
          } else {
            sapply(
              X = player$cosmetics,
              FUN = function(x) {
                if (is.null(unlist(x$item_rarity)) | 
                    is.null(unlist(x$used_by_heroes))) {
                  FALSE
                } else {
                  if (x$used_by_heroes %in% heroes$hero_name) {
                    x$item_rarity == "arcana"
                  } else {
                    FALSE
                  }
                }
              }
            ) %>%
              sum() > 0
          }
        )
      
      # Hirsute
      ## +12% when playing a Bearded or Fuzzy Hero
      prefix_incids <- prefix_incids %>% 
        add_row(
          !!!base_row,
          prefix_name = "Hirsute",
          cond = player$hero_id %in% 
            (heroes %>% filter(bearded == 1 | fuzzy == 1) %>% pull(hero_id))
        )
      
      # Otherworldly
      ## +24% when playing an Undead, Demon, or Spirit Hero
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
      
      # Sacrificial
      ## +19% when that player's hero is chosen first
      prefix_incids <- prefix_incids %>%
        add_row(
          !!!base_row,
          prefix_name = "Sacrificial",
          cond = if (is.null(picks)) {
            NA
          } else {
            picks %>%
              filter(team == filter(picks, hero_id == player$hero_id)$team) %>%
              slice_min(order_by = order, n = 1) %>%
              pull(hero_id) == player$hero_id
          }
        )
    }
  }
  
  progress$tick()
  rm(match, player, base_row, picks)
}

progress <- progress_bar$new(
  format = "(:spin) [:bar] :percent | ETA: :eta",
  total = length(match_ids),
  complete = "=",
  incomplete = "-",
  current = ">",
  clear = FALSE
)
for (match in matches_stratz) {
  for (player in match$match$players) {
    if (player$steamAccountId %in% players$player_id) {
      base_row <- list2(
        player_id = player$steamAccountId,
        time = match$match$startDateTime,
      )
      
      # Virtuoso
      ## +22% when playing a hero they are a Master or Grandmaster with
      prefix_incids <- prefix_incids %>%
        add_row(
          !!!base_row,
          prefix_name = "Virtuoso",
          cond = if(is.null(player$dotaPlus$level)) {
            FALSE
          } else {
            player$dotaPlus$level >= 25
          }
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
    ss = "1U5X3r00hNPcafQpNTbWQwLi2Vja3JpAi42pDTBGmHHs", 
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
