import { MAP_GEOMETRY } from "./match_map_layout.js?v=1";

var SVG_NS = "http://www.w3.org/2000/svg";

export function createMapSvg(edges, pos, loot, colors) {
  var svg = drawBase(edges, pos, colors);
  var routeLayer = group(svg);
  var nodes = drawNodes(svg, pos, colors);
  var lootMarkers = drawLoot(svg, pos, loot, colors);
  var thief = marker(svg, colors.thief, "L", colors.contrast);
  var detective = marker(svg, colors.detective, "D", colors.contrast);
  return {
    element: svg,
    routeLayer: routeLayer,
    nodes: nodes,
    lootMarkers: lootMarkers,
    thief: thief,
    detective: detective
  };
}

export function renderMapSvg(view, pos, frame, colors) {
  clear(view.routeLayer);
  drawRoute(view.routeLayer, pos, frame.tPath, colors.thief, -4);
  drawRoute(view.routeLayer, pos, frame.dPath, colors.detective, 4);
  place(view.thief, pos[frame.t], -10);
  place(view.detective, pos[frame.d], 10);
  paintLoot(view.lootMarkers, frame.collected);
  paintNodes(
    view.nodes,
    frame.blocked,
    frame.objectiveCity,
    frame.objectiveReady,
    frame.robberyCities,
    eventCities(frame.events, "inspection"),
    colors
  );
}

export function lootGlyph(entry) {
  return entry && entry.kind === "treasure" ? "💎" : "🔑";
}

export function lootKindLabel(entry) {
  return entry && entry.kind === "treasure" ? "Tesouro" : "Item";
}

function drawBase(edges, pos, colors) {
  var svg = document.createElementNS(SVG_NS, "svg");
  svg.setAttribute(
    "viewBox",
    "0 0 " + MAP_GEOMETRY.width + " " + MAP_GEOMETRY.height
  );
  svg.setAttribute("width", "100%");
  svg.setAttribute("class", "block w-full");
  svg.setAttribute("role", "img");
  svg.setAttribute("aria-label", "Mapa e rotas da partida");
  svg.setAttribute("preserveAspectRatio", "xMidYMid meet");

  edges.forEach(function (edgePair) {
    var a = pos[edgePair[0]], b = pos[edgePair[1]];
    if (!a || !b) return;
    var edge = line(a, b, colors.edge, 2);
    edge.setAttribute("stroke-linecap", "round");
    svg.appendChild(edge);
  });
  return svg;
}

function drawNodes(svg, pos, colors) {
  var layer = group(svg);
  var nodes = {};
  Object.keys(pos).forEach(function (city) {
    var point = pos[city];
    var node = group(layer);
    var nodeTitle = title(city);
    var nodeRect = rect(
      point.x - point.w / 2,
      point.y - MAP_GEOMETRY.nodeHeight / 2,
      point.w,
      MAP_GEOMETRY.nodeHeight,
      9,
      colors.node.fill,
      colors.node.stroke,
      1.5
    );
    node.appendChild(nodeTitle);
    node.appendChild(nodeRect);
    var label = text(
      point.x,
      point.y,
      compactLabel(city),
      colors.node.text,
      12,
      "600"
    );
    node.appendChild(label);
    nodes[city] = { rect: nodeRect, title: nodeTitle, label: label };
  });
  return nodes;
}

function paintNodes(
  nodes,
  blocked,
  objectiveCity,
  objectiveReady,
  robberyCities,
  inspectionCities,
  colors
) {
  var blockedLookup = {};
  (blocked || []).forEach(function (city) {
    blockedLookup[city] = true;
  });
  var robberyLookup = {};
  (robberyCities || []).forEach(function (city) {
    robberyLookup[city] = true;
  });
  var inspectionLookup = {};
  (inspectionCities || []).forEach(function (city) {
    inspectionLookup[city] = true;
  });
  Object.keys(nodes).forEach(function (city) {
    var isBlocked = Boolean(blockedLookup[city]);
    var isReadyObjective = objectiveReady && city === objectiveCity;
    var hasRobbery = Boolean(robberyLookup[city]);
    var hasInspection = Boolean(inspectionLookup[city]);
    var fill = colors.node.fill;
    var stroke = colors.node.stroke;
    var labelFill = colors.node.text;
    var suffix = "";
    if (isReadyObjective) {
      fill = colors.ready.fill;
      stroke = colors.ready.stroke;
      suffix = " (objetivo liberado)";
    }
    if (hasRobbery) {
      fill = colors.robbery.fill;
      stroke = colors.robbery.stroke;
      labelFill = colors.contrast;
      suffix = " (furto neste turno)";
    }
    if (isBlocked) {
      fill = colors.blocked.fill;
      stroke = colors.blocked.stroke;
      labelFill = colors.node.text;
      suffix = " (bloqueada)";
    }
    if (hasInspection) {
      fill = colors.inspection.fill;
      stroke = colors.inspection.stroke;
      labelFill = colors.node.text;
      suffix = " (inspecionada neste turno)";
    }
    nodes[city].rect.setAttribute("fill", fill);
    nodes[city].rect.setAttribute("stroke", stroke);
    nodes[city].label.setAttribute("fill", labelFill);
    nodes[city].title.textContent = city + suffix;
  });
}

