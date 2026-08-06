source("src/get-team-data.R")

library(tidyverse)
library(httr)
library(rlang)

get_player_data <- function(league_id) {
  message("Retrieving player data")

  dir_path <- "data"
  file_path <- paste0(dir_path, "/players.csv")

  if (file.exists(file_path)) {
    players <- read_csv(file_path, progress = FALSE, show_col_types = FALSE)
  } else {
    teams <- get_team_data(league_id)

    # Get the roster of each competing team
    players <- data.frame(
      player_id = as.numeric(),
      player_name = as.character(),
      team_id = as.numeric(),
      player_role = as.numeric()
    )
    for (team_id in teams$team_id) {
      response <- GET(
        url = "https://www.dota2.com/webapi/IDOTA2Teams/GetSingleTeamInfo/v001",
        query = list(team_id = team_id)
      )
      if (http_status(response)$category != "Success") {
        stop("Unsuccessful request")
      }

      for (player in content(response)$members) {
        players <- players %>%
          add_row(
            player_id = as.numeric(player$account_id),
            player_name = if (is.null(player$pro_name)) {
              NA_character_
            } else {
              as.character(chr_unserialise_unicode(player$pro_name))
            },
            team_id = as.numeric(team_id),
            player_role = as.numeric(player$role)
          )
      }

      Sys.sleep(1)
    }

    players <- players %>%
      mutate(
        player_role = as.character(
          factor(
            x = player_role,
            levels = c(0, 1, 2, 4),
            labels = c("Undefined", "Core", "Support", "Mid")
          )
        )
      ) %>%
      # Coaches and inactive members are listed with no role
      filter(player_role %in% c("Core", "Mid", "Support")) %>%
      tibble() %>%
      distinct()

    # Caching an empty response would keep failing every later run
    if (nrow(players) == 0) {
      stop(paste0("League ", league_id, " returned no players with a role"))
    }

    if (!dir.exists(dir_path)) {
      dir.create(dir_path)
    }
    players <- players %>% arrange(player_id)
    write_csv(x = players, file = file_path)
  }

  return(players)
}
