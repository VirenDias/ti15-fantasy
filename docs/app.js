"use strict";

var ROLES = ["Core", "Mid", "Support"];

var DATA = null;      // data.json
var UNITS = {};       // role -> the role's team-units
var BANNER = {};      // role -> [{stat, quality, trait}] per slot
var COMPUTED = null;  // { pairs, results[unit][pair][n], nValues }
var ROWS = [];        // one per roster
var ROLL_ROWS = [];   // one per applicable (operation, banner) pair
var UNIT = {};        // "team|role" -> index into DATA.units
var median = 0;       // index of the assumed series count within nValues
var sortIndex = 0;    // which roster column the table is ordered by
var options = [-1, -1, -1];   // the three the game is offering
var openRow = "";             // "operationIndex|role" of the expanded row

// jsonlite unboxes length-one vectors, so anything that can be a singleton
// has to be coerced back
function asArray(x) {
  if (x === null || x === undefined) return [];
  return Array.isArray(x) ? x : [x];
}

function el(tag, cls, text) {
  var node = document.createElement(tag);
  if (cls) node.className = cls;
  if (text !== undefined) node.textContent = text;
  return node;
}

function signed(x) {
  var n = Math.round(x);
  // A change that rounds to nothing is not a gain, so it gets no sign either
  if (n === 0) return "0";
  return (n > 0 ? "+" : "−") + Math.abs(n).toLocaleString();
}

function tone(x) {
  if (Math.round(x) === 0) return "zero";
  return x > 0 ? "gain" : "loss";
}

function key(text) { return { text: text, cls: "key" }; }
function mark(text, cls) { return { text: text, cls: cls }; }

// Both tabs word their recommendation the same way: a mood on the box, and a
// sentence with the choice and the figures picked out of it
function say(id, mood, parts) {
  var box = document.getElementById(id);
  var text = box.querySelector(".advice-text");
  box.className = "advice " + mood;
  text.textContent = "";
  parts.forEach(function (part) {
    text.appendChild(typeof part === "string"
      ? document.createTextNode(part)
      : el("span", part.cls, part.text));
  });
}

function breakingOut() {
  return document.getElementById("show-n").checked;
}

// --- banner ----------------------------------------------------------------

// A War Banner cannot hold the same stat twice, so a clash swaps the two slots
// rather than refusing the choice. Both slots must share a colour for a clash to
// be possible at all, and a swap between them is therefore always legal.
function setStat(role, position, value) {
  BANNER[role].forEach(function (slot, i) {
    if (i !== position && slot.stat === value) slot.stat = BANNER[role][position].stat;
  });
  BANNER[role][position].stat = value;
}

function buildBanner() {
  var host = document.getElementById("banner");
  host.textContent = "";

  var byColour = {};
  DATA.stats.forEach(function (s, i) {
    (byColour[s.colour] = byColour[s.colour] || []).push({ index: i, label: s.label });
  });
  Object.keys(byColour).forEach(function (colour) {
    byColour[colour].sort(function (a, b) { return a.label.localeCompare(b.label); });
  });
  var traits = DATA.traits.map(function (t, i) { return { index: i, label: t.name }; })
    .sort(function (a, b) { return a.label.localeCompare(b.label); });

  ROLES.forEach(function (role) {
    var colours = asArray(DATA.banner[role]);
    var card = el("div", "role");
    card.appendChild(el("h3", null, role));

    colours.forEach(function (colour, position) {
      // The coloured spine says which colour the emblem is; the stats the
      // dropdown offers say it again for anyone who cannot see it
      var slot = el("div", "slot " + colour);

      // Stat, then quality and trait on their own lines with their own bonuses,
      // the way the game lays an emblem out
      var head = el("div", "slot-line");
      head.appendChild(dropdown(byColour[colour], BANNER[role][position].stat,
        role + " " + colour + " emblem", function (v) { setStat(role, position, v); }));
      head.appendChild(readout("mult", role, position, "total"));
      slot.appendChild(head);

      var quality = el("div", "slot-line sub");
      quality.appendChild(dropdown(
        DATA.qualities.map(function (q, i) { return { index: i, label: q.name }; }),
        BANNER[role][position].quality, role + " quality",
        function (v) { BANNER[role][position].quality = v; }));
      quality.appendChild(readout("bonus", role, position, "quality"));
      slot.appendChild(quality);

      var trait = el("div", "slot-line sub");
      trait.appendChild(dropdown(traits,
        BANNER[role][position].trait, role + " trait",
        function (v) { BANNER[role][position].trait = v; }));
      trait.appendChild(readout("bonus", role, position, "trait"));
      slot.appendChild(trait);

      card.appendChild(slot);
    });

    host.appendChild(card);
  });

  showMultipliers();
}

