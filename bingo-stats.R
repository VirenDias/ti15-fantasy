source("src/get-player-data.R")
source("src/get-match-data.R")
source("src/get-hero-data.R")
source("src/get-bingo-data.R")
source("src/calc-exp-summary.R")

library(tidyverse)
library(progress)
library(googlesheets4)

# Get data
teams_elim <- scan("data/teams_elim.csv", quiet = TRUE)
players <- get_player_data(league_id) %>% filter(!(team_id %in% teams_elim))
heroes <- get_hero_data("C:/Users/Viren/.conda/envs/dota-compendium/python.exe")
bingo_squares <- get_bingo_data(
  "C:/Users/Viren/.conda/envs/dota-compendium/python.exe"
)

match_ids <- get_match_ids(players$player_id)
match_ids_black <- scan(
  "data/matches/match_ids_black.csv", 
  quiet = TRUE
)
match_ids <- setdiff(match_ids, match_ids_black)
matches_odota <- get_match_odota_data(match_ids)
matches_stratz <- get_match_stratz_data(match_ids)


# Calculate the bingo square stats
bingo_stats <- bingo_squares %>% 
  mutate(average = as.numeric(NA), stddev = as.numeric(NA))

progress <- progress_bar$new(
  format = "(:spin) [:bar] :percent | ETA: eta",
  total = 137,
  complete = "=",
  incomplete = "-",
  current = ">",
  clear = FALSE
)

## Kill streak stats
kill_streak <- function(matches, streak, threshold) {
  results <- c()
  for (match in matches) {
    metric <- 0
    for (player in match$players) {
      if (streak %in% names(player$kill_streaks)) {
        metric <- metric + player$kill_streaks[[as.character(streak)]]
      }
    }
    if (metric >= threshold) {
      results <- c(results, 1)
    } else {
      results <- c(results, 0)
    }
  }
  return(
    tibble(
      average = calc_exp_summary(results, func = "average"),
      stddev = calc_exp_summary(results, func = "stddev")
    )
  )
}

bingo_stats <- bingo_stats %>% rows_update(
  tibble(
    name = "Divine Intervention",
    desc = "At least 1 Godlike kill streak in a match.",
    kill_streak(matches_odota, 9, 1)
  ),
  by = c("name", "desc")
)
progress$tick()
bingo_stats <- bingo_stats %>% rows_update(
  tibble(
    name = "Divine Intervention",
    desc = "At least 2 Godlike kill streaks in a match.",
    kill_streak(matches_odota, 9, 2)
  ),
  by = c("name", "desc")
)
progress$tick()
bingo_stats <- bingo_stats %>% rows_update(
  tibble(
    name = "Divine Intervention",
    desc = "At least 3 Godlike kill streaks in a match.",
    kill_streak(matches_odota, 9, 3)
  ),
  by = c("name", "desc")
)
progress$tick()
bingo_stats <- bingo_stats %>% rows_update(
  tibble(
    name = "Divine Retribution",
    desc = "A player achieves a Beyond Godlike kill streak in a match.",
    kill_streak(matches_odota, 10, 1)
  ),
  by = c("name", "desc")
)
progress$tick()
bingo_stats <- bingo_stats %>% rows_update(
  tibble(
    name = "Divine Retribution",
    desc = "At least 2 Beyond Godlike kill streaks in a match.",
    kill_streak(matches_odota, 10, 2)
  ),
  by = c("name", "desc")
)
progress$tick()
bingo_stats <- bingo_stats %>% rows_update(
  tibble(
    name = "Mega Mega Kill",
    desc = "At least 4 Mega Kill streaks in a match.",
    kill_streak(matches_odota, 5, 4)
  ),
  by = c("name", "desc")
)
progress$tick()
bingo_stats <- bingo_stats %>% rows_update(
  tibble(
    name = "Mega Mega Kill",
    desc = "At least 5 Mega Kill streaks in a match.",
    kill_streak(matches_odota, 5, 5)
  ),
  by = c("name", "desc")
)
progress$tick()
bingo_stats <- bingo_stats %>% rows_update(
  tibble(
    name = "Monstrous Mayhem",
    desc = "At least 1 Monster kill streak in a match.",
    kill_streak(matches_odota, 8, 1)
  ),
  by = c("name", "desc")
)
progress$tick()
bingo_stats <- bingo_stats %>% rows_update(
  tibble(
    name = "Monstrous Mayhem",
    desc = "At least 2 Monster kill streaks in a match.",
    kill_streak(matches_odota, 8, 2)
  ),
  by = c("name", "desc")
)
progress$tick()
bingo_stats <- bingo_stats %>% rows_update(
  tibble(
    name = "Monstrous Mayhem",
    desc = "At least 3 Monster kill streaks in a match.",
    kill_streak(matches_odota, 8, 3)
  ),
  by = c("name", "desc")
)
progress$tick()
bingo_stats <- bingo_stats %>% rows_update(
  tibble(
    name = "Something Wicked",
    desc = "At least 2 Wicked Sick kill streaks in a match.",
    kill_streak(matches_odota, 7, 2)
  ),
  by = c("name", "desc")
)
progress$tick()
bingo_stats <- bingo_stats %>% rows_update(
  tibble(
    name = "Something Wicked",
    desc = "At least 3 Wicked Sick kill streaks in a match.",
    kill_streak(matches_odota, 7, 3)
  ),
  by = c("name", "desc")
)
progress$tick()
bingo_stats <- bingo_stats %>% rows_update(
  tibble(
    name = "Something Wicked",
    desc = "At least 4 Wicked Sick kill streaks in a match.",
    kill_streak(matches_odota, 7, 4)
  ),
  by = c("name", "desc")
)
progress$tick()
bingo_stats <- bingo_stats %>% rows_update(
  tibble(
    name = "Truly Unstoppable",
    desc = "At least 3 Unstoppable kill streaks in a match.",
    kill_streak(matches_odota, 6, 3)
  ),
  by = c("name", "desc")
)
progress$tick()
bingo_stats <- bingo_stats %>% rows_update(
  tibble(
    name = "Truly Unstoppable",
    desc = "At least 4 Unstoppable kill streaks in a match.",
    kill_streak(matches_odota, 6, 4)
  ),
  by = c("name", "desc")
)
progress$tick()
bingo_stats <- bingo_stats %>% rows_update(
  tibble(
    name = "Truly Unstoppable",
    desc = "At least 5 Unstoppable kill streaks in a match.",
    kill_streak(matches_odota, 6, 5)
  ),
  by = c("name", "desc")
)
progress$tick()

## Multi kill stats
multi_kill <- function(matches, multi, threshold) {
  results <- c()
  for (match in matches) {
    metric <- 0
    for (player in match$players) {
      if (multi %in% names(player$multi_kills)) {
        metric <- metric + player$multi_kills[[as.character(multi)]]
      }
    }
    if (metric >= threshold) {
      results <- c(results, 1)
    } else {
      results <- c(results, 0)
    }
  }
  return(
    tibble(
      average = calc_exp_summary(results, func = "average"),
      stddev = calc_exp_summary(results, func = "stddev")
    )
  )
}

