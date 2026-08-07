# Methodology record

Measurements taken to justify the modelling assumptions, kept so the readme
footnotes can cite numbers rather than assertions. Every figure below comes from
the 7.41 patch data in `data/match_data.csv` unless stated otherwise.

Dataset: 1,175 of 1,182 matches (99.4%), 7,667 player-matches, 80 players,
16 teams, 2026-03-24 to 2026-08-05. The 7 excluded matches have no replay URL in
OpenDota at all.

**Pool: 4,380 role-games across 48 team-roles.** A role-game exists where a
team's registered role-mates played the same match on the same side (Core 2,
Mid 1, Support 2). No further filter — in particular *not* `same_team_in_match`,
which would cut the pool to 3,453 by discarding 753 role-games where the whole
registered five played together under a previous org tag. That filter costs
HULIGANI 114 role-games down to 21 and Iron Wing 93 down to 23, the two thinnest
pools in the set, for a rebrand rather than a roster change.

Sizes: min 29, median 99.5, max 131 games per team-role.

> Sections 4 to 7 were measured on the older 3,453 pool and are superseded in
> magnitude, though not in direction. Re-run them through
> `src/export-web-data.R` so the figures and the calculator share a code path.

## 1. Scoring structure

Points are the best 2 matches of a series, then the best series of the period,
**per role**. Two nested maxima, so variance is rewarded and order statistics
apply rather than means.

A player scores, in one match,

```
sum over emblems of (stat points x emblem multiplier)  x  (1 + prefix + suffix)
```

and **a role scores the average of its players**, per the in-game glossary. The
average is taken before the game is selected, which is what makes a role's two
players want to peak together: two strong games and one weak beats three games
in which one player is good and the other is not.

**The emblem multiplier is per emblem, not per banner** — one banner routinely
carries GPM at 230% next to Roshan Kills at 100%, so a single multiplier cannot
be applied to a summed base score. It is `1 + quality + trait`.

Quality has five tiers: **I +10%, II +30%, III +60%, IV +100%, V +150%**.

Traits are conditional, and two of them act on their **linear neighbours**:

| Trait | Effect |
|---|---|
| Fractal | +60% if every quality on the banner differs |
| Benevolent | +20% to adjacent emblems, nothing to itself |
| Vampiric | +50% to itself, -10% to adjacent |
| Unique | +30% if it is the only Unique on the banner |
| Friendly | +50% if at least 3 Friendly are on the banner |

The percentage the game displays on an emblem is the **net** trait contribution
including its neighbours' effects. That reconciles every figure on a live
banner: a Vampiric GPM showing +70% is its own +50% plus +20% from an adjacent
Benevolent; that Benevolent shows -10% because it gives itself nothing and sits
beside the Vampiric; a Fractal showing +80% is +60% for distinct qualities plus
+20% from an adjacent Benevolent. Two Uniques on one banner both show 0%.

The prefix and suffix are one global choice across all five players, additive,
and freely changeable without spending tokens. Both must be applied **per player
per match, before the maxima**: per match because trigger rates are
match-specific, and per player because a role's two players rarely trigger the
same prefix in the same match, so averaging the pair first loses the
interaction. `src/export-web-data.R` ships unaggregated player rows for exactly
this reason, and the browser averages only after amplifying.

Consequence: the three role slots optimise independently, but the shared
prefix/suffix couples them, giving a 56-pair outer loop (8 prefixes x 7 usable
suffixes) around three independent role optimisations.

## 2. Tournament format

Verified against Liquipedia on 2026-08-07. Ordinary page fetches return HTTP
403, but the MediaWiki API serves wikitext when given a descriptive User-Agent:

    curl --compressed -A "ti15-fantasy/1.0 (<contact>)" \
      "https://liquipedia.net/dota2/api.php?action=parse&page=The_International/2026&prop=wikitext&section=1&format=json"

