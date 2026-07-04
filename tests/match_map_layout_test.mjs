import assert from "node:assert/strict";
import {
  layout,
  MAP_GEOMETRY
} from "../assets/match_map_layout.js";

const cities = ["a", "b", "c", "d"];
const edges = [["a", "b"], ["b", "c"], ["c", "d"]];
const first = layout(cities, edges);
const second = layout(cities, edges);

assert.deepEqual(first, second, "o layout deve ser determinístico");
for (const city of cities) {
  assert.ok(first[city], `posição ausente para ${city}`);
  assert.ok(first[city].x >= 0 && first[city].x <= MAP_GEOMETRY.width);
  assert.ok(first[city].y >= 0 && first[city].y <= MAP_GEOMETRY.height);
  assert.ok(first[city].w > 0);
}
