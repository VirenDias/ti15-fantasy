# Update for each new tournament
league_id <- 19719
starting_patch <- "7.41" # Matches from this patch onwards
league_whitelist <- c(19656) # Tier 1 or 2 events OpenDota tags as excluded

# Update as the tournament progresses
current_period <- 1 # Selects the War Banner shape
teams_eliminated <- c() # Knocked out between periods, left out of the results

weight_alpha <- NULL # Recency decay per match, NULL for 2 / (matches + 1)
web_dir <- "docs" # GitHub Pages serves the calculator from here
python_exe <- "C:/Users/Viren/.conda/envs/dota-compendium/python.exe"
download_workers <- 16 # Valve throttles each connection, not the total
parse_workers <- 8 # One jvm per worker, so below the core count