Period 1, group stage (August 13-16), quoted from the TI2026 format section:
Swiss-system of sixteen teams, all matches Bo3, top three teams advance to
playoffs, 4th to 13th place proceed to an elimination round, remaining teams are
eliminated; five teams then advance from the elimination round. The TI2026 group
stage page has exactly five round sections, and TI2025 states the elimination
round pairs 3-2 records against 2-3 records.

Teams at 4-0 and 0-4 sit out round 5. This is not stated in the format text but
is confirmed by TI2025's results: round 4 has 8 matches, round 5 has only 7
(2 at 3-1, 3 at 2-2, 2 at 1-3). After 4 rounds the standings are 1x(4-0),
4x(3-1), 6x(2-2), 4x(1-3), 1x(0-4); the middle 14 play round 5, producing
2x(4-1), 5x(3-2), 5x(2-3), 2x(1-4) — the 5 elimination matches, 3 teams
advancing directly and 3 eliminated directly. The TI2026 prize pool corroborates
this with tiers at 9-13 (5 teams), 14-15 (2 teams) and 16 (1 team). 8 teams
advance, 8 are eliminated.

| Series in period 1 | Teams |
|---|---|
| 4 | 2 (the 4-0 and the 0-4) |
| 5 | 4 |
| 6 | 10 |

Note the best Swiss team plays the *fewest* series.

Period 2, main event (August 20-23): double-elimination bracket, grand final Bo5
and all other matches Bo3. TI2025 used `Bracket/8U4L2DSL1D` with 14 match slots
— the standard 8-team double elimination, all teams starting upper bracket.
Minimum 2 series (UB QF loss, LB R1 loss), maximum 6 (UB QF loss then a full
lower-bracket run).

`N` alone does not determine whether a Bo5 is included — a team can reach N=4
either through the grand final or through a lower-bracket exit at LB R3.

Caveat: Liquipedia records that at TI2025 the organisers introduced rules
mid-tournament without public announcement, including a previously non-existent
limit of two series per day. The format is verified as published, not as
guaranteed.

## 3. Series lengths

Realised game counts across all 476 observed series:

| Format | Series | 1 game | 2 | 3 | 4 | 5 |
|---|---|---|---|---|---|---|
| Bo1 | 84 | 83 | 1 | | | |
| Bo2 | 97 | 6 | 91 | | | |
| Bo3 | 355 | 16 | 197 | 142 | | |
| Bo5 | 20 | 1 | 2 | 9 | 6 | 2 |

Among the 339 complete Bo3s: **58.1% go 2 games, 41.9% go 3**. Mean 2.42 games
(2.36 including the 16 one-game Bo3s, whose cause has not been established).

Role-games by the length of the series they sit in: 405 in 1-game series, 1,678
in 2-game, 1,370 in 3-or-more. So **12% of role-games contain no top-2 pair** and
would be lost by any method that resamples whole series.

## 4. Dispersion (sigma / mu)

Median over all 16 teams x every legal emblem selection for the banner shape;
brackets are the 10th-90th percentile across selections.

| Period | Role | Selections | Per game | Series top-2 |
|---|---|---|---|---|
| 1 | Core | 90 | 0.32 [0.21-0.47] | 0.22 [0.13-0.33] |
| 1 | Mid | 216 | 0.46 [0.25-0.81] | 0.31 [0.15-0.55] |
| 1 | Support | 90 | 0.38 [0.22-0.49] | 0.27 [0.16-0.36] |
| 2 | Core | 300 | 0.30 [0.21-0.41] | 0.20 [0.14-0.29] |
| 2 | Mid | 1350 | 0.37 [0.24-0.55] | 0.25 [0.15-0.39] |
| 2 | Support | 300 | 0.33 [0.22-0.42] | 0.23 [0.14-0.32] |

The emblem selection moves this more than the team does — Mid ranges 0.25 to
0.81 per game depending on which emblems are run.

## 5. Within-series correlation (rho)

One-way ANOVA ICC of the role-game score, centred within team-role first,
grouped by series.

