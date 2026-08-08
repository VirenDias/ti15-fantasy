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

**Decision: the flag does not travel. It is applied to the last possible match of
the simulated series.** In a Bo3 that is game 3, and only when the series runs to
three — a 2-0 has no last possible match at all. The realised rate is then
`p3 / (2 + p3) = 17.1%` by construction, matching the tournament rather than the
pool, and no games are discarded to get there.

Mechanics. `data/suffixes.csv` carries a `suffix_scope` column, so a positional
suffix is identified from data rather than by name. `src/export-web-data.R`
leaves it out of the indicator bitmask entirely and ships it with a bit of zero.
`docs/calc.js` derives a per-game `positionalBoost` and `seriesHistogram` applies
it to the third draw.

The algebra that keeps this cheap: the top-two sum of `{A, B, v}` — two plain
draws and the bonused one — is `M + max(m, v)`, where `M` and `m` are the larger
and smaller of the plain pair. `(M, m)` is exactly the pair the enumeration
already produces, so conditioning on whether `v` falls below `m` keeps the work at
`O(n^2)`: 8,646 pair atoms plus 17,161 (pair-max, bonused) atoms at the largest
unit, against 8,646 before. Only the eight prefix/suffix pairs that select the
Clutch take this path; the rest short-circuit to the closed form.

Measured effect, averaged across all 48 team-roles at the period's median run:

| Model | `the Clutch` over no suffix |
|---|---|
| Flag travels with the game | +5.70% |
| Applied to the last possible match | +3.59% |

The overstatement was therefore **2.11 percentage points**, which supersedes the
0.85pp estimated earlier from the rate gap alone. It is still the strongest
suffix — `the Lucky` is next at +2.11% — but the choice is now contested: across
the 4,096 rosters it wins 3,976, `the Lucky` 115 and `the Tormented` 5. The best
roster's period-1 score falls from 23,119 to 22,548.

**What the change costs.** The bonus now lands on a game drawn from the whole
pool rather than on one that actually was a decider, and deciding games do score
more — measured over Bo3 games only, so format is held fixed:

| Role | Non-clutch mean | Clutch mean | Difference | p |
|---|---|---|---|---|
| Core | 21,893 | 23,167 | +5.8% | 0.017 |
| Mid | 10,687 | 11,274 | +5.4% | 0.019 |
| Support | 19,216 | 20,295 | +5.6% | 0.011 |

Pooled and centred within team-role, p < 0.001. That correlation is no longer
modelled — worth about 0.15pp against the 2.11pp removed, so the trade is clearly
positive, but it is a real loss and is recorded in section 11.

Three alternatives were measured and rejected. Letting the flag travel gives
29.6%, the original decision, superseded here. Restricting the flag to Bo3
sources gives 11.9%. Restricting the whole pool to Bo3 games gives a correct
17.8% but costs 33% of the data and drops five units below 25 games. A fourth,
scaling the positional draw by the measured decider premium, was rejected because
the pool mean already contains decider games at their elevated scores, so the
premium would be counted twice; correcting for that needs two further
approximations to recover 0.15pp.

**Verification.** The positional branch is checked against brute-force
enumeration of every draw the model can make, agreeing to 1.4e-07 on synthetic
units; against the closed form when the boost is zero, agreeing to 1.5e-16; and
in the R/JS cross-check against an independent R implementation that takes the
top two as `sum - min` rather than by the rearrangement above, agreeing to
1.5e-06. Atom masses sum to 1 within 2.7e-15 across all 48 team-roles.

## 9. Series composition

A Bo3's win/loss pattern is not free. Two games means a **2-0 or a 0-2**; three
games means the first two were **split one apiece** — that is what took it to a
third — plus a decider. Drawing three games freely from the pool produces 3-0 and
0-3 series that cannot occur, and two-game series with one win and one loss,
which also cannot occur.

**Decision: the draw is conditioned on the result.** A two-game series takes both
games from one pool. A three-game series takes one from each, plus a decider
drawn over the whole pool. `the Clutch` rides on that decider.

Two quantities follow from the recency-weighted game win rate `r`, using the
independence already established in section 5:

| Quantity | Value | Reason |
|---|---|---|
| P(the sweep is ours \| two games) | `r² / (r² + (1-r)²)` | Bayes on two independent games, conditioned on them agreeing |
| P(we take the decider \| three games) | `r` | It is one game |
| P(the decider is a given game) | its plain weight | The win pool holds exactly `r` of the weight, so choosing the pool and drawing within it cancel |

That last line is why the decider needs no special handling: `t = r` makes it an
ordinary weighted draw over every game.

Self-consistency check. Implied marginal win rate is
`[(1-p3)·2s + p3·(1+r)] / (2 + p3)`, which at `r = 0.7, p3 = 0.414` gives 0.702
against the 0.700 it was built from.

**The direction of the correction is not what it looks like.** The obvious
argument — free draws over-produce homogeneous series, more spread, higher
`E[max]` — is wrong, because `s ≥ r²` always. Conditioning on a two-game series
is *informative*: a sweep more likely belongs to the stronger side. At `r = 0.7`
that is an 84% chance both games are wins against 49% under free draws, which
lifts the ceiling more than losing the impossible 3-0 lowers it.

Measured across all 48 team-roles at the period's median run:

| | Change in E[max] |
|---|---|
| All units | **+0.86%** mean, 4 of 48 fall |
| Win rate above 60% (19 units) | +0.32% |
| Win rate below 50% (14 units) | +1.30% |
| Range | -0.70% at `r` = 0.76 to +3.05% at `r` = 0.42 |

So the unconditioned model was *understating* most team-roles, and understating
the weaker ones most. It re-ranks: the best period-1 roster's Core changes from
TEAM VISION to Aurora Gaming.