function readout(cls, role, position, kind) {
  var node = el("span", cls);
  node.dataset.role = role;
  node.dataset.position = position;
  node.dataset.kind = kind;
  return node;
}

function dropdown(items, selected, label, onPick) {
  var select = el("select");
  select.setAttribute("aria-label", label);
  items.forEach(function (o) {
    var option = el("option", null, o.label);
    option.value = o.index;
    select.appendChild(option);
  });
  select.value = selected;
  select.addEventListener("change", function () {
    onPick(+select.value);
    syncBanner();
    recompute();
  });
  return select;
}

// The stat swap can change a select other than the one that was touched
function syncBanner() {
  var host = document.getElementById("banner");
  ROLES.forEach(function (role) {
    var cards = host.querySelectorAll(".role");
    var card = cards[ROLES.indexOf(role)];
    card.querySelectorAll(".slot").forEach(function (slot, i) {
      var selects = slot.querySelectorAll("select");
      selects[0].value = BANNER[role][i].stat;
      selects[1].value = BANNER[role][i].quality;
      selects[2].value = BANNER[role][i].trait;
    });
  });
  showMultipliers();
}

function showMultipliers() {
  ROLES.forEach(function (role) {
    multipliers(BANNER[role], DATA).forEach(function (slot, i) {
      var at = function (kind) {
        return document.querySelector('[data-role="' + role + '"][data-position="' + i +
                                      '"][data-kind="' + kind + '"]');
      };
      var pct = function (x) {
        return (x >= 0 ? "+" : "−") + Math.abs(Math.round(x * 100)) + "%";
      };

      at("total").textContent = Math.round(slot.total * 100) + "%";
      at("quality").textContent = pct(slot.quality);
      // The trait figure the game prints is the net one, after neighbours
      at("trait").textContent = pct(slot.trait);
      at("trait").title = "Includes what neighbouring emblems do to this one";
    });
  });
}

// --- rosters ---------------------------------------------------------------

function resolved(role) {
  var m = multipliers(BANNER[role], DATA);
  return BANNER[role].map(function (s, i) { return { stat: s.stat, mult: m[i].total }; });
}

function buildRows() {
  var results = COMPUTED.results;
  var pairs = COMPUTED.pairs;
  var nCount = COMPUTED.nValues.length;
  var rows = [];

  DATA.teams.forEach(function (core) {
    var ci = UNIT[core.id + "|Core"];
    DATA.teams.forEach(function (mid) {
      var mi = UNIT[mid.id + "|Mid"];
      DATA.teams.forEach(function (support) {
        var si = UNIT[support.id + "|Support"];

        // One prefix and one suffix cover the whole roster, so the best pair
        // depends on all three teams at once and cannot be chosen per role
        var best = 0;
        var bestValue = -Infinity;
        for (var p = 0; p < pairs.length; p++) {
          var value = results[ci][p][median] + results[mi][p][median] + results[si][p][median];
          if (value > bestValue) { bestValue = value; best = p; }
        }

        var values = new Array(nCount);
        for (var k = 0; k < nCount; k++) {
          values[k] = results[ci][best][k] + results[mi][best][k] + results[si][best][k];
        }

        rows.push({ core: core, mid: mid, support: support, pair: pairs[best], values: values });
      });
    });
  });

  return rows;
}

