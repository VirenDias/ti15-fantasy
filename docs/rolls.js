// What a roll operation does to a War Banner, and what that is worth.
//
// Every outcome is enumerated exactly rather than sampled: the largest case is a
// stat reroll across three same-colour slots, which has 71 possibilities. The
// operations themselves, the quality ladder and the trait bonuses all come from
// the CSVs via data.json, so nothing about them is a literal here.

var CALC = (function () {
  if (typeof module !== "undefined" && module.exports) return require("./calc.js");
  return null;
})();

function valueOf(units, slots, data) {
  return CALC ? CALC.bannerValue(units, slots, data) : bannerValue(units, slots, data);
}

function cloneSlots(slots) {
  return slots.map(function (s) {
    return { stat: s.stat, quality: s.quality, trait: s.trait };
  });
}

// The slot groups an operation can hit, each with the chance of being the one
// hit — "one random Red emblem" is a mixture over the Red slots. An empty list
// means the operation cannot apply to this banner at all.
function targetGroups(colours, operation) {
  if (operation.property === "increase" || operation.property === "redistribute") {
    return [{ slots: colours.map(function (_, i) { return i; }), probability: 1 }];
  }

  var idx = [];
  colours.forEach(function (c, i) { if (c === operation.colour) idx.push(i); });
  if (idx.length === 0) return [];

  if (operation.scope === "all") return [{ slots: idx, probability: 1 }];
  if (operation.scope === "first") return [{ slots: [idx[0]], probability: 1 }];
  if (operation.scope === "last") return [{ slots: [idx[idx.length - 1]], probability: 1 }];
  if (operation.scope === "random") {
    return idx.map(function (i) {
      return { slots: [i], probability: 1 / idx.length };
    });
  }
  throw new Error("unknown roll scope: " + operation.scope);
}

// Quality and trait rerolls are independent per slot and cannot return the
// current value, so the remaining options renormalise.
function independentOutcomes(base, targets, key, options) {
  var results = [{ slots: cloneSlots(base), probability: 1 }];

  targets.forEach(function (si) {
    var current = base[si][key];
    var choices = options.filter(function (o) { return o.value !== current; });
    var mass = choices.reduce(function (s, c) { return s + c.weight; }, 0);
    var next = [];

    results.forEach(function (r) {
      choices.forEach(function (c) {
        var slots = cloneSlots(r.slots);
        slots[si][key] = c.value;
        next.push({ slots: slots, probability: r.probability * (c.weight / mass) });
      });
    });
    results = next;
  });

  return results;
}

// A stat reroll is a joint draw, not independent ones: a banner cannot hold the
// same stat twice, so the new stats must differ from each other, from every
// same-colour slot left untouched, and from their own current value. Uniform
// over the valid assignments.
function statOutcomes(base, targets, colours, colour, pool) {
  var held = [];
  colours.forEach(function (c, i) {
    if (c === colour && targets.indexOf(i) < 0) held.push(base[i].stat);
  });

  var results = [];
  (function recurse(k, taken, slots) {
    if (k === targets.length) {
      results.push(slots);
      return;
    }
    var si = targets[k];
    pool.forEach(function (stat) {
      if (stat === base[si].stat) return;
      if (held.indexOf(stat) >= 0) return;
      if (taken.indexOf(stat) >= 0) return;
      var copy = cloneSlots(slots);
      copy[si].stat = stat;
      recurse(k + 1, taken.concat([stat]), copy);
    });
  })(0, [], cloneSlots(base));

  return results.map(function (s) {
    return { slots: s, probability: 1 / results.length };
  });
}

// Assumed: uniform over the emblems that can still rise, one tier each time.
function increaseOutcomes(base, top) {
  var can = [];
  base.forEach(function (s, i) { if (s.quality < top) can.push(i); });
  if (can.length === 0) return [{ slots: cloneSlots(base), probability: 1 }];

  return can.map(function (i) {
    var slots = cloneSlots(base);
    slots[i].quality += 1;
    return { slots: slots, probability: 1 / can.length };
  });
}

