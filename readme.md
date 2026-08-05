# Updating the Data

1. **Delete:**

   * `results/*`
   * `data/match_data.csv`
   * `data/matches/odota/*`
   * `data/matches/replay/*`
   * `data/matches/match_ids.csv`
   * `data/players.csv`
   * `data/teams.csv`

2. **Update:**

   * `config.R` (league ID, patch numbers, phase)
   * `data/heroes.txt` (extract `npc_heroes.txt` from
     `dota 2 beta/game/dota/pak01_dir.vpk`)
   * `data/stats.csv` (with the new points system)
   * `data/prefixes.csv`
   * `data/suffixes.csv`
   * `data/banners.csv` (with the emblem colours and order of each War Banner)

3. **Clean out and update as the tournament progresses:**

   * `config.R` (the phase, once the second one begins)
   * `data/matches/match_ids_black.csv`
   * `data/teams_elim.csv`

Everything else is fetched on the first run: the roster and teams from Valve, the
match IDs from datdota, the match data from OpenDota, and the replays from Valve.

Two things to know when supplying the data above:

* `data/heroes.txt` must parse with `vdf`, which only handles one closing brace
  per line. If it fails, look for a line holding two and split them.
* Each prefix and suffix needs a matching condition in `src/compile-match-data.R`.
  Renaming or adding one without that fails the run rather than silently
  producing an empty column. `the Cruel` is deliberately unimplemented, as no
  available data source records where a player died.

# Updating the Replay Parser

1. Take a pull from `https://github.com/skadistats/clarity-examples` and merge it
   into `https://github.com/VirenDias/clarity-dota2-fantasy`.
2. Update for any new fantasy developments and fix any issues.
3. Compile the `.jar` and add it to `utils/fantasy.jar`.

The parser is the only source of stat values, so a property renamed by a new
patch produces a silently empty column rather than an error. After the first
matches are parsed, check a few against the same fields on OpenDota
(`kills`, `deaths`, `tower_kills`, `camps_stacked`, `roshan_kills` and
`courier_kills` should match exactly) before trusting a run.

# Running the Analysis

Run `fantasy-stats.R`. It fetches whatever is missing, which on a first run means
downloading and parsing every replay, and writes:

* `data/match_data.csv` — one row per player per match, with the points each
  emblem stat scored and which prefixes and suffixes applied
* `results/role_stats.csv` — recency-weighted average and standard deviation per
  team, role and metric, with the number of matches behind each figure