bingo_stats <- bingo_stats %>% rows_update(
  tibble(
    name = "Double Deca",
    desc = "At least 10 double kills in a match.",
    multi_kill(matches_odota, 2, 10)
  ),
  by = c("name", "desc")
)
progress$tick()
bingo_stats <- bingo_stats %>% rows_update(
  tibble(
    name = "Double Time",
    desc = "At least 15 double kills in a match.",
    multi_kill(matches_odota, 2, 15)
  ),
  by = c("name", "desc")
)
progress$tick()
bingo_stats <- bingo_stats %>% rows_update(
  tibble(
    name = "Call It a Rampage",
    desc = "A player gets a Rampage in a match.",
    multi_kill(matches_odota, 5, 1)
  ),
  by = c("name", "desc")
)
progress$tick()
bingo_stats <- bingo_stats %>% rows_update(
  tibble(
    name = "Quad Trio",
    desc = "At least 4 triple kills in a match.",
    multi_kill(matches_odota, 3, 4)
  ),
  by = c("name", "desc")
)
progress$tick()
bingo_stats <- bingo_stats %>% rows_update(
  tibble(
    name = "Three for Three",
    desc = "At least 3 triple kills in a match.",
    multi_kill(matches_odota, 3, 3)
  ),
  by = c("name", "desc")
)
progress$tick()
bingo_stats <- bingo_stats %>% rows_update(
  tibble(
    name = "Ultra Cool",
    desc = "At least 1 ultra kill occurs in a match.",
    multi_kill(matches_odota, 4, 1)
  ),
  by = c("name", "desc")
)
progress$tick()
bingo_stats <- bingo_stats %>% rows_update(
  tibble(
    name = "Ultra Cool",
    desc = "At least 2 ultra kills occurs in a match.",
    multi_kill(matches_odota, 4, 2)
  ),
  by = c("name", "desc")
)
progress$tick()
bingo_stats <- bingo_stats %>% rows_update(
  tibble(
    name = "Ultra Cool",
    desc = "At least 3 ultra kills occurs in a match.",
    multi_kill(matches_odota, 4, 3)
  ),
  by = c("name", "desc")
)
progress$tick()

## Item purchase stats
item_purchase <- function(matches, item, threshold, team = FALSE) {
  results <- c()
  for (match in matches) {
    metric_1 <- 0
    metric_2 <- 0
    result <- 0
    for (player in match$players) {
      for (purchase in player$purchase_log) {
        if (purchase$key == item) {
          if (player$team_number == 0) metric_1 <- metric_1 + 1
          if (player$team_number == 1) metric_2 <- metric_2 + 1
        }
      }
    }
    if (team) {
      if (metric_1 >= threshold) result <- 1
      if (metric_2 >= threshold) result <- 1
    } else {
      if ((metric_1 + metric_2) >= threshold) result <- 1
    }
    results <- c(results, result)
  }
  return(
    tibble(
      average = calc_exp_summary(results, func = "average"),
      stddev = calc_exp_summary(results, func = "stddev")
    )
  )
}

bingo_stats <- bingo_stats %>% rows_update(
  tibble(
    name = "Blink and You'll Miss It",
    desc = "At least 5 blink daggers are purchased in a single match.",
    item_purchase(matches_odota, "blink", 5)
  ),
  by = c("name", "desc")
)
progress$tick()
bingo_stats <- bingo_stats %>% rows_update(
  tibble(
    name = "Dagon Enthusiast",
    desc = "Dagon Level 5 is purchased in a match.",
    item_purchase(matches_odota, "dagon_5", 1)
  ),
  by = c("name", "desc")
)
progress$tick()
bingo_stats <- bingo_stats %>% rows_update(
  tibble(
    name = "Hammer Time",
    desc = "A team purchases at least 2 meteor hammers in a match.",
    item_purchase(matches_odota, "meteor_hammer", 2, TRUE)
  ),
  by = c("name", "desc")
)
progress$tick()
bingo_stats <- bingo_stats %>% rows_update(
  tibble(
    name = "Kingmaker",
    desc = "At least 3 BKBs are purchased in a single match.",
    item_purchase(matches_odota, "black_king_bar", 3)
  ),
  by = c("name", "desc")
)
progress$tick()
bingo_stats <- bingo_stats %>% rows_update(
  tibble(
    name = "Kingmaker",
    desc = "At least 5 BKBs are purchased in a single match.",
    item_purchase(matches_odota, "black_king_bar", 5)
  ),
  by = c("name", "desc")
)
progress$tick()
bingo_stats <- bingo_stats %>% rows_update(
  tibble(
    name = "Look Sharp",
    desc = "At least 1 Divine Rapier is purchased in a match.",
    item_purchase(matches_odota, "rapier", 1)
  ),
  by = c("name", "desc")
)
progress$tick()
bingo_stats <- bingo_stats %>% rows_update(
  tibble(
    name = "Moonlit",
    desc = "At least 1 player buys a Moon Shard in a match.",
    item_purchase(matches_odota, "moon_shard", 1)
  ),
  by = c("name", "desc")
)
progress$tick()
bingo_stats <- bingo_stats %>% rows_update(
  tibble(
    name = "Solidly Gold",
    desc = "At least 2 Hand of Midases bought in a match.",
    item_purchase(matches_odota, "hand_of_midas", 2)
  ),
  by = c("name", "desc")
)
progress$tick()
bingo_stats <- bingo_stats %>% rows_update(
  tibble(
    name = "Solidly Gold",
    desc = "At least 3 Hand of Midases bought in a match.",
    item_purchase(matches_odota, "hand_of_midas", 3)
  ),
  by = c("name", "desc")
)
progress$tick()

## Hero pick stats
hero_pick <- function(matches, heroes, category, threshold, boundary) {
  results <- c()
  for (match in matches) {
    team_1 <- c()
    team_2 <- c()
    result <- 0
    for (pick in match$picks_bans) {
      if (pick$is_pick == TRUE) {
        if (pick$team == 0) team_1 <- c(team_1, pick$hero_id)
        if (pick$team == 1) team_2 <- c(team_2, pick$hero_id)
      }
    }
    
    metric_1 <- heroes %>% 
      filter(hero_id %in% team_1) %>%
      pull(!!category) %>%
      sum()
    metric_2 <- heroes %>% 
      filter(hero_id %in% team_2) %>%
      pull(!!category) %>%
      sum()
    
    if (boundary == "upper") {
      if (metric_1 <= threshold) result <- result + 1
      if (metric_2 <= threshold) result <- result + 1
    }
    if (boundary == "lower") {
      if (metric_1 >= threshold) result <- result + 1
      if (metric_2 >= threshold) result <- result + 1
    }
    results <- c(results, result)
  }
  
  return(
    tibble(
      average = calc_exp_summary(results, func = "average"),
      stddev = calc_exp_summary(results, func = "stddev")
    )
  )
}

