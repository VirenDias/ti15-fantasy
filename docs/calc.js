// Expected fantasy points for a team-role under the TI15 scoring rules: the best
// two matches of a series, then the best series of the period.
//
// Both maxima are evaluated exactly rather than sampled. A unit's series score
// is always the sum of two of its games, so every possible series score is an
// atom y[i] + y[j] with a closed-form probability, and there are only n(n+1)/2
// of them. Nothing here touches the DOM, so the Node cross-check can require it.

var BINS = 1024;

// Points for each player row under a banner, before any amplification. Depends
// only on the banner, so it is hoisted out of the prefix/suffix loop.
function baseScores(unit, slots) {
  var rows = unit.pts.length;
  var base = new Float64Array(rows);
  for (var r = 0; r < rows; r++) {
    var row = unit.pts[r];
    var total = 0;
    for (var s = 0; s < slots.length; s++) {
      total += row[slots[s].stat] * slots[s].mult;
    }
    base[r] = total;
  }
  return base;
}

// A role-game scores the average of its players, each amplified by their own
// triggers. The amplification has to be applied per player before averaging,
// since the two rarely trigger the same prefix in the same match.
//
// Averaging before the game is picked is what makes a role's two players want
// to peak together: two good games and one bad beats three games where one
// player is good and the other is not.
// A suffix that describes the match itself travels with the game it was measured
// on. One that describes the match's *position in its series* cannot, because
// resampling is exactly what destroys the position — carrying the flag along
// imports the source data's format mix instead of the tournament's. Those are
// applied by where the draw puts the game, not by what it was flagged with.
function isPositional(suffix) {
  return !!suffix && suffix.scope === "series_position";
}

// What a positional suffix adds to a game if the draw puts it last. The bonus is
// a property of the match, so both players of the role trigger it together, and
// it lands additively alongside the prefix rather than multiplying the result.
function positionalBoost(unit, base, suffix) {
  if (!isPositional(suffix) || !suffix.bonus) return null;

  var games = unit.w.length;
  var size = unit.size;
  var bonus = suffix.bonus / 100;
  var boost = new Float64Array(games);
  for (var g = 0; g < games; g++) {
    var raw = 0;
    for (var k = 0; k < size; k++) raw += base[g * size + k];
    boost[g] = bonus * raw / size;
  }
  return boost;
}

function amplify(unit, base, prefix, suffix) {
  var games = unit.w.length;
  var size = unit.size;
  var y = new Float64Array(games);
  var carried = isPositional(suffix) ? null : suffix;
  var pBit = prefix ? prefix.bit : 0;
  var sBit = carried ? carried.bit : 0;
  var pBonus = prefix ? prefix.bonus / 100 : 0;
  var sBonus = carried ? carried.bonus / 100 : 0;

  for (var g = 0; g < games; g++) {
    var total = 0;
    for (var k = 0; k < size; k++) {
      var r = g * size + k;
      var flags = unit.ind[r];
      var amp = 1;
      if (pBit && (flags & pBit) !== 0) amp += pBonus;
      if (sBit && (flags & sBit) !== 0) amp += sBonus;
      total += base[r] * amp;
    }
    y[g] = total / size;
  }
  return y;
}

// Mass at or below x, and mass strictly below x, over an ascending list with its
// running totals. The two have to split a tie the same way or the pieces of the
// enumeration below do not add to one.
function massAtOrBelow(values, cums, x) {
  var a = 0;
  var b = values.length;
  while (a < b) { var m = (a + b) >> 1; if (values[m] <= x) a = m + 1; else b = m; }
  return a > 0 ? cums[a - 1] : 0;
}

function massBelow(values, cums, x) {
  var a = 0;
  var b = values.length;
  while (a < b) { var m = (a + b) >> 1; if (values[m] < x) a = m + 1; else b = m; }
  return a > 0 ? cums[a - 1] : 0;
}

function running(probs) {
  var out = new Float64Array(probs.length);
  var acc = 0;
  for (var i = 0; i < probs.length; i++) { acc += probs[i]; out[i] = acc; }
  return out;
}

