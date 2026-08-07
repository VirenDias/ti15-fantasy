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

// Assumed: two distinct emblems go up and a third comes down, drawn only from
// the ones that can actually move. Whichever half cannot happen simply does not
// — with every emblem at the bottom of the ladder there is nothing to take away,
// so the operation is a pure gain.
function redistributeOutcomes(base, top) {
  var up = [];
  var down = [];
  base.forEach(function (slot, i) {
    if (slot.quality < top) up.push(i);
    if (slot.quality > 0) down.push(i);
  });

  var raises = [];
  if (up.length >= 2) {
    for (var a = 0; a < up.length; a++) {
      for (var b = a + 1; b < up.length; b++) raises.push([up[a], up[b]]);
    }
  } else {
    raises.push(up.slice());
  }

  var combos = [];
  raises.forEach(function (pair) {
    var choices = down.filter(function (i) { return pair.indexOf(i) < 0; });
    if (choices.length === 0) {
      combos.push({ raise: pair, lower: -1 });
    } else {
      choices.forEach(function (d) { combos.push({ raise: pair, lower: d }); });
    }
  });

  return combos.map(function (c) {
    var slots = cloneSlots(base);
    c.raise.forEach(function (i) { slots[i].quality += 1; });
    if (c.lower >= 0) slots[c.lower].quality -= 1;
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

if (typeof module !== "undefined" && module.exports) {
  module.exports = {
    targetGroups: targetGroups,
    outcomesFor: outcomesFor,
    evaluate: evaluate,
    evaluateAll: evaluateAll
  };
}
