source("config.R")
source("src/get-player-data.R")
source("src/gql-query.R")

library(tidyverse)
library(httr)
library(jsonlite)

get_match_ids <- function(
    player_ids,
    start_time = as.integer(Sys.time()),
    patch = patch_numbers,
    max_matches = 50
) {
  message("Retrieving match IDs")
  
  dir_path <- "data/matches"
  file_path <- paste0(dir_path, "/match_ids.csv")
  
  if (file.exists(file_path)) {
    # Read data from disk
    match_ids <- scan(file_path, quiet = TRUE)
  } else {
    # Get recent pro match data before start date
    match_ids <- c()
    i <- 1
    for (player_id in player_ids) {
      message(
        paste0(
          "Retrieving match IDs for player ID ",
          player_id,
          " (",
          i, 
          "/", 
          length(player_ids), 
          ")"
        )
      )
      
      response <- GET(
        "https://datdota.com/api/players/single-performance",
        query = list(
          players = player_id,
          before = as.POSIXct(
            start_time, 
            tz = "UTC", 
            origin = "1970-01-01"
          ) %>%
            format(., "%d/%m/%Y"),
          patch = patch,
          tier = "1,2",
          "valve-event" = "does-not-matter"
        )
      )
      if (http_status(response)$category != "Success") {
        message(paste0("Unsuccessful request for player ID ", player_id))
      }
      
      # Store match IDs up to the specified max
      for (match in content(response)$data[1:max_matches]) {
        match_ids <- c(match_ids, match$matchId)
      }
      
      i <- i + 1
      Sys.sleep(1)
    }
    
    # Write data to disk
    if (!dir.exists(dir_path)) {
      dir.create(dir_path)
    }
    match_ids <- sort(unique(match_ids))
    write_csv(x = as.data.frame(match_ids), file = file_path, col_names = FALSE)
  }
  
  return(match_ids)
}

get_match_odota_data <- function(match_ids) {
  message("Retrieving match OpenDota data")
  
  dir_path <- "data/matches/odota"
  i <- 1
  for (match_id in match_ids) {
    file_path <- paste0(dir_path, "/", match_id, ".json")
    if (!file.exists(file_path)) {
      message(
        paste0(
          "Retrieving OpenDota data for match ID ",
          match_id, 
          " (",
          i, 
          "/", 
          length(match_ids),
          ")"
        )
      )
      
      # Get OpenDota data
      response <- GET(
        paste0("https://api.opendota.com/api/matches/", match_id)
      )
      if (http_status(response)$category != "Success") {
        message(paste0("Unsuccessful request for match ID ", match_id))
      } else {
        if (!dir.exists(dir_path)) dir.create(dir_path)
        if (!file.exists(file_path)) {
          write_json(
            x = content(response), 
            path = file_path, 
            auto_unbox = TRUE
          )
        }
      }
      
      Sys.sleep(1)
    }
    
    i <- i + 1
  }
  
  # Read data from disk
  matches <- list()
  for (match_id in match_ids) {
    file_path <- paste0(dir_path, "/", match_id, ".json")
    matches[[as.character(match_id)]] <- read_json(file_path)
  }
  
  return(matches)
}

get_match_stratz_data <- function(match_ids, token = NULL) {
  message("Retrieving match Stratz data")
  
  dir_path <- "data/matches/stratz"
  i <- 1
  for (match_id in match_ids) {
    file_path <- paste0(dir_path, "/", match_id, ".json")
    if (!file.exists(file_path)) {
      if (is.null(token)) stop("Stratz API token not set")
      message(
        paste0(
          "Retrieving Stratz data for match ID ",
          match_id, 
          " (",
          i, 
          "/", 
          length(match_ids),
          ")"
        )
      )
      
      # Get Stratz data
      response <- gql_query(
        query = paste0("{
            match(id: ", match_id, ") {
              startDateTime
              chatEvents {
                type
                fromHeroId
                toHeroId
                value
              }
              players {
                steamAccountId
                heroId
                dotaPlus {
                  level
                }
                playbackData {
                  runeEvents {
                    time
                    rune
                    action
                  }
                  killEvents {
                    time
                    isSmoke
                    isRuneEffected
                  }
                }
              }
            }
          }"),
        token = token,
        url = "https://api.stratz.com/graphql",
        httr::add_headers(`User-Agent` = "STRATZ_API")
      )
      if(!is.null(response$errors)){
        message(paste0("Unsuccessful request for match ID ", match_id))
      } else {
        if (!dir.exists(dir_path)) dir.create(dir_path)
        if (!file.exists(file_path)) {
          write_json(
            x = response$data, 
            path = file_path, 
            auto_unbox = TRUE
          )
        }
      }
      
    }
    
    i <- i + 1
  }
  
  # Read data from disk
  matches <- list()
  for (match_id in match_ids) {
    file_path <- paste0(dir_path, "/", match_id, ".json")
    matches[[as.character(match_id)]] <- read_json(file_path)
  }
  
  return(matches)
}

get_match_replay_data <- function(match_ids, timeout = 600) {
  options(timeout = timeout)
  match_odota_data <- get_match_odota_data(match_ids = match_ids)
  
  message("Retrieving match replay data")
  
  dir_path <- "data/matches/replay"
  if (!dir.exists(dir_path)) dir.create(dir_path)
  
  i <- 1
  for (match in match_odota_data) {
    match_id <- unlist(match$match_id)
    bz2_path <- paste0(dir_path, "/", match_id, ".dem.bz2")
    dem_path <- paste0(dir_path, "/", match_id, ".dem")
    csv_path <- paste0(dir_path, "/", match_id, ".csv")
    if (!file.exists(csv_path)) {
      message(
        paste0(
          "Retrieving replay data for match ID ",
          unlist(match$match_id),
          " (",
          i,
          "/",
          length(match_odota_data),
          ")"
        )
      )
      
      # Download replay
      if (!file.exists(bz2_path)) {
        message("Downloading replay")
        if (!file.exists(dem_path)) {
          download.file(
            url = unlist(match$replay_url),
            destfile = bz2_path,
            mode = "wb"
          )
          Sys.sleep(1)
        }
      }
      
      # Decompress replay
      if (!file.exists(dem_path)) {
        message("Decompressing replay")
        system2(
          command = "7z",
          args = c("x", bz2_path, paste0("-o", dir_path)),
          stdout = FALSE,
          stderr = FALSE
        )
      }

      # Parse replay
      message("Parsing replay")
      system2(
        command = "java",
        args = c("-jar", "utils/fantasy.jar", dem_path),
        stdout = csv_path,
        stderr = FALSE
      )
      invisible(file.remove(dem_path))
    }
    
    i <- i + 1
  }
  
  # Read data from disk
  matches <- list()
  for (match_id in match_ids) {
    matches[[as.character(match_id)]] <- read_csv(
      paste0(dir_path, "/", match_id, ".csv"),
      progress = FALSE,
      show_col_types = FALSE
    )
  }
  
  return(matches)
}
