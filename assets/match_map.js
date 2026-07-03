/*
 * Visualizacao interativa da partida no grafo do cenario.
 */
(function () {
  "use strict";

  var SVG_NS = "http://www.w3.org/2000/svg";
  var W = 920, H = 620, PAD_X = 72, PAD_Y = 62, NODE_H = 34;
  var THIEF = "#fbbf24";   // amber-400
  var DET = "#38bdf8";     // sky-400

  function init() {
    var dataEl = document.getElementById("match-map-data");
    var host = document.getElementById("mm-graph");
    if (!dataEl || !host) return;

    var data;
    try { data = JSON.parse(dataEl.textContent); } catch (e) { return; }

    var cities = data.cities || [];
    if (!cities.length) {
      host.innerHTML =
        '<p class="p-6 text-slate-400 text-sm">Grafo do cenário indisponível ' +
        "para esta partida.</p>";
      return;
    }

    var pos = layout(cities, data.edges || []);
    var frames = buildFrames(data);

    var svg = drawBase(data.edges || [], pos);
    host.appendChild(svg);

    // A rota fica entre as arestas do mapa e os nos, para atravessar cada
    // cidade sem encobrir seu rotulo.
    var routeLayer = group(svg);
    drawNodes(svg, pos);
    var thief = marker(svg, THIEF, "L");
    var det = marker(svg, DET, "D");

    var slider = document.getElementById("mm-slider");
    var label = document.getElementById("mm-turn-label");
    var playBtn = document.getElementById("mm-play");
    var intervalEl = document.getElementById("mm-interval");
    var thiefInfo = document.getElementById("mm-thief");
    var detInfo = document.getElementById("mm-detective");

    slider.max = String(frames.length - 1);
    slider.value = "0";

    var timer = null;

    function render(idx) {
      var f = frames[idx];
      clear(routeLayer);
      drawRoute(routeLayer, pos, f.tPath, THIEF, -4);
      drawRoute(routeLayer, pos, f.dPath, DET, 4);
      place(thief, pos[f.t], -10);
      place(det, pos[f.d], 10);
      if (label) label.textContent = f.label;
      if (thiefInfo) thiefInfo.textContent = info(f.t, f.tAct);
      if (detInfo) detInfo.textContent = info(f.d, f.dAct);
    }

    function info(city, action) {
      var c = city ? city : "?";
      return action ? c + " — " + action : c;
    }

    function stop() {
      if (timer) { clearInterval(timer); timer = null; }
      if (playBtn) playBtn.textContent = "Reproduzir";
    }

    function play() {
      var ms = Math.max(100, parseInt(intervalEl && intervalEl.value, 10) || 800);
      if (Number(slider.value) >= frames.length - 1) slider.value = "0";
      if (playBtn) playBtn.textContent = "Pausar";
      timer = setInterval(function () {
        var next = Number(slider.value) + 1;
        if (next > frames.length - 1) { stop(); return; }
        slider.value = String(next);
        render(next);
      }, ms);
    }

    if (playBtn) {
      playBtn.addEventListener("click", function () {
        if (timer) stop(); else play();
      });
    }
    slider.addEventListener("input", function () {
      stop();
      render(Number(slider.value));
    });

    render(0);
  }

  /*
   * Layout orientado pela topologia. Primeiro cria camadas a partir de uma
   * extremidade do grafo e ordena cada camada pela media dos vizinhos. Depois
   * aplica uma simulacao de molas curta e deterministica. O resultado espalha
   * os nos pela area disponivel e evita o emaranhado produzido pelo circulo.
   */
  function layout(cities, edges) {
    var graph = adjacency(cities, edges);
    var pos = layeredSeed(cities, graph);

    if (cities.length <= 120) relaxLayout(cities, edges, pos);
    normalizeLayout(cities, pos);
    if (cities.length <= 30) improveCrossings(cities, edges, pos);
    normalizeLayout(cities, pos);

    cities.forEach(function (city) {
      pos[city].w = nodeWidth(city);
    });
    return pos;
  }

  function adjacency(cities, edges) {
    var graph = {};
    cities.forEach(function (city) { graph[city] = []; });
    edges.forEach(function (edge) {
      var a = edge[0], b = edge[1];
      if (!graph[a] || !graph[b] || a === b) return;
      graph[a].push(b);
      graph[b].push(a);
    });
    return graph;
  }

  function layeredSeed(cities, graph) {
    var root = cities[0];
    if (root) root = farthest(farthest(root, graph), graph);

    var distance = {};
    var queue = root ? [root] : [];
    if (root) distance[root] = 0;
    for (var qi = 0; qi < queue.length; qi++) {
      var current = queue[qi];
      graph[current].forEach(function (next) {
        if (distance[next] !== undefined) return;
        distance[next] = distance[current] + 1;
        queue.push(next);
      });
    }

    // Componentes desconectados ficam em camadas adicionais.
    var maxLevel = 0;
    cities.forEach(function (city) {
      if (distance[city] !== undefined) maxLevel = Math.max(maxLevel, distance[city]);
    });
    cities.forEach(function (city) {
      if (distance[city] === undefined) distance[city] = ++maxLevel;
    });

    var levels = [];
    for (var level = 0; level <= maxLevel; level++) levels[level] = [];
    cities.forEach(function (city) { levels[distance[city]].push(city); });

    // Sweeps baricentricos reduzem cruzamentos entre camadas consecutivas.
    for (var pass = 0; pass < 8; pass++) {
      orderLevels(levels, graph, distance, 1);
      orderLevels(levels, graph, distance, -1);
    }

    var pos = {};
    var usableW = W - 2 * PAD_X, usableH = H - 2 * PAD_Y;
    levels.forEach(function (nodes, levelIndex) {
      var y = levels.length === 1
        ? H / 2
        : PAD_Y + (usableH * levelIndex) / (levels.length - 1);
      nodes.forEach(function (city, index) {
        var x = nodes.length === 1
          ? W / 2
          : PAD_X + (usableW * index) / (nodes.length - 1);
        pos[city] = { x: x, y: y };
      });
    });
    return pos;
  }

  function farthest(start, graph) {
    var queue = [start], distance = {};
    distance[start] = 0;
    var result = start;
    for (var i = 0; i < queue.length; i++) {
      var city = queue[i];
      if (distance[city] > distance[result]) result = city;
      graph[city].forEach(function (next) {
        if (distance[next] !== undefined) return;
        distance[next] = distance[city] + 1;
        queue.push(next);
      });
    }
    return result;
  }

  function orderLevels(levels, graph, distance, direction) {
    var start = direction > 0 ? 1 : levels.length - 2;
    var end = direction > 0 ? levels.length : -1;
    for (var level = start; level !== end; level += direction) {
      var reference = levels[level - direction];
      var rank = {};
      reference.forEach(function (city, index) { rank[city] = index; });
      levels[level] = levels[level]
        .map(function (city, stableIndex) {
          var neighbors = graph[city].filter(function (neighbor) {
            return distance[neighbor] === level - direction;
          });
          var sum = neighbors.reduce(function (total, neighbor) {
            return total + rank[neighbor];
          }, 0);
          return {
            city: city,
            barycenter: neighbors.length ? sum / neighbors.length : stableIndex,
            stableIndex: stableIndex
          };
        })
        .sort(function (a, b) {
          return a.barycenter - b.barycenter || a.stableIndex - b.stableIndex;
        })
        .map(function (entry) { return entry.city; });
    }
  }

  function relaxLayout(cities, edges, pos) {
    var velocity = {};
    cities.forEach(function (city) { velocity[city] = { x: 0, y: 0 }; });

    for (var iteration = 0; iteration < 360; iteration++) {
      var force = {};
      cities.forEach(function (city) { force[city] = { x: 0, y: 0 }; });

      for (var i = 0; i < cities.length; i++) {
        for (var j = i + 1; j < cities.length; j++) {
          var aName = cities[i], bName = cities[j];
          var a = pos[aName], b = pos[bName];
          var dx = a.x - b.x, dy = a.y - b.y;
          var distance = Math.max(1, Math.hypot(dx, dy));
          var repel = 9000 / (distance * distance);
          var fx = (dx / distance) * repel;
          var fy = (dy / distance) * repel;
          force[aName].x += fx; force[aName].y += fy;
          force[bName].x -= fx; force[bName].y -= fy;
        }
      }

      edges.forEach(function (edge) {
        var aName = edge[0], bName = edge[1];
        var a = pos[aName], b = pos[bName];
        if (!a || !b) return;
        var dx = b.x - a.x, dy = b.y - a.y;
        var distance = Math.max(1, Math.hypot(dx, dy));
        var pull = (distance - 125) * 0.018;
        var fx = (dx / distance) * pull;
        var fy = (dy / distance) * pull;
        force[aName].x += fx; force[aName].y += fy;
        force[bName].x -= fx; force[bName].y -= fy;
      });

      var temperature = 8 * (1 - iteration / 360) + 0.35;
      cities.forEach(function (city) {
        // Gravidade suave impede componentes e folhas de escaparem da tela.
        force[city].x += (W / 2 - pos[city].x) * 0.0015;
        force[city].y += (H / 2 - pos[city].y) * 0.0015;
        velocity[city].x = (velocity[city].x + force[city].x) * 0.72;
        velocity[city].y = (velocity[city].y + force[city].y) * 0.72;
        var speed = Math.max(1, Math.hypot(velocity[city].x, velocity[city].y));
        var scale = Math.min(1, temperature / speed);
        pos[city].x += velocity[city].x * scale;
        pos[city].y += velocity[city].y * scale;
      });
    }
  }

  function improveCrossings(cities, edges, pos) {
    var best = layoutScore(cities, edges, pos);
    for (var pass = 0; pass < 5; pass++) {
      var changed = false;
      for (var i = 0; i < cities.length; i++) {
        for (var j = i + 1; j < cities.length; j++) {
          swapPositions(pos[cities[i]], pos[cities[j]]);
          var score = layoutScore(cities, edges, pos);
          if (score + 0.01 < best) {
            best = score;
            changed = true;
          } else {
            swapPositions(pos[cities[i]], pos[cities[j]]);
          }
        }
      }
      if (!changed) break;
    }
  }

  function layoutScore(cities, edges, pos) {
    var score = 0;
    for (var i = 0; i < edges.length; i++) {
      var e1 = edges[i], a = pos[e1[0]], b = pos[e1[1]];
      if (!a || !b) continue;
      score += Math.hypot(b.x - a.x, b.y - a.y);
      for (var j = i + 1; j < edges.length; j++) {
        var e2 = edges[j];
        if (e1[0] === e2[0] || e1[0] === e2[1] ||
            e1[1] === e2[0] || e1[1] === e2[1]) continue;
        var c = pos[e2[0]], d = pos[e2[1]];
        if (c && d && segmentsCross(a, b, c, d)) score += 100000;
      }
    }

    // Tambem evita que uma aresta passe por dentro de uma cidade intermediaria.
    edges.forEach(function (edge) {
      var a = pos[edge[0]], b = pos[edge[1]];
      if (!a || !b) return;
      cities.forEach(function (city) {
        if (city === edge[0] || city === edge[1]) return;
        if (pointSegmentDistance(pos[city], a, b) < 24) score += 25000;
      });
    });
    return score;
  }

  function segmentsCross(a, b, c, d) {
    var abC = orientation(a, b, c), abD = orientation(a, b, d);
    var cdA = orientation(c, d, a), cdB = orientation(c, d, b);
    return abC * abD < 0 && cdA * cdB < 0;
  }

  function orientation(a, b, c) {
    return (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x);
  }

  function pointSegmentDistance(point, a, b) {
    var dx = b.x - a.x, dy = b.y - a.y;
    var lengthSquared = dx * dx + dy * dy || 1;
    var t = ((point.x - a.x) * dx + (point.y - a.y) * dy) / lengthSquared;
    t = Math.max(0, Math.min(1, t));
    return Math.hypot(point.x - (a.x + t * dx), point.y - (a.y + t * dy));
  }

  function swapPositions(a, b) {
    var x = a.x, y = a.y;
    a.x = b.x; a.y = b.y;
    b.x = x; b.y = y;
  }

  function normalizeLayout(cities, pos) {
    if (!cities.length) return;
    var minX = Infinity, maxX = -Infinity, minY = Infinity, maxY = -Infinity;
    cities.forEach(function (city) {
      minX = Math.min(minX, pos[city].x); maxX = Math.max(maxX, pos[city].x);
      minY = Math.min(minY, pos[city].y); maxY = Math.max(maxY, pos[city].y);
    });
    var rawSpanX = maxX - minX, rawSpanY = maxY - minY;
    var spanX = Math.max(1, rawSpanX), spanY = Math.max(1, rawSpanY);
    cities.forEach(function (city) {
      pos[city].x = cities.length === 1 || rawSpanX < 1
        ? W / 2
        : PAD_X + ((pos[city].x - minX) / spanX) * (W - 2 * PAD_X);
      pos[city].y = cities.length === 1 || rawSpanY < 1
        ? H / 2
        : PAD_Y + ((pos[city].y - minY) / spanY) * (H - 2 * PAD_Y);
    });
  }

  function nodeWidth(city) {
    return Math.max(54, Math.min(150, String(city).length * 7.5 + 24));
  }

  // Reconstroi as posicoes correntes a partir do inicio + dos movimentos. Os
  // turnos vem em ordem decrescente (turno alto = inicio do jogo).
  function buildFrames(data) {
    var start = data.start || {};
    var turns = (data.turns || []).slice().sort(function (a, b) {
      return b.turn - a.turn;
    });
    var t = start.thief, d = start.detective;
    var tPath = validCity(t) ? [t] : [];
    var dPath = validCity(d) ? [d] : [];
    var frames = [{
      label: "Início", t: t, d: d,
      tPath: tPath.slice(), dPath: dPath.slice(),
      tAct: "", dAct: ""
    }];
    turns.forEach(function (tn) {
      if (validCity(tn.thief_pos)) {
        if (tn.thief_pos !== t) tPath.push(tn.thief_pos);
        t = tn.thief_pos;
      }
      if (validCity(tn.detective_pos)) {
        if (tn.detective_pos !== d) dPath.push(tn.detective_pos);
        d = tn.detective_pos;
      }
      frames.push({
        label: "Turno " + tn.turn,
        t: t, d: d,
        tPath: tPath.slice(),
        dPath: dPath.slice(),
        tAct: tn.thief_action || "",
        dAct: tn.detective_action || ""
      });
    });
    return frames;
  }

  function validCity(city) {
    return city !== null && city !== undefined && city !== "" && city !== "-";
  }

  function drawBase(edges, pos) {
    var svg = document.createElementNS(SVG_NS, "svg");
    svg.setAttribute("viewBox", "0 0 " + W + " " + H);
    svg.setAttribute("width", "100%");
    svg.setAttribute("class", "block w-full");
    svg.setAttribute("role", "img");
    svg.setAttribute("aria-label", "Mapa e rotas da partida");
    svg.setAttribute("preserveAspectRatio", "xMidYMid meet");

    edges.forEach(function (e) {
      var a = pos[e[0]], b = pos[e[1]];
      if (!a || !b) return;
      var edge = line(a, b, "#334155", 2);
      edge.setAttribute("stroke-linecap", "round");
      svg.appendChild(edge);
    });
    return svg;
  }

  function drawNodes(svg, pos) {
    var layer = group(svg);
    Object.keys(pos).forEach(function (city) {
      var p = pos[city];
      var node = group(layer);
      node.appendChild(title(city));
      node.appendChild(rect(
        p.x - p.w / 2, p.y - NODE_H / 2, p.w, NODE_H,
        9, "#1e293b", "#64748b", 1.5
      ));
      var label = text(p.x, p.y, compactLabel(city), "#e2e8f0", 12, "600");
      node.appendChild(label);
    });
  }

  function compactLabel(city) {
    var value = String(city);
    return value.length > 18 ? value.slice(0, 15) + "…" : value;
  }

  // Desenha todos os segmentos percorridos ate o frame atual. O ultimo recebe
  // mais contraste, mas nenhum segmento anterior desaparece durante o replay.
  function drawRoute(layer, pos, path, color, off) {
    for (var i = 1; i < path.length; i++) {
      var a = pos[path[i - 1]], b = pos[path[i]];
      if (!a || !b || path[i - 1] === path[i]) continue;
      var segment = offsetLine(a, b, color, i === path.length - 1 ? 5 : 3.5, off);
      segment.setAttribute("opacity", i === path.length - 1 ? "1" : "0.68");
      layer.appendChild(segment);
    }
  }

  function marker(svg, color, ch) {
    var g = group(svg);
    g.style.transition = "transform 250ms ease";
    g.appendChild(circle(0, 0, 9, color, "#0f172a", 2));
    g.appendChild(text(0, 0, ch, "#0f172a", 11, "700"));
    return g;
  }

  function place(g, p, off) {
    if (!p) {
      g.setAttribute("display", "none");
      return;
    }
    g.removeAttribute("display");
    g.setAttribute(
      "transform",
      "translate(" + (p.x + off) + "," + (p.y - NODE_H / 2 - 3) + ")"
    );
  }

  // ---- helpers SVG ----

  function group(svg) {
    var g = document.createElementNS(SVG_NS, "g");
    svg.appendChild(g);
    return g;
  }

  function clear(node) {
    while (node.firstChild) node.removeChild(node.firstChild);
  }

  function line(a, b, color, w) {
    var l = document.createElementNS(SVG_NS, "line");
    l.setAttribute("x1", a.x); l.setAttribute("y1", a.y);
    l.setAttribute("x2", b.x); l.setAttribute("y2", b.y);
    l.setAttribute("stroke", color); l.setAttribute("stroke-width", w);
    return l;
  }

  // Linha deslocada perpendicularmente para distinguir os caminhos do ladrao e
  // do detetive quando coincidem na mesma aresta.
  function offsetLine(a, b, color, w, off) {
    var dx = b.x - a.x, dy = b.y - a.y, len = Math.hypot(dx, dy) || 1;
    // Mantem cada agente no mesmo lado da aresta mesmo quando ele a percorre
    // no sentido contrario.
    if (a.x > b.x || (a.x === b.x && a.y > b.y)) off = -off;
    var ox = (-dy / len) * off, oy = (dx / len) * off;
    var l = line({ x: a.x + ox, y: a.y + oy }, { x: b.x + ox, y: b.y + oy }, color, w);
    l.setAttribute("stroke-linecap", "round");
    return l;
  }

  function rect(x, y, w, h, radius, fill, stroke, sw) {
    var r = document.createElementNS(SVG_NS, "rect");
    r.setAttribute("x", x); r.setAttribute("y", y);
    r.setAttribute("width", w); r.setAttribute("height", h);
    r.setAttribute("rx", radius);
    r.setAttribute("fill", fill);
    if (stroke) { r.setAttribute("stroke", stroke); r.setAttribute("stroke-width", sw); }
    return r;
  }

  function circle(x, y, r, fill, stroke, sw) {
    var c = document.createElementNS(SVG_NS, "circle");
    c.setAttribute("cx", x); c.setAttribute("cy", y); c.setAttribute("r", r);
    c.setAttribute("fill", fill);
    if (stroke) { c.setAttribute("stroke", stroke); c.setAttribute("stroke-width", sw); }
    return c;
  }

  function text(x, y, str, fill, size, weight) {
    var t = document.createElementNS(SVG_NS, "text");
    t.setAttribute("x", x); t.setAttribute("y", y);
    t.setAttribute("text-anchor", "middle");
    t.setAttribute("dominant-baseline", "central");
    t.setAttribute("fill", fill);
    t.setAttribute("font-size", size);
    t.setAttribute("font-family", "ui-monospace, monospace");
    if (weight) t.setAttribute("font-weight", weight);
    t.textContent = str;
    return t;
  }

  function title(str) {
    var node = document.createElementNS(SVG_NS, "title");
    node.textContent = str;
    return node;
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init);
  } else {
    init();
  }
})();
