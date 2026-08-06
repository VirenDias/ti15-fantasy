source("config.R")
source("src/get-player-data.R")

library(tidyverse)
library(httr)
library(curl)
library(parallel)

num_or_na <- function(value) {
  return(if (is.null(value)) NA_real_ else as.numeric(value))
}

query_explorer <- function(sql) {
  response <- GET(
    "https://api.opendota.com/api/explorer",
    query = list(sql = sql)
  )
  if (http_status(response)$category != "Success") {
    stop("Unsuccessful request")
  }

  result <- content(response)
  if (!is.null(result$err)) {
    stop(paste0("OpenDota rejected the query: ", result$err))
  }

  return(result$rows)
}

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

  match_ids <- map_dbl(query_explorer(query), ~ num_or_na(.x$match_id))
  if (length(match_ids) == 0) {
    stop(
      paste0(
        "OpenDota returned no matches for these players since patch ", patch
      )
    )
  }

  # Written for auditing only, since the query runs on every pass
  if (!dir.exists(dir_path)) {
    dir.create(dir_path)
  }
  match_ids <- sort(unique(match_ids))
  write_csv(x = as.data.frame(match_ids), file = file_path, col_names = FALSE)

  return(match_ids)
}


get_match_odota_data <- function(match_ids, chunk_size = 500) {
  message("Retrieving match OpenDota data")

  dir_path <- "data/matches"
  matches_path <- paste0(dir_path, "/matches.csv")
  players_path <- paste0(dir_path, "/match_players.csv")

  # Chunked to keep the query string inside any url length limit
  id_lists <- match_ids %>%
    split(ceiling(seq_along(match_ids) / chunk_size)) %>%
    map_chr(~ paste(format(.x, scientific = FALSE, trim = TRUE), collapse = ","))

  match_rows <- id_lists %>%
    map(
      ~ query_explorer(
        paste0(
          "SELECT match_id, series_id, series_type, start_time, duration, ",
          "first_blood_time, radiant_team_id, dire_team_id, radiant_win, ",
          "cluster, replay_salt FROM matches WHERE match_id IN (", .x, ")"
        )
      )
    ) %>%
    list_flatten()

  # killed_by is the only place a tormentor kill is recorded
  player_rows <- id_lists %>%
    map(
      ~ query_explorer(
        paste0(
          "SELECT match_id, account_id, hero_id, player_slot, ",
          "(killed_by->>'npc_dota_miniboss') IS NOT NULL AS tormentor ",
          "FROM player_matches WHERE match_id IN (", .x, ")"
        )
      )
    ) %>%
    list_flatten()

  matches <- tibble(
    match_id = map_dbl(match_rows, ~ num_or_na(.x$match_id)),
    series_id = map_dbl(match_rows, ~ num_or_na(.x$series_id)),
    series_type = map_dbl(match_rows, ~ num_or_na(.x$series_type)),
    start_time = map_dbl(match_rows, ~ num_or_na(.x$start_time)),
    duration = map_dbl(match_rows, ~ num_or_na(.x$duration)),
    first_blood_time = map_dbl(match_rows, ~ num_or_na(.x$first_blood_time)),
    radiant_team_id = map_dbl(match_rows, ~ num_or_na(.x$radiant_team_id)),
    dire_team_id = map_dbl(match_rows, ~ num_or_na(.x$dire_team_id)),
    radiant_win = map_lgl(match_rows, ~ isTRUE(.x$radiant_win)),
    cluster = map_dbl(match_rows, ~ num_or_na(.x$cluster)),
    replay_salt = map_dbl(match_rows, ~ num_or_na(.x$replay_salt))
  )

  # Dropped rather than raised, because the caller weighs what is left against
  # everything else it could not obtain
  missing <- setdiff(match_ids, matches$match_id)
  if (length(missing) > 0) {
    message(
      paste0(
        "  ", length(missing), " of ", length(match_ids),
        " matches have no row in OpenDota's match table"
      )
    )
  }

  match_players <- tibble(
    match_id = map_dbl(player_rows, ~ num_or_na(.x$match_id)),
    player_id = map_dbl(player_rows, ~ num_or_na(.x$account_id)),
    hero_id = map_dbl(player_rows, ~ num_or_na(.x$hero_id)),
    player_slot = map_dbl(player_rows, ~ num_or_na(.x$player_slot)),
    tormentor = map_lgl(player_rows, ~ isTRUE(.x$tormentor))
  )

  matches <- matches %>%
    left_join(
      match_players %>% summarise(tormentor_death = any(tormentor), .by = match_id),
      by = "match_id"
    ) %>%
    # OpenDota serves a replay url but stores only the parts it is built from
    mutate(
      replay_url = if_else(
        is.na(cluster) | is.na(replay_salt),
        NA_character_,
        paste0(
          "http://replay", cluster, ".valve.net/570/",
          format(match_id, scientific = FALSE, trim = TRUE), "_",
          format(replay_salt, scientific = FALSE, trim = TRUE), ".dem.bz2"
        )
      )
    ) %>%
    select(-cluster, -replay_salt) %>%
    arrange(match_id)

  match_players <- match_players %>%
    left_join(matches %>% select(match_id, radiant_win), by = "match_id") %>%
    mutate(
      is_radiant = player_slot < 128,
      lose = as.numeric(is_radiant != radiant_win)
    ) %>%
    select(match_id, player_id, hero_id, is_radiant, lose) %>%
    arrange(match_id, player_id)

  matches <- matches %>% select(-radiant_win)

  if (!dir.exists(dir_path)) {
    dir.create(dir_path)
  }
  write_csv(x = matches, file = matches_path)
  write_csv(x = match_players, file = players_path)

  return(list(matches = matches, match_players = match_players))
}

