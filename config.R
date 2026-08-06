# Update for each new tournament
league_id <- 19719
starting_patch <- "7.41" # Matches from this patch onwards
league_whitelist <- c(19656) # Tier 1 or 2 events OpenDota tags as excluded
current_phase <- 1 # War Banner shape, changes when phase 2 begins

weight_alpha <- NULL # Recency decay per match, NULL for 2 / (matches + 1)
python_exe <- "C:/Users/Viren/.conda/envs/dota-compendium/python.exe"
