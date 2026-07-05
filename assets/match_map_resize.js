var MIN_GRAPH_WIDTH = 448;
var MIN_WIDE_SIDE_WIDTH = 192;

export function fillMapSpace(svg) {
  if (!svg) return;
  svg.setAttribute("height", "100%");
  svg.style.height = "100%";
}

export function resizeInlinePanels(options) {
  var direction = options.direction;
  var delta = options.delta;
  var mapWidth = options.mapWidth;
  var leftWidth = options.leftWidth;
  var rightWidth = options.rightWidth;
  var minGraph = options.minGraph || MIN_GRAPH_WIDTH;
  var minSide = options.minSide || MIN_WIDE_SIDE_WIDTH;

  if (direction < 0) {
    var leftDelta = clamp(
      delta,
      minSide - leftWidth,
      mapWidth - minGraph
    );
    return {
      map: mapWidth - leftDelta,
      left: leftWidth + leftDelta,
      right: rightWidth
    };
  }

  var rightDelta = clamp(
    delta,
    minGraph - mapWidth,
    rightWidth - minSide
  );
  return {
    map: mapWidth + rightDelta,
    left: leftWidth,
    right: rightWidth - rightDelta
  };
}

export function restoredPanelWidths(options) {
  var layoutWidth = options.layoutWidth;
  var gap = options.gap;
  var left = options.leftWidth;
  var right = options.rightWidth;
  var side = options.side;
  var minGraph = options.minGraph || MIN_GRAPH_WIDTH;
  var minSide = options.minSide || MIN_WIDE_SIDE_WIDTH;

  if (side === "left") {
    left = clamp(
      left,
      minSide,
      layoutWidth - right - gap * 2 - minGraph
    );
  } else {
    right = clamp(
      right,
      minSide,
      layoutWidth - left - gap * 2 - minGraph
    );
  }
  return {
    map: Math.max(minGraph, layoutWidth - left - right - gap * 2),
    left: left,
    right: right
  };
}