function addSortable(head, label, index, extra) {
  var th = el("th", "num sortable" + (extra || ""), label);
  th.dataset.index = index;
  th.tabIndex = 0;
  th.setAttribute("role", "button");
  function sort() { sortIndex = index; renderRosters(); }
  th.addEventListener("click", sort);
  th.addEventListener("keydown", function (event) {
    if (event.key === "Enter" || event.key === " ") { event.preventDefault(); sort(); }
  });
  head.appendChild(th);
}

function renderRosters() {
  if (!breakingOut()) sortIndex = median;
  ROWS.sort(function (a, b) { return b.values[sortIndex] - a.values[sortIndex]; });

  var head = document.getElementById("head");
  head.textContent = "";
  ["", "Core", "Mid", "Support", "Prefix", "Suffix"].forEach(function (label) {
    head.appendChild(el("th", null, label));
  });
  if (breakingOut()) {
    COMPUTED.nValues.forEach(function (n, index) {
      addSortable(head, n + " series", index, n === DATA.meta.n_median ? " median" : "");
    });
  } else {
    addSortable(head, "Expected", median, " median");
  }

  var columns = breakingOut() ? COMPUTED.nValues.map(function (_, i) { return i; }) : [median];
  var body = document.getElementById("body");
  body.textContent = "";

  ROWS.forEach(function (row, rank) {
    var tr = el("tr");
    tr.appendChild(el("td", "rank", rank + 1));
    tr.appendChild(el("td", null, row.core.name));
    tr.appendChild(el("td", null, row.mid.name));
    tr.appendChild(el("td", null, row.support.name));
    tr.appendChild(el("td", null, row.pair.prefix.name));
    tr.appendChild(el("td", null, row.pair.suffix.name));
    columns.forEach(function (index) {
      tr.appendChild(el("td", "num" + (index === median ? " median" : ""),
        Math.round(row.values[index]).toLocaleString()));
    });
    body.appendChild(tr);
  });

  document.querySelectorAll("#head th.sortable").forEach(function (th) {
    th.classList.toggle("sorted", +th.dataset.index === sortIndex);
  });

  document.getElementById("roster-title").textContent =
    "Best roster-title combinations · " + ROWS.length.toLocaleString() +
    " possible rosters";

  renderRosterAdvice();
}

// The top row of the table as it is currently ordered, so the box and the table
// can never disagree about which roster is being recommended
function renderRosterAdvice() {
  var top = ROWS[0];
  say("roster-advice", "gain", [
    "Take ", key(top.core.name), " Core, ", key(top.mid.name), " Mid and ",
    key(top.support.name), " Support, with ", key(top.pair.prefix.name),
    " prefix and ", key(top.pair.suffix.name), " suffix: ",
    mark(Math.round(top.values[sortIndex]).toLocaleString(), "gain"),
    " points at " + COMPUTED.nValues[sortIndex] + " series."
  ]);
}

// --- rerolls ---------------------------------------------------------------

// Grouped by colour then by what they change, in file order, which is the order
// the game lists them in
function rollGroups() {
  var groups = [];
  var seen = {};
  DATA.rolls.forEach(function (roll, index) {
    var label = roll.colour
      ? roll.colour + " " + roll.property.charAt(0).toUpperCase() + roll.property.slice(1)
      : "Misc";
    if (!seen[label]) {
      seen[label] = { label: label, items: [] };
      groups.push(seen[label]);
    }
    seen[label].items.push({ roll: roll, index: index });
  });
  return groups;
}

function buildOptions() {
  var host = document.getElementById("options");
  host.textContent = "";
  var groups = rollGroups();

  for (var slot = 0; slot < 3; slot++) {
    (function (index) {
      var wrap = el("label", "offer");
      wrap.appendChild(el("span", null, "Option " + (index + 1)));
      var select = el("select");
      var none = el("option", null, "— none —");
      none.value = -1;
      select.appendChild(none);
      groups.forEach(function (group) {
        var optgroup = el("optgroup");
        optgroup.label = group.label;
        group.items.forEach(function (entry) {
          var option = el("option", null, entry.roll.name);
          option.value = entry.index;
          optgroup.appendChild(option);
        });
        select.appendChild(optgroup);
      });
      select.value = options[index];
      select.addEventListener("change", function () {
        var picked = +select.value;
        // The game never offers the same operation twice, so a clash swaps
        if (picked >= 0) {
          options.forEach(function (other, j) {
            if (j !== index && other === picked) options[j] = options[index];
          });
        }
        options[index] = picked;
        syncOptions();
        renderRolls();
      });
      wrap.appendChild(select);
      host.appendChild(wrap);
    })(slot);
  }
}