# Runs on a worker, so it takes absolute paths and returns a reason rather than
# raising. A corrupt archive is discarded to be downloaded again, but one that
# only fails to parse is kept, since redownloading it would not help
parse_replay <- function(match_id, dir_path, jar_path) {
  bz2_path <- paste0(dir_path, "/", match_id, ".dem.bz2")
  dem_path <- paste0(dir_path, "/", match_id, ".dem")
  tmp_path <- paste0(dir_path, "/", match_id, ".csv.tmp")
  csv_path <- paste0(dir_path, "/", match_id, ".csv")

  status <- system2(
    command = "7z",
    args = c("x", "-y", shQuote(bz2_path), paste0("-o", shQuote(dir_path))),
    stdout = FALSE,
    stderr = FALSE
  )
  if (status != 0 | !file.exists(dem_path)) {
    unlink(c(bz2_path, dem_path))
    return("archive is corrupt")
  }


  status <- system2(
    command = "java",
    args = c("-jar", shQuote(jar_path), shQuote(dem_path)),
    stdout = tmp_path,
    stderr = FALSE
  )
  unlink(dem_path)
  if (status != 0) {
    unlink(tmp_path)
    return("parser failed")
  }

  # A header and one row per player, so anything else is a truncated parse
  lines <- sum(nzchar(trimws(readLines(tmp_path, warn = FALSE))))
  if (lines != 11) {
    unlink(tmp_path)
    return("parser wrote the wrong row count")
  }

  # Renamed last so a file that exists is always a complete one
  file.rename(tmp_path, csv_path)
  unlink(bz2_path)
  return(NA_character_)
}

# Runs a failure of each kind is retried over before the match is left alone. A
# stopped transfer resumes where it left off so it is worth many attempts, but a
# replay Valve no longer serves will never appear
replay_attempts <- c(
  "replay is gone" = 1,
  "archive is corrupt" = 3,
  "parser failed" = 3,
  "parser wrote the wrong row count" = 3,
  "download stopped early" = 5
)

read_replay_failures <- function(file_path) {
  # Spelled out so an empty ledger and a read one can be bound together
  if (!file.exists(file_path)) {
    return(
      tibble(
        match_id = numeric(),
        attempts = integer(),
        reason = character(),
        last_tried = as.Date(character())
      )
    )
  }

  return(
    read_csv(
      file_path,
      col_types = cols(
        match_id = col_double(),
        attempts = col_integer(),
        reason = col_character(),
        last_tried = col_date()
      ),
      progress = FALSE
    )
  )
}

# Anything absent has either been parsed or is no longer asked for, so the file
# only ever holds matches still worth an attempt
write_replay_failures <- function(failures, file_path) {
  if (nrow(failures) == 0) {
    unlink(file_path)
  } else {
    write_csv(x = failures %>% arrange(match_id), file = file_path)
  }
}

