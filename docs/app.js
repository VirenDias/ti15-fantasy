"use strict";

var ROLES = ["Core", "Mid", "Support"];
var PERIOD_NAME = { 1: "Group Stage", 2: "Playoffs" };

var DATA = null;      // data.json
var COMPUTED = null;  // { pairs, results[unit][pair][n], nValues }
var ROWS = [];        // one per roster
var UNIT = {};        // "team|role" -> index into DATA.units
var median = 0;       // index of the assumed series count within nValues
var sortIndex = 0;    // which column the table is ordered by

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

function breakingOut() {
  return document.getElementById("show-n").checked;
}

// --- banner ----------------------------------------------------------------

function buildBanner() {
  var host = document.getElementById("banner");
  var byColour = {};
  DATA.stats.forEach(function (s, i) {
    (byColour[s.colour] = byColour[s.colour] || []).push({ index: i, label: s.label });
  });

  ROLES.forEach(function (role) {
    var colours = asArray(DATA.banner[role]);
    var card = el("div", "role");
    card.appendChild(el("h3", null, role));

    colours.forEach(function (colour, position) {
      var slot = el("div", "slot");
      slot.appendChild(el("span", "chip " + colour, colour));

      var select = el("select");
      select.dataset.role = role;
      select.dataset.position = position;
      select.setAttribute("aria-label", role + " " + colour + " emblem");
      byColour[colour].forEach(function (stat) {
        var option = el("option", null, stat.label);
        option.value = stat.index;
        select.appendChild(option);
      });
      // Default to a different emblem per slot of the same colour, which is the
      // usual roll and stops every slot defaulting to Kills
      var nth = colours.slice(0, position).filter(function (c) { return c === colour; }).length;
      select.selectedIndex = nth % byColour[colour].length;
      select.addEventListener("change", recompute);
      slot.appendChild(select);

      var mult = el("input", "mult");
      mult.type = "number";
      mult.min = "0";
      mult.step = "10";
      mult.value = "100";
      mult.dataset.role = role;
      mult.dataset.position = position;
      mult.setAttribute("aria-label", role + " " + colour + " multiplier, percent");
      mult.addEventListener("change", recompute);
      slot.appendChild(mult);
      slot.appendChild(el("span", "pct", "%"));

      card.appendChild(slot);
    });

    host.appendChild(card);
  });
}

function readBanner() {
  var banner = {};
  ROLES.forEach(function (role) { banner[role] = []; });
  document.querySelectorAll("#banner select").forEach(function (select) {
    banner[select.dataset.role][+select.dataset.position] = {
      stat: +select.value,
      mult: 1
    };
  });
  document.querySelectorAll("#banner .mult").forEach(function (input) {
    var slot = banner[input.dataset.role][+input.dataset.position];
    slot.mult = (parseFloat(input.value) || 0) / 100;
  });
  return banner;
}

// --- rosters ---------------------------------------------------------------

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

        rows.push({
          core: core, mid: mid, support: support,
          pair: pairs[best],
          values: values
        });
      });
    });
  });

  return rows;
}

// --- rendering -------------------------------------------------------------

function addSortable(head, label, index, extra) {
  var th = el("th", "num sortable" + (extra || ""), label);
  th.dataset.index = index;
  th.tabIndex = 0;
  th.setAttribute("role", "button");
  function sort() {
    sortIndex = index;
    render();
  }
  th.addEventListener("click", sort);
  th.addEventListener("keydown", function (event) {
    if (event.key === "Enter" || event.key === " ") {
      event.preventDefault();
      sort();
    }
  });
  head.appendChild(th);
}

function buildHead() {
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
}

function render() {
  if (!breakingOut()) sortIndex = median;
  ROWS.sort(function (a, b) { return b.values[sortIndex] - a.values[sortIndex]; });

  buildHead();
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

function recompute() {
  var status = document.getElementById("status");
  status.textContent = "Working it out…";

  // Yield first so the message paints before the arithmetic
  setTimeout(function () {
    COMPUTED = computeAll(DATA, readBanner());
    ROWS = buildRows();
    render();
  }, 0);
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
      window.scrollTo(0, 0);
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
}

function boot() {
  fetch("data.json").then(function (res) {
    return res.json();
  }).then(function (json) {
    DATA = json;
    DATA.units.forEach(function (unit, index) {
      UNIT[unit.team + "|" + unit.role] = index;
    });
    DATA.teams.sort(function (a, b) { return a.name.localeCompare(b.name); });

    buildTabs();
    buildBanner();
    COMPUTED = computeAll(DATA, readBanner());
    median = COMPUTED.nValues.indexOf(DATA.meta.n_median);
    sortIndex = median;
    ROWS = buildRows();
    document.getElementById("show-n").addEventListener("change", render);
    render();
    describe();
  }).catch(function (err) {
    document.getElementById("meta").textContent =
      "Could not load data.json (" + err.message + "). Serve this directory over " +
      "HTTP — file:// blocks fetch.";
  });
}

boot();
