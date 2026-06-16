/*
 * Visualizacao interativa da partida no grafo do cenario.
 *
 * Le os dados embutidos em <script id="match-map-data"> (cidades, arestas,
 * posicoes inicial e por turno) e desenha um SVG com o grafo. O ladrao (ambar)
 * e o detetive (azul) andam pelo grafo turno a turno; a aresta escolhida no
 * turno atual fica destacada. Um slider controla o turno e o botao "Reproduzir"
 * avanca automaticamente no intervalo (ms) configurado.
 */
(function () {
  "use strict";

  var SVG_NS = "http://www.w3.org/2000/svg";
  var W = 600, H = 520, CX = 300, CY = 250, R = 195, NODE_R = 18;
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
        '<p class="p-6 text-slate-400 text-sm">Grafo do cenario indisponivel ' +
        "para esta partida.</p>";
      return;
    }

    var pos = layout(cities);
    var frames = buildFrames(data);

    var svg = drawBase(data.edges || [], pos);
    host.appendChild(svg);

    // Camadas dinamicas: destaque das arestas escolhidas + marcadores moveis.
    var highlightLayer = group(svg);
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
      clear(highlightLayer);
      drawHighlight(highlightLayer, pos, f.tFrom, f.t, THIEF, 3);
      drawHighlight(highlightLayer, pos, f.dFrom, f.d, DET, -3);
      place(thief, pos[f.t], -7);
      place(det, pos[f.d], 7);
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

  // Layout circular: distribui as cidades igualmente numa circunferencia.
  function layout(cities) {
    var pos = {}, n = cities.length;
    for (var i = 0; i < n; i++) {
      var ang = -Math.PI / 2 + (2 * Math.PI * i) / n;
      pos[cities[i]] = { x: CX + R * Math.cos(ang), y: CY + R * Math.sin(ang) };
    }
    return pos;
  }

  // Reconstroi as posicoes correntes a partir do inicio + dos movimentos. Os
  // turnos vem em ordem decrescente (turno alto = inicio do jogo).
  function buildFrames(data) {
    var start = data.start || {};
    var turns = (data.turns || []).slice().sort(function (a, b) {
      return b.turn - a.turn;
    });
    var t = start.thief, d = start.detective;
    var frames = [{
      label: "Inicio", t: t, d: d, tFrom: null, dFrom: null, tAct: "", dAct: ""
    }];
    turns.forEach(function (tn) {
      var tFrom = t, dFrom = d, tMoved = false, dMoved = false;
      if (tn.thief_pos && tn.thief_pos !== "-") { t = tn.thief_pos; tMoved = true; }
      if (tn.detective_pos && tn.detective_pos !== "-") {
        d = tn.detective_pos; dMoved = true;
      }
      frames.push({
        label: "Turno " + tn.turn,
        t: t, d: d,
        tFrom: tMoved ? tFrom : null,
        dFrom: dMoved ? dFrom : null,
        tAct: tn.thief_action || "",
        dAct: tn.detective_action || ""
      });
    });
    return frames;
  }

  function drawBase(edges, pos) {
    var svg = document.createElementNS(SVG_NS, "svg");
    svg.setAttribute("viewBox", "0 0 " + W + " " + H);
    svg.setAttribute("width", "100%");
    svg.setAttribute("class", "block");

    edges.forEach(function (e) {
      var a = pos[e[0]], b = pos[e[1]];
      if (!a || !b) return;
      svg.appendChild(line(a, b, "#334155", 2));
    });

    Object.keys(pos).forEach(function (city) {
      var p = pos[city];
      svg.appendChild(circle(p.x, p.y, NODE_R, "#1e293b", "#475569", 2));
      svg.appendChild(text(p.x, p.y, city, "#e2e8f0", 13));
    });
    return svg;
  }

  function drawHighlight(layer, pos, from, to, color, off) {
    if (!from || !to || from === to) return;
    var a = pos[from], b = pos[to];
    if (!a || !b) return;
    layer.appendChild(offsetLine(a, b, color, 4, off));
  }

  function marker(svg, color, ch) {
    var g = group(svg);
    g.style.transition = "transform 250ms ease";
    g.appendChild(circle(0, 0, 9, color, "#0f172a", 2));
    g.appendChild(text(0, 0, ch, "#0f172a", 11, "700"));
    return g;
  }

  function place(g, p, off) {
    if (!p) return;
    g.setAttribute("transform", "translate(" + (p.x + off) + "," + (p.y + off) + ")");
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
    var ox = (-dy / len) * off, oy = (dx / len) * off;
    var l = line({ x: a.x + ox, y: a.y + oy }, { x: b.x + ox, y: b.y + oy }, color, w);
    l.setAttribute("stroke-linecap", "round");
    return l;
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

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init);
  } else {
    init();
  }
})();