bingo_stats <- bingo_stats %>% rows_update(
  tibble(
    name = "Caped Crew",
    desc = "Team has at least 2 caped heroes.",
    hero_pick(matches_odota, heroes, "cape", 2, "lower")
  ),
  by = c("name", "desc")
)
progress$tick()
bingo_stats <- bingo_stats %>% rows_update(
  tibble(
    name = "Caped Crew",
    desc = "Team has at least 3 caped heroes.",
    hero_pick(matches_odota, heroes, "cape", 3, "lower")
  ),
  by = c("name", "desc")
)
progress$tick()
bingo_stats <- bingo_stats %>% rows_update(
  tibble(
    name = "Devil's Duo",
    desc = "Team has at least 2 demonic heroes.",
    hero_pick(matches_odota, heroes, "demon", 2, "lower")
  ),
  by = c("name", "desc")
)
progress$tick()
bingo_stats <- bingo_stats %>% rows_update(
  tibble(
    name = "Devil's Trio",
    desc = "Team has at least 3 demonic heroes.",
    hero_pick(matches_odota, heroes, "demon", 3, "lower")
  ),
  by = c("name", "desc")
)
progress$tick()
bingo_stats <- bingo_stats %>% rows_update(
  tibble(
    name = "Flock Jocks",
    desc = "Team has at least 2 heroes with wings.",
    hero_pick(matches_odota, heroes, "wings", 2, "lower")
  ),
  by = c("name", "desc")
)
progress$tick()
bingo_stats <- bingo_stats %>% rows_update(
  tibble(
    name = "Flock Jocks",
    desc = "Team has at least 3 heroes with wings.",
    hero_pick(matches_odota, heroes, "wings", 3, "lower")
  ),
  by = c("name", "desc")
)
progress$tick()
bingo_stats <- bingo_stats %>% rows_update(
  tibble(
    name = "Friendly Fire",
    desc = "Team has at least 2 fiery heroes.",
    hero_pick(matches_odota, heroes, "fiery", 2, "lower")
  ),
  by = c("name", "desc")
)
progress$tick()
bingo_stats <- bingo_stats %>% rows_update(
  tibble(
    name = "Friendly Fire",
    desc = "Team has at least 3 fiery heroes.",
    hero_pick(matches_odota, heroes, "fiery", 3, "lower")
  ),
  by = c("name", "desc")
)
progress$tick()
bingo_stats <- bingo_stats %>% rows_update(
  tibble(
    name = "Fuzzy Wuzzy",
    desc = "Team has at least 2 fuzzy heroes.",
    hero_pick(matches_odota, heroes, "fuzzy", 2, "lower")
  ),
  by = c("name", "desc")
)
progress$tick()
bingo_stats <- bingo_stats %>% rows_update(
  tibble(
    name = "Fuzzy Wuzzy",
    desc = "Team has at least 3 fuzzy heroes.",
    hero_pick(matches_odota, heroes, "fuzzy", 3, "lower")
  ),
  by = c("name", "desc")
)
progress$tick()
bingo_stats <- bingo_stats %>% rows_update(
  tibble(
    name = "Girl Power",
    desc = "Team has at least 2 female heroes.",
    hero_pick(matches_odota, heroes, "female", 2, "lower")
  ),
  by = c("name", "desc")
)
progress$tick()
bingo_stats <- bingo_stats %>% rows_update(
  tibble(
    name = "Girl Power",
    desc = "Team has at least 3 female heroes.",
    hero_pick(matches_odota, heroes, "female", 3, "lower")
  ),
  by = c("name", "desc")
)
progress$tick()
bingo_stats <- bingo_stats %>% rows_update(
  tibble(
    name = "Gruesome Grills",
    desc = "Team has at least 2 heroes with bad teeth.",
    hero_pick(matches_odota, heroes, "bad_teeth", 2, "lower")
  ),
  by = c("name", "desc")
)
progress$tick()
bingo_stats <- bingo_stats %>% rows_update(
  tibble(
    name = "Gruesome Grills",
    desc = "Team has at least 3 heroes with bad teeth.",
    hero_pick(matches_odota, heroes, "bad_teeth", 3, "lower")
  ),
  by = c("name", "desc")
)
progress$tick()
bingo_stats <- bingo_stats %>% rows_update(
  tibble(
    name = "Gym Rats",
    desc = "Team has at least 2 heroes that have nice pecs.",
    hero_pick(matches_odota, heroes, "nice_pecs", 2, "lower")
  ),
  by = c("name", "desc")
)
progress$tick()
bingo_stats <- bingo_stats %>% rows_update(
  tibble(
    name = "Gym Rats",
    desc = "Team has at least 3 heroes that have nice pecs.",
    hero_pick(matches_odota, heroes, "nice_pecs", 3, "lower")
  ),
  by = c("name", "desc")
)
progress$tick()
bingo_stats <- bingo_stats %>% rows_update(
  tibble(
    name = "High Flyers",
    desc = "Team has at least 2 flying heroes.",
    hero_pick(matches_odota, heroes, "flying", 2, "lower")
  ),
  by = c("name", "desc")
)
progress$tick()
bingo_stats <- bingo_stats %>% rows_update(
  tibble(
    name = "High Flyers",
    desc = "Team has at least 3 flying heroes.",
    hero_pick(matches_odota, heroes, "flying", 3, "lower")
  ),
  by = c("name", "desc")
)
progress$tick()
bingo_stats <- bingo_stats %>% rows_update(
  tibble(
    name = "Horse Play",
    desc = "Team has at least 2 heroes with steeds.",
    hero_pick(matches_odota, heroes, "steed", 2, "lower")
  ),
  by = c("name", "desc")
)
progress$tick()
bingo_stats <- bingo_stats %>% rows_update(
  tibble(
    name = "Horse Play",
    desc = "Team has at least 3 heroes with steeds.",
    hero_pick(matches_odota, heroes, "steed", 3, "lower")
  ),
  by = c("name", "desc")
)
progress$tick()
bingo_stats <- bingo_stats %>% rows_update(
  tibble(
    name = "Huggable Heroes",
    desc = "Team has at least 2 cute heroes.",
    hero_pick(matches_odota, heroes, "cute", 2, "lower")
  ),
  by = c("name", "desc")
)
progress$tick()
bingo_stats <- bingo_stats %>% rows_update(
  tibble(
    name = "Huggable Heroes",
    desc = "Team has at least 3 cute heroes.",
    hero_pick(matches_odota, heroes, "cute", 3, "lower")
  ),
  by = c("name", "desc")
)
progress$tick()
bingo_stats <- bingo_stats %>% rows_update(
  tibble(
    name = "Ice Cold",
    desc = "Team has at least 2 icy heroes.",
    hero_pick(matches_odota, heroes, "icy", 2, "lower")
  ),
  by = c("name", "desc")
)
progress$tick()
bingo_stats <- bingo_stats %>% rows_update(
  tibble(
    name = "Ice Cold",
    desc = "Team has at least 3 icy heroes.",
    hero_pick(matches_odota, heroes, "icy", 3, "lower")
  ),
  by = c("name", "desc")
)
progress$tick()
bingo_stats <- bingo_stats %>% rows_update(
  tibble(
    name = "Kindred Spirits",
    desc = "Team has at least 2 spirit heroes.",
    hero_pick(matches_odota, heroes, "spirit", 2, "lower")
  ),
  by = c("name", "desc")
)
progress$tick()
bingo_stats <- bingo_stats %>% rows_update(
  tibble(
    name = "Kindred Spirits",
    desc = "Team has at least 3 spirit heroes.",
    hero_pick(matches_odota, heroes, "spirit", 3, "lower")
  ),
  by = c("name", "desc")
)
progress$tick()
bingo_stats <- bingo_stats %>% rows_update(
  tibble(
    name = "Legged Legion",
    desc = "A team has at least 14 legs.",
    hero_pick(matches_odota, heroes, "legs", 14, "lower")
  ),
  by = c("name", "desc")
)
progress$tick()
bingo_stats <- bingo_stats %>% rows_update(
  tibble(
    name = "Legged Legion",
    desc = "A team has at least 15 legs.",
    hero_pick(matches_odota, heroes, "legs", 15, "lower")
  ),
  by = c("name", "desc")
)
progress$tick()
bingo_stats <- bingo_stats %>% rows_update(
  tibble(
    name = "Lock Horns",
    desc = "Team has at least 2 horned heroes.",
    hero_pick(matches_odota, heroes, "horns", 2, "lower")
  ),
  by = c("name", "desc")
)
progress$tick()
bingo_stats <- bingo_stats %>% rows_update(
  tibble(
    name = "Lock Horns",
    desc = "Team has at least 3 horned heroes.",
    hero_pick(matches_odota, heroes, "horns", 3, "lower")
  ),
  by = c("name", "desc")
)
progress$tick()
bingo_stats <- bingo_stats %>% rows_update(
  tibble(
    name = "Marine Mayhem",
    desc = "Team has at least 2 aquatic heroes.",
    hero_pick(matches_odota, heroes, "aquatic", 2, "lower")
  ),
  by = c("name", "desc")
)
progress$tick()
bingo_stats <- bingo_stats %>% rows_update(
  tibble(
    name = "Marine Mayhem",
    desc = "Team has at least 3 aquatic heroes.",
    hero_pick(matches_odota, heroes, "aquatic", 3, "lower")
  ),
  by = c("name", "desc")
)
progress$tick()
bingo_stats <- bingo_stats %>% rows_update(
  tibble(
    name = "No Leg Strategy",
    desc = "A team has at most 5 legs.",
    hero_pick(matches_odota, heroes, "legs", 5, "upper")
  ),
  by = c("name", "desc")
)
progress$tick()
bingo_stats <- bingo_stats %>% rows_update(
  tibble(
    name = "No Leg Strategy",
    desc = "Team has at most 6 legs.",
    hero_pick(matches_odota, heroes, "legs", 6, "upper")
  ),
  by = c("name", "desc")
)
progress$tick()
bingo_stats <- bingo_stats %>% rows_update(
  tibble(
    name = "Parental Unit",
    desc = "Team has at least 2 heroes that are parents.",
    hero_pick(matches_odota, heroes, "parent", 2, "lower")
  ),
  by = c("name", "desc")
)
progress$tick()
bingo_stats <- bingo_stats %>% rows_update(
  tibble(
    name = "Parental Unit",
    desc = "Team has at least 3 heroes that are parents.",
    hero_pick(matches_odota, heroes, "parent", 3, "lower")
  ),
  by = c("name", "desc")
)
progress$tick()
bingo_stats <- bingo_stats %>% rows_update(
  tibble(
    name = "Portly Party",
    desc = "Team has at least 2 heroes that have a potbelly.",
    hero_pick(matches_odota, heroes, "potbelly", 2, "lower")
  ),
  by = c("name", "desc")
)
progress$tick()
bingo_stats <- bingo_stats %>% rows_update(
  tibble(
    name = "Portly Party",
    desc = "Team has at least 3 heroes that have a potbelly.",
    hero_pick(matches_odota, heroes, "potbelly", 3, "lower")
  ),
  by = c("name", "desc")
)
progress$tick()
bingo_stats <- bingo_stats %>% rows_update(
  tibble(
    name = "Snout Deficit",
    desc = "A team has at most 2 noses.",
    hero_pick(matches_odota, heroes, "nose", 2, "upper")
  ),
  by = c("name", "desc")
)
progress$tick()
bingo_stats <- bingo_stats %>% rows_update(
  tibble(
    name = "Snout Deficit",
    desc = "A team has at most 3 noses.",
    hero_pick(matches_odota, heroes, "nose", 3, "upper")
  ),
  by = c("name", "desc")
)
progress$tick()
bingo_stats <- bingo_stats %>% rows_update(
  tibble(
    name = "Spider Bitten",
    desc = "Team has at least 2 heroes that are arachnophobic.",
    hero_pick(matches_odota, heroes, "arachnophobic", 2, "lower")
  ),
  by = c("name", "desc")
)
progress$tick()
bingo_stats <- bingo_stats %>% rows_update(
  tibble(
    name = "Spider Bitten",
    desc = "Team has at least 3 heroes that are arachnophobic.",
    hero_pick(matches_odota, heroes, "arachnophobic", 3, "lower")
  ),
  by = c("name", "desc")
)
progress$tick()
bingo_stats <- bingo_stats %>% rows_update(
  tibble(
    name = "Three-Beard",
    desc = "Team has at least 3 heroes with a beard.",
    hero_pick(matches_odota, heroes, "bearded", 3, "lower")
  ),
  by = c("name", "desc")
)
progress$tick()
bingo_stats <- bingo_stats %>% rows_update(
  tibble(
    name = "Two-Beard",
    desc = "Team has at least 2 heroes with a beard.",
    hero_pick(matches_odota, heroes, "bearded", 2, "lower")
  ),
  by = c("name", "desc")
)
progress$tick()
bingo_stats <- bingo_stats %>% rows_update(
  tibble(
    name = "Undeadly Duo",
    desc = "Team has at least 2 undead heroes.",
    hero_pick(matches_odota, heroes, "undead", 2, "lower")
  ),
  by = c("name", "desc")
)
progress$tick()
bingo_stats <- bingo_stats %>% rows_update(
  tibble(
    name = "Undeadly Trio",
    desc = "Team has at least 3 undead heroes.",
    hero_pick(matches_odota, heroes, "undead", 3, "lower")
  ),
  by = c("name", "desc")
)
progress$tick()

