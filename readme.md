# Updating the Data

1. **Delete:**

   * `data/players.csv`
   * `data/teams.csv`
   * `data/matches/replay/*`
   * `data/matches/replay_failures.csv`

2. **Update:**

   * `config.R` (league ID, starting patch, period, and any tier 1 or 2 events
     OpenDota marks as excluded)
   * `data/heroes.txt` (extract `npc_heroes.txt` from
     `dota 2 beta/game/dota/pak01_dir.vpk`)
   * `data/stats.csv` (with the new points system)
   * `data/prefixes.csv`
   * `data/suffixes.csv`
   * `data/banners.csv` (with the emblem colours and order of each War Banner)

3. **Update as the tournament progresses:**

   * `config.R` (`current_period` and `teams_eliminated` between periods)

Only the three files above are read from disk when they exist, so they are the
only ones a new tournament needs deleted. The rosters and teams are kept because
they can be corrected by hand; the parsed replays because they take hours to
rebuild. Everything else is refetched and overwritten on every run.

The match list and the match data both come from OpenDota's SQL explorer, a few
whole-set queries rather than one request per match, cheap enough to repeat every
run. A patch is a span of time, so `starting_patch` is turned into a date using
the release dates OpenDota publishes. The explorer stores a replay's cluster and
salt rather than the url built from them.

Two things to know when supplying the data above:

* `data/heroes.txt` must parse with `vdf`, which only handles one closing brace
  per line. If it fails, look for a line holding two and split them.
* Each prefix and suffix needs a matching condition in `src/compile-match-data.R`.
  Renaming or adding one without that fails the run rather than silently
  producing an empty column. `the Cruel` is currently unimplemented.

# Updating the Replay Parser

1. Take a pull from `https://github.com/skadistats/clarity-examples` and merge it
   into `https://github.com/VirenDias/clarity-dota2-fantasy`.
2. Update for any new fantasy developments and fix any issues.
3. Compile the `.jar` and add it to `utils/fantasy.jar`.

The parser is the only source of stat values, so a property renamed by a new
patch produces a silently empty column rather than an error. After the first
matches are parsed, compare a few against the same fields on OpenDota before
trusting a run.

# Running the Analysis

Run `fantasy-stats.R`. It fetches whatever is missing, which on a first run means
downloading and parsing every replay, and writes:

* `data/match_data.csv` — one row per player per match, with the points each
  emblem stat scored and which prefixes and suffixes applied
* `results/role_stats.csv` — recency-weighted average and standard deviation per
  team, role and metric, with the number of matches behind each figure

A replay is downloaded once and kept only as its parsed csv, so a rerun resumes
wherever the last one stopped. Matches whose replay cannot be downloaded or
parsed are reported and dropped, but the run stops if fewer than 95% survive,
since that points at the parser rather than at the matches.

Replays that keep failing are counted in `data/matches/replay_failures.csv` and
left alone after a few runs, sooner for one Valve no longer serves than for a
transfer that stops early, which resumes where it stopped. Delete that file to
try them all again. Matches OpenDota has no data for are only reported, never
recorded, since asking again costs nothing and OpenDota fills them in late.