// Wins and losses as two ascending pools, each with its own normalised weights.
// Null when either is empty, since the composition below needs both.
function splitByResult(ys, ws, order, win) {
  var wv = [], wp = [], lv = [], lp = [], share = 0;
  for (var i = 0; i < ys.length; i++) {
    if (win[order[i]]) { wv.push(ys[i]); wp.push(ws[i]); share += ws[i]; }
    else { lv.push(ys[i]); lp.push(ws[i]); }
  }
  if (wv.length === 0 || lv.length === 0) return null;

  for (i = 0; i < wp.length; i++) wp[i] /= share;
  for (i = 0; i < lp.length; i++) lp[i] /= 1 - share;

  return {
    order: order,
    win: win,
    share: share,
    wv: Float64Array.from(wv), wp: Float64Array.from(wp), wc: running(wp),
    lv: Float64Array.from(lv), lp: Float64Array.from(lp), lc: running(lp)
  };
}

// A series conditioned on its result. Games within a series are taken as
// independent (methodology.md section 5), so the chance of sweeping a two-game
// series follows from the recency-weighted game win rate r as r^2/(r^2+(1-r)^2),
// and the decider is a single game, won with probability r.
function conditioned(pools, ys, yc, ws, p3, add) {
  var r = pools.share;
  var sweepOdds = r * r / (r * r + (1 - r) * (1 - r));
  var p2 = 1 - p3;
  var a, b, d;

  // Two games: a 2-0 or a 0-2, so both come from the same pool
  function sweep(values, probs, weight) {
    for (var x = 0; x < values.length; x++) {
      add(2 * values[x], weight * probs[x] * probs[x]);
      for (var z = 0; z < x; z++) {
        add(values[x] + values[z], weight * 2 * probs[x] * probs[z]);
      }
    }
  }
  sweep(pools.wv, pools.wp, p2 * sweepOdds);
  sweep(pools.lv, pools.lp, p2 * (1 - sweepOdds));

  // The decider carries the positional bonus, and goes to the side that takes
  // the series — probability r. The win pool holds exactly r of the weight, so
  // choosing the pool and then drawing within it cancel out, and the decider
  // comes out a plain weighted draw over every game.
  var dv = [], dp = [];
  for (var i = 0; i < ys.length; i++) {
    dv.push(yc ? yc[i] : ys[i]);
    dp.push(ws[i]);
  }
  var di = dv.map(function (_, k) { return k; })
    .sort(function (x, z) { return dv[x] - dv[z]; });
  var DV = Float64Array.from(di, function (k) { return dv[k]; });
  var DP = Float64Array.from(di, function (k) { return dp[k]; });
  var DC = running(DP);

  // Top two of the three is M + max(m, v), with M and m the larger and smaller
  // of the split pair and v the decider.
  //
  // (a) the decider is no larger than the smaller of the pair, so the pair alone
  //     scores
  for (a = 0; a < pools.wv.length; a++) {
    for (b = 0; b < pools.lv.length; b++) {
      var smaller = pools.wv[a] < pools.lv[b] ? pools.wv[a] : pools.lv[b];
      var g = massAtOrBelow(DV, DC, smaller);
      if (g > 0) add(pools.wv[a] + pools.lv[b], p3 * pools.wp[a] * pools.lp[b] * g);
    }
  }

  // (b) the decider displaces the smaller, so it scores with the larger. Split
  //     by which side of the pair is larger, so each mass is a prefix sum.
  var lossBelowWin = Float64Array.from(pools.wv, function (v) {
    return massBelow(pools.lv, pools.lc, v);
  });
  var lossBelowDecider = Float64Array.from(DV, function (v) {
    return massBelow(pools.lv, pools.lc, v);
  });
  for (a = 0; a < pools.wv.length; a++) {
    for (d = 0; d < DV.length; d++) {
      // both bounds are strict, and the mass is monotone, so the tighter wins
      var mass = lossBelowWin[a] < lossBelowDecider[d] ? lossBelowWin[a] : lossBelowDecider[d];
      if (mass > 0) add(pools.wv[a] + DV[d], p3 * DP[d] * pools.wp[a] * mass);
    }
  }

  var winBelowDecider = Float64Array.from(DV, function (v) {
    return massBelow(pools.wv, pools.wc, v);
  });
  var winAtOrBelowLoss = Float64Array.from(pools.lv, function (v) {
    return massAtOrBelow(pools.wv, pools.wc, v);
  });
  for (b = 0; b < pools.lv.length; b++) {
    for (d = 0; d < DV.length; d++) {
      var m2 = DV[d] <= pools.lv[b] ? winBelowDecider[d] : winAtOrBelowLoss[b];
      if (m2 > 0) add(pools.lv[b] + DV[d], p3 * DP[d] * pools.lp[b] * m2);
    }
  }
}

