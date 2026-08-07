"use strict";

var ROLES = ["Core", "Mid", "Support"];
var PERIOD_NAME = { 1: "Group Stage", 2: "Playoffs" };

var DATA = null;      // data.json
var UNITS = {};       // role -> the role's team-units
var BANNER = {};      // role -> [{stat, quality, trait}] per slot
var COMPUTED = null;  // { pairs, results[unit][pair][n], nValues }
var ROWS = [];        // one per roster
var ROLL_ROWS = [];   // one per applicable (operation, banner) pair
var REFRESH = 0;      // what a fresh set of three offers is worth
var UNIT = {};        // "team|role" -> index into DATA.units
var median = 0;       // index of the assumed series count within nValues
var sortIndex = 0;    // which roster column the table is ordered by
var offers = [-1, -1, -1];
var openRow = -1;

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
  return (x >= 0 ? "+" : "−") + Math.round(Math.abs(x)).toLocaleString();
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

  ROLES.forEach(function (role) {
    var colours = asArray(DATA.banner[role]);
    var card = el("div", "role");
    card.appendChild(el("h3", null, role + " · " + colours.join(" ")));

    colours.forEach(function (colour, position) {
      // The box itself carries the colour, so no label repeats it — the card
      // heading already states the order in words
      var slot = el("div", "slot " + colour);

      var top = el("div", "slot-line");
      top.appendChild(dropdown(byColour[colour], BANNER[role][position].stat,
        role + " " + colour + " emblem", function (v) { setStat(role, position, v); }));
      var pct = el("span", "mult");
      pct.dataset.role = role;
      pct.dataset.position = position;
      top.appendChild(pct);
      slot.appendChild(top);

      var bottom = el("div", "slot-line sub");
      bottom.appendChild(dropdown(
        DATA.qualities.map(function (q, i) { return { index: i, label: q.name }; }),
        BANNER[role][position].quality, role + " quality",
        function (v) { BANNER[role][position].quality = v; }));
      bottom.appendChild(dropdown(
        DATA.traits.map(function (t, i) { return { index: i, label: t.name }; }),
        BANNER[role][position].trait, role + " trait",
        function (v) { BANNER[role][position].trait = v; }));
      var hint = el("span", "hint");
      hint.dataset.role = role;
      hint.dataset.position = position;
      bottom.appendChild(hint);
      slot.appendChild(bottom);

      card.appendChild(slot);
    });

    host.appendChild(card);
  });

  showMultipliers();
}

