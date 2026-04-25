/**
 * Faithful Arrow Puzzle arrow renderer for marketing scenes.
 *
 * Mirrors `games/arrow-puzzle/src/rendering/arrow-drawer.js` from the AP repo
 * — same visual conventions, different output (SVG instead of canvas):
 *
 * - Line: stroke-width = ARROW_LINE_WIDTH × cellPx (0.14)
 * - Head: triangle, size = ARROW_HEAD_SIZE × cellPx (0.28), apex angle ~64°
 *   via back-angle PI × 0.82 from the tip on each side, back-points at 0.85×size
 * - Filleted corners: R = 0.22 × cellPx, quadratic Bézier through each interior
 *   bend so 90° turns render as smooth curves (game/collision unchanged; this
 *   is purely visual and matches the real game).
 * - Shaft penetrates head: extend the path endpoint by headSize × 0.35 INTO
 *   the head triangle so the round line-cap overlaps the head's base — gives
 *   the arrow a connected, organic look.
 * - Tail dot: filled circle at the start, radius lw × 0.6, nudged backward by
 *   lw × 0.3 along the incoming direction (caps the start visually).
 * - Color: --arrow-color CSS variable per theme (default #3D3831, dark
 *   #F3F4F7, ocean #FFFFFF).
 *
 * Usage:
 *   <svg id="arrows-svg" viewBox="0 0 380 600"></svg>
 *   <script src="arrows.js"></script>
 *   <script>
 *     renderArrowPuzzleArrows({
 *       svgId: 'arrows-svg',
 *       cellPx: 22,
 *       offsetX: 14, offsetY: 14,
 *       arrows: [
 *         { path: [[0,0], [0,2]], dir: 'down' },
 *         { path: [[3,0], [3,2], [5,2]], dir: 'right' },
 *       ],
 *     });
 *   </script>
 */
