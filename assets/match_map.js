import { layout } from "./match_map_layout.js?v=1";
import {
  createMapSvg,
  lootGlyph,
  lootKindLabel,
  renderMapSvg
} from "./match_map_svg.js?v=2";

var ROW_STATE_CLASSES = {
  revealedFake: ["border-reveal-border", "bg-reveal-surface/40"],
  revealed: ["border-sky-800", "bg-sky-950/40"],
  changed: ["border-amber-800", "bg-amber-950/40"],
  normal: ["border-surface-700", "bg-surface-950"]
};

var BADGE_STATE_CLASSES = {
  revealedFake: [
    "bg-reveal-surface",
    "border-reveal-border",
    "text-reveal-text"
  ],
  revealed: ["bg-sky-950", "border-sky-800", "text-sky-300"]
};

var EVENT_TONE_CLASSES = {
  robbery: [
    "bg-amber-950/40",
    "border-amber-900/60",
    "text-amber-200"
  ],
  disguise: [
    "bg-reveal-surface/40",
    "border-reveal-border",
    "text-reveal-text"
  ],
  mandate: [
    "bg-emerald-950/40",
    "border-emerald-800",
    "text-emerald-200"
  ],
  inspection: [
    "bg-sky-950/40",
    "border-sky-800",
    "text-sky-200"
  ],
  neutral: [
    "bg-surface-950",
    "border-surface-700",
    "text-surface-300"
  ]
};

function init() {
  var colors = window.appTheme && window.appTheme.colors;
  var dataElement = document.getElementById("match-map-data");
  var host = document.getElementById("mm-graph");
  if (!colors || !colors.map || !dataElement || !host) return;

  var data;
  try {
    data = JSON.parse(dataElement.textContent);
  } catch (_error) {
    return;
  }

  renderThiefIdentity(
    document.getElementById("mm-thief-identity"),
    data.thiefIdentity
  );

  var cities = data.cities || [];
  var frames = data.frames || [];
  if (!cities.length) {
    host.innerHTML =
      '<p class="p-6 text-surface-400 text-sm">' +
      "Grafo do cenário indisponível para esta partida.</p>";
    return;
  }
  if (!frames.length) return;

  var edges = data.edges || [];
  var loot = data.loot || [];
  var objective = data.objective || null;
  var positions = layout(cities, edges);
  var mapView = createMapSvg(edges, positions, loot, colors.map);
  var lootByName = lootIndex(loot);
  host.appendChild(mapView.element);

  var slider = document.getElementById("mm-slider");
  var label = document.getElementById("mm-turn-label");
  var playButton = document.getElementById("mm-play");
  var playIcon = document.getElementById("mm-play-icon");
  var intervalInput = document.getElementById("mm-interval");
  var eventInfo = document.getElementById("mm-event");
  var appearanceInfo = document.getElementById("mm-appearance");
  var collectedInfo = document.getElementById("mm-collected");
  var lootViewToggle = document.getElementById("mm-loot-view-toggle");
  var mandateInfo = document.getElementById("mm-mandate");
  if (!slider) return;

  slider.max = String(frames.length - 1);
  slider.value = "0";
  var timer = null;
  var lootView = "tree";

  function render(index) {
    var frame = frames[index];
    if (!frame) return;
    renderMapSvg(mapView, positions, frame, colors.map);
    if (label) label.textContent = frame.label;
    renderTurnEvents(eventInfo, frame.events, frame.eventText);
    renderAppearance(appearanceInfo, frame.appearance, frame.revealed);
    renderLootPanel(
      collectedInfo,
      objective,
      lootByName,
      frame.collected,
      lootView
    );
    renderMandate(mandateInfo, frame.mandate);
  }

  function setPlaybackControl(isPlaying) {
    if (!playButton) return;
    var controlLabel = isPlaying ? "Pausar" : "Reproduzir";
    if (playIcon) {
      playIcon.textContent = isPlaying ? "⏸\uFE0E" : "▶\uFE0E";
      playIcon.style.transform =
        isPlaying ? "translateY(1px)" : "translateY(-1px)";
    }
    playButton.setAttribute("aria-label", controlLabel);
    playButton.setAttribute("title", controlLabel);
  }

  function stop() {
    if (timer) {
      clearInterval(timer);
      timer = null;
    }
    setPlaybackControl(false);
  }

  function play() {
    var interval = Math.max(
      100,
      parseInt(intervalInput && intervalInput.value, 10) || 800
    );
    if (Number(slider.value) >= frames.length - 1) slider.value = "0";
    setPlaybackControl(true);
    timer = setInterval(function () {
      var next = Number(slider.value) + 1;
      if (next > frames.length - 1) {
        stop();
        return;
      }
      slider.value = String(next);
      render(next);
    }, interval);
  }

  if (playButton) {
    playButton.addEventListener("click", function () {
      if (timer) stop();
      else play();
    });
  }
  slider.addEventListener("input", function () {
    stop();
    render(Number(slider.value));
  });
  if (lootViewToggle) {
    lootViewToggle.addEventListener("click", function () {
      lootView = lootView === "tree" ? "list" : "tree";
      updateLootViewToggle(lootViewToggle, lootView);
      var frame = frames[Number(slider.value)];
      if (frame) {
        renderLootPanel(
          collectedInfo,
          objective,
          lootByName,
          frame.collected,
          lootView
        );
      }
    });
  }

  updateLootViewToggle(lootViewToggle, lootView);
  render(0);
  setupSidePanels(host);
}