// The exact distribution of a series score, as a histogram over y[i] + y[j].
//
// Games are drawn independently with replacement, weighted by recency. Sorting
// ascending lets the three-game case be written in closed form by conditioning
// on which index is largest and which is second largest:
//
//   two games    P(i,j) = 2*wi*wj                        i<j    wi^2                   i=j
//   three games  P(i,j) = 3*wj*(wi^2 + 2*wi*W[i-1])      i<j    3*wj^2*W[j-1] + wj^3   i=j
//
// Both telescope to 1, which the tests assert.
//
// `boost` carries a positional suffix. A Bo3 that runs to three games has a last
// possible match and a two-game one does not, so the bonus lands on the third
// draw only — which reproduces the tournament's rate, p3 / (2 + p3), by
// construction rather than by filtering the pool.
//
// `win` conditions the draw on the result. A Bo3's win/loss pattern is not free:
// two games means a 2-0 or a 0-2, and three games means the first two were split
// one apiece — that is what took it to a third — plus a decider that goes to
// whoever takes the series. Drawing from the pool as a whole would produce 3-0
// and 0-3 series that cannot happen, and the extra spread flatters E[max].
function seriesHistogram(y, w, p3, boost, win) {
  var n = y.length;
  var order = new Array(n);
  for (var i = 0; i < n; i++) order[i] = i;
  order.sort(function (a, b) { return y[a] - y[b]; });

  var ys = new Float64Array(n);
  var ws = new Float64Array(n);
  var sumW = 0;
  for (i = 0; i < n; i++) {
    ys[i] = y[order[i]];
    ws[i] = w[order[i]];
    sumW += ws[i];
  }
  var cum = new Float64Array(n);
  var acc = 0;
  for (i = 0; i < n; i++) {
    ws[i] /= sumW;
    acc += ws[i];
    cum[i] = acc;
  }

  // The bonused values are not sorted even though the plain ones are, since the
  // boost varies from game to game
  var yc = null;
  var top = ys[n - 1];
  if (boost) {
    yc = new Float64Array(n);
    for (i = 0; i < n; i++) {
      yc[i] = ys[i] + boost[order[i]];
      if (yc[i] > top) top = yc[i];
    }
  }

  var lo = 2 * ys[0];
  var span = ys[n - 1] + top - lo || 1;
  var binP = new Float64Array(BINS);
  var binV = new Float64Array(BINS);
  var p2 = 1 - p3;
  var j, wj, wi, below, under;

  function add(value, prob) {
    var b = ((value - lo) / span * BINS) | 0;
    if (b < 0) b = 0;
    if (b >= BINS) b = BINS - 1;
    binP[b] += prob;
    binV[b] += prob * value;
  }

  // Split the sorted games by result. A team with nothing in one pool cannot be
  // modelled this way, so it falls back to drawing from the pool as a whole.
  var pools = win ? splitByResult(ys, ws, order, win) : null;
  if (pools) {
    conditioned(pools, ys, yc, ws, p3, add);
    return { p: binP, v: binV };
  }

  // Two games: both count, and neither is the last possible match of the series
  for (j = 0; j < n; j++) {
    wj = ws[j];
    add(2 * ys[j], p2 * wj * wj);
    for (i = 0; i < j; i++) add(ys[i] + ys[j], p2 * 2 * ws[i] * wj);
  }

  if (!yc) {
    for (j = 0; j < n; j++) {
      wj = ws[j];
      below = j > 0 ? cum[j - 1] : 0;
      add(2 * ys[j], p3 * (3 * wj * wj * below + wj * wj * wj));

      for (i = 0; i < j; i++) {
        wi = ws[i];
        under = i > 0 ? cum[i - 1] : 0;
        add(ys[i] + ys[j], p3 * 3 * wj * (wi * wi + 2 * wi * under));
      }
    }
    return { p: binP, v: binV };
  }

  // Three games with the bonus on the third, which is no longer exchangeable
  // with the other two. Writing the top-two sum as M + max(m, v) — M and m the
  // larger and smaller of the two plain draws, v the bonused one — keeps this to
  // the same order of work as the closed form above.
  var cOrder = new Array(n);
  for (i = 0; i < n; i++) cOrder[i] = i;
  cOrder.sort(function (a, b) { return yc[a] - yc[b]; });

  var cVal = new Float64Array(n);
  var cCum = new Float64Array(n);
  acc = 0;
  for (i = 0; i < n; i++) {
    cVal[i] = yc[cOrder[i]];
    acc += ws[cOrder[i]];
    cCum[i] = acc;
  }

  // P(v <= x), and how many plain values fall strictly below x. The two have to
  // split on the tie the same way or the masses do not add to one.
  function massAtOrBelow(x) {
    var a = 0, b = n;
    while (a < b) { var mid = (a + b) >> 1; if (cVal[mid] <= x) a = mid + 1; else b = mid; }
    return a > 0 ? cCum[a - 1] : 0;
  }
  function countBelow(x) {
    var a = 0, b = n;
    while (a < b) { var mid = (a + b) >> 1; if (ys[mid] < x) a = mid + 1; else b = mid; }
    return a;
  }

  var gOf = new Float64Array(n);
  for (i = 0; i < n; i++) gOf[i] = massAtOrBelow(ys[i]);
  var kOf = new Int32Array(n);
  for (i = 0; i < n; i++) kOf[i] = countBelow(yc[i]);

  // v is no larger than the smaller plain draw, so the pair alone scores
  for (j = 0; j < n; j++) {
    wj = ws[j];
    for (i = 0; i <= j; i++) {
      var g = gOf[i];
      if (g > 0) {
        add(ys[i] + ys[j], p3 * (i === j ? wj * wj : 2 * ws[i] * wj) * g);
      }
    }
  }

  // v displaces the smaller draw, so it scores alongside the larger one
  for (j = 0; j < n; j++) {
    wj = ws[j];
    for (var c = 0; c < n; c++) {
      var k = kOf[c];
      var t = Math.min(k, j) - 1;
      var mass = 2 * wj * (t >= 0 ? cum[t] : 0) + (k > j ? wj * wj : 0);
      if (mass > 0) add(ys[j] + yc[c], p3 * ws[c] * mass);
    }
  }

  return { p: binP, v: binV };
}