## Rune kill stats
rune_kills <- function(matches, rune, threshold) {
  results <- c()
  for (match in matches) {
    metric <- 0
    for (player in match$match$players) {
      rune_events <- bind_rows(player$playbackData$runeEvents)
      for (kill_event in player$playbackData$killEvents) {
        if (kill_event$isRuneEffected) {
          rune_type <- rune_events %>% 
            filter(time <= kill_event$time) %>%
            arrange(time) %>%
            tail(1) %>%
            pull(rune)
          if (rune_type == rune) metric <- metric + 1
        }
      }
      
    }
    if (metric >= threshold) result <- 1 else result <- 0
    results <- c(results, result)
  }
  return(
    tibble(
      average = calc_exp_summary(results, func = "average"),
      stddev = calc_exp_summary(results, func = "stddev")
    )
  )
}

bingo_stats <- bingo_stats %>% rows_update(
  tibble(
    name = "Arcane Ruined",
    desc = "At least 1 kill occurs with an Arcane Rune in a match.",
    rune_kills(matches_stratz, "ARCANE", 1)
  ),
  by = c("name", "desc")
)
progress$tick()
bingo_stats <- bingo_stats %>% rows_update(
  tibble(
    name = "Arcane Ruined",
    desc = "At least 2 kills occur with an Arcane Rune in a match.",
    rune_kills(matches_stratz, "ARCANE", 2)
  ),
  by = c("name", "desc")
)
progress$tick()
bingo_stats <- bingo_stats %>% rows_update(
  tibble(
    name = "Arcane Ruined",
    desc = "At least 3 kills occur with an Arcane Rune in a match.",
    rune_kills(matches_stratz, "ARCANE", 3)
  ),
  by = c("name", "desc")
)
progress$tick()
bingo_stats <- bingo_stats %>% rows_update(
  tibble(
    name = "Die On My Shield",
    desc = "At least 1 kill occurs with a Shield Rune in a match.",
    rune_kills(matches_stratz, "SHIELD", 1)
  ),
  by = c("name", "desc")
)
progress$tick()
bingo_stats <- bingo_stats %>% rows_update(
  tibble(
    name = "Die On My Shield",
    desc = "At least 2 kills occur with a Shield Rune in a match.",
    rune_kills(matches_stratz, "SHIELD", 2)
  ),
  by = c("name", "desc")
)
progress$tick()
bingo_stats <- bingo_stats %>% rows_update(
  tibble(
    name = "Die On My Shield",
    desc = "At least 3 kills occur with a Shield Rune in a match.",
    rune_kills(matches_stratz, "SHIELD", 3)
  ),
  by = c("name", "desc")
)
progress$tick()
bingo_stats <- bingo_stats %>% rows_update(
  tibble(
    name = "Double Down",
    desc = "At least 1 kill occurs with an Amplify Damage Rune in a match.",
    rune_kills(matches_stratz, "DOUBLE_DAMAGE", 1)
  ),
  by = c("name", "desc")
)
progress$tick()
bingo_stats <- bingo_stats %>% rows_update(
  tibble(
    name = "Double Down",
    desc = "At least 2 kills occur with an Amplify Damage Rune in a match.",
    rune_kills(matches_stratz, "DOUBLE_DAMAGE", 2)
  ),
  by = c("name", "desc")
)
progress$tick()
bingo_stats <- bingo_stats %>% rows_update(
  tibble(
    name = "Double Down",
    desc = "At least 3 kills occur with an Amplify Damage Rune in a match.",
    rune_kills(matches_stratz, "DOUBLE_DAMAGE", 3)
  ),
  by = c("name", "desc")
)
progress$tick()
bingo_stats <- bingo_stats %>% rows_update(
  tibble(
    name = "The Quick and the Dead",
    desc = "At least 1 kill occurs with a Haste Rune in a match.",
    rune_kills(matches_stratz, "HASTE", 1)
  ),
  by = c("name", "desc")
)
progress$tick()
bingo_stats <- bingo_stats %>% rows_update(
  tibble(
    name = "The Quick and the Dead",
    desc = "At least 2 kills occur with a Haste Rune in a match.",
    rune_kills(matches_stratz, "HASTE", 2)
  ),
  by = c("name", "desc")
)
progress$tick()
bingo_stats <- bingo_stats %>% rows_update(
  tibble(
    name = "The Quick and the Dead",
    desc = "At least 3 kills occur with a Haste Rune in a match.",
    rune_kills(matches_stratz, "HASTE", 3)
  ),
  by = c("name", "desc")
)
progress$tick()