function renderThiefIdentity(container, identity) {
  if (!container || !identity || identity.name === undefined ||
      identity.id === undefined) {
    return;
  }
  container.textContent = String(identity.name) + " #" + String(identity.id);
  container.classList.remove("hidden");
}

function renderTurnEvents(container, events, legacyText) {
  if (!container) return;
  var sides = {
    thief: container.querySelector('[data-event-agent="thief"]'),
    detective: container.querySelector('[data-event-agent="detective"]')
  };
  if (!sides.thief || !sides.detective) return;

  clearElement(sides.thief);
  clearElement(sides.detective);

  var grouped = { thief: [], detective: [] };
  (events || []).forEach(function (event) {
    grouped[eventAgent(event)].push(event);
  });

  if (!grouped.thief.length && !grouped.detective.length && legacyText) {
    grouped.thief.push({ type: "neutral", text: legacyText });
  }

  renderAgentEvents(sides.thief, grouped.thief);
  renderAgentEvents(sides.detective, grouped.detective);
}

function eventAgent(event) {
  if (event && event.agent === "detective") return "detective";
  if (event && event.agent === "thief") return "thief";
  return event && (event.type === "mandate" || event.type === "inspection")
    ? "detective"
    : "thief";
}

function renderAgentEvents(container, events) {
  if (!events.length) {
    container.appendChild(emptyState("Nenhum evento."));
    return;
  }
  events.forEach(function (event) {
    var element = cloneTemplate("mm-template-turn-event");
    var tone = EVENT_TONE_CLASSES[event.type] || EVENT_TONE_CLASSES.neutral;
    addClasses(element, tone);
    findRole(element, "text").textContent = event.text || "-";
    container.appendChild(element);
  });
}