(function () {
  'use strict';

  const DIR = {
    right: { dx:  1, dy:  0 },
    left:  { dx: -1, dy:  0 },
    up:    { dx:  0, dy: -1 },
    down:  { dx:  0, dy:  1 },
  };

  // Geometry constants — match GAMEPLAY config in the AP repo.
  const ARROW_LINE_WIDTH = 0.14;     // × cellPx → stroke width
  const ARROW_HEAD_SIZE  = 0.28;     // × cellPx → triangle "size"
  const FILLET_R_FACTOR  = 0.22;     // × cellPx → corner radius
  const HEAD_BACK_ANGLE  = Math.PI * 0.82; // back-corner angle from tip
  const HEAD_BACK_LEN    = 0.85;     // × headSize → distance from tip to back corner
  const SHAFT_OVERLAP    = 0.35;     // × headSize → shaft extension into head
  const TAIL_RADIUS_F    = 0.6;      // × lw → tail circle radius
  const TAIL_NUDGE_F     = 0.3;      // × lw → tail offset back along inbound dir

  function cellCenter(p, cellPx, ox, oy) {
    return [ ox + (p[0] + 0.5) * cellPx, oy + (p[1] + 0.5) * cellPx ];
  }

  function buildShaftPath(points, cellPx, ox, oy, lastDir, headSize) {
    const R = FILLET_R_FACTOR * cellPx;
    const cx = (i) => ox + (points[i][0] + 0.5) * cellPx;
    const cy = (i) => oy + (points[i][1] + 0.5) * cellPx;

    let d = `M${cx(0)},${cy(0)}`;

    // Walk through interior points emitting filleted corners or straight-throughs.
    for (let i = 1; i < points.length - 1; i++) {
      const inDx  = Math.sign(points[i][0] - points[i - 1][0]);
      const inDy  = Math.sign(points[i][1] - points[i - 1][1]);
      const outDx = Math.sign(points[i + 1][0] - points[i][0]);
      const outDy = Math.sign(points[i + 1][1] - points[i][1]);

      const px = cx(i);
      const py = cy(i);

      if (inDx === outDx && inDy === outDy) {
        // straight through — no fillet
        d += ` L${px},${py}`;
        continue;
      }
      // Approach corner along inbound direction (stop R before center).
      d += ` L${px - inDx * R},${py - inDy * R}`;
      // Quadratic curve to the exit point along outbound direction.
      d += ` Q${px},${py} ${px + outDx * R},${py + outDy * R}`;
    }

    // Final point + extend INTO the head.
    const last = points[points.length - 1];
    const lx = ox + (last[0] + 0.5) * cellPx;
    const ly = oy + (last[1] + 0.5) * cellPx;
    const exit = DIR[lastDir] || DIR.right;
    const overlap = headSize * SHAFT_OVERLAP;
    d += ` L${lx + exit.dx * overlap},${ly + exit.dy * overlap}`;
    return d;
  }

  function buildHeadPath(tip, dir, headSize) {
    const exit = DIR[dir] || DIR.right;
    const angle = Math.atan2(exit.dy, exit.dx);
    const tipX = tip[0] + Math.cos(angle) * headSize;
    const tipY = tip[1] + Math.sin(angle) * headSize;
    const lx = tipX + Math.cos(angle + HEAD_BACK_ANGLE) * headSize * HEAD_BACK_LEN;
    const ly = tipY + Math.sin(angle + HEAD_BACK_ANGLE) * headSize * HEAD_BACK_LEN;
    const rx = tipX + Math.cos(angle - HEAD_BACK_ANGLE) * headSize * HEAD_BACK_LEN;
    const ry = tipY + Math.sin(angle - HEAD_BACK_ANGLE) * headSize * HEAD_BACK_LEN;
    return `M${tipX},${tipY} L${lx},${ly} L${rx},${ry} Z`;
  }

  function buildTailDot(points, cellPx, ox, oy, lw) {
    const first = points[0];
    const next  = points[1] || points[0];
    const fx = ox + (first[0] + 0.5) * cellPx;
    const fy = oy + (first[1] + 0.5) * cellPx;
    const nx = ox + (next[0]  + 0.5) * cellPx;
    const ny = oy + (next[1]  + 0.5) * cellPx;
    const len = Math.hypot(nx - fx, ny - fy) || 1;
    const ux = (nx - fx) / len;
    const uy = (ny - fy) / len;
    return {
      cx: fx - ux * lw * TAIL_NUDGE_F,
      cy: fy - uy * lw * TAIL_NUDGE_F,
      r:  lw * TAIL_RADIUS_F,
    };
  }

  function renderArrowPuzzleArrows(opts) {
    const {
      svgId, cellPx,
      offsetX = 0, offsetY = 0,
      arrows = [],
      colorVar = '--arrow-color',
      colorFallback = '#3D3831',
    } = opts;

    const svg = document.getElementById(svgId);
    if (!svg) return;

    const lw = Math.max(4, ARROW_LINE_WIDTH * cellPx);
    const headSize = Math.max(8, ARROW_HEAD_SIZE * cellPx);
    // Resolve the CSS variable to a concrete color string. SVG presentation
    // attributes (fill, stroke) historically didn't accept var(...) reliably
    // across renderers, so we inline the computed color.
    const computed = getComputedStyle(document.documentElement).getPropertyValue(colorVar).trim();
    const color = computed || colorFallback;

    const ns = 'http://www.w3.org/2000/svg';
    const group = document.createElementNS(ns, 'g');
    group.setAttribute('class', 'ap-arrows');
    group.setAttribute('stroke-linecap', 'round');
    group.setAttribute('stroke-linejoin', 'round');

    for (const a of arrows) {
      if (!a || !a.path || a.path.length < 1) continue;

      const last = a.path[a.path.length - 1];
      const lastCenter = cellCenter(last, cellPx, offsetX, offsetY);

      // Single-cell arrow: no shaft, just a head at the cell center.
      if (a.path.length === 1) {
        const head = document.createElementNS(ns, 'path');
        head.setAttribute('d', buildHeadPath(lastCenter, a.dir, headSize));
        head.setAttribute('fill', color);
        group.appendChild(head);
        continue;
      }

      // Shaft
      const shaft = document.createElementNS(ns, 'path');
      shaft.setAttribute('d', buildShaftPath(a.path, cellPx, offsetX, offsetY, a.dir, headSize));
      shaft.setAttribute('fill', 'none');
      shaft.setAttribute('stroke', color);
      shaft.setAttribute('stroke-width', String(lw));
      group.appendChild(shaft);

      // Head
      const head = document.createElementNS(ns, 'path');
      head.setAttribute('d', buildHeadPath(lastCenter, a.dir, headSize));
      head.setAttribute('fill', color);
      group.appendChild(head);

      // Tail dot
      const tail = buildTailDot(a.path, cellPx, offsetX, offsetY, lw);
      const dot = document.createElementNS(ns, 'circle');
      dot.setAttribute('cx', String(tail.cx));
      dot.setAttribute('cy', String(tail.cy));
      dot.setAttribute('r',  String(tail.r));
      dot.setAttribute('fill', color);
      group.appendChild(dot);
    }

    svg.appendChild(group);
  }

  // expose for inline scripts
  window.renderArrowPuzzleArrows = renderArrowPuzzleArrows;
})();
