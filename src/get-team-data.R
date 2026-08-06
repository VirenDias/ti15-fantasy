library(tidyverse)
library(httr)

get_team_data <- function(league_id) {
  message("Retrieving team data")

  dir_path <- "data"
  file_path <- paste0(dir_path, "/teams.csv")

  if (file.exists(file_path)) {
    teams <- read_csv(file_path, progress = FALSE, show_col_types = FALSE)
  } else {
    response <- GET(
      url = "https://www.dota2.com/webapi/IDOTA2League/GetLeagueData/v001",
      query = list(league_id = league_id)
    )
    if (http_status(response)$category != "Success") {
      stop("Unsuccessful request")
    }

    # The competing teams are listed in the bracket standings
    teams <- content(response)$node_groups %>%
      map("team_standings") %>%
      list_flatten() %>%
      compact() %>%
      map(
        ~ tibble(
          team_id = as.numeric(.x$team_id),
          team_name = as.character(.x$team_name),
          team_tag = as.character(.x$team_tag)
        )
      ) %>%
      list_rbind() %>%
      distinct()

    # Caching an empty response would keep failing every later run
    if (nrow(teams) == 0) {
      stop(paste0("League ", league_id, " returned no teams"))
    }

    if (!dir.exists(dir_path)) {
      dir.create(dir_path)
    }
    teams <- teams %>% arrange(team_id)
    write_csv(x = teams, file = file_path)
  }

  return(teams)
}