function eventCities(events, type) {
  return (events || [])
    .filter(function (event) {
      return event && event.type === type && event.city;
    })
    .map(function (event) {
      return event.city;
    });
}

function drawLoot(svg, pos, loot, colors) {
  var layer = group(svg);
  var perCity = {};
  var markers = [];
  (loot || []).forEach(function (entry) {
    var point = pos[entry.city];
    if (!point) return;
    var slot = perCity[entry.city] || 0;
    perCity[entry.city] = slot + 1;
    var x = point.x + point.w / 2 - 8 - slot * 16;
    var y = point.y - MAP_GEOMETRY.nodeHeight / 2 - 2;
    var item = group(layer);
    item.appendChild(title(
      lootKindLabel(entry) + ": " + entry.name + " (" + entry.city + ")"
    ));
    item.appendChild(text(x, y, lootGlyph(entry), colors.node.text, 15, "400"));
    markers.push({ name: entry.name, element: item });
  });
  return markers;
}

function paintLoot(markers, collected) {
  var lookup = {};
  (collected || []).forEach(function (name) { lookup[name] = true; });
  markers.forEach(function (item) {
    if (lookup[item.name]) item.element.setAttribute("display", "none");
    else item.element.removeAttribute("display");
  });
}

function compactLabel(city) {
  var value = String(city);
  return value.length > 18 ? value.slice(0, 15) + "…" : value;
}

function drawRoute(layer, pos, path, color, offset) {
  for (var i = 1; i < path.length; i++) {
    var a = pos[path[i - 1]], b = pos[path[i]];
    if (!a || !b || path[i - 1] === path[i]) continue;
    var segment = offsetLine(
      a,
      b,
      color,
      i === path.length - 1 ? 5 : 3.5,
      offset
    );
    segment.setAttribute("opacity", i === path.length - 1 ? "1" : "0.68");
    layer.appendChild(segment);
  }
}

function marker(svg, color, character, contrast) {
  var markerGroup = group(svg);
  markerGroup.style.transition = "transform 250ms ease";
  markerGroup.appendChild(circle(0, 0, 9, color, contrast, 2));
  markerGroup.appendChild(text(0, 0, character, contrast, 11, "700"));
  return markerGroup;
}

function place(markerGroup, point, offset) {
  if (!point) {
    markerGroup.setAttribute("display", "none");
    return;
  }
  markerGroup.removeAttribute("display");
  markerGroup.setAttribute(
    "transform",
    "translate(" + (point.x + offset) + " " + point.y + ")"
  );
}

function group(parent) {
  var element = document.createElementNS(SVG_NS, "g");
  parent.appendChild(element);
  return element;
}

function clear(node) {
  while (node.firstChild) node.removeChild(node.firstChild);
}

function line(a, b, color, width) {
  var element = document.createElementNS(SVG_NS, "line");
  element.setAttribute("x1", a.x);
  element.setAttribute("y1", a.y);
  element.setAttribute("x2", b.x);
  element.setAttribute("y2", b.y);
  element.setAttribute("stroke", color);
  element.setAttribute("stroke-width", width);
  return element;
}

function offsetLine(a, b, color, width, offset) {
  var dx = b.x - a.x, dy = b.y - a.y;
  var length = Math.hypot(dx, dy) || 1;
  var ox = (-dy / length) * offset;
  var oy = (dx / length) * offset;
  return line(
    { x: a.x + ox, y: a.y + oy },
    { x: b.x + ox, y: b.y + oy },
    color,
    width
  );
}

function rect(x, y, width, height, radius, fill, stroke, strokeWidth) {
  var element = document.createElementNS(SVG_NS, "rect");
  element.setAttribute("x", x);
  element.setAttribute("y", y);
  element.setAttribute("width", width);
  element.setAttribute("height", height);
  element.setAttribute("rx", radius);
  element.setAttribute("fill", fill);
  if (stroke) {
    element.setAttribute("stroke", stroke);
    element.setAttribute("stroke-width", strokeWidth);
  }
  return element;
}

function circle(x, y, radius, fill, stroke, strokeWidth) {
  var element = document.createElementNS(SVG_NS, "circle");
  element.setAttribute("cx", x);
  element.setAttribute("cy", y);
  element.setAttribute("r", radius);
  element.setAttribute("fill", fill);
  if (stroke) {
    element.setAttribute("stroke", stroke);
    element.setAttribute("stroke-width", strokeWidth);
  }
  return element;
}

function text(x, y, content, fill, size, weight) {
  var element = document.createElementNS(SVG_NS, "text");
  element.setAttribute("x", x);
  element.setAttribute("y", y);
  element.setAttribute("text-anchor", "middle");
  element.setAttribute("dominant-baseline", "central");
  element.setAttribute("fill", fill);
  element.setAttribute("font-size", size);
  element.setAttribute("font-family", "ui-monospace, monospace");
  if (weight) element.setAttribute("font-weight", weight);
  element.textContent = content;
  return element;
}

function title(content) {
  var element = document.createElementNS(SVG_NS, "title");
  element.textContent = content;
  return element;
}