get_match_replay_data <- function(
    match_ids,
    replay_urls,
    workers = download_workers,
    parsers = parse_workers,
    chunk_size = 64,
    rounds = 3
) {
  message("Retrieving match replay data")

  dir_path <- "data/matches/replay"
  if (!dir.exists(dir_path)) {
    dir.create(dir_path, recursive = TRUE)
  }
  failures_path <- "data/matches/replay_failures.csv"
  dir_path <- normalizePath(dir_path, winslash = "/")
  jar_path <- normalizePath("utils/fantasy.jar", winslash = "/")

  csv_of <- function(ids) paste0(dir_path, "/", ids, ".csv")
  bz2_of <- function(ids) paste0(dir_path, "/", ids, ".dem.bz2")

  # The replays already parsed are the only record of what is done, so a rerun
  # picks up exactly what is left
  todo <- tibble(match_id = match_ids, replay_url = replay_urls) %>%
    filter(!file.exists(csv_of(match_id)))
  failed <- todo %>%
    filter(is.na(replay_url)) %>%
    transmute(match_id, reason = "OpenDota has no replay url")
  todo <- todo %>% filter(!is.na(replay_url))

  # Matches that have failed the same way often enough to stop paying for
  abandoned <- read_replay_failures(failures_path) %>%
    filter(
      match_id %in% todo$match_id,
      attempts >= coalesce(replay_attempts[reason], 3)
    )
  todo <- todo %>% filter(!match_id %in% abandoned$match_id)
  if (nrow(abandoned) > 0) {
    message(
      paste0(
        "Leaving ", nrow(abandoned), " replays alone, see ", failures_path
      )
    )
  }

  if (nrow(todo) == 0) {
    write_replay_failures(abandoned, failures_path)
    return(bind_rows(failed, abandoned %>% select(match_id, reason)))
  }
  message(paste0("Fetching ", nrow(todo), " replays with ", workers, " connections"))

  # Concurrency is a property of the shared pool, not of the call below
  multi_set(total_con = workers, host_con = workers)

  cluster <- makePSOCKcluster(min(parsers, nrow(todo)))
  on.exit(stopCluster(cluster))

  # Why each match failed most recently, so the run can tell a transfer that
  # stopped early from a replay that is not there at all
  reasons <- set_names(
    rep("download stopped early", nrow(todo)),
    as.character(todo$match_id)
  )

  for (round in seq_len(rounds)) {
    pending <- todo %>% filter(!file.exists(csv_of(match_id)))
    if (nrow(pending) == 0) {
      break
    }
    if (round > 1) {
      message(paste0("Retrying ", nrow(pending), " replays (round ", round, ")"))
    }

    chunks <- split(
      seq_len(nrow(pending)),
      ceiling(seq_len(nrow(pending)) / chunk_size)
    )
    for (chunk in chunks) {
      batch <- pending[chunk, ]

      # An archive left by an earlier run only needs parsing
      fetch <- batch %>% filter(!file.exists(bz2_of(match_id)))
      if (nrow(fetch) > 0) {
        parts <- paste0(bz2_of(fetch$match_id), ".part")
        result <- multi_download(
          fetch$replay_url,
          parts,
          resume = TRUE,
          progress = TRUE
        )

        # A transfer that stops early still reports success, and an error page
        # still arrives as a complete one
        whole <- result$success &
          result$status_code %in% c(200, 206) &
          file.exists(parts)
        file.rename(parts[whole], bz2_of(fetch$match_id[whole]))

        # Nothing to resume from when the replay itself is missing
        gone <- !whole & result$status_code %in% c(403, 404, 410)
        unlink(parts[gone | file.size(parts) %in% 0])
        reasons[as.character(fetch$match_id[gone])] <- "replay is gone"
      }

      ready <- batch$match_id[file.exists(bz2_of(batch$match_id))]
      if (length(ready) > 0) {
        parsed <- parLapply(cluster, ready, parse_replay, dir_path, jar_path)
        parsed <- set_names(unlist(parsed), as.character(ready))
        reasons[names(parsed)[!is.na(parsed)]] <- parsed[!is.na(parsed)]
      }

      message(
        paste0(
          "  ", sum(file.exists(csv_of(todo$match_id))), "/", nrow(todo),
          " replays parsed"
        )
      )
    }
  }

  # One attempt per run, so a match is left alone after so many runs rather than
  # so many requests
  still_failing <- todo %>%
    filter(!file.exists(csv_of(match_id))) %>%
    transmute(match_id, reason = unname(reasons[as.character(match_id)])) %>%
    left_join(
      read_replay_failures(failures_path) %>% select(match_id, was = attempts),
      by = "match_id"
    ) %>%
    transmute(
      match_id,
      attempts = as.integer(coalesce(was, 0L) + 1L),
      reason,
      last_tried = Sys.Date()
    )

  write_replay_failures(bind_rows(abandoned, still_failing), failures_path)

  # Reported rather than raised, because the caller decides whether the matches
  # left are enough to work with
  return(
    bind_rows(
      failed,
      abandoned %>% select(match_id, reason),
      still_failing %>% select(match_id, reason)
    ) %>%
      arrange(match_id)
  )
}
