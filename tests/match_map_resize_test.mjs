import assert from "node:assert/strict";
import {
  resizeInlinePanels,
  restoredPanelWidths
} from "../assets/match_map_resize.js";

assert.deepEqual(
  resizeInlinePanels({
    direction: 1,
    delta: -80,
    mapWidth: 1267,
    leftWidth: 1637,
    rightWidth: 354
  }),
  { map: 1187, left: 1637, right: 434 },
  "o painel direito deve redimensionar com o esquerdo destacado"
);

assert.deepEqual(
  resizeInlinePanels({
    direction: -1,
    delta: 80,
    mapWidth: 1267,
    leftWidth: 354,
    rightWidth: 1637
  }),
  { map: 1187, left: 434, right: 1637 },
  "o painel esquerdo deve redimensionar com o direito destacado"
);

assert.deepEqual(
  resizeInlinePanels({
    direction: 1,
    delta: 500,
    mapWidth: 896,
    leftWidth: 354,
    rightWidth: 300
  }),
  { map: 1004, left: 354, right: 192 },
  "o redimensionamento deve preservar a largura mínima do painel"
);

assert.deepEqual(
  restoredPanelWidths({
    layoutWidth: 1637,
    gap: 16,
    leftWidth: 192,
    rightWidth: 434,
    side: "left"
  }),
  { map: 979, left: 192, right: 434 },
  "o painel esquerdo deve voltar no mínimo sem alterar o direito"
);

assert.deepEqual(
  restoredPanelWidths({
    layoutWidth: 1637,
    gap: 16,
    leftWidth: 435,
    rightWidth: 192,
    side: "right"
  }),
  { map: 978, left: 435, right: 192 },
  "o painel direito deve voltar no mínimo sem alterar o esquerdo"
);