function renderAppearance(container, appearance, revealed) {
  if (!container) return;
  clearElement(container);
  if (!appearance || !appearance.length) {
    container.appendChild(emptyState("Aparência indisponível."));
    return;
  }

  var revealedLookup = {};
  (revealed || []).forEach(function (value) {
    revealedLookup[String(value)] = true;
  });

  appearance.forEach(function (attribute) {
    var row = cloneTemplate("mm-template-appearance");
    var added = attribute.original === null;
    var omitted = attribute.current === null;
    var changed = added || omitted ||
      attribute.original !== attribute.current;
    var isRevealed = !omitted &&
      Boolean(revealedLookup[String(attribute.current)]);
    var revealedFake = isRevealed &&
      (added || attribute.original !== attribute.current);

    var rowState = revealedFake
      ? "revealedFake"
      : isRevealed
        ? "revealed"
        : changed ? "changed" : "normal";
    addClasses(row, ROW_STATE_CLASSES[rowState]);

    var originLabel = findRole(row, "origin-label");
    var originValue = findRole(row, "origin-value");
    var currentValue = findRole(row, "current-value");
    var badge = findRole(row, "badge");
    originLabel.textContent = added ? "Origem" : "Original";
    originValue.textContent = added ? "adicionado" : attribute.original;
    currentValue.textContent = omitted ? "omitido" : attribute.current;

    originValue.classList.add(
      added
        ? "text-emerald-300"
        : isRevealed
          ? revealedFake ? "text-reveal-text" : "text-sky-300"
          : "text-surface-300"
    );
    currentValue.classList.add(
      omitted
        ? "text-ufop-400"
        : isRevealed
          ? revealedFake ? "text-reveal-text" : "text-sky-300"
          : changed ? "text-amber-300" : "text-surface-300"
    );

    if (isRevealed) {
      badge.classList.remove("hidden");
      badge.textContent = revealedFake ? "Disfarce revelado" : "Revelado";
      addClasses(
        badge,
        BADGE_STATE_CLASSES[revealedFake ? "revealedFake" : "revealed"]
      );
    }
    container.appendChild(row);
  });
}

function updateLootViewToggle(button, view) {
  if (!button) return;
  var showList = view === "tree";
  button.textContent =
    showList ? "Ver itens coletados" : "Ver dependências";
  button.setAttribute(
    "aria-label",
    showList
      ? "Exibir itens coletados como lista"
      : "Exibir dependências do tesouro"
  );
  button.setAttribute(
    "title",
    showList ? "Ver itens coletados" : "Ver dependências"
  );
}

function renderLootPanel(container, objective, lootByName, collected, view) {
  if (view === "list") {
    renderCollectedList(container, collected, lootByName);
    return;
  }
  renderLootTree(container, objective, lootByName, collected);
}

function renderCollectedList(container, collected, lootByName) {
  if (!container) return;
  clearElement(container);
  if (!collected || !collected.length) {
    container.appendChild(emptyState("Nada roubado até aqui."));
    return;
  }

  var list = document.createElement("div");
  list.className = "flex flex-wrap content-start gap-2";
  collected.forEach(function (name) {
    var entry = lootByName[name] || { name: name, kind: "item" };
    var item = cloneTemplate("mm-template-collected-list-item");
    findRole(item, "glyph").textContent = lootGlyph(entry);
    findRole(item, "kind").textContent = lootKindLabel(entry);
    findRole(item, "name").textContent = name;
    list.appendChild(item);
  });
  container.appendChild(list);
}

function renderLootTree(container, objective, lootByName, collected) {
  if (!container) return;
  clearElement(container);
  if (!objective || objective.name === null || objective.name === undefined) {
    container.appendChild(emptyState("Cadeia do tesouro indisponível."));
    return;
  }

  var collectedLookup = {};
  (collected || []).forEach(function (name) {
    collectedLookup[name] = true;
  });

  var root = {
    kind: "treasure",
    name: objective.name,
    city: objective.city,
    requirements: objective.requirements || []
  };
  var tree = document.createElement("ul");
  tree.className = "space-y-1.5 pr-1";
  tree.style.width = "max-content";
  tree.style.minWidth = "100%";
  tree.appendChild(
    buildLootTreeNode(root, lootByName, collectedLookup, {})
  );
  container.appendChild(tree);
}

var LOOT_TREE_STATE_CLASSES = {
  collected: [
    "border-emerald-800",
    "bg-emerald-950/40",
    "text-emerald-200"
  ],
  ready: [
    "border-amber-800",
    "bg-amber-950/40",
    "text-amber-200"
  ],
  pending: [
    "border-surface-700",
    "bg-surface-950",
    "text-surface-300"
  ]
};