| Period | Role | rho |
|---|---|---|
| 1 | Core | 0.044 [0.000-0.125] |
| 1 | Mid | 0.037 [0.000-0.086] |
| 1 | Support | 0.050 [0.017-0.109] |
| 2 | Core | 0.048 [0.000-0.109] |
| 2 | Mid | 0.047 [0.000-0.099] |
| 2 | Support | 0.054 [0.020-0.097] |

**Games within a series are effectively independent.** This is the measurement
that licenses resampling individual games rather than whole series.

An earlier estimate of this quantity gave 0.63-0.78 for the economy stats and
was wrong: it pooled series-means across all players, so between-player variation
(a Core's GPM against a Support's) landed in the between-series term and inflated
it. Any figure in that range is superseded by this table.

At rho = 0.05, ignoring the correlation understates series-score sd by 2.5%,
which reaches E[max] as roughly 0.1%.

## 6. Value of playing more series

Exact E[max of N series] off the empirical mixture, relative to N = 4:

| Period | Role | N=2 | N=6 |
|---|---|---|---|
| 1 | Core | -7.8% | +3.7% |
| 1 | Mid | -11.4% | +5.8% |
| 1 | Support | -10.0% | +5.0% |
| 2 | Core | -7.1% | +3.3% |
| 2 | Mid | -9.4% | +4.8% |
| 2 | Support | -8.9% | +4.4% |

- Period 1 (4 to 6 series): **+3 to +6%**.
- Period 2 (2 to 6 series): **+11 to +16%**.

For scale, the spread *between teams* in period 1 is 6,148 to 7,288 points for
Core (+18%) and 3,907 to 5,261 for Mid (+35%). Picking the right team matters
3-6x more than how deep they go in period 1; in period 2 the two effects are
comparable.

Sanity check against order-statistic theory: for i.i.d. normals,
`E[max of N] = mu + sigma * a_N` with `a_2 = 1/sqrt(pi) = 0.564`,
`a_4 = 1.029`, `a_6 = 1.267`. Predicted gain from N=4 to N=6 is
`0.238 * sigma/mu`: 5.2% Core, 7.4% Mid, 6.4% Support, against 3.7 / 5.8 / 5.0
measured. The normal approximation runs 28-40% high across all three. Cause not
established — a shorter upper tail than normal and truncation by the discrete
empirical pool would both produce this.

## 7. Thin-pool bias

Observed series per team-role range from 5 to 43 (median 25). Resampling whole
series truncates the tail for the thin ones: with 5 observed series the
empirical max-of-6 is essentially the pool maximum. Visible in the data —
HULIGANI (8 series) gains only +2.4% at Core while Xtreme Gaming (31 series)
gains +5.1%, at an identical series-level sigma/mu of 0.22.

Resampling individual games removes this: a team with 20 role-games has
C(20,3) = 1,140 possible 3-game series instead of ~10 observed ones.

## 8. `the Clutch`, the one position-dependent indicator

Every other indicator describes the match itself — the hero's colour, its
duration, whether the player lost — so it travels correctly when a game is
resampled. `the Clutch` ("+16% in the last possible match of a series") describes
the match's **position in its series**, derived at `src/compile-match-data.R:24`
as `match_no == best_of`. Its rate therefore carries the pool's format mix,
which is not the tournament's.

Rates in the 4,380-game pool:

| Source | Games | Clutch | Rate |
|---|---|---|---|
| Bo1 | 389 | 387 | 99.5% |
| Bo2 | 776 | 379 | 48.8% |
| Bo3 | 2,938 | 522 | 17.8% |
| Bo5 | 277 | 9 | 3.2% |
| **Pool** | **4,380** | **1,297** | **29.6%** |

A Bo3-only tournament produces `p3 / (2 + p3) = 0.414 / 2.414 = 17.1%`. Bo1 and
Bo2 games are 27% of the pool but supply 59% of its clutch flags, because nearly
every Bo1 game is trivially the last possible one.

**Decision: the flag travels unrestricted**, giving 29.6%. The basis is that
deciding games genuinely score more — measured over Bo3 games only, so format is
held fixed:

| Role | Non-clutch mean | Clutch mean | Difference | p |
|---|---|---|---|---|
| Core | 21,893 | 23,167 | +5.8% | 0.017 |
| Mid | 10,687 | 11,274 | +5.4% | 0.019 |
| Support | 19,216 | 20,295 | +5.6% | 0.011 |

Pooled and centred within team-role, p < 0.001. Two alternatives were measured
and rejected: restricting the flag to Bo3 sources gives 11.9%, and restricting
the whole pool to Bo3 games gives a correct 17.8% but costs 33% of the data and
drops five units below 25 games.

Known cost of the decision: at 29.6% against a structural 17.1%, `the Clutch` is
overstated by roughly **0.85 percentage points of roster score** — about six
times the 0.15pp the decider premium is worth. Discount it when reading the
suffix column.

## 9. Decisions taken

| Decision | Basis |
|---|---|
| Resample individual games, not whole series | rho ~ 0.05 (section 5); keeps the 12% of role-games in 1-game series (section 3); removes thin-pool truncation (section 7) |
| Draw 2 or 3 games per Bo3, weighted by the observed rate | Section 3. Rate to be computed on the fly and exponentially weighted like every other statistic, not hardcoded |
| Use the global 2-vs-3 rate, not per team | It is a matchup property, not a team one, and the opponent field at TI differs from the patch history. At a median 25 Bo3s per team the binomial SE is ~0.10, so a true 42% reads anywhere from 22% to 62% |
| Model the grand final as a Bo3 | Affects 2 of 8 teams, at most 1 of their 2-6 series, and only if that series happens to be their max. Systematically understates those two teams, almost certainly by under 1% |
| Report E[P given N] rather than forecasting N | Separates an estimable quantity from a prediction, and leaves the judgement call with the user |
| Period 1 quotes a single number at N=6, footnoting the 4-6 spread; period 2 exposes N | Section 6: 3-6% against 11-16% |
| Pool is pairing only, no `same_team_in_match` | Header. The filter discards rebrands and whole-roster moves, which is where history transfers best |
| `the Clutch` travels unrestricted | Section 8. Deciding games really do score ~5.6% more; the cost is a 29.6% rate against a structural 17.1% |
| Indicators are dropped on `all(is.na(...))`, never by name | `the Cruel` returns on its own once `fantasy.jar` supplies it, with no code change |
| Exact enumeration, not Monte Carlo | A series score is always `y_i + y_j`, so there are at most `n(n+1)/2` atoms with closed-form probabilities — 8,646 at the largest unit. Sampling would add error for nothing |
| Amplification applied per player, before pairing | Section 1. 27 role-games in one Core unit alone have exactly one of the pair triggering a given prefix |

## 10. Open assumptions

- **Series are drawn independently**, so form persistence *across* series is not
  modelled. Direction of the bias is up. Unmeasured.
- **Per-game distributions do not depend on how long the series ran.** A 2-0
  sweep and a 1-1-into-game-3 may produce different kinds of games. Unmeasured.
- **The 2-vs-3 rate is global**, so a team that consistently draws close series
  is not distinguished from one that sweeps.
- **`the Cruel` is unimplemented** — it needs a fountain-death counter in
  `fantasy.jar`. It stays a first-class `NA` rather than being silently dropped.
- **16 Bo3s show only 1 game** in the data and the cause has not been
  established.
- **Games are drawn with replacement**, so a simulated series can contain the
  same game twice.
- **`the Underdog` amplifies losses**, which are the low-scoring games both
  maxima discard, so its +6% lands disproportionately on matches that are never
  selected. Ranking suffixes by rate x bonus is therefore wrong — only the
  calculation settles it. The same logic cuts the other way for `the Clutch`,
  whose games score above average.