function syncOptions() {
  document.querySelectorAll("#options select").forEach(function (select, i) {
    select.value = options[i];
  });
}

function shownRows() {
  var picked = options.filter(function (i) { return i >= 0; });
  return ROLL_ROWS.filter(function (r) { return picked.indexOf(r.index) >= 0; });
}

// Rerolling sits in the table as a fourth choice, the way the game presents it.
// Its change is exactly zero because it leaves the banners alone — and zero is
// the right thing to compare an option against, since both actions cost a token
// and both hand you three new options. That common part cancels out.
function rerollRow() {
  return {
    reroll: true,
    index: -1,
    operation: { name: "Reroll operations" },
    role: null,
    result: { expected: 0, worse: 0, worst: 0, best: 0, outcomes: [] }
  };
}

function tableRows() {
  return shownRows().concat([rerollRow()]).sort(function (a, b) {
    var d = b.result.expected - a.result.expected;
    if (Math.abs(d) > 1e-9) return d;
    // An option that changes nothing is the same outcome as a reroll, so put the
    // reroll first and let the advice say the clearer of the two
    return (a.reroll ? -1 : 0) - (b.reroll ? -1 : 0);
  });
}

function renderRolls() {
  var head = document.getElementById("roll-head");
  head.textContent = "";
  ["Option", "Apply to"].forEach(function (label) {
    head.appendChild(el("th", null, label));
  });
  ["Expected", "Chance worse", "Worst", "Best"].forEach(function (label) {
    head.appendChild(el("th", "num", label));
  });

  var body = document.getElementById("roll-body");
  body.textContent = "";
  var rows = tableRows();

  rows.forEach(function (row) {
    var id = row.index + "|" + row.role;
    var tr = el("tr", row.reroll ? "reroll" : "");
    if (!row.reroll) tr.tabIndex = 0;
    tr.appendChild(el("td", null, row.operation.name));
    tr.appendChild(el("td", "dim", row.reroll ? "—" : row.role));
    tr.appendChild(el("td", "num " + tone(row.result.expected),
      signed(row.result.expected)));
    tr.appendChild(el("td", "num " + risk(row.result.worse),
      Math.round(100 * row.result.worse) + "%"));
    tr.appendChild(el("td", "num dim", signed(row.result.worst)));
    tr.appendChild(el("td", "num dim", signed(row.result.best)));

    if (!row.reroll) {
      var toggle = function () {
        openRow = openRow === id ? "" : id;
        renderRolls();
      };
      tr.addEventListener("click", toggle);
      tr.addEventListener("keydown", function (event) {
        if (event.key === "Enter" || event.key === " ") { event.preventDefault(); toggle(); }
      });
      if (id === openRow) tr.classList.add("open");
    }
    body.appendChild(tr);
  });

  renderDetail();
  renderAdvice();

  document.getElementById("roll-note").textContent =
    "Click a row to see all possible outcomes.";
}