## Hero deny stats
hero_deny <- function(matches, heroes, threshold = FALSE) {
  results <- c()
  for (match in matches) {
    team_1 <- c()
    team_2 <- c()
    metric <- 0
    for (pick in match$picks_bans) {
      if (pick$is_pick == TRUE) {
        if (pick$team == 0) team_1 <- c(team_1, pick$hero_id)
        if (pick$team == 1) team_2 <- c(team_2, pick$hero_id)
      }
    }
    
    for (player in match$players) {
      for (killer_name in names(player$killed_by)) {
        if (killer_name %in% heroes$hero_name) {
          killer_id <- heroes %>% 
            filter(hero_name == killer_name) %>% 
            pull(hero_id)
          deny <- (killer_id %in% team_1 && player$hero_id %in% team_1) ||
            (killer_id %in% team_2 && player$hero_id %in% team_2)
          if (deny) metric <- metric + player$killed_by[[killer_name]]
        }
      }
    }
    
    if (threshold) {
      if (metric >= threshold) result <- 1 else result <- 0
    } else {
      result <- metric
    }
    results <- c(results, metric)
  }
  return(
    tibble(
      average = calc_exp_summary(results, func = "average"),
      stddev = calc_exp_summary(results, func = "stddev")
    )
  )
}

bingo_stats <- bingo_stats %>% rows_update(
  tibble(
    name = "End a Friend",
    desc = "At least 1 hero is denied in a match.",
    hero_deny(matches_odota, heroes, 1)
  ),
  by = c("name", "desc")
)
progress$tick()
bingo_stats <- bingo_stats %>% rows_update(
  tibble(
    name = "End a Friend",
    desc = "At least 2 heroes are denied in a match.",
    hero_deny(matches_odota, heroes, 2)
  ),
  by = c("name", "desc")
)
progress$tick()
bingo_stats <- bingo_stats %>% rows_update(
  tibble(
    name = "End a Friend",
    desc = "At least 3 heroes are denied in a match.",
    hero_deny(matches_odota, heroes, 3)
  ),
  by = c("name", "desc")
)
progress$tick()
bingo_stats <- bingo_stats %>% rows_update(
  tibble(
    name = "End a Friend",
    desc = "At least 4 heroes are denied in a match.",
    hero_deny(matches_odota, heroes, 4)
  ),
  by = c("name", "desc")
)
progress$tick()
bingo_stats <- bingo_stats %>% rows_update(
  tibble(
    name = "End a Friend",
    desc = "At least 5 heroes are denied in a match.",
    hero_deny(matches_odota, heroes, 5)
  ),
  by = c("name", "desc")
)
progress$tick()
bingo_stats <- bingo_stats %>% rows_update(
  tibble(
    name = "End a Friend",
    desc = "A hero is denied.",
    hero_deny(matches_odota, heroes)
  ),
  by = c("name", "desc")
)
progress$tick()