// Assumed: three distinct emblems, two up and one down, uniform over the
// combinations that respect the top and bottom of the ladder.
function redistributeOutcomes(base, top) {
  var n = base.length;
  var combos = [];
  for (var d = 0; d < n; d++) {
    if (base[d].quality <= 0) continue;
    for (var a = 0; a < n; a++) {
      for (var b = a + 1; b < n; b++) {
        if (a === d || b === d) continue;
        if (base[a].quality >= top || base[b].quality >= top) continue;
        combos.push([a, b, d]);
      }
    }
  }
  if (combos.length === 0) return [{ slots: cloneSlots(base), probability: 1 }];

  return combos.map(function (c) {
    var slots = cloneSlots(base);
    slots[c[0]].quality += 1;
    slots[c[1]].quality += 1;
    slots[c[2]].quality -= 1;
    return { slots: slots, probability: 1 / combos.length };
  });
}

function outcomesFor(data, base, colours, group, operation) {
  var top = data.qualities.length - 1;

  if (operation.property === "quality") {
    return independentOutcomes(base, group.slots, "quality",
      data.qualities.map(function (q, i) { return { value: i, weight: q.weight }; }));
  }
  if (operation.property === "trait") {
    return independentOutcomes(base, group.slots, "trait",
      data.traits.map(function (_, i) { return { value: i, weight: 1 }; }));
  }
  if (operation.property === "stat") {
    var pool = [];
    data.stats.forEach(function (s, i) { if (s.colour === operation.colour) pool.push(i); });
    return statOutcomes(base, group.slots, colours, operation.colour, pool);
  }
  if (operation.property === "increase") return increaseOutcomes(base, top);
  if (operation.property === "redistribute") return redistributeOutcomes(base, top);

  throw new Error("unknown roll property: " + operation.property);
}

// null when the operation cannot touch this banner. Otherwise every outcome with
// its probability and its change in points, plus the summary the table shows.
function evaluate(data, units, slots, role, operation) {
  var colours = data.banner[role];
  var groups = targetGroups(colours, operation);
  if (groups.length === 0) return null;

  var current = valueOf(units, slots, data);
  var outcomes = [];

  groups.forEach(function (group) {
    outcomesFor(data, slots, colours, group, operation).forEach(function (o) {
      outcomes.push({
        slots: o.slots,
        probability: group.probability * o.probability
      });
    });
  });

  var expected = 0;
  var worse = 0;
  var worst = Infinity;
  var best = -Infinity;

  outcomes.forEach(function (o) {
    o.delta = valueOf(units, o.slots, data) - current;
    expected += o.probability * o.delta;
    if (o.delta < -1e-9) worse += o.probability;
    if (o.delta < worst) worst = o.delta;
    if (o.delta > best) best = o.delta;
  });

  return {
    current: current,
    expected: expected,
    worse: worse,
    worst: worst,
    best: best,
    outcomes: outcomes
  };
}

// Every operation against every banner, dropping the pairs that cannot apply.
function evaluateAll(data, unitsByRole, banner) {
  var rows = [];
  Object.keys(banner).forEach(function (role) {
    data.rolls.forEach(function (operation, oi) {
      var result = evaluate(data, unitsByRole[role], banner[role], role, operation);
      if (result) rows.push({ operation: operation, index: oi, role: role, result: result });
    });
  });
  rows.sort(function (a, b) { return b.result.expected - a.result.expected; });
  return rows;
}

// What a fresh set of three offers is worth, if you would take the best of them
// and only when it gains. Exact over all C(n,3) sets: with the operations sorted
// by value, the set's best is the k-th exactly when k is drawn and the other two
// come from below it.
function refreshValue(rows, operationCount) {
  var best = {};
  rows.forEach(function (r) {
    if (best[r.index] === undefined || r.result.expected > best[r.index]) {
      best[r.index] = r.result.expected;
    }
  });

  var values = [];
  for (var i = 0; i < operationCount; i++) {
    values.push(best[i] === undefined ? 0 : best[i]);
  }
  values.sort(function (a, b) { return b - a; });

  var n = values.length;
  if (n < 3) return 0;
  var total = (n * (n - 1) * (n - 2)) / 6;
  var expected = 0;
  for (var k = 0; k < n - 2; k++) {
    var below = n - 1 - k;
    var ways = (below * (below - 1)) / 2;
    expected += Math.max(0, values[k]) * (ways / total);
  }
  return expected;
}

if (typeof module !== "undefined" && module.exports) {
  module.exports = {
    targetGroups: targetGroups,
    outcomesFor: outcomesFor,
    evaluate: evaluate,
    evaluateAll: evaluateAll,
    refreshValue: refreshValue
  };
}
