/**
 * Curated showroom boards for AP marketing screenshots (#93).
 *
 * These are NOT random procedurally-generated levels. They are hand-picked,
 * high-density boards designed for the screenshot's job: convert a store
 * browser into an installer. Density ≥75% cell occupancy, lots of L-bends,
 * T-junctions, near-misses — mid-Expert visual feel.
 *
 * Rendered by `arrows.js` (faithful AP renderer). Scenes import this file
 * and pass the named board into renderArrowPuzzleArrows({ arrows: ... }).
 */
(function () {
  'use strict';

  // 14×24 grid — packed mid-game board for the default and dark themes.
  // 48 arrows, dense in the center, slight breathing room at top/bottom.
  const packed_mid_game = [
    // ─── Top rows (0-3) — 8 arrows
    { path: [[0,0],[2,0],[2,2]], dir: 'down' },
    { path: [[4,1],[6,1]], dir: 'right' },
    { path: [[8,0],[8,2]], dir: 'down' },
    { path: [[10,1],[12,1],[12,3]], dir: 'down' },
    { path: [[14,0],[14,2]], dir: 'down' },
    { path: [[1,3],[3,3]], dir: 'right' },
    { path: [[5,3],[7,3]], dir: 'right' },
    { path: [[10,3],[12,3]], dir: 'right' },

    // ─── Upper-middle (4-8) — 11 arrows, denser
    { path: [[0,5],[3,5]], dir: 'right' },
    { path: [[5,4],[5,6]], dir: 'down' },
    { path: [[7,5],[9,5],[9,7]], dir: 'down' },
    { path: [[11,5],[13,5]], dir: 'right' },
    { path: [[14,4],[14,7]], dir: 'down' },
    { path: [[1,7],[3,7],[3,9]], dir: 'down' },
    { path: [[5,8],[7,8]], dir: 'right' },
    { path: [[9,7],[11,7]], dir: 'right' },
    { path: [[12,8],[14,8]], dir: 'right' },
    { path: [[2,9],[4,9]], dir: 'right' },
    { path: [[6,9],[6,11]], dir: 'down' },

    // ─── Center (9-14) — densest cluster, 13 arrows
    { path: [[8,9],[10,9],[10,11]], dir: 'down' },
    { path: [[12,10],[14,10]], dir: 'right' },
    { path: [[0,11],[2,11]], dir: 'right' },
    { path: [[4,10],[4,12]], dir: 'down' },
    { path: [[7,11],[7,13]], dir: 'down' },
    { path: [[9,12],[11,12]], dir: 'right' },
    { path: [[13,12],[13,14]], dir: 'down' },
    { path: [[1,13],[3,13]], dir: 'right' },
    { path: [[5,13],[5,15]], dir: 'down' },
    { path: [[8,14],[10,14]], dir: 'right' },
    { path: [[11,14],[11,16]], dir: 'down' },
    { path: [[2,15],[4,15]], dir: 'right' },
    { path: [[6,14],[6,16]], dir: 'down' },

    // ─── Lower-middle (15-19) — 10 arrows
    { path: [[0,16],[2,16]], dir: 'right' },
    { path: [[4,17],[6,17]], dir: 'right' },
    { path: [[8,15],[8,17]], dir: 'down' },
    { path: [[10,17],[12,17]], dir: 'right' },
    { path: [[13,16],[14,16],[14,18]], dir: 'down' },
    { path: [[1,18],[3,18],[3,20]], dir: 'down' },
    { path: [[5,19],[7,19]], dir: 'right' },
    { path: [[9,18],[9,20]], dir: 'down' },
    { path: [[11,19],[13,19]], dir: 'right' },
    { path: [[6,20],[8,20]], dir: 'right' },

    // ─── Bottom (20-23) — 6 arrows
    { path: [[0,21],[2,21]], dir: 'right' },
    { path: [[4,21],[4,23]], dir: 'down' },
    { path: [[10,21],[12,21]], dir: 'right' },
    { path: [[13,21],[13,23]], dir: 'down' },
    { path: [[6,22],[8,22]], dir: 'right' },
    { path: [[1,23],[3,23]], dir: 'right' },
  ];

  // Daily challenge mini-board — smaller, tidier showcase for the streak scene.
  // 11×9 grid, 16 arrows, more readable at smaller render size.
  const daily_compact = [
    { path: [[0,0],[2,0]], dir: 'right' },
    { path: [[4,0],[4,2]], dir: 'down' },
    { path: [[6,0],[8,0],[8,2]], dir: 'down' },
    { path: [[10,1],[10,3]], dir: 'down' },

    { path: [[1,2],[3,2]], dir: 'right' },
    { path: [[5,3],[7,3]], dir: 'right' },
    { path: [[9,3],[10,3]], dir: 'right' },

    { path: [[0,4],[2,4]], dir: 'right' },
    { path: [[3,4],[3,6]], dir: 'down' },
    { path: [[5,5],[7,5]], dir: 'right' },
    { path: [[8,4],[8,6]], dir: 'down' },

    { path: [[1,6],[3,6]], dir: 'right' },
    { path: [[5,6],[5,8]], dir: 'down' },
    { path: [[7,7],[9,7]], dir: 'right' },

    { path: [[0,8],[2,8]], dir: 'right' },
    { path: [[6,8],[8,8]], dir: 'right' },
  ];

  window.AP_BOARDS = { packed_mid_game, daily_compact };
})();