## Tower deny stats
tower_deny <- function(matches, heroes, threshold = FALSE) {
  results <- c()
  for (match in matches) {
    radiant <- c()
    dire <- c()
    metric <- 0
    for (pick in match$picks_bans) {
      if (pick$is_pick == TRUE) {
        hero <- heroes %>% filter(hero_id == pick$hero_id) %>% pull(hero_name)
        if (pick$team == 0) radiant <- c(radiant, hero)
        if (pick$team == 1) dire <- c(dire, hero)
      }
    }
    
    for (objective in match$objectives) {
      if (objective$type == "building_kill") {
        deny <- (grepl("^npc_dota_goodguys_tower", objective$key) &&
                   objective$unit %in% radiant)
        if (deny) metric <- metric + 1
      }
    }
    
    if (threshold) {
      if (metric >= threshold) result <- 1 else result <- 0
    } else {
      result <- metric
    }
    results <- c(results, metric)
  }
  return(
    tibble(
      average = calc_exp_summary(results, func = "average"),
      stddev = calc_exp_summary(results, func = "stddev")
    )
  )
}

bingo_stats <- bingo_stats %>% rows_update(
  tibble(
    name = "Controlled Demolition",
    desc = "At least 1 tower is denied in a match.",
    tower_deny(matches_odota, heroes, 1)
  ),
  by = c("name", "desc")
)
progress$tick()
bingo_stats <- bingo_stats %>% rows_update(
  tibble(
    name = "Controlled Demolition",
    desc = "At least 2 towers are denied in a match.",
    tower_deny(matches_odota, heroes, 2)
  ),
  by = c("name", "desc")
)
progress$tick()
bingo_stats <- bingo_stats %>% rows_update(
  tibble(
    name = "Controlled Demolition",
    desc = "At least 3 towers are denied in a match.",
    tower_deny(matches_odota, heroes, 3)
  ),
  by = c("name", "desc")
)
progress$tick()
bingo_stats <- bingo_stats %>% rows_update(
  tibble(
    name = "Controlled Demolition",
    desc = "A tower is denied.",
    tower_deny(matches_odota, heroes)
  ),
  by = c("name", "desc")
)
progress$tick()

## Match duration stats
match_duration <- function(matches, threshold, boundary) {
  results <- c()
  for (match in matches) {
    metric <- match$duration / 60
    if (boundary == "upper") {
      if (metric < threshold) result <- 1 else result <- 0
    }
    if (boundary == "lower") {
      if (metric > threshold) result <- 1 else result <- 0
    }
    results <- c(results, result)
  }
  return(
    tibble(
      average = calc_exp_summary(results, func = "average"),
      stddev = calc_exp_summary(results, func = "stddev")
    )
  )
}

bingo_stats <- bingo_stats %>% rows_update(
  tibble(
    name = "Fast and Furious",
    desc = "A match ends in less than 20 minutes.",
    match_duration(matches_odota, 20, "upper")
  ),
  by = c("name", "desc")
)
progress$tick()
bingo_stats <- bingo_stats %>% rows_update(
  tibble(
    name = "Fast and Furious",
    desc = "A match ends in less than 23 minutes.",
    match_duration(matches_odota, 23, "upper")
  ),
  by = c("name", "desc")
)
progress$tick()
bingo_stats <- bingo_stats %>% rows_update(
  tibble(
    name = "Fast and Furious",
    desc = "A match ends in less than 25 minutes.",
    match_duration(matches_odota, 25, "upper")
  ),
  by = c("name", "desc")
)
progress$tick()
bingo_stats <- bingo_stats %>% rows_update(
  tibble(
    name = "Never-Ending Story",
    desc = "A match lasts longer than 50 minutes.",
    match_duration(matches_odota, 50, "lower")
  ),
  by = c("name", "desc")
)
progress$tick()
bingo_stats <- bingo_stats %>% rows_update(
  tibble(
    name = "Never-Ending Story",
    desc = "A match lasts longer than 55 minutes.",
    match_duration(matches_odota, 55, "lower")
  ),
  by = c("name", "desc")
)
progress$tick()
bingo_stats <- bingo_stats %>% rows_update(
  tibble(
    name = "Never-Ending Story",
    desc = "A match lasts longer than 60 minutes.",
    match_duration(matches_odota, 60, "lower")
  ),
  by = c("name", "desc")
)
progress$tick()

## Smoke kill stats
smoke_kill <- function(matches, threshold) {
  results <- c()
  for (match in matches) {
    metric <- 0
    for (player in match$match$players) {
      for (kill_event in player$playbackData$killEvents) {
        if (kill_event$isSmoke) metric <- metric + 1
      }
    }
    if (metric >= threshold) result <- 1 else result <- 0
    results <- c(results, result)
  }
  return(
    tibble(
      average = calc_exp_summary(results, func = "average"),
      stddev = calc_exp_summary(results, func = "stddev")
    )
  )
}

bingo_stats <- bingo_stats %>% rows_update(
  tibble(
    name = "Smoking Kills",
    desc = "At least 6 kills occur after use of Smoke of Deceit.",
    smoke_kill(matches_stratz, 6)
  ),
  by = c("name", "desc")
)
progress$tick()
bingo_stats <- bingo_stats %>% rows_update(
  tibble(
    name = "Smoking Kills",
    desc = "At least 7 kills occur after use of Smoke of Deceit.",
    smoke_kill(matches_stratz, 7)
  ),
  by = c("name", "desc")
)
progress$tick()
bingo_stats <- bingo_stats %>% rows_update(
  tibble(
    name = "Smoking Kills",
    desc = "At least 8 kills occur after use of Smoke of Deceit.",
    smoke_kill(matches_stratz, 8)
  ),
  by = c("name", "desc")
)
progress$tick()
bingo_stats <- bingo_stats %>% rows_update(
  tibble(
    name = "Smoking Kills",
    desc = "At least 9 kills occur after use of Smoke of Deceit.",
    smoke_kill(matches_stratz, 9)
  ),
  by = c("name", "desc")
)
progress$tick()
bingo_stats <- bingo_stats %>% rows_update(
  tibble(
    name = "Smoking Kills",
    desc = "At least 10 kills occur after use of Smoke of Deceit.",
    smoke_kill(matches_stratz, 10)
  ),
  by = c("name", "desc")
)
progress$tick()

## Courier kill stats
courier_kill <- function(matches, threshold) {
  results <- c()
  for (match in matches) {
    metric <- 0
    for (player in match$players) {
      metric <- metric + player$courier_kills
    }
    if (metric >= threshold) result <- 1 else result <- 0
    results <- c(results, result)
  }
  return(
    tibble(
      average = calc_exp_summary(results, func = "average"),
      stddev = calc_exp_summary(results, func = "stddev")
    )
  )
}