export function setupResizableMap(layoutHost, mapHost, canvas, onCommit) {
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
        "minmax(28rem, 1fr) var(--mm-right-width)";
      layoutHost.style.gridTemplateAreas =
        '"graph right" "left left"';
    } else {
      layoutHost.style.gridTemplateColumns =
        "var(--mm-left-width) minmax(28rem, 1fr)";
      layoutHost.style.gridTemplateAreas =
        '"left graph" "right right"';
    }
  }

  function currentLeftWidth() {
    return leftPanel ? leftPanel.getBoundingClientRect().width : 0;
  }

  function currentRightWidth() {
    return rightPanel ? rightPanel.getBoundingClientRect().width : 0;
  }

  function savedSideWidth(property, fallback) {
    var value = parseFloat(
      getComputedStyle(layoutHost).getPropertyValue(property)
    );
    return Number.isFinite(value) ? Math.round(value) : fallback;
  }

  function widthLimits() {
    var layoutWidth = layoutHost.getBoundingClientRect().width;
    var gap = parseFloat(getComputedStyle(layoutHost).columnGap) || 16;
    var wide = isWideLayout();
    var sideSpace = wide ? MIN_WIDE_SIDE_WIDTH * 2 : 256;
    var gapSpace = wide ? gap * 2 : gap;
    return {
      min: MIN_GRAPH_WIDTH,
      max: Math.max(
        MIN_GRAPH_WIDTH,
        Math.round(layoutWidth - sideSpace - gapSpace)
      )
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
      handle.setAttribute(
        "aria-valuetext",
        "Largura do mapa: " + width + " pixels"
      );
    });
    return width;
  }

  function applyLeftWidth(value) {
    if (!isWideLayout()) return currentLeftWidth();
    var layoutWidth = layoutHost.getBoundingClientRect().width;
    var graphWidth = mapHost.getBoundingClientRect().width;
    var gap = parseFloat(getComputedStyle(layoutHost).columnGap) || 16;
    var max = detached.right
      ? layoutWidth - gap * 2 - MIN_GRAPH_WIDTH -
        MIN_WIDE_SIDE_WIDTH
      : layoutWidth - graphWidth - gap * 2 - MIN_WIDE_SIDE_WIDTH;
    max = Math.max(MIN_WIDE_SIDE_WIDTH, max);
    var width = Math.round(
      clamp(value, MIN_WIDE_SIDE_WIDTH, max)
    );
    layoutHost.style.setProperty("--mm-left-width", width + "px");
    return width;
  }

  function applyRightWidth(value) {
    if (!isWideLayout()) return currentRightWidth();
    var layoutWidth = layoutHost.getBoundingClientRect().width;
    var graphWidth = mapHost.getBoundingClientRect().width;
    var gap = parseFloat(getComputedStyle(layoutHost).columnGap) || 16;
    var max = detached.left
      ? layoutWidth - gap * 2 - MIN_GRAPH_WIDTH -
        MIN_WIDE_SIDE_WIDTH
      : layoutWidth - graphWidth - gap * 2 - MIN_WIDE_SIDE_WIDTH;
    max = Math.max(MIN_WIDE_SIDE_WIDTH, max);
    var width = Math.round(
      clamp(value, MIN_WIDE_SIDE_WIDTH, max)
    );
    layoutHost.style.setProperty("--mm-right-width", width + "px");
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
      bottomHandle.setAttribute(
        "aria-valuetext",
        "Altura do mapa: " + height + " pixels"
      );
    }
    return height;
  }

  if (saved.width && supportsDetachedLayout()) {
    applyWidth(saved.width);
  } else {
    applyWidth(mapHost.getBoundingClientRect().width);
  }
  if (isWideLayout()) {
    applyLeftWidth(saved.left || currentLeftWidth());
    layoutHost.style.setProperty(
      "--mm-right-width",
      (saved.right || currentRightWidth()) + "px"
    );
  }
  renderLayoutMode();
  var naturalHeight = mapHost.getBoundingClientRect().height;
  applyHeight(saved.height || naturalHeight);
  fillMapSpace(canvas.querySelector("svg"));

  function commit() {
    var measuredWidth = Math.round(mapHost.getBoundingClientRect().width);
    var width = detached.left || detached.right
      ? savedSideWidth("--mm-graph-width", measuredWidth)
      : measuredWidth;
    var height = Math.round(mapHost.getBoundingClientRect().height);
    var left = detached.left
      ? savedSideWidth("--mm-left-width", MIN_WIDE_SIDE_WIDTH)
      : Math.round(currentLeftWidth());
    var right = detached.right
      ? savedSideWidth("--mm-right-width", MIN_WIDE_SIDE_WIDTH)
      : Math.round(currentRightWidth());
    saveMapSize({
      width: width,
      height: height,
      left: left,
      right: right,
      leftDetached: detached.left,
      rightDetached: detached.right
    });
    if (onCommit) onCommit();
  }

  commit();

  function preserveSideWidths(leftWidth, rightWidth) {
    layoutHost.style.setProperty("--mm-left-width", leftWidth + "px");
    layoutHost.style.setProperty("--mm-right-width", rightWidth + "px");
  }

  function restorePanel(side) {
    detached[side] = false;
    layoutHost.style.setProperty(
      side === "left" ? "--mm-left-width" : "--mm-right-width",
      MIN_WIDE_SIDE_WIDTH + "px"
    );
    if (isWideLayout() && !detached.left && !detached.right) {
      var layoutWidth = layoutHost.getBoundingClientRect().width;
      var gap = parseFloat(getComputedStyle(layoutHost).columnGap) || 16;
      var left = savedSideWidth(
        "--mm-left-width",
        MIN_WIDE_SIDE_WIDTH
      );
      var right = savedSideWidth(
        "--mm-right-width",
        MIN_WIDE_SIDE_WIDTH
      );
      var restored = restoredPanelWidths({
        layoutWidth: layoutWidth,
        gap: gap,
        leftWidth: left,
        rightWidth: right,
        side: side
      });
      layoutHost.style.setProperty(
        "--mm-left-width",
        restored.left + "px"
      );
      layoutHost.style.setProperty(
        "--mm-right-width",
        restored.right + "px"
      );
      applyWidth(restored.map);
    }
    renderLayoutMode();
  }

  function applyHorizontalResize(
    direction,
    delta,
    startWidth,
    startLeft,
    startRight
  ) {
    if (!isWideLayout()) {
      applyWidth(startWidth + delta * direction);
      return;
    }
    var resized = resizeInlinePanels({
      direction: direction,
      delta: delta,
      mapWidth: startWidth,
      leftWidth: startLeft,
      rightWidth: startRight
    });
    if (direction < 0) {
      applyLeftWidth(resized.left);
      if (!detached.right) applyWidth(resized.map);
    } else {
      applyRightWidth(resized.right);
      if (!detached.left) applyWidth(resized.map);
    }
  }

  function wireHorizontalHandle(handle, direction) {
    if (!handle) return;
    handle.addEventListener("pointerdown", function (event) {
      if (event.button !== 0) return;
      event.preventDefault();
      var startX = event.clientX;
      var startWidth = mapHost.getBoundingClientRect().width;
      var startLeft = currentLeftWidth();
      var startRight = currentRightWidth();
      var side = direction < 0 ? "left" : "right";
      var snapped = false;
      beginResize(handle, event, "ew-resize", function (moveEvent) {
        if (snapped) return;
        var delta = moveEvent.clientX - startX;
        if (detached[side]) {
          var restoresSide = direction < 0 ? delta > 48 : delta < -48;
          if (restoresSide) {
            restorePanel(side);
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
          preserveSideWidths(startLeft, startRight);
          detached[side] = true;
          renderLayoutMode();
          snapped = true;
          return;
        }
        applyHorizontalResize(
          direction,
          delta,
          startWidth,
          startLeft,
          startRight
        );
      }, commit);
    });
    handle.addEventListener("keydown", function (event) {
      if (event.key !== "ArrowLeft" && event.key !== "ArrowRight") return;
      event.preventDefault();
      var physicalDelta = event.key === "ArrowRight" ? 24 : -24;
      var startWidth = mapHost.getBoundingClientRect().width;
      var startLeft = currentLeftWidth();
      var startRight = currentRightWidth();
      var side = direction < 0 ? "left" : "right";
      if (detached[side]) {
        var restoresSide = direction < 0
          ? physicalDelta > 0
          : physicalDelta < 0;
        if (restoresSide) {
          restorePanel(side);
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
        preserveSideWidths(startLeft, startRight);
        detached[side] = true;
        renderLayoutMode();
        commit();
        return;
      }
      applyHorizontalResize(
        direction,
        physicalDelta,
        startWidth,
        startLeft,
        startRight
      );
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
      layoutHost.style.setProperty("--mm-right-width", "20rem");
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
      renderLayoutMode();
      if (supportsDetachedLayout() && !detached.left && !detached.right) {
        applyWidth(mapHost.getBoundingClientRect().width);
      }
      commit();
    }, 120);
  });
}

function crossedPanelLimit(direction, delta, startLeft, startRight) {
  var minSide = window.matchMedia("(min-width: 1440px)").matches
    ? MIN_WIDE_SIDE_WIDTH
    : 256;
  if (direction < 0) return startLeft + delta < minSide;
  return startRight - delta < minSide;
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
export function setupSidePanels(mapHost) {
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
