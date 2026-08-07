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
function amplify(unit, base, prefix, suffix) {
  var games = unit.w.length;
  var size = unit.size;
  var y = new Float64Array(games);
  var pBit = prefix ? prefix.bit : 0;
  var sBit = suffix ? suffix.bit : 0;
  var pBonus = prefix ? prefix.bonus / 100 : 0;
  var sBonus = suffix ? suffix.bonus / 100 : 0;

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
function seriesHistogram(y, w, p3) {
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

  var lo = 2 * ys[0];
  var span = 2 * ys[n - 1] - lo || 1;
  var binP = new Float64Array(BINS);
  var binV = new Float64Array(BINS);
  var p2 = 1 - p3;

  function add(value, prob) {
    var b = ((value - lo) / span * BINS) | 0;
    if (b < 0) b = 0;
    if (b >= BINS) b = BINS - 1;
    binP[b] += prob;
    binV[b] += prob * value;
  }

  for (var j = 0; j < n; j++) {
    var wj = ws[j];
    var below = j > 0 ? cum[j - 1] : 0;
    add(2 * ys[j], p2 * wj * wj + p3 * (3 * wj * wj * below + wj * wj * wj));

    for (i = 0; i < j; i++) {
      var wi = ws[i];
      var under = i > 0 ? cum[i - 1] : 0;
      add(
        ys[i] + ys[j],
        p2 * 2 * wi * wj + p3 * 3 * wj * (wi * wi + 2 * wi * under)
      );
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
    total += expectedMax(seriesHistogram(y, units[u].w, data.meta.p3), n)[0];
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
      return Array.from(
        expectedMax(seriesHistogram(y, unit.w, data.meta.p3), nValues)
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
    seriesHistogram: seriesHistogram,
    expectedMax: expectedMax,
    pairList: pairList,
    computeAll: computeAll,
    multipliers: multipliers,
    bannerValue: bannerValue,
    assertTraitsKnown: assertTraitsKnown,
    TRAIT_CONDITION: TRAIT_CONDITION
  };
}
