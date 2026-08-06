source("config.R")
source("src/get-player-data.R")

library(tidyverse)
library(httr)
library(jsonlite)

get_patch_start <- function(patch_name) {
  response <- GET("https://api.opendota.com/api/constants/patch")
  if (http_status(response)$category != "Success") {
    stop("Unsuccessful request")
  }

  patch <- keep(content(response), ~ identical(as.character(.x$name), patch_name))
  if (length(patch) == 0) {
    stop(
      paste0(
        "OpenDota has no patch called ", patch_name,
        ", check starting_patch in config.R"
      )
    )
  }

  return(
    as.numeric(
      as.POSIXct(patch[[1]]$date, format = "%Y-%m-%dT%H:%M:%OSZ", tz = "UTC")
    )
  )
}

get_match_ids <- function(
    player_ids,
    patch = starting_patch,
    whitelist = league_whitelist
) {
  message("Retrieving match IDs")

  dir_path <- "data/matches"
  file_path <- paste0(dir_path, "/match_ids.csv")

  if (file.exists(file_path)) {
    match_ids <- scan(file_path, quiet = TRUE)
  } else {
    # A patch is a span of time, so the window opens at its release
    patch_start <- get_patch_start(patch)
    message(
      paste0(
        "Patch ", patch, " released ",
        format(
          as.POSIXct(patch_start, origin = "1970-01-01", tz = "UTC"),
          "%Y-%m-%d"
        )
      )
    )

    # League tiers are only exposed through the sql explorer
    query <- paste0(
      "SELECT DISTINCT m.match_id ",
      "FROM matches m ",
      "JOIN player_matches pm ON pm.match_id = m.match_id ",
      "JOIN leagues l ON l.leagueid = m.leagueid ",
      "WHERE pm.account_id IN (",
      paste(format(player_ids, scientific = FALSE, trim = TRUE), collapse = ","),
      ") AND m.start_time >= ", patch_start,
      " AND (l.tier IN (\'premium\', \'professional\')",
      if (length(whitelist) > 0) {
        paste0(" OR l.leagueid IN (", paste(whitelist, collapse = ","), ")")
      } else {
        ""
      },
      ")"
    )

    response <- GET(
      "https://api.opendota.com/api/explorer",
      query = list(sql = query)
    )
    if (http_status(response)$category != "Success") {
      stop("Unsuccessful request")
    }

    result <- content(response)
    if (!is.null(result$err)) {
      stop(paste0("OpenDota rejected the query: ", result$err))
    }
    match_ids <- map_dbl(result$rows, ~ as.numeric(.x$match_id))

    # Caching an empty response would keep failing every later run
    if (length(match_ids) == 0) {
      stop(
        paste0(
          "OpenDota returned no matches for these players since patch ", patch
        )
      )
    }

    if (!dir.exists(dir_path)) {
      dir.create(dir_path)
    }
    match_ids <- sort(unique(match_ids))
    write_csv(x = as.data.frame(match_ids), file = file_path, col_names = FALSE)
  }

  return(match_ids)
}


get_match_odota_data <- function(match_ids, parse = TRUE) {
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
  
  # Parsing every match at once costs several gigabytes, so a caller that
  # streams them asks for the paths instead
  file_paths <- set_names(
    paste0(dir_path, "/", match_ids, ".json"),
    match_ids
  )
  if (!parse) {
    return(file_paths)
  }

  matches <- list()
  for (match_id in match_ids) {
    file_path <- paste0(dir_path, "/", match_id, ".json")
    matches[[as.character(match_id)]] <- read_json(file_path)
  }

  return(matches)
}

get_match_replay_data <- function(match_ids, replay_urls, timeout = 600) {
  options(timeout = timeout)

  message("Retrieving match replay data")

  dir_path <- "data/matches/replay"
  if (!dir.exists(dir_path)) dir.create(dir_path)

  for (i in seq_along(match_ids)) {
    match_id <- match_ids[i]
    bz2_path <- paste0(dir_path, "/", match_id, ".dem.bz2")
    dem_path <- paste0(dir_path, "/", match_id, ".dem")
    csv_path <- paste0(dir_path, "/", match_id, ".csv")
    if (file.exists(csv_path)) next

    if (is.na(replay_urls[i])) {
      message(paste0("No replay URL for match ID ", match_id))
      next
    }

    message(
      paste0(
        "Retrieving replay data for match ID ",
        match_id,
        " (",
        i,
        "/",
        length(match_ids),
        ")"
      )
    )

    if (!file.exists(bz2_path) & !file.exists(dem_path)) {
      message("Downloading replay")
      download.file(url = replay_urls[i], destfile = bz2_path, mode = "wb")
      Sys.sleep(1)
    }

    if (!file.exists(dem_path)) {
      message("Decompressing replay")
      system2(
        command = "7z",
        args = c("x", bz2_path, paste0("-o", dir_path)),
        stdout = FALSE,
        stderr = FALSE
      )
    }

    message("Parsing replay")
    system2(
      command = "java",
      args = c("-jar", "utils/fantasy.jar", dem_path),
      stdout = csv_path,
      stderr = FALSE
    )
    invisible(file.remove(dem_path))
  }

  return(invisible(NULL))
}
