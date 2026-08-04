library(tidyverse)
library(knitr)

# Get data
top_players <- read_csv("results/top_players.csv")
top_stats <- read_csv("results/top_stats.csv")
top_prefixes <- read_csv("results/top_prefixes.csv")
top_suffixes <- read_csv("results/top_suffixes.csv")

for (role in unique(top_players$player_role)) {
  # Top player tables
  top_players %>%
    filter(player_role == role) %>%
    mutate(points = paste0(round(average), " (±", round(stddev), ")")) %>%
    select(player_name, team_name, points) %>%
    kable(
      format = "pipe",
      digits = 0,
      col.names = c("Player", "Team", "Points"),
      align = "llr",
      caption = paste0(
        "The top scoring ", role, " players, format: ",
        "Average (Standard Deviation)"
      )
    ) %>%
    print()
  
  # Top stat tables
  top_stats %>%
    filter(player_role == role) %>%
    mutate(
      all_player_points = paste0(
        round(all_player_average), 
        " (±", 
        round(all_player_stddev),
        ")"
      ),
      top_player_points = paste0(
        round(top_player_average),
        " (±",
        round(top_player_stddev),
        ")"
      )
    ) %>%
    select(emblem_colour, emblem_stat, all_player_points, top_player_points) %>%
    kable(
      format = "pipe",
      digits = 0,
      col.names = c("Colour", "Stat", "All Players", "Top 25% Players"),
      align = "llrr",
      caption = paste0(
        "The top War Banner Emblem Stats for ", role, " players, format: ",
        "Average (Standard Deviation)"
      )
    ) %>%
    print()
  
  # Top prefix tables
  top_prefixes %>%
    filter(player_role == role) %>%
    mutate(
      all_player_bonus = paste0(
        format(round(all_player_bonus, 2), nsmall = 2, trim = TRUE), 
        "% (", 
        format(round(all_player_prob * 100, 2), nsmall = 2, trim = TRUE),
        "%)"
      ),
      top_player_bonus = paste0(
        format(round(top_player_bonus, 2), nsmall = 2, trim = TRUE),
        "% (",
        format(round(top_player_prob * 100, 2), nsmall = 2, trim = TRUE),
        "%)"
      )
    ) %>%
    select(prefix_name, prefix_desc, all_player_bonus, top_player_bonus) %>%
    kable(
      format = "pipe",
      digits = 2,
      col.names = c("Prefix", "Description", "All Players", "Top 25% Players"),
      align = "llrr",
      caption = paste0(
        "The top Title Prefixes for ", role, " players, format: ",
        "Effective Bonus (Probability)"
      )
    ) %>%
    print()
  
  # Top suffix tables
  top_suffixes %>%
    filter(player_role == role) %>%
    mutate(
      all_player_bonus = paste0(
        format(round(all_player_bonus, 2), nsmall = 2, trim = TRUE), 
        "% (", 
        format(round(all_player_prob * 100, 2), nsmall = 2, trim = TRUE),
        "%)"
      ),
      top_player_bonus = paste0(
        format(round(top_player_bonus, 2), nsmall = 2, trim = TRUE),
        "% (",
        format(round(top_player_prob * 100, 2), nsmall = 2, trim = TRUE),
        "%)"
      )
    ) %>%
    select(suffix_name, suffix_desc, all_player_bonus, top_player_bonus) %>%
    kable(
      format = "pipe",
      digits = 2,
      col.names = c("Suffix", "Description", "All Players", "Top 25% Players"),
      align = "llrr",
      caption = paste0(
        "The top Title Suffixes for ", role, " players, format: ",
        "Effective Bonus (Probability)"
      )
    ) %>%
    print()
}