function dropdown(options, selected, label, onPick) {
  var select = el("select");
  select.setAttribute("aria-label", label);
  options.forEach(function (o) {
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
    var m = multipliers(BANNER[role], DATA);
    m.forEach(function (slot, i) {
      var pct = document.querySelector('.mult[data-role="' + role + '"][data-position="' + i + '"]');
      var hint = document.querySelector('.hint[data-role="' + role + '"][data-position="' + i + '"]');
      pct.textContent = Math.round(slot.total * 100) + "%";
      // What the game prints on the emblem: the trait plus its neighbours
      hint.textContent = (slot.trait >= 0 ? "+" : "−") +
        Math.abs(Math.round(slot.trait * 100)) + "%";
      hint.title = "Quality +" + Math.round(slot.quality * 100) +
        "%, trait " + Math.round(slot.trait * 100) + "% including neighbours";
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
    addSortable(head, "Expected points", median, " median");
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

  document.getElementById("status").textContent =
    ROWS.length.toLocaleString() + " rosters, every combination of one team per role.";

  document.querySelectorAll("#head th.sortable").forEach(function (th) {
    th.classList.toggle("sorted", +th.dataset.index === sortIndex);
  });
}

// --- rerolls ---------------------------------------------------------------

function buildOffers() {
  var host = document.getElementById("offers");
  host.textContent = "";
  for (var slot = 0; slot < 3; slot++) {
    (function (index) {
      var wrap = el("label", "offer");
      wrap.appendChild(el("span", null, "Offer " + (index + 1)));
      var select = el("select");
      var none = el("option", null, "— not offered —");
      none.value = -1;
      select.appendChild(none);
      DATA.rolls.forEach(function (roll, i) {
        var option = el("option", null, roll.name);
        option.value = i;
        select.appendChild(option);
      });
      select.value = offers[index];
      select.addEventListener("change", function () {
        offers[index] = +select.value;
        renderRolls();
      });
      wrap.appendChild(select);
      host.appendChild(wrap);
    })(slot);
  }
}

function renderRolls() {
  var head = document.getElementById("roll-head");
  head.textContent = "";
  ["Operation", "Banner"].forEach(function (label) {
    head.appendChild(el("th", null, label));
  });
  ["Expected", "Chance worse", "Worst", "Best", "Outcomes"].forEach(function (label) {
    head.appendChild(el("th", "num", label));
  });

  var body = document.getElementById("roll-body");
  body.textContent = "";

  ROLL_ROWS.forEach(function (row, i) {
    var offered = offers.indexOf(row.index) >= 0;
    var tr = el("tr", offered ? "offered" : "");
    tr.tabIndex = 0;
    tr.appendChild(el("td", null, row.operation.name));
    tr.appendChild(el("td", "dim", row.role));
    tr.appendChild(el("td", "num " + (row.result.expected >= 0 ? "gain" : "loss"),
      signed(row.result.expected)));
    tr.appendChild(el("td", "num dim", Math.round(100 * row.result.worse) + "%"));
    tr.appendChild(el("td", "num dim", signed(row.result.worst)));
    tr.appendChild(el("td", "num dim", signed(row.result.best)));
    tr.appendChild(el("td", "num dim", row.result.outcomes.length));
    tr.addEventListener("click", function () {
      openRow = openRow === i ? -1 : i;
      renderRolls();
    });
    tr.addEventListener("keydown", function (event) {
      if (event.key === "Enter" || event.key === " ") {
        event.preventDefault();
        openRow = openRow === i ? -1 : i;
        renderRolls();
      }
    });
    if (i === openRow) tr.classList.add("open");
    body.appendChild(tr);
  });

  renderDetail();
  renderAdvice();

  document.getElementById("roll-note").textContent =
    ROLL_ROWS.length + " of " + (DATA.rolls.length * ROLES.length) +
    " operation and banner pairs can apply; the rest need a colour that banner " +
    "does not carry. Click a row for every outcome behind its numbers.";
}

function renderDetail() {
  var host = document.getElementById("detail");
  host.textContent = "";
  if (openRow < 0 || openRow >= ROLL_ROWS.length) return;

  var row = ROLL_ROWS[openRow];
  var colours = asArray(DATA.banner[row.role]);
  host.appendChild(el("h3", null,
    row.operation.name + " · " + row.role + " · " +
    row.result.outcomes.length + " possible outcomes"));

  var wrap = el("div", "table-wrap short");
  var table = el("table");
  var thead = el("thead");
  var hr = el("tr");
  hr.appendChild(el("th", "num", "Chance"));
  colours.forEach(function (c, i) { hr.appendChild(el("th", null, "Slot " + (i + 1) + " · " + c)); });
  hr.appendChild(el("th", "num", "Change"));
  thead.appendChild(hr);
  table.appendChild(thead);

  var tbody = el("tbody");
  row.result.outcomes.slice().sort(function (a, b) { return b.delta - a.delta; })
    .forEach(function (o) {
      var tr = el("tr");
      tr.appendChild(el("td", "num dim", (100 * o.probability).toFixed(1) + "%"));
      var m = multipliers(o.slots, DATA);
      o.slots.forEach(function (s, i) {
        var now = BANNER[row.role][i];
        var changed = s.stat !== now.stat || s.quality !== now.quality ||
                      s.trait !== now.trait;
        tr.appendChild(el("td", changed ? "changed" : "dim",
          DATA.stats[s.stat].label + " · " + DATA.qualities[s.quality].name +
          " · " + DATA.traits[s.trait].name +
          " · " + Math.round(m[i].total * 100) + "%"));
      });
      tr.appendChild(el("td", "num " + (o.delta >= 0 ? "gain" : "loss"), signed(o.delta)));
      tbody.appendChild(tr);
    });
  table.appendChild(tbody);
  wrap.appendChild(table);
  host.appendChild(wrap);
}

function renderAdvice() {
  var picked = offers.filter(function (i) { return i >= 0; });
  var advice = document.getElementById("advice");

  if (picked.length === 0) {
    advice.textContent = "A fresh set of three offers is worth " + signed(REFRESH) +
      " on average, so an offer down to " + signed(-REFRESH) +
      " is still worth taking if you have tokens to spare.";
    advice.className = "advice";
    return;
  }

  var best = null;
  ROLL_ROWS.forEach(function (row) {
    if (picked.indexOf(row.index) < 0) return;
    if (!best || row.result.expected > best.result.expected) best = row;
  });

  if (!best) {
    advice.textContent = "None of those apply to any of your banners.";
    advice.className = "advice loss";
    return;
  }

  if (best.result.expected > 0) {
    advice.textContent = "Take " + best.operation.name + " on " + best.role + ": " +
      signed(best.result.expected) + " expected, " +
      Math.round(100 * best.result.worse) + "% chance it hurts.";
    advice.className = "advice gain";
  } else if (best.result.expected > -REFRESH) {
    advice.textContent = "None of the three gain. " + best.operation.name + " on " +
      best.role + " loses least at " + signed(best.result.expected) +
      ", and a fresh set is worth " + signed(REFRESH) + ", so it is still worth " +
      "spending a token to cycle.";
    advice.className = "advice";
  } else {
    advice.textContent = "Take none. The best of the three is " + best.operation.name +
      " on " + best.role + " at " + signed(best.result.expected) +
      ", worse than the " + signed(REFRESH) + " a fresh set is worth.";
    advice.className = "advice loss";
  }
}

// --- recompute -------------------------------------------------------------

var pending = null;
function recompute() {
  document.getElementById("status").textContent = "Working it out…";
  document.getElementById("roll-note").textContent = "Working it out…";
  clearTimeout(pending);
  pending = setTimeout(function () {
    var banner = {};
    ROLES.forEach(function (role) { banner[role] = resolved(role); });
    COMPUTED = computeAll(DATA, banner);
    ROWS = buildRows();
    renderRosters();

    ROLL_ROWS = evaluateAll(DATA, UNITS, BANNER);
    REFRESH = refreshValue(ROLL_ROWS, DATA.rolls.length);
    openRow = -1;
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
  var stage = PERIOD_NAME[meta.period] || "Period " + meta.period;
  var values = asArray(meta.n_values);
  var sizes = DATA.units.map(function (unit) { return unit.w.length; });

  document.getElementById("meta").textContent =
    stage + " · updated " + String(meta.generated).slice(0, 10);

  document.getElementById("assume").textContent =
    "Assumes every team plays " + meta.n_median + " series, the middle of the " +
    values[0] + " to " + values[values.length - 1] + " a team can play in the " +
    stage + ". How far a team actually goes is the one thing this cannot know.";

  document.getElementById("m-games").textContent = meta.role_games.toLocaleString();
  document.getElementById("m-min").textContent = Math.min.apply(null, sizes);
  document.getElementById("m-max").textContent = Math.max.apply(null, sizes);
  document.getElementById("m-p3").textContent = Math.round(meta.p3 * 100) + "%";
  document.getElementById("m-weights").textContent =
    DATA.qualities.map(function (q) { return q.weight + "%"; }).join(" / ");
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
    buildOffers();
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