Cost: `computeAll` goes from about 450 ms to 680 ms, since the three-game
enumeration is now `|wins|·|losses|` pairs plus `n²` pair-and-decider atoms
rather than one closed form. A team-role with nothing in either pool falls back
to the unconditioned draw; none currently do, with win rates spanning 0.418 to
0.778.

**Verification.** Brute-force enumeration of the model straight from its
description agrees to 1.5e-15 without `the Clutch` and 1.0e-06 with it; mass sums
to 1 within 2.4e-15 across all 48 team-roles; Monte Carlo of the full series
model agrees to 0.06%; and the R/JS cross-check, with the R side taking the top
two as `sum - min` rather than by the rearrangement `calc.js` uses, agrees to
1.5e-06.

## 10. Decisions taken

| Decision | Basis |
|---|---|
| Resample individual games, not whole series | rho ~ 0.05 (section 5); keeps the 12% of role-games in 1-game series (section 3); removes thin-pool truncation (section 7) |
| Draw 2 or 3 games per Bo3, weighted by the observed rate | Section 3. Rate to be computed on the fly and exponentially weighted like every other statistic, not hardcoded |
| Use the global 2-vs-3 rate, not per team | It is a matchup property, not a team one, and the opponent field at TI differs from the patch history. At a median 25 Bo3s per team the binomial SE is ~0.10, so a true 42% reads anywhere from 22% to 62% |
| Model the grand final as a Bo3 | Affects 2 of 8 teams, at most 1 of their 2-6 series, and only if that series happens to be their max. Systematically understates those two teams, almost certainly by under 1% |
| Report E[P given N] rather than forecasting N | Separates an estimable quantity from a prediction, and leaves the judgement call with the user |
| Period 1 quotes a single number at N=6, footnoting the 4-6 spread; period 2 exposes N | Section 6: 3-6% against 11-16% |
| Pool is pairing only, no `same_team_in_match` | Header. The filter discards rebrands and whole-roster moves, which is where history transfers best |
| `the Clutch` is applied positionally, not carried | Section 8. Resampling destroys the position the flag describes, so carrying it imports the pool's format mix. Applying it to the third game of a simulated Bo3 reproduces the tournament's 17.1% by construction and discards no data. Costs the decider premium, 0.15pp against 2.11pp removed |
| Indicators are dropped on `all(is.na(...))`, never by name | `the Cruel` returns on its own once `fantasy.jar` supplies it, with no code change |
| Exact enumeration, not Monte Carlo | A series score is always `y_i + y_j`, so there are at most `n(n+1)/2` atoms with closed-form probabilities — 8,646 at the largest unit. Sampling would add error for nothing |
| Amplification applied per player, before pairing | Section 1. 27 role-games in one Core unit alone have exactly one of the pair triggering a given prefix |
| The series draw is conditioned on the result | Section 9. A Bo3 is 2-0, 0-2, 2-1 or 1-2, so free draws produce series that cannot happen. Worth +0.86% mean, and it re-ranks teams |

## 11. Open assumptions

- **Series are drawn independently**, so form persistence *across* series is not
  modelled. Direction of the bias is up. Unmeasured.
- **Within a pool, the game a series draws does not depend on the series.** The
  win/loss *composition* is now conditioned on length and result (section 9), but
  a win drawn into a 2-0 comes from the same distribution as a win drawn into a
  2-1, and they may not be alike. Unmeasured.
- **The 2-vs-3 rate is global**, so a team that consistently draws close series
  is not distinguished from one that sweeps. The sweep and decider odds are
  derived from the team's own win rate rather than from its observed series
  record, which would be far more thinly evidenced.
- **The last possible match is a random game.** Applying `the Clutch` positionally
  puts the bonus on a game drawn from the whole pool, so the measured tendency of
  deciders to score ~5.6% more is not modelled. Direction of the bias is down, by
  roughly 0.15pp of role score. Section 8.
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

## 12. The reroll model

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
| "Increase two and reduce one": three distinct emblems drawn only from those that can move in that direction; whichever half cannot happen does not | Behaviour at the caps is unstated. This makes the operation a guaranteed gain when every emblem sits at the bottom, since there is nothing to take away, and a guaranteed loss when every emblem is at the top. The game may instead withhold the operation entirely in the second case |

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

**Two ways to spend a token**, and they settle the recommendation entirely. Using
an option applies its effect *and* replaces all three options; a plain reroll
replaces all three and leaves the banners alone. Both cost one token and both
refresh, so the refresh cancels out of the comparison — the only difference is
whether the operation's effect comes with it. A gaining option therefore strictly
beats a plain reroll, and a losing one is strictly beaten by it. **Never take an
option with a negative expectation.**

Rerolling therefore sits in the table as a fourth row whose change is exactly
**zero**, and an option is worth taking only if it beats zero. Nothing
probabilistic is needed to make that comparison.

**When to stop.** Rerolling is worth a token only while some operation still
gains on some banner; if none does, a new set cannot hold one either. That is a
fact about the current banners rather than an expectation, and it replaces an
earlier "refresh value" — the average best of three random options — which was
removed. That figure could not be collected with the token being spent, since
taking the best of the new set costs another one, and it never entered the
recommendation.

The recommendation is **one step ahead**: a full dynamic program over the token
budget is not attempted, and the state space of banner configurations is why.

**Ground truth.** The multiplier model reproduces all nine emblems of a live
banner exactly, totals and trait percentages alike — 230/100/210, 130/110/160,
140/240/130. That is the only check against something other than our own
arithmetic, and it is a hard assertion in the test suite.

## 13. Data quality

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