function renderDetail() {
  var host = document.getElementById("detail");
  host.textContent = "";

  var row = null;
  shownRows().forEach(function (r) {
    if (r.index + "|" + r.role === openRow) row = r;
  });
  if (!row) return;

  var colours = asArray(DATA.banner[row.role]);
  host.appendChild(el("h3", null,
    row.operation.name + " · " + row.role + " · " +
    row.result.outcomes.length + " possible outcomes"));

  var wrap = el("div", "table-wrap short");
  var table = el("table");
  var thead = el("thead");
  // The rows are ordered by the slots, so those are the index; the two figures
  // belong together at the end where they can be read as a pair
  var hr = el("tr");
  colours.forEach(function (c, i) { hr.appendChild(el("th", null, "Slot " + (i + 1) + " · " + c)); });
  hr.appendChild(el("th", "num", "Chance"));
  hr.appendChild(el("th", "num", "Change"));
  thead.appendChild(hr);
  table.appendChild(thead);

  // Ordered by what the outcome actually is, slot by slot, so the list reads
  // like an enumeration rather than a leaderboard
  var tbody = el("tbody");
  row.result.outcomes.slice().sort(function (a, b) {
    for (var i = 0; i < a.slots.length; i++) {
      var d = (a.slots[i].stat - b.slots[i].stat) ||
              (a.slots[i].quality - b.slots[i].quality) ||
              (a.slots[i].trait - b.slots[i].trait);
      if (d) return d;
    }
    return 0;
  }).forEach(function (o) {
      // No multiplier here: the stat, quality and trait fully determine it, and
      // what it comes to is already in the Change column
      var tr = el("tr");
      o.slots.forEach(function (s, i) {
        var now = BANNER[row.role][i];
        var changed = s.stat !== now.stat || s.quality !== now.quality ||
                      s.trait !== now.trait;
        tr.appendChild(el("td", changed ? "changed" : "dim",
          DATA.stats[s.stat].label + " · " + DATA.qualities[s.quality].name +
          " · " + DATA.traits[s.trait].name));
      });
      tr.appendChild(el("td", "num dim", (100 * o.probability).toFixed(1) + "%"));
      tr.appendChild(el("td", "num " + tone(o.delta), signed(o.delta)));
      tbody.appendChild(tr);
    });
  table.appendChild(tbody);
  wrap.appendChild(table);
  host.appendChild(wrap);
}

// Both actions cost one token and both replace all three options, so the refresh
// is not a reason to prefer either. The only difference is whether the
// operation's effect comes with it: a gaining option beats a plain reroll, and a
// losing one loses to it.
function decide() {
  if (options.every(function (i) { return i < 0; })) return { action: "pick" };

  var best = tableRows()[0];
  if (!best.reroll) return { action: "take", row: best };

  // Rerolling won, so nothing on offer gains. It is only worth the token if
  // something, somewhere, still could — otherwise a new set cannot help either.
  var anythingGains = ROLL_ROWS.length > 0 && ROLL_ROWS[0].result.expected > 0;
  return anythingGains ? { action: "reroll" } : { action: "stop" };
}

// Colour is a gradient of concern, so the bands can be round numbers. The one
// that carries meaning is 50%, past which losing is the likelier outcome.
function risk(p) {
  if (p < 0.25) return "gain";
  if (p < 0.5) return "warn";
  return "loss";
}

// Every word the recommendation can say, in one place and out of the decision.
// Built from parts so the operation, the banner and the figures stand out.
var ADVICE = {
  pick: function () {
    return { tone: "", parts: ["Set your roll options to get a recommendation."] };
  },
  // One breakpoint, at the only place the claim changes: past 50% the advice
  // says take it while the likeliest single outcome is regret.
  take: function (d) {
    var r = d.row.result;
    var risky = r.worse > 0.5;
    return {
      tone: risky ? "warn" : "gain",
      parts: [
        "Take ", key(d.row.operation.name), " on ", key(d.row.role),
        risky ? ", but it is risky: " : ": ",
        mark(signed(r.expected), tone(r.expected)), " expected, ",
        mark(Math.round(100 * r.worse) + "%", risk(r.worse)), " chance worse."
      ]
    };
  },
  reroll: function () {
    return { tone: "", parts: [
      "Nothing on offer gains. Take ", key("Reroll operations"), "."
    ] };
  },
  stop: function () {
    return { tone: "loss", parts: [
      "No operation gains on any banner, offered or not. Do not take any option. " +
      "Keep your tokens."
    ] };
  }
};

function renderAdvice() {
  var decision = decide();
  var said = ADVICE[decision.action](decision);
  say("advice", said.tone, said.parts);
}

