# Update these for each new tournament
league_id <- 19719
patch_numbers <- "7.41" # Comma separated, major patches only

# Update this as the tournament progresses, it selects the War Banner shape
current_phase <- 1

# Analysis parameters
match_cap <- NULL # Matches per player pulled from datdota, NULL for no cap
weight_alpha <- NULL # Recency decay per match, NULL for 2 / (matches + 1)

# Local environment
python_exe <- "C:/Users/Viren/.conda/envs/dota-compendium/python.exe"