bingo_stats <- bingo_stats %>% rows_update(
  tibble(
    name = "Endangered Species",
    desc = "At least 3 couriers die in a match.",
    courier_kill(matches_odota, 3)
  ),
  by = c("name", "desc")
)
progress$tick()
bingo_stats <- bingo_stats %>% rows_update(
  tibble(
    name = "Endangered Species",
    desc = "At least 5 couriers die in a match.",
    courier_kill(matches_odota, 5)
  ),
  by = c("name", "desc")
)
progress$tick()

## First blood stats
first_blood <- function(matches, threshold, boundary) {
  results <- c()
  for (match in matches) {
    metric <- match$first_blood_time / 60
    if (boundary == "upper") {
      if (metric <= threshold) result <- 1 else result <- 0
    }
    if (boundary == "lower") {
      if (metric > threshold) result <- 1 else result <- 0
    }
    results <- c(results, result)
  }
  return(
    tibble(
      average = calc_exp_summary(results, func = "average"),
      stddev = calc_exp_summary(results, func = "stddev")
    )
  )
}

bingo_stats <- bingo_stats %>% rows_update(
  tibble(
    name = "Bloody Standoff",
    desc = "First blood occurs after 6 minutes.",
    first_blood(matches_odota, 6, "lower")
  ),
  by = c("name", "desc")
)
progress$tick()
bingo_stats <- bingo_stats %>% rows_update(
  tibble(
    name = "Firster First Blood",
    desc = "First blood occurs before the horn.",
    first_blood(matches_odota, 0, "upper")
  ),
  by = c("name", "desc")
)
progress$tick()

## Player kill stats
player_kill <- function(matches, threshold) {
  results <- c()
  for (match in matches) {
    result <- 0
    for (player in match$players) {
      if (player$kills >= threshold) result <- 1
    }
    results <- c(results, result)
  }
  return(
    tibble(
      average = calc_exp_summary(results, func = "average"),
      stddev = calc_exp_summary(results, func = "stddev")
    )
  )
}

bingo_stats <- bingo_stats %>% rows_update(
  tibble(
    name = "Quarter Killer",
    desc = "A player gets 25 kills in a match.",
    player_kill(matches_odota, 25)
  ),
  by = c("name", "desc")
)
progress$tick()
bingo_stats <- bingo_stats %>% rows_update(
  tibble(
    name = "Killer Instinct",
    desc = "A player gets 30 kills in a match.",
    player_kill(matches_odota, 30)
  ),
  by = c("name", "desc")
)
progress$tick()
bingo_stats <- bingo_stats %>% rows_update(
  tibble(
    name = "Killer Instinct",
    desc = "A player gets 35 kills in a match.",
    player_kill(matches_odota, 35)
  ),
  by = c("name", "desc")
)
progress$tick()

## Roshan kill stats
roshan_kill <- function(matches, threshold) {
  results <- c()
  for (match in matches) {
    metric_1 <- 0
    metric_2 <- 0
    for (player in match$players) {
      if (player$team_number == 0) metric_1 <- metric_1 + player$roshan_kills
      if (player$team_number == 1) metric_2 <- metric_2 + player$roshan_kills
    }
    if (metric_1 >= threshold | metric_2 >= threshold) {
      result <- 1 
    } else {
      result <- 0
    }
    results <- c(results, result)
  }
  return(
    tibble(
      average = calc_exp_summary(results, func = "average"),
      stddev = calc_exp_summary(results, func = "stddev")
    )
  )
}

bingo_stats <- bingo_stats %>% rows_update(
  tibble(
    name = "Everybody Hates Roshan",
    desc = "Roshan killed 3 times by same team in a match.",
    roshan_kill(matches_odota, 3)
  ),
  by = c("name", "desc")
)
progress$tick()
bingo_stats <- bingo_stats %>% rows_update(
  tibble(
    name = "Everybody Hates Roshan",
    desc = "Roshan killed 4 times by same team in a match.",
    roshan_kill(matches_odota, 4)
  ),
  by = c("name", "desc")
)
progress$tick()
bingo_stats <- bingo_stats %>% rows_update(
  tibble(
    name = "Everybody Hates Roshan",
    desc = "Roshan killed 5 times by same team in a match.",
    roshan_kill(matches_odota, 5)
  ),
  by = c("name", "desc")
)
progress$tick()

## Ward kill stats
## Measures observer and sentry dewards
ward_kill <- function(matches, threshold) {
  results <- c()
  for (match in matches) {
    metric <- 0
    for (player in match$players) {
      metric <- metric + player$observer_kills + player$sentry_kills
    }
    if (metric >= threshold) result <- 1 else result <- 0
    results <- c(results, result)
  }
  return(
    tibble(
      average = calc_exp_summary(results, func = "average"),
      stddev = calc_exp_summary(results, func = "stddev")
    )
  )
}

bingo_stats <- bingo_stats %>% rows_update(
  tibble(
    name = "Ward Cleaver",
    desc = "At least 25 observer wards dewarded.",
    ward_kill(matches_odota, 25)
  ),
  by = c("name", "desc")
)
progress$tick()
bingo_stats <- bingo_stats %>% rows_update(
  tibble(
    name = "Ward Cleaver",
    desc = "At least 30 observer wards dewarded.",
    ward_kill(matches_odota, 30)
  ),
  by = c("name", "desc")
)
progress$tick()
bingo_stats <- bingo_stats %>% rows_update(
  tibble(
    name = "Ward Cleaver",
    desc = "At least 35 observer wards dewarded.",
    ward_kill(matches_odota, 35)
  ),
  by = c("name", "desc")
)
progress$tick()

## Cheese use stats
cheese_use <- function(matches, threshold) {
  results <- c()
  for (match in matches) {
    metric <- 0
    for (player in match$players) {
      if (!is.null(player$item_uses$cheese)) {
        metric <- metric + player$item_uses$cheese
      }
    }
    if (metric >= threshold) result <- 1 else result <- 0
    results <- c(results, result)
  }
  return(
    tibble(
      average = calc_exp_summary(results, func = "average"),
      stddev = calc_exp_summary(results, func = "stddev")
    )
  )
}

bingo_stats <- bingo_stats %>% rows_update(
  tibble(
    name = "Dairy Delight",
    desc = "At least 1 cheese is eaten in a match.",
    cheese_use(matches_odota, 1)
  ),
  by = c("name", "desc")
)
progress$tick()
bingo_stats <- bingo_stats %>% rows_update(
  tibble(
    name = "Dairy Delight",
    desc = "At least 2 cheeses are eaten in a match.",
    cheese_use(matches_odota, 2)
  ),
  by = c("name", "desc")
)
progress$tick()

## Team wipe stats
team_wipe <- function(matches, threshold) {
  results <- c()
  for (match in matches) {
    metric <- 0
    for (fight in match$teamfights) {
      deaths <- c()
      for (player in fight$players) {
        deaths <- c(deaths, player$deaths > 0)
      }
      if (sum(deaths[1:5]) == 5) metric <- metric + 1
      if (sum(deaths[6:10]) == 5) metric <- metric + 1
    }
    if (metric >= threshold) result <- 1 else result <- 0
    results <- c(results, result)
  }
  return(
    tibble(
      average = calc_exp_summary(results, func = "average"),
      stddev = calc_exp_summary(results, func = "stddev")
    )
  )
}