// --- recompute -------------------------------------------------------------

var pending = null;
function recompute() {
  document.getElementById("roll-note").textContent = "Working it out…";
  clearTimeout(pending);
  pending = setTimeout(function () {
    var banner = {};
    ROLES.forEach(function (role) { banner[role] = resolved(role); });
    COMPUTED = computeAll(DATA, banner);
    ROWS = buildRows();
    renderRosters();

    ROLL_ROWS = evaluateAll(DATA, UNITS, BANNER);
    openRow = "";
    renderRolls();
  }, 30);
}

// --- page ------------------------------------------------------------------

function buildTabs() {
  var tabs = document.querySelectorAll(".tab");
  tabs.forEach(function (tab) {
    tab.addEventListener("click", function () {
      tabs.forEach(function (other) {
        var on = other === tab;
        other.classList.toggle("active", on);
        other.setAttribute("aria-selected", on ? "true" : "false");
        document.getElementById("panel-" + other.dataset.panel).hidden = !on;
      });
    });
  });
  tabs[0].click();
}

function describe() {
  var meta = DATA.meta;
  var sizes = DATA.units.map(function (unit) { return unit.w.length; });

  document.getElementById("meta").textContent =
    meta.periods[meta.period].name + " · updated " + String(meta.generated).slice(0, 10);

  var set = function (id, value) { document.getElementById(id).textContent = value; };
  var span = function (p) {
    var v = asArray(p.n_values);
    return v[0] + " to " + v[v.length - 1] + " series in the " + p.name;
  };
  var dropped = asArray(meta.dropped_indicators);

  set("m-matches", meta.matches.toLocaleString());
  set("m-patch", meta.patch);
  set("m-min", Math.min.apply(null, sizes));
  set("m-max", Math.max.apply(null, sizes));
  set("m-series", span(meta.periods["1"]) + " and " + span(meta.periods["2"]));
  set("m-assumed", meta.periods["1"].n_median + " and " + meta.periods["2"].n_median);
  set("m-p3", Math.round(meta.p3 * 100) + "%");
  set("m-weights", DATA.qualities.map(function (q) { return q.weight + "%"; }).join(" / "));

  // Nothing is missing once the parser supplies it, so the line goes with it
  set("m-dropped", dropped.join(" and "));
  document.getElementById("m-missing").hidden = dropped.length === 0;
}

// Start from a legal banner: a different stat per slot of the same colour, the
// bottom quality and the first trait
function defaultBanner() {
  var byColour = {};
  DATA.stats.forEach(function (s, i) { (byColour[s.colour] = byColour[s.colour] || []).push(i); });

  ROLES.forEach(function (role) {
    var colours = asArray(DATA.banner[role]);
    BANNER[role] = colours.map(function (colour, position) {
      var nth = colours.slice(0, position).filter(function (c) { return c === colour; }).length;
      return {
        stat: byColour[colour][nth % byColour[colour].length],
        quality: 0,
        trait: 0
      };
    });
  });
}

function boot() {
  fetch("data.json").then(function (res) {
    return res.json();
  }).then(function (json) {
    DATA = json;
    assertTraitsKnown(DATA);

    DATA.units.forEach(function (unit, index) {
      UNIT[unit.team + "|" + unit.role] = index;
    });
    ROLES.forEach(function (role) {
      UNITS[role] = DATA.units.filter(function (u) { return u.role === role; });
    });
    DATA.teams.sort(function (a, b) { return a.name.localeCompare(b.name); });

    median = asArray(DATA.meta.n_values).indexOf(DATA.meta.n_median);
    sortIndex = median;

    defaultBanner();
    buildTabs();
    buildBanner();
    buildOptions();
    document.getElementById("show-n").addEventListener("change", renderRosters);
    recompute();
    describe();
  }).catch(function (err) {
    document.getElementById("meta").textContent =
      "Could not load data.json (" + err.message + "). Serve this directory over " +
      "HTTP — file:// blocks fetch.";
  });
}

boot();
