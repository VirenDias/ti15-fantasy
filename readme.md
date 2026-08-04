# Updating the Data

1. **Delete:**

   * `results/*`
   * `data/matches/odota/*`
   * `data/matches/replay/*`
   * `data/matches/stratz/*`
   * `data/matches/match_ids.csv`
   * `data/items.csv`
   * `data/players.csv`
   * `data/teams.csv`
   * `data/top_players.csv`

2. **Update:**

   * `data/bingo_squares.txt`
   * `data/heroes.txt` (remove trailing brace or it won't parse properly)
   * `data/prefixes.csv`
   * `data/suffixes.csv`
   * `top-stats.R` (with new points system)
   * `src/get-match-data.R` (with new patch numbers)

3. **Clean out and update as the tournament progresses:**

   * `data/matches/match_ids_black.csv`
   * `data/matches/match_ids_ti.csv`
   * `data/teams_elim.csv`

4. **Update the league ID** in `top-stats.R`, `top-prefixes.R`, `top-suffixes.R`, and `ideal_rolls.R`.

5. **Spreadsheet update:**
   * Create a new copy of the spreadsheet from [this folder](https://drive.google.com/drive/folders/1EBKHBAtyM7fpoKZQczZ3sw7lXXyUAqKr), get the link for the new spreadsheet, and update `top-stats.R`, `top-prefixes.R`, and `top-suffixes.R`.

# Updating the Replay Parser

1. Take a pull from `https://github.com/skadistats/clarity-examples` and merge it into `https://github.com/VirenDias/clarity-dota2-fantasy`.
2. Update for any new fantasy developments and fix any issues.
3. Compile the `.jar` and add it to `utils/fantasy.jar`.

# Running the Analysis

1. Run `top-stats.R`
2. Run `top-prefixes.R` and `top-suffixes.R`
3. Run `ideal-rolls.R`
4. Run `reddit-post.R`
5. Run `bingo-stats.R`