bingo_stats <- bingo_stats %>% rows_update(
  tibble(
    name = "Well Wiped",
    desc = "At least 3 team wipes occur in a match.",
    team_wipe(matches_odota, 3)
  ),
  by = c("name", "desc")
)
progress$tick()
bingo_stats <- bingo_stats %>% rows_update(
  tibble(
    name = "Well Wiped",
    desc = "At least 4 team wipes occur in a match.",
    team_wipe(matches_odota, 4)
  ),
  by = c("name", "desc")
)
progress$tick()
bingo_stats <- bingo_stats %>% rows_update(
  tibble(
    name = "Well Wiped",
    desc = "At least 5 team wipes occur in a match.",
    team_wipe(matches_odota, 5)
  ),
  by = c("name", "desc")
)
progress$tick()

## Miscellaneous stats
indestructible <- function(matches) {
  results <- c()
  for (match in matches) {
    result <- 0
    for (player in match$players) {
      if (player$win == 1 && player$deaths == 0) result <- 1
    }
    results <- c(results, result)
  }
  return(
    tibble(
      average = calc_exp_summary(results, func = "average"),
      stddev = calc_exp_summary(results, func = "stddev")
    )
  )
}
bingo_stats <- bingo_stats %>% rows_update(
  tibble(
    name = "Indestructible",
    desc = "A winning team has a player with zero deaths.",
    indestructible(matches_odota)
  ),
  by = c("name", "desc")
)
progress$tick()

peacemaker <- function(matches) {
  results <- c()
  for (match in matches) {
    result <- 0
    for (player in match$players) {
      if (player$win == 1 && player$kills == 0) result <- 1
    }
    results <- c(results, result)
  }
  return(
    tibble(
      average = calc_exp_summary(results, func = "average"),
      stddev = calc_exp_summary(results, func = "stddev")
    )
  )
}
bingo_stats <- bingo_stats %>% rows_update(
  tibble(
    name = "Peacemaker",
    desc = "A winning team has a player with zero kills.",
    peacemaker(matches_odota)
  ),
  by = c("name", "desc")
)
progress$tick()

fully_sharded <- function(matches) {
  results <- c()
  for (match in matches) {
    result <- 0
    metric <- c()
    for (player in match$players) {
      metric <- c(metric, player$aghanims_shard)
    }
    if (sum(metric[1:5]) == 5) result <- result + 1
    if (sum(metric[6:10]) == 5) result <- result + 1
    results <- c(results, result)
  }
  return(
    tibble(
      average = calc_exp_summary(results, func = "average"),
      stddev = calc_exp_summary(results, func = "stddev")
    )
  )
}
bingo_stats <- bingo_stats %>% rows_update(
  tibble(
    name = "Fully Sharded",
    desc = "All members of a team have Aghanim's Shards.",
    fully_sharded(matches_odota)
  ),
  by = c("name", "desc")
)
progress$tick()

scepter_squad <- function(matches) {
  results <- c()
  for (match in matches) {
    result <- 0
    metric <- c()
    for (player in match$players) {
      buff <- player$aghanims_scepter
      item <- player$item_0 == 108 | player$item_1 == 108 | 
        player$item_2 == 108 | player$item_3 == 108 | player$item_4 == 108 | 
        player$item_5 == 108
      metric <- c(metric, buff | item)
    }
    if (sum(metric[1:5]) == 5) result <- result + 1
    if (sum(metric[6:10]) == 5) result <- result + 1
    results <- c(results, result)
  }
  return(
    tibble(
      average = calc_exp_summary(results, func = "average"),
      stddev = calc_exp_summary(results, func = "stddev")
    )
  )
}
bingo_stats <- bingo_stats %>% rows_update(
  tibble(
    name = "Scepter Squad",
    desc = "All members of a team have Aghanim's Scepter.",
    scepter_squad(matches_odota)
  ),
  by = c("name", "desc")
)
progress$tick()

tormented <- function(matches) {
  results <- c()
  for (match in matches) {
    result <- 0
    for (player in match$players) {
      if (!is.null(player$killed_by$npc_dota_miniboss)) result <- 1
    }
    results <- c(results, result)
  }
  return(
    tibble(
      average = calc_exp_summary(results, func = "average"),
      stddev = calc_exp_summary(results, func = "stddev")
    )
  )
}
bingo_stats <- bingo_stats %>% rows_update(
  tibble(
    name = "Tormented",
    desc = "At least 1 player dies to Tormentor in a match.",
    tormented(matches_odota)
  ),
  by = c("name", "desc")
)
progress$tick()

comeback_kings <- function(matches) {
  results <- c()
  for (match in matches) {
    if (match$radiant_win) {
      result <- tail(unlist(match$radiant_gold_adv), 1) < 0
    } else {
      result <- tail(unlist(match$radiant_gold_adv), 1) > 0
    }
    results <- c(results, result)
  }
  return(
    tibble(
      average = calc_exp_summary(results, func = "average"),
      stddev = calc_exp_summary(results, func = "stddev")
    )
  )
}
bingo_stats <- bingo_stats %>% rows_update(
  tibble(
    name = "Comeback Kings",
    desc = "A team wins while having a net worth deficit.",
    comeback_kings(matches_odota)
  ),
  by = c("name", "desc")
)
progress$tick()

divine_fumble <- function(matches) {
  results <- c()
  for (match in matches) {
    for (player in match$players) {
      if ((player$item_0 == 133 | player$item_1 == 133 | player$item_2 == 133 | 
           player$item_3 == 133 | player$item_4 == 133 | player$item_5 == 133) & 
          is.null(player$purchase_rapier)) {
        result <- 1
      } else {
        result <- 0
      }
    }
    results <- c(results, result)
  }
  return(
    tibble(
      average = calc_exp_summary(results, func = "average"),
      stddev = calc_exp_summary(results, func = "stddev")
    )
  )
}
bingo_stats <- bingo_stats %>% rows_update(
  tibble(
    name = "Divine Fumble",
    desc = "A players's rapier is taken by the opposing team.",
    divine_fumble(matches_odota)
  ),
  by = c("name", "desc")
)
progress$tick()

# Save the data to disk
bingo_stats %>%
  mutate(
    square = case_when(
      is.na(average) ~ paste0(name, " — ", desc, " [NO DATA]"),
      .default = paste0(name, " — ", desc)
    ),
    average,
    stddev,
    .keep = "none",
    .before = "average"
  ) %>%
  arrange(square) %>%
  rename(
    "Square" = "square",
    "Average" = "average",
    "Standard Deviation" = "stddev"
  ) %>%
  write_sheet(
    ss = "1U5X3r00hNPcafQpNTbWQwLi2Vja3JpAi42pDTBGmHHs", 
    sheet = "Bingo Square Data"
  )

write_csv(x = bingo_stats, file = "results/bingo_stats.csv")