function buildLootTreeNode(entry, lootByName, collected, ancestors) {
  var item = cloneTemplate("mm-template-collected");
  var requirements = entry.requirements || [];
  var isCollected = Boolean(collected[entry.name]);
  var isReady = requirements.every(function (name) {
    return Boolean(collected[name]);
  });
  var state = isCollected ? "collected" : isReady ? "ready" : "pending";
  var node = findRole(item, "node");
  addClasses(node, LOOT_TREE_STATE_CLASSES[state]);

  findRole(item, "glyph").textContent = lootGlyph(entry);
  findRole(item, "name").textContent = entry.name;
  findRole(item, "status").textContent = lootNodeStatus(entry, state);

  var city = findRole(item, "city");
  if (entry.city !== null && entry.city !== undefined) {
    city.textContent = "em " + entry.city;
    city.classList.remove("hidden");
  }

  var children = findRole(item, "children");
  if (!requirements.length || ancestors[entry.name]) {
    children.remove();
    return item;
  }

  var nextAncestors = Object.assign({}, ancestors);
  nextAncestors[entry.name] = true;
  requirements.forEach(function (name) {
    var dependency = lootByName[name] || {
      kind: "item",
      name: name,
      city: null,
      requirements: []
    };
    children.appendChild(
      buildLootTreeNode(dependency, lootByName, collected, nextAncestors)
    );
  });
  return item;
}

function lootNodeStatus(entry, state) {
  if (state === "collected") {
    return entry.kind === "treasure" ? "roubado" : "coletado";
  }
  if (state === "ready") {
    return entry.kind === "treasure" ? "tesouro liberado" : "liberado";
  }
  return "bloqueado";
}

function renderMandate(container, mandate) {
  if (!container) return;
  clearElement(container);
  if (!mandate) {
    container.appendChild(emptyState("Nenhum mandato emitido."));
    return;
  }

  var mandateElement = cloneTemplate("mm-template-mandate");
  findRole(mandateElement, "suspect").textContent =
    mandate.suspectName !== undefined
      ? mandate.suspectName + " #" + mandate.suspect
      : mandate.suspect;
  var clues = findRole(mandateElement, "clues");
  if (!mandate.clues.length) {
    clues.appendChild(emptyState("Sem pistas associadas."));
  } else {
    mandate.clues.forEach(function (clue) {
      var clueElement = cloneTemplate("mm-template-clue");
      findRole(clueElement, "clue").textContent = clue;
      clues.appendChild(clueElement);
    });
  }
  container.appendChild(mandateElement);
}

function lootIndex(loot) {
  var index = {};
  (loot || []).forEach(function (entry) {
    if (!entry.requirements) entry.requirements = [];
    index[entry.name] = entry;
  });
  return index;
}

function emptyState(message) {
  var element = cloneTemplate("mm-template-empty");
  findRole(element, "message").textContent = message;
  return element;
}

function cloneTemplate(id) {
  var template = document.getElementById(id);
  return template.content.firstElementChild.cloneNode(true);
}

function findRole(element, role) {
  var selector = '[data-role="' + role + '"]';
  return element.matches(selector) ? element : element.querySelector(selector);
}

function addClasses(element, classes) {
  classes.forEach(function (className) {
    element.classList.add(className);
  });
}

function clearElement(element) {
  while (element.firstChild) element.removeChild(element.firstChild);
}

// Iguala ao mapa apenas os cards que o CSS posicionou na mesma linha.
function setupSidePanels(mapHost) {
  var panels = document.querySelectorAll(".js-map-height");
  if (!panels.length || !mapHost) return;
  function sync() {
    var mapBounds = mapHost.getBoundingClientRect();
    var height = Math.round(mapBounds.height);
    for (var i = 0; i < panels.length; i++) {
      var panelTop = panels[i].getBoundingClientRect().top;
      var sharesMapRow = Math.abs(panelTop - mapBounds.top) < 2;
      panels[i].style.height =
        sharesMapRow && height > 0 ? height + "px" : "";
    }
  }
  sync();
  if (window.ResizeObserver) {
    new ResizeObserver(sync).observe(mapHost);
  }
  window.addEventListener("resize", sync);
}

if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", init);
} else {
  init();
}