// E[max of N] over the binned CDF. Each bucket contributes its conditional mean
// rather than its midpoint, so the answer is exact to the width of a bucket
// only in the tail ordering, not in the values.
function expectedMax(hist, nValues) {
  var total = 0;
  for (var b = 0; b < BINS; b++) total += hist.p[b];

  var out = new Float64Array(nValues.length);
  var below = 0;
  for (b = 0; b < BINS; b++) {
    if (hist.p[b] <= 0) continue;
    var mean = hist.v[b] / hist.p[b];
    var above = below + hist.p[b] / total;
    if (b === BINS - 1) above = 1;
    for (var k = 0; k < nValues.length; k++) {
      out[k] += mean * (Math.pow(above, nValues[k]) - Math.pow(below, nValues[k]));
    }
    below = above;
  }
  return out;
}

// Every bonus comes from qualities.csv and traits.csv. Only the conditions live
// here, because they are structural rather than numeric — the same split as
// prefixes.csv and its conditions in src/compile-match-data.R.
var TRAIT_CONDITION = {
  Fractal: function (banner) { return banner.allQualitiesDiffer; },
  Benevolent: function () { return false; },   // gives nothing to itself
  Vampiric: function () { return true; },      // unconditional
  Unique: function (banner) { return banner.uniques === 1; },
  Friendly: function (banner) { return banner.friendlies >= 3; }
};

