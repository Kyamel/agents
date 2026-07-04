/*
 * Visualizacao interativa da partida no grafo do cenario.
 */
(function () {
  "use strict";

  var SVG_NS = "http://www.w3.org/2000/svg";
  var W = 920, H = 620, PAD_X = 72, PAD_Y = 62, NODE_H = 34;
  var THIEF = "#fbbf24";   // amber-400
  var DET = "#38bdf8";     // sky-400
  var NODE_FILL = "#1e293b";
  var NODE_STROKE = "#64748b";
  var BLOCKED_FILL = "#dc2626";   // red-600
  var BLOCKED_STROKE = "#fca5a5"; // red-300
  var READY_FILL = "#059669";     // emerald-600
  var READY_STROKE = "#6ee7b7";   // emerald-300
  var ROBBERY_FILL = "#fbbf24";   // amber-400
  var ROBBERY_STROKE = "#fde68a"; // amber-200
  var NODE_TEXT = "#e2e8f0";
  var ROBBERY_TEXT = "#0f172a";

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
    var nodes = drawNodes(svg, pos);
    var loot = drawLoot(svg, pos, data.loot || []);
    var lootByName = lootIndex(data.loot || []);
    var thief = marker(svg, THIEF, "L");
    var det = marker(svg, DET, "D");

    var slider = document.getElementById("mm-slider");
    var label = document.getElementById("mm-turn-label");
    var playBtn = document.getElementById("mm-play");
    var playIcon = document.getElementById("mm-play-icon");
    var intervalEl = document.getElementById("mm-interval");
    var eventInfo = document.getElementById("mm-event");
    var appearanceInfo = document.getElementById("mm-appearance");
    var collectedInfo = document.getElementById("mm-collected");
    var mandateInfo = document.getElementById("mm-mandate");

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
      paintLoot(loot, f.collected);
      paintNodes(
        nodes,
        f.blocked,
        f.objectiveCity,
        f.objectiveReady,
        f.robberyCities
      );
      if (label) label.textContent = f.label;
      if (eventInfo) eventInfo.textContent = f.eventText || "-";
      renderAppearance(appearanceInfo, f.appearance, f.revealed);
      renderCollected(collectedInfo, f.collected, lootByName);
      renderMandate(mandateInfo, f.mandate);
    }

    function setPlaybackControl(isPlaying) {
      if (!playBtn) return;
      var controlLabel = isPlaying ? "Pausar" : "Reproduzir";
      if (playIcon) {
        playIcon.textContent = isPlaying ? "⏸\uFE0E" : "▶\uFE0E";
        playIcon.style.transform =
          isPlaying ? "translateY(1px)" : "translateY(-1px)";
      }
      playBtn.setAttribute("aria-label", controlLabel);
      playBtn.setAttribute("title", controlLabel);
    }

    function stop() {
      if (timer) { clearInterval(timer); timer = null; }
      setPlaybackControl(false);
    }

    function play() {
      var ms = Math.max(100, parseInt(intervalEl && intervalEl.value, 10) || 800);
      if (Number(slider.value) >= frames.length - 1) slider.value = "0";
      setPlaybackControl(true);
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
    setupSidePanels(host);
  }

  // Iguala ao mapa apenas os cards que o CSS posicionou na mesma linha. Assim,
  // os breakpoints ficam centralizados no layout Tailwind e nao se repetem aqui.
  function setupSidePanels(mapHost) {
    var panels = document.querySelectorAll(".js-map-height");
    if (!panels.length || !mapHost) return;
    function sync() {
      var mapBounds = mapHost.getBoundingClientRect();
      var h = Math.round(mapBounds.height);
      for (var i = 0; i < panels.length; i++) {
        var panelTop = panels[i].getBoundingClientRect().top;
        var sharesMapRow = Math.abs(panelTop - mapBounds.top) < 2;
        panels[i].style.height = sharesMapRow && h > 0 ? h + "px" : "";
      }
    }
    sync();
    if (window.ResizeObserver) {
      new ResizeObserver(sync).observe(mapHost);
    }
    window.addEventListener("resize", sync);
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
    var blocked = (start.blocked || []).slice();
    var lockMode = start.lock_mode || "accumulate";
    var objective = data.objective || {};
    var objectiveCity = objective.city;
    var requirements = objective.requirements || [];
    var collected = {};
    // Ordem em que itens/tesouros foram roubados, para a lista de coletados.
    var collectedOrder = [];
    var appearance = initialAppearance(start.appearance || []);
    // Valores da aparencia que ja foram expostos ao detetive por algum furto.
    // Acumula ao longo dos turnos: uma vez revelado, permanece revelado.
    var revealed = {};
    var mandate = null;
    var tPath = validCity(t) ? [t] : [];
    var dPath = validCity(d) ? [d] : [];
    var frames = [{
      label: "Início", t: t, d: d,
      tPath: tPath.slice(), dPath: dPath.slice(),
      blocked: blocked.slice(),
      objectiveCity: objectiveCity,
      objectiveReady: objectiveIsReady(
        objectiveCity,
        requirements,
        collected
      ),
      robberyCities: [],
      eventText: "",
      appearance: cloneAppearance(appearance),
      revealed: [],
      collected: [],
      mandate: cloneMandate(mandate)
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
      var lockChange = lockChangeForTurn(tn);
      blocked = updateBlockedCities(
        blocked,
        lockChange.effect,
        lockChange.city,
        lockMode
      );
      (tn.stolen_items || []).forEach(function (item) {
        if (!collected[item]) collectedOrder.push(item);
        collected[item] = true;
      });
      appearance = applyDisguiseEffect(
        appearance,
        tn.disguise_effect || { type: "none", changes: [] }
      );
      mandate = applyMandateEffect(
        mandate,
        tn.mandate_effect || { type: "none" }
      );
      (tn.robbery_events || []).forEach(function (event) {
        (event.revealed || []).forEach(function (value) {
          revealed[String(value)] = true;
        });
      });
      frames.push({
        label: "Turno " + tn.turn,
        t: t, d: d,
        tPath: tPath.slice(),
        dPath: dPath.slice(),
        blocked: blocked.slice(),
        objectiveCity: objectiveCity,
        objectiveReady: objectiveIsReady(
          objectiveCity,
          requirements,
          collected
        ),
        robberyCities: (tn.robbery_cities || []).slice(),
        eventText: formatTurnEvents(tn, d, mandate),
        appearance: cloneAppearance(appearance),
        revealed: Object.keys(revealed),
        collected: collectedOrder.slice(),
        mandate: cloneMandate(mandate)
      });
    });
    return frames;
  }

  function initialAppearance(attributes) {
    return attributes.map(function (attribute) {
      return { original: String(attribute), current: String(attribute) };
    });
  }

  function cloneAppearance(appearance) {
    return appearance.map(function (attribute) {
      return {
        original: attribute.original,
        current: attribute.current
      };
    });
  }

  function applyDisguiseEffect(appearance, effect) {
    if (effect.type === "remove") {
      return appearance
        .filter(function (attribute) {
          return attribute.original !== null;
        })
        .map(function (attribute) {
          return {
            original: attribute.original,
            current: attribute.original
          };
        });
    }
    if (effect.type !== "apply") return appearance;

    var next = cloneAppearance(appearance);
    var additions = [];
    (effect.changes || []).forEach(function (change) {
      if (change.type === "add") {
        additions.push({ original: null, current: change.current });
        return;
      }
      var index = next.findIndex(function (attribute) {
        return attribute.current === change.original;
      });
      if (index === -1) return;
      if (change.type === "replace") {
        next[index].current = change.current;
      } else if (change.type === "omit") {
        next[index].current = null;
      }
    });
    return additions.concat(next);
  }

  function applyMandateEffect(mandate, effect) {
    if (effect.type !== "set") return mandate;
    return {
      suspect: effect.suspect,
      clues: (effect.clues || []).slice()
    };
  }

  function cloneMandate(mandate) {
    if (!mandate) return null;
    return {
      suspect: mandate.suspect,
      clues: mandate.clues.slice()
    };
  }

  function formatTurnEvents(turn, detectiveCity, mandate) {
    var events = [];
    var robberies = formatRobberyEvents(turn.robbery_events || []);
    if (robberies) events.push(robberies);

    var disguise = turn.disguise_effect || {};
    if (disguise.type === "apply" || disguise.type === "remove") {
      events.push("Disfarce: " + String(turn.thief_action || ""));
    }

    var mandateEffect = turn.mandate_effect || {};
    if (mandateEffect.type === "set") {
      events.push("Mandato emitido: " + formatMandateTerm(mandate));
    }

    if (turn.inspection) {
      var inspection = "Inspeção em " + eventValue(detectiveCity);
      inspection += mandate
        ? " — mandato ativo: " + formatMandateTerm(mandate)
        : " — sem mandato ativo";
      events.push(inspection);
    }
    return events.join("\n");
  }

  function formatMandateTerm(mandate) {
    if (!mandate) return "nenhum";
    return "pedir_mandato(" +
      eventValue(mandate.suspect) + ", [" +
      mandate.clues.map(eventValue).join(", ") +
      "])";
  }

  function formatRobberyEvents(events) {
    return events.map(function (event) {
      var revealed = event.revealed || [];
      return "roubo(" +
        eventValue(event.item) + ", " +
        eventValue(event.city) + ", [" +
        revealed.map(eventValue).join(", ") +
        "])";
    }).join(" | ");
  }

  function eventValue(value) {
    if (value === null || value === undefined) return "?";
    if (typeof value === "object") return JSON.stringify(value);
    return String(value);
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
      var added = attribute.original === null;
      var omitted = attribute.current === null;
      var changed = added || omitted ||
        attribute.original !== attribute.current;
      // Revelado quando o valor apresentado atualmente ja foi exposto ao
      // detetive por algum furto. Tem prioridade visual sobre o disfarce.
      var isRevealed = !omitted &&
        Boolean(revealedLookup[String(attribute.current)]);
      // Um valor revelado pode ser o traco real (original == atual) ou um
      // disfarce que o detetive flagrou (adicionado ou trocado). O disfarce
      // revelado ganha violeta; o traco real revelado fica em azul.
      var revealedFake = isRevealed &&
        (added || attribute.original !== attribute.current);
      var revealedValue = revealedFake ? "text-violet-300" : "text-sky-300";
      var rowBase = "flex flex-wrap items-center gap-2 rounded-lg border " +
        "px-3 py-2 ";
      var rowClass = rowBase + (
        revealedFake
          ? "border-violet-800 bg-violet-950/40"
          : isRevealed
            ? "border-sky-800 bg-sky-950/40"
            : changed
              ? "border-amber-800 bg-amber-950/40"
              : "border-surface-700 bg-surface-950"
      );
      var row = htmlElement("div", rowClass);
      row.appendChild(stateLabel(added ? "Origem" : "Original"));
      row.appendChild(stateValue(
        added ? "adicionado" : attribute.original,
        added
          ? "text-emerald-300"
          : isRevealed ? revealedValue : "text-surface-300"
      ));
      row.appendChild(htmlElement(
        "span",
        "text-surface-500",
        "→"
      ));
      row.appendChild(stateLabel("Atual"));
      row.appendChild(stateValue(
        omitted ? "omitido" : attribute.current,
        omitted
          ? "text-rose-300"
          : isRevealed
            ? revealedValue
            : changed ? "text-amber-300" : "text-surface-300"
      ));
      if (isRevealed) {
        row.appendChild(htmlElement(
          "span",
          "ml-auto rounded-full border px-2 py-0.5 text-[0.65rem] " +
            "uppercase tracking-wide font-semibold " +
            (revealedFake
              ? "bg-violet-950 border-violet-800 text-violet-300"
              : "bg-sky-950 border-sky-800 text-sky-300"),
          revealedFake ? "Disfarce revelado" : "Revelado"
        ));
      }
      container.appendChild(row);
    });
  }

  // Indexa o loot por nome do item para cruzar com a lista de coletados.
  function lootIndex(loot) {
    var index = {};
    (loot || []).forEach(function (entry) {
      index[entry.name] = entry;
    });
    return index;
  }

  function lootGlyph(entry) {
    return entry && entry.kind === "treasure" ? "💎" : "📦";
  }

  function lootKindLabel(entry) {
    return entry && entry.kind === "treasure" ? "Tesouro" : "Item";
  }

  function renderCollected(container, collected, lootByName) {
    if (!container) return;
    clearElement(container);
    if (!collected || !collected.length) {
      container.appendChild(emptyState("Nada roubado até aqui."));
      return;
    }
    collected.forEach(function (name) {
      var entry = lootByName[name] || { name: name, kind: "item" };
      var chip = htmlElement(
        "span",
        "flex items-center gap-2 rounded-lg bg-surface-950 " +
          "border border-surface-700 px-2.5 py-1"
      );
      chip.appendChild(htmlElement("span", "text-base leading-none",
        lootGlyph(entry)));
      chip.appendChild(htmlElement(
        "span",
        "text-[0.65rem] uppercase tracking-wide font-semibold " +
          "text-surface-500",
        lootKindLabel(entry)
      ));
      chip.appendChild(htmlElement("span", "font-mono text-surface-200", name));
      container.appendChild(chip);
    });
  }

  function renderMandate(container, mandate) {
    if (!container) return;
    clearElement(container);
    if (!mandate) {
      container.appendChild(emptyState("Nenhum mandato emitido."));
      return;
    }

    var header = htmlElement(
      "div",
      "flex items-center gap-2 mb-3 text-surface-200",
      "Suspeito"
    );
    header.appendChild(htmlElement(
      "span",
      "rounded-full bg-sky-950 border border-sky-800 " +
        "px-2.5 py-1 font-mono font-semibold text-sky-300",
      eventValue(mandate.suspect)
    ));
    container.appendChild(header);

    var clues = htmlElement("div", "flex flex-wrap gap-2");
    if (!mandate.clues.length) {
      clues.appendChild(emptyState("Sem pistas associadas."));
    } else {
      mandate.clues.forEach(function (clue) {
        clues.appendChild(htmlElement(
          "span",
          "rounded-lg bg-surface-950 border border-surface-700 " +
            "px-2.5 py-1 font-mono text-surface-300",
          clue
        ));
      });
    }
    container.appendChild(clues);
  }

  function stateLabel(label) {
    return htmlElement(
      "span",
      "text-[0.65rem] uppercase tracking-wide font-semibold " +
        "text-surface-500",
      label
    );
  }

  function stateValue(value, colorClass) {
    return htmlElement(
      "code",
      "font-mono break-all " + colorClass,
      value
    );
  }

  function emptyState(message) {
    return htmlElement(
      "p",
      "text-surface-500 italic",
      message
    );
  }

  function htmlElement(tag, className, content) {
    var element = document.createElement(tag);
    if (className) element.className = className;
    if (content !== undefined) element.textContent = content;
    return element;
  }

  function clearElement(element) {
    while (element.firstChild) element.removeChild(element.firstChild);
  }

  function objectiveIsReady(city, requirements, collected) {
    return validCity(city) && requirements.every(function (requirement) {
      return Boolean(collected[requirement]);
    });
  }

  // Replays novos recebem o efeito normalizado do backend. O parser da acao
  // mantem compatibilidade com paginas/replays gerados antes desse campo.
  function lockChangeForTurn(turn) {
    if (turn.lock_effect === "close" || turn.lock_effect === "open") {
      return { effect: turn.lock_effect, city: turn.lock_city };
    }
    if (turn.detective_status && turn.detective_status !== "OK") {
      return { effect: "none", city: null };
    }
    var action = String(turn.detective_action || "").trim();
    var match = /^(fechar|liberar)\((.*)\)$/.exec(action);
    if (!match) return { effect: "none", city: null };
    return {
      effect: match[1] === "fechar" ? "close" : "open",
      city: unquoteAtom(match[2].trim())
    };
  }

  function unquoteAtom(value) {
    if (value.length >= 2) {
      var first = value.charAt(0);
      var last = value.charAt(value.length - 1);
      if ((first === "'" && last === "'") ||
          (first === '"' && last === '"')) {
        return value.slice(1, -1);
      }
    }
    return value;
  }

  function updateBlockedCities(blocked, effect, city, lockMode) {
    if (effect === "close" && validCity(city)) {
      if (lockMode === "single") return [city];
      if (blocked.indexOf(city) !== -1) return blocked;
      return blocked.concat([city]);
    }
    if (effect === "open" && validCity(city)) {
      return blocked.filter(function (blockedCity) {
        return blockedCity !== city;
      });
    }
    return blocked;
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
    var nodes = {};
    Object.keys(pos).forEach(function (city) {
      var p = pos[city];
      var node = group(layer);
      var nodeTitle = title(city);
      var nodeRect = rect(
        p.x - p.w / 2, p.y - NODE_H / 2, p.w, NODE_H,
        9, NODE_FILL, NODE_STROKE, 1.5
      );
      node.appendChild(nodeTitle);
      node.appendChild(nodeRect);
      var label = text(p.x, p.y, compactLabel(city), NODE_TEXT, 12, "600");
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
    robberyCities
  ) {
    var blockedLookup = {};
    (blocked || []).forEach(function (city) {
      blockedLookup[city] = true;
    });
    var robberyLookup = {};
    (robberyCities || []).forEach(function (city) {
      robberyLookup[city] = true;
    });
    Object.keys(nodes).forEach(function (city) {
      var isBlocked = Boolean(blockedLookup[city]);
      var isReadyObjective = objectiveReady && city === objectiveCity;
      var hasRobbery = Boolean(robberyLookup[city]);
      var fill = NODE_FILL;
      var stroke = NODE_STROKE;
      var labelFill = NODE_TEXT;
      var suffix = "";
      if (isReadyObjective) {
        fill = READY_FILL;
        stroke = READY_STROKE;
        suffix = " (objetivo liberado)";
      }
      if (hasRobbery) {
        fill = ROBBERY_FILL;
        stroke = ROBBERY_STROKE;
        labelFill = ROBBERY_TEXT;
        suffix = " (furto neste turno)";
      }
      if (isBlocked) {
        fill = BLOCKED_FILL;
        stroke = BLOCKED_STROKE;
        labelFill = NODE_TEXT;
        suffix = " (bloqueada)";
      }
      nodes[city].rect.setAttribute(
        "fill",
        fill
      );
      nodes[city].rect.setAttribute(
        "stroke",
        stroke
      );
      nodes[city].label.setAttribute("fill", labelFill);
      nodes[city].title.textContent = city + suffix;
    });
  }

  // Marcadores de tesouro/item nas cidades de origem. Multiplos itens na mesma
  // cidade sao empilhados horizontalmente no canto superior direito do no.
  function drawLoot(svg, pos, loot) {
    var layer = group(svg);
    var perCity = {};
    var markers = [];
    (loot || []).forEach(function (entry) {
      var p = pos[entry.city];
      if (!p) return;
      var slot = perCity[entry.city] || 0;
      perCity[entry.city] = slot + 1;
      var gx = p.x + p.w / 2 - 8 - slot * 16;
      var gy = p.y - NODE_H / 2 - 2;
      var g = group(layer);
      g.appendChild(title(
        lootKindLabel(entry) + ": " + entry.name + " (" + entry.city + ")"
      ));
      g.appendChild(text(gx, gy, lootGlyph(entry), NODE_TEXT, 15, "400"));
      markers.push({ name: entry.name, el: g });
    });
    return markers;
  }

  // Some com o marcador quando o item ja foi roubado no frame corrente.
  function paintLoot(markers, collected) {
    var lookup = {};
    (collected || []).forEach(function (name) { lookup[name] = true; });
    markers.forEach(function (marker) {
      if (lookup[marker.name]) marker.el.setAttribute("display", "none");
      else marker.el.removeAttribute("display");
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