- **Reroll probabilities are not published.** Traits and offered roll options are
  assumed uniform. Quality is assumed to fall off inversely with its boost —
  60 / 20 / 10 / 6 / 4 percent for tiers I to V — which is monotone as the game
  states and gives every tier the same expected contribution of 6 points. A
  reroll cannot return the current tier, so the remaining four renormalise. The
  live banner cannot validate this, since its emblems have already been rerolled.

## 11. The reroll model

Twenty roll operations, in `data/rolls.csv`. Each colour has one granular category
with all / first / last / random variants and all-only for the other two — Red is
granular on quality, Blue on trait, Green on stat — plus two colourless ones that
move quality around. Three are offered at a time, each costs a token, and using
one replaces all three. A roll applies to whichever banner is selected, so the
decision is really (operation x banner).

Outcomes are **enumerated exactly**, never sampled. The largest case is a stat
reroll across three same-colour slots at 71 possibilities:

- **Stat** — a joint draw, not independent ones. A banner cannot hold a stat
  twice, so the new stats must differ from each other, from every same-colour slot
  left untouched, and from their own current value. Uniform over valid
  assignments. Injections with inclusion-exclusion give 21 for two slots, 71 for
  three.
- **Quality / trait** — independent per slot, current value excluded, remaining
  weights renormalised.
- **random** — a `1/k` mixture over which slot of that colour is hit.

**Assumed, because the game does not publish it:**

| Assumption | Basis |
|---|---|
| Quality weights 60 / 20 / 10 / 6 / 4 for tiers I to V | Inversely proportional to the boost, the only rule the game states. Monotone as required, and gives every tier the same expected contribution of 6 points. A reroll cannot return the current tier |
| Traits uniform over the other four | No stated rule |
| Offered operations uniform over the twenty | No stated rule |
| "Increase one Quality": uniform over emblems below the top tier, raise one | Behaviour at the cap is unstated |
| "Increase two and reduce one": three distinct emblems, uniform over combinations respecting both caps | Behaviour at the caps is unstated |

**The objective.** A banner is worth the mean, across the role's 16 teams, of the
same nested-maxima expectation the calculator uses. Nothing is averaged inside a
team — each term is already a full `E[max]`. The across-teams mean only stands in
for a team choice not yet made, and prefix and suffix are left out because they
are free to change later.

Measured against the alternative of optimising for whichever team is best, the
across-teams mean ranks banners at **rho 0.994 (Core), 0.981 (Mid), 0.938
(Support)** over 200 random banners — so the more elaborate option buys nothing.
It is also steadier: the best team changes with the banner, with 11 of 16 taking
the crown for some Core banner and 13 of 16 for some Mid banner.

Rolls are ranked **across all three banners at once**, since tokens are shared and
the roster total is the sum of the three role scores.

**Refresh value.** The expected best delta over a uniformly random set of three
distinct operations, taking each one's best banner and treating a set with no
gain as worth zero. Exact over all 1,140 three-subsets. It sets how much loss is
worth accepting to cycle the offers. The recommendation is **one step ahead**: a
full dynamic program over the token budget is not attempted, and the state space
of banner configurations is why.

**Ground truth.** The multiplier model reproduces all nine emblems of a live
banner exactly, totals and trait percentages alike — 230/100/210, 130/110/160,
140/240/130. That is the only check against something other than our own
arithmetic, and it is a hard assertion in the test suite.

## 12. Data quality

`fantasy.jar` validated against OpenDota over 400 player-matches on patch 7.41:

| Agreement | Stats |
|---|---|
| 100% exact | kills, deaths, creep score, camps stacked, roshan kills, first blood, wards placed, runes grabbed |
| 99.5% | tower kills |
| 99.2% | stuns |
| within 0.017 | teamfight participation |
| ~1.8% high | GPM — expected, the parser uses `m_iTotalEarnedGold/min` |

Six stats have no OpenDota equivalent and are therefore unvalidated: madstone
collected, watchers taken, smokes used, lotuses grabbed, tormentor kills,
courier kills. All show sensible distributions.

Replay coverage is enforced at 95% in `compile_match_data()`; the current run
sits at 99.4%.
