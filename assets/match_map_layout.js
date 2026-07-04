export var MAP_GEOMETRY = {
  width: 920,
  height: 620,
  paddingX: 72,
  paddingY: 62,
  nodeHeight: 34
};

export function fitMapGeometry(pixelWidth, pixelHeight) {
  if (!(pixelWidth > 0) || !(pixelHeight > 0)) return;
  MAP_GEOMETRY.height = Math.max(
    1,
    Math.round(MAP_GEOMETRY.width * pixelHeight / pixelWidth)
  );
  MAP_GEOMETRY.paddingY = Math.max(
    24,
    Math.min(62, Math.round(MAP_GEOMETRY.height * 0.1))
  );
}

/*
 * Layout orientado pela topologia. Primeiro cria camadas a partir de uma
 * extremidade do grafo e ordena cada camada pela media dos vizinhos. Depois
 * aplica uma simulacao de molas curta e deterministica.
 */
export function layout(cities, edges) {
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

  var maxLevel = 0;
  cities.forEach(function (city) {
    if (distance[city] !== undefined) {
      maxLevel = Math.max(maxLevel, distance[city]);
    }
  });
  cities.forEach(function (city) {
    if (distance[city] === undefined) distance[city] = ++maxLevel;
  });

  var levels = [];
  for (var level = 0; level <= maxLevel; level++) levels[level] = [];
  cities.forEach(function (city) { levels[distance[city]].push(city); });

  for (var pass = 0; pass < 8; pass++) {
    orderLevels(levels, graph, distance, 1);
    orderLevels(levels, graph, distance, -1);
  }

  var geometry = MAP_GEOMETRY;
  var pos = {};
  var usableW = geometry.width - 2 * geometry.paddingX;
  var usableH = geometry.height - 2 * geometry.paddingY;
  levels.forEach(function (nodes, levelIndex) {
    var y = levels.length === 1
      ? geometry.height / 2
      : geometry.paddingY + (usableH * levelIndex) / (levels.length - 1);
    nodes.forEach(function (city, index) {
      var x = nodes.length === 1
        ? geometry.width / 2
        : geometry.paddingX + (usableW * index) / (nodes.length - 1);
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
        return a.barycenter - b.barycenter ||
          a.stableIndex - b.stableIndex;
      })
      .map(function (entry) { return entry.city; });
  }
}

function relaxLayout(cities, edges, pos) {
  var geometry = MAP_GEOMETRY;
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
      force[city].x += (geometry.width / 2 - pos[city].x) * 0.0015;
      force[city].y += (geometry.height / 2 - pos[city].y) * 0.0015;
      velocity[city].x = (velocity[city].x + force[city].x) * 0.72;
      velocity[city].y = (velocity[city].y + force[city].y) * 0.72;
      var speed = Math.max(
        1,
        Math.hypot(velocity[city].x, velocity[city].y)
      );
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
  return (b.x - a.x) * (c.y - a.y) -
    (b.y - a.y) * (c.x - a.x);
}

function pointSegmentDistance(point, a, b) {
  var dx = b.x - a.x, dy = b.y - a.y;
  var lengthSquared = dx * dx + dy * dy || 1;
  var t = ((point.x - a.x) * dx + (point.y - a.y) * dy) / lengthSquared;
  t = Math.max(0, Math.min(1, t));
  return Math.hypot(
    point.x - (a.x + t * dx),
    point.y - (a.y + t * dy)
  );
}

function swapPositions(a, b) {
  var x = a.x, y = a.y;
  a.x = b.x; a.y = b.y;
  b.x = x; b.y = y;
}

function normalizeLayout(cities, pos) {
  if (!cities.length) return;
  var geometry = MAP_GEOMETRY;
  var minX = Infinity, maxX = -Infinity;
  var minY = Infinity, maxY = -Infinity;
  cities.forEach(function (city) {
    minX = Math.min(minX, pos[city].x);
    maxX = Math.max(maxX, pos[city].x);
    minY = Math.min(minY, pos[city].y);
    maxY = Math.max(maxY, pos[city].y);
  });
  var rawSpanX = maxX - minX, rawSpanY = maxY - minY;
  var spanX = Math.max(1, rawSpanX), spanY = Math.max(1, rawSpanY);
  cities.forEach(function (city) {
    pos[city].x = cities.length === 1 || rawSpanX < 1
      ? geometry.width / 2
      : geometry.paddingX +
        ((pos[city].x - minX) / spanX) *
        (geometry.width - 2 * geometry.paddingX);
    pos[city].y = cities.length === 1 || rawSpanY < 1
      ? geometry.height / 2
      : geometry.paddingY +
        ((pos[city].y - minY) / spanY) *
        (geometry.height - 2 * geometry.paddingY);
  });
}

function nodeWidth(city) {
  return Math.max(54, Math.min(150, String(city).length * 7.5 + 24));
}