// A rename in traits.csv has to be matched by a condition here, so it fails on
// load rather than silently scoring the trait as worthless
function assertTraitsKnown(data) {
  var want = Object.keys(TRAIT_CONDITION).slice().sort().join(", ");
  var got = data.traits.map(function (t) { return t.name; }).slice().sort().join(", ");
  if (want !== got) {
    throw new Error("traits.csv holds [" + got + "] but calc.js has conditions for [" +
                    want + "]");
  }
}

// Per slot: the quality bonus, the net trait contribution including what the
// neighbours do to it, and the total multiplier. The net trait figure is the
// percentage the game prints on the emblem, so it can be checked by eye.
function multipliers(slots, data) {
  var n = slots.length;
  var names = slots.map(function (s) { return data.traits[s.trait].name; });
  var context = {
    allQualitiesDiffer: new Set(slots.map(function (s) { return s.quality; })).size === n,
    uniques: names.filter(function (x) { return x === "Unique"; }).length,
    friendlies: names.filter(function (x) { return x === "Friendly"; }).length
  };

  var out = new Array(n);
  for (var i = 0; i < n; i++) {
    var quality = data.qualities[slots[i].quality].bonus / 100;
    var own = data.traits[slots[i].trait];
    var trait = TRAIT_CONDITION[own.name](context) ? own.bonus / 100 : 0;

    // Adjacency is linear, so only i-1 and i+1
    if (i > 0) trait += data.traits[slots[i - 1].trait].adjacent / 100;
    if (i < n - 1) trait += data.traits[slots[i + 1].trait].adjacent / 100;

    out[i] = { quality: quality, trait: trait, total: 1 + quality + trait };
  }
  return out;
}

// What one role's banner is worth: the mean across that role's teams of the
// calculator's own expectation. Nothing is averaged inside a team — each term is
// already the full nested-maxima value. The mean only stands in for a team
// choice that has not been made yet.
function bannerValue(units, slots, data) {
  var mult = multipliers(slots, data);
  var resolved = slots.map(function (s, i) {
    return { stat: s.stat, mult: mult[i].total };
  });
  var n = [data.meta.n_median];

  var total = 0;
  for (var u = 0; u < units.length; u++) {
    var base = baseScores(units[u], resolved);
    var y = amplify(units[u], base, null, null);
    total += expectedMax(
      seriesHistogram(y, units[u].w, data.meta.p3, null, units[u].win), n)[0];
  }
  return total / units.length;
}

function pairList(data) {
  var pairs = [];
  for (var p = 0; p < data.prefixes.length; p++) {
    for (var s = 0; s < data.suffixes.length; s++) {
      pairs.push({ prefix: data.prefixes[p], suffix: data.suffixes[s] });
    }
  }
  return pairs;
}

// results[unit][pair][n] -- expected points for that team-role
function computeAll(data, banner) {
  var pairs = pairList(data);
  var nValues = data.meta.n_values;

  var results = data.units.map(function (unit) {
    var base = baseScores(unit, banner[unit.role]);
    return pairs.map(function (pair) {
      var y = amplify(unit, base, pair.prefix, pair.suffix);
      var boost = positionalBoost(unit, base, pair.suffix);
      return Array.from(
        expectedMax(seriesHistogram(y, unit.w, data.meta.p3, boost, unit.win), nValues)
      );
    });
  });

  return { pairs: pairs, results: results, nValues: nValues };
}

if (typeof module !== "undefined" && module.exports) {
  module.exports = {
    BINS: BINS,
    baseScores: baseScores,
    amplify: amplify,
    positionalBoost: positionalBoost,
    seriesHistogram: seriesHistogram,
    splitByResult: splitByResult,
    expectedMax: expectedMax,
    pairList: pairList,
    computeAll: computeAll,
    multipliers: multipliers,
    bannerValue: bannerValue,
    assertTraitsKnown: assertTraitsKnown,
    TRAIT_CONDITION: TRAIT_CONDITION
  };
}
