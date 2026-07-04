import {
  fitMapGeometry,
  layout
} from "./match_map_layout.js?v=2";
import {
  createMapSvg,
  lootGlyph,
  lootKindLabel,
  renderMapSvg
} from "./match_map_svg.js?v=3";

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
  var canvas = document.getElementById("mm-graph-canvas") || host;
  var replayLayout = document.getElementById("mm-replay-layout");
  if (!colors || !colors.map || !dataElement || !host || !canvas) return;

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
    canvas.innerHTML =
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
  canvas.appendChild(mapView.element);

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
    if (Number(slider.value) >= frames.length - 1) {
      slider.value = "0";
      render(0);
    }
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
  document.addEventListener("keydown", function (event) {
    if (event.ctrlKey || event.metaKey || event.altKey) return;
    var intervalDirection = playbackIntervalDirection(event);
    if (intervalDirection && !isTextEditingControl(event.target)) {
      event.preventDefault();
      if (!intervalInput) return;
      var step = Number(intervalInput.step) || 100;
      var minimum = Number(intervalInput.min) || 0;
      var maximum = Number(intervalInput.max) || Infinity;
      var current = Number(intervalInput.value) || minimum;
      intervalInput.value = String(
        clamp(current + intervalDirection * step, minimum, maximum)
      );
      if (timer) {
        clearInterval(timer);
        timer = null;
        play();
      }
      return;
    }
    if (isKeyboardControl(event.target)) return;
    if (event.code === "Space") {
      if (event.repeat) return;
      event.preventDefault();
      if (timer) stop();
      else play();
      return;
    }
    if (event.key !== "ArrowLeft" && event.key !== "ArrowRight") return;
    event.preventDefault();
    stop();
    var direction = event.key === "ArrowRight" ? 1 : -1;
    var next = clamp(
      Number(slider.value) + direction,
      0,
      frames.length - 1
    );
    slider.value = String(next);
    render(next);
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
  setupResizableMap(replayLayout, host, canvas, function () {
    fitMapGeometry(host.clientWidth, host.clientHeight);
    var nextPositions = layout(cities, edges);
    var nextMapView = createMapSvg(
      edges,
      nextPositions,
      loot,
      colors.map
    );
    fillMapSpace(nextMapView.element);
    canvas.replaceChildren(nextMapView.element);
    positions = nextPositions;
    mapView = nextMapView;
    var frame = frames[Number(slider.value)];
    if (frame) renderMapSvg(mapView, positions, frame, colors.map);
  });
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

    var originValue = findRole(row, "origin-value");
    var arrow = findRole(row, "arrow");
    var currentValue = findRole(row, "current-value");
    var badge = findRole(row, "badge");
    originValue.textContent = added ? "adicionado" : attribute.original;
    currentValue.textContent = omitted ? "omitido" : attribute.current;
    if (changed) {
      arrow.classList.remove("hidden");
      currentValue.classList.remove("hidden");
    }

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

function isKeyboardControl(target) {
  return Boolean(target && target.closest && target.closest(
    "input, textarea, select, button, a, [contenteditable='true'], " +
    "[role='separator']"
  ));
}

function isTextEditingControl(target) {
  return Boolean(target && target.closest && target.closest(
    "textarea, select, input:not([type='range']), " +
    "[contenteditable='true']"
  ));
}

function playbackIntervalDirection(event) {
  var legacyCode = event.keyCode || event.which;
  if (
    event.key === "+" ||
    event.key === "Add" ||
    event.code === "NumpadAdd" ||
    (event.code === "Equal" && event.shiftKey) ||
    legacyCode === 107 ||
    (event.shiftKey && (legacyCode === 61 || legacyCode === 187))
  ) {
    return 1;
  }
  if (
    event.key === "-" ||
    event.key === "\u2212" ||
    event.key === "Subtract" ||
    event.code === "Minus" ||
    event.code === "NumpadSubtract" ||
    legacyCode === 109 ||
    legacyCode === 173 ||
    legacyCode === 189
  ) {
    return -1;
  }
  return 0;
}

function fillMapSpace(svg) {
  if (!svg) return;
  svg.setAttribute("height", "100%");
  svg.style.height = "100%";
}

function clearElement(element) {
  while (element.firstChild) element.removeChild(element.firstChild);
}

function setupResizableMap(layoutHost, mapHost, canvas, onCommit) {
  if (!layoutHost || !mapHost || !canvas) return;
  var leftHandle = document.getElementById("mm-resize-left");
  var rightHandle = document.getElementById("mm-resize-right");
  var bottomHandle = document.getElementById("mm-resize-bottom");
  var resetButton = document.getElementById("mm-map-size-reset");
  var widthHandles = [leftHandle, rightHandle].filter(Boolean);
  var leftPanel = document.getElementById("mm-left-panel");
  var rightPanel = document.getElementById("mm-right-panel");
  var heightLimits = { min: 320, max: 1200 };
  var saved = readMapSize();
  var detached = {
    left: Boolean(saved.leftDetached || saved.expanded),
    right: Boolean(saved.rightDetached || saved.expanded)
  };

  function isWideLayout() {
    return window.matchMedia("(min-width: 1440px)").matches;
  }

  function supportsDetachedLayout() {
    return window.matchMedia("(min-width: 1280px)").matches;
  }

  function renderLayoutMode() {
    var leftDown = detached.left && supportsDetachedLayout();
    var rightDown = detached.right && supportsDetachedLayout();
    if (!leftDown && !rightDown) {
      layoutHost.style.removeProperty("grid-template-columns");
      layoutHost.style.removeProperty("grid-template-areas");
      leftPanel.style.removeProperty("grid-area");
      mapHost.style.removeProperty("grid-area");
      rightPanel.style.removeProperty("grid-area");
      return;
    }

    leftPanel.style.gridArea = "left";
    mapHost.style.gridArea = "graph";
    rightPanel.style.gridArea = "right";
    if (!isWideLayout()) {
      layoutHost.style.gridTemplateColumns = "minmax(0, 1fr)";
      layoutHost.style.gridTemplateAreas = '"graph" "left" "right"';
    } else if (leftDown && rightDown) {
      layoutHost.style.gridTemplateColumns =
        "repeat(2, minmax(0, 1fr))";
      layoutHost.style.gridTemplateAreas =
        '"graph graph" "left right"';
    } else if (leftDown) {
      layoutHost.style.gridTemplateColumns =
        "minmax(0, 1fr) minmax(12rem, 20rem)";
      layoutHost.style.gridTemplateAreas =
        '"graph right" "left left"';
    } else {
      layoutHost.style.gridTemplateColumns =
        "minmax(12rem, 20rem) minmax(0, 1fr)";
      layoutHost.style.gridTemplateAreas =
        '"left graph" "right right"';
    }
  }

  function currentLeftWidth() {
    return leftPanel ? leftPanel.getBoundingClientRect().width : 0;
  }

  function widthLimits() {
    var layoutWidth = layoutHost.getBoundingClientRect().width;
    var gap = parseFloat(getComputedStyle(layoutHost).columnGap) || 16;
    var wide = isWideLayout();
    var sideSpace = wide ? 384 : 256;
    var gapSpace = wide ? gap * 2 : gap;
    var min = 448;
    return {
      min: min,
      max: Math.max(min, Math.round(layoutWidth - sideSpace - gapSpace))
    };
  }

  function applyWidth(value) {
    var limits = widthLimits();
    var width = Math.round(clamp(value, limits.min, limits.max));
    layoutHost.style.setProperty("--mm-graph-width", width + "px");
    widthHandles.forEach(function (handle) {
      handle.setAttribute("aria-valuemin", String(limits.min));
      handle.setAttribute("aria-valuemax", String(limits.max));
      handle.setAttribute("aria-valuenow", String(width));
    });
    return width;
  }

  function applyLeftWidth(value) {
    if (!isWideLayout()) return currentLeftWidth();
    var layoutWidth = layoutHost.getBoundingClientRect().width;
    var graphWidth = mapHost.getBoundingClientRect().width;
    var gap = parseFloat(getComputedStyle(layoutHost).columnGap) || 16;
    var min = 192;
    var max = Math.max(min, layoutWidth - graphWidth - gap * 2 - 192);
    var width = Math.round(clamp(value, min, max));
    layoutHost.style.setProperty("--mm-left-width", width + "px");
    return width;
  }

  function applyHeight(value) {
    var height = Math.round(
      clamp(value, heightLimits.min, heightLimits.max)
    );
    mapHost.style.height = height + "px";
    if (bottomHandle) {
      bottomHandle.setAttribute("aria-valuemin", String(heightLimits.min));
      bottomHandle.setAttribute("aria-valuemax", String(heightLimits.max));
      bottomHandle.setAttribute("aria-valuenow", String(height));
    }
    return height;
  }

  if (saved.width && window.matchMedia("(min-width: 1280px)").matches) {
    applyWidth(saved.width);
  } else {
    applyWidth(mapHost.getBoundingClientRect().width);
  }
  if (isWideLayout()) {
    applyLeftWidth(saved.left || currentLeftWidth());
  }
  renderLayoutMode();
  var naturalHeight = mapHost.getBoundingClientRect().height;
  applyHeight(saved.height || naturalHeight);
  fillMapSpace(canvas.querySelector("svg"));

  function commit() {
    var width = Math.round(mapHost.getBoundingClientRect().width);
    var height = Math.round(mapHost.getBoundingClientRect().height);
    var left = Math.round(currentLeftWidth());
    saveMapSize({
      width: width,
      height: height,
      left: left,
      leftDetached: detached.left,
      rightDetached: detached.right
    });
    if (onCommit) onCommit();
  }

  commit();

  function wireHorizontalHandle(handle, direction) {
    if (!handle) return;
    handle.addEventListener("pointerdown", function (event) {
      if (event.button !== 0) return;
      event.preventDefault();
      var startX = event.clientX;
      var startWidth = mapHost.getBoundingClientRect().width;
      var startLeft = currentLeftWidth();
      var startRight = rightPanel.getBoundingClientRect().width;
      var side = direction < 0 ? "left" : "right";
      var snapped = false;
      beginResize(handle, event, "ew-resize", function (moveEvent) {
        if (snapped) return;
        var delta = moveEvent.clientX - startX;
        if (detached[side]) {
          var restoresSide = direction < 0 ? delta > 48 : delta < -48;
          if (restoresSide) {
            detached[side] = false;
            renderLayoutMode();
            snapped = true;
          }
          return;
        }
        if (crossedPanelLimit(
          direction,
          delta,
          startLeft,
          startRight
        )) {
          detached[side] = true;
          renderLayoutMode();
          snapped = true;
          return;
        }
        if (isWideLayout()) {
          resizeWideMapSide(
            direction,
            delta,
            startWidth,
            startLeft,
            layoutHost,
            applyWidth,
            applyLeftWidth
          );
        } else {
          applyWidth(startWidth + delta * direction);
        }
      }, commit);
    });
    handle.addEventListener("keydown", function (event) {
      if (event.key !== "ArrowLeft" && event.key !== "ArrowRight") return;
      event.preventDefault();
      var physicalDelta = event.key === "ArrowRight" ? 24 : -24;
      var startWidth = mapHost.getBoundingClientRect().width;
      var startLeft = currentLeftWidth();
      var startRight = rightPanel.getBoundingClientRect().width;
      var side = direction < 0 ? "left" : "right";
      if (detached[side]) {
        var restoresSide = direction < 0
          ? physicalDelta > 0
          : physicalDelta < 0;
        if (restoresSide) {
          detached[side] = false;
          renderLayoutMode();
          commit();
        }
        return;
      }
      if (crossedPanelLimit(
        direction,
        physicalDelta,
        startLeft,
        startRight
      )) {
        detached[side] = true;
        renderLayoutMode();
        commit();
        return;
      }
      if (isWideLayout()) {
        resizeWideMapSide(
          direction,
          physicalDelta,
          startWidth,
          startLeft,
          layoutHost,
          applyWidth,
          applyLeftWidth
        );
      } else {
        applyWidth(startWidth + physicalDelta * direction);
      }
      commit();
    });
  }

  wireHorizontalHandle(leftHandle, -1);
  wireHorizontalHandle(rightHandle, 1);

  if (bottomHandle) {
    bottomHandle.addEventListener("pointerdown", function (event) {
      if (event.button !== 0) return;
      event.preventDefault();
      var startY = event.clientY;
      var startHeight = mapHost.getBoundingClientRect().height;
      beginResize(bottomHandle, event, "ns-resize", function (moveEvent) {
        applyHeight(startHeight + moveEvent.clientY - startY);
      }, commit);
    });
    bottomHandle.addEventListener("keydown", function (event) {
      if (event.key !== "ArrowUp" && event.key !== "ArrowDown") return;
      event.preventDefault();
      var delta = event.key === "ArrowDown" ? 24 : -24;
      applyHeight(mapHost.getBoundingClientRect().height + delta);
      commit();
    });
  }

  if (resetButton) {
    resetButton.addEventListener("click", function () {
      detached.left = false;
      detached.right = false;
      layoutHost.style.setProperty("--mm-graph-width", "56rem");
      layoutHost.style.setProperty(
        "--mm-left-width",
        "minmax(12rem, 1fr)"
      );
      renderLayoutMode();
      window.requestAnimationFrame(function () {
        applyWidth(896);
        applyHeight(mapHost.clientWidth * 620 / 920);
        commit();
      });
    });
  }

  var resizeTimer = null;
  window.addEventListener("resize", function () {
    if (resizeTimer) clearTimeout(resizeTimer);
    resizeTimer = setTimeout(function () {
      if (window.matchMedia("(min-width: 1280px)").matches) {
        applyWidth(mapHost.getBoundingClientRect().width);
      }
      if (isWideLayout()) applyLeftWidth(currentLeftWidth());
      renderLayoutMode();
      commit();
    }, 120);
  });
}

function crossedPanelLimit(
  direction,
  delta,
  startLeft,
  startRight
) {
  var minSide = window.matchMedia("(min-width: 1440px)").matches
    ? 192
    : 256;
  if (direction < 0) return startLeft + delta < minSide;
  return startRight - delta < minSide;
}

function resizeWideMapSide(
  direction,
  delta,
  startWidth,
  startLeft,
  layoutHost,
  applyWidth,
  applyLeftWidth
) {
  var minGraph = 448;
  var minSide = 192;
  if (direction < 0) {
    var leftDelta = clamp(
      delta,
      minSide - startLeft,
      startWidth - minGraph
    );
    applyWidth(startWidth - leftDelta);
    applyLeftWidth(startLeft + leftDelta);
    return;
  }

  var layoutWidth = layoutHost.getBoundingClientRect().width;
  var gap = parseFloat(getComputedStyle(layoutHost).columnGap) || 16;
  var rightWidth = layoutWidth - startLeft - startWidth - gap * 2;
  var rightDelta = clamp(
    delta,
    minGraph - startWidth,
    rightWidth - minSide
  );
  applyWidth(startWidth + rightDelta);
  applyLeftWidth(startLeft);
}

function beginResize(handle, event, cursor, onMove, onEnd) {
  var previousCursor = document.body.style.cursor;
  var previousSelection = document.body.style.userSelect;
  document.body.style.cursor = cursor;
  document.body.style.userSelect = "none";
  handle.setPointerCapture(event.pointerId);

  function move(moveEvent) {
    onMove(moveEvent);
  }

  function end(endEvent) {
    handle.removeEventListener("pointermove", move);
    handle.removeEventListener("pointerup", end);
    handle.removeEventListener("pointercancel", end);
    if (handle.hasPointerCapture(endEvent.pointerId)) {
      handle.releasePointerCapture(endEvent.pointerId);
    }
    document.body.style.cursor = previousCursor;
    document.body.style.userSelect = previousSelection;
    onEnd();
  }

  handle.addEventListener("pointermove", move);
  handle.addEventListener("pointerup", end);
  handle.addEventListener("pointercancel", end);
}

function clamp(value, min, max) {
  var number = Number(value);
  if (!Number.isFinite(number)) number = min;
  return Math.max(min, Math.min(max, number));
}

function readMapSize() {
  try {
    return JSON.parse(localStorage.getItem("match-map-size")) || {};
  } catch (_error) {
    return {};
  }
}

function saveMapSize(size) {
  try {
    localStorage.setItem("match-map-size", JSON.stringify(size));
  } catch (_error) {
    // O redimensionamento continua funcional quando o storage esta bloqueado.
  }
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
