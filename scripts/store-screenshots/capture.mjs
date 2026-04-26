/**
 * v6 capture pipeline (replaces scenes-as-HTML for store-bound output).
 *
 * Pipeline:
 *   1. For each composition, drive the real game in Playwright at the game's
 *      natural viewport. Seed localStorage / click navigation as specified.
 *      Capture the viewport as a raw PNG.
 *   2. For each (composition × store size), render template/marketing.html
 *      at the target size with the captured PNG embedded inside the device
 *      frame. Caption / gradient / brand wordmark layer chrome AROUND the
 *      capture exactly like v4 — the chrome template is unchanged.
 *
 * Architecture rule (CLAUDE.md Step 8 v6 #2): nothing inside the device
 * frame is brain-authored. The capture is real game pixels.
 *
 *   node capture.mjs arrow-puzzle [--sizes ios-6.9,play-1080x1920] [--comps 1,2]
 */

import { chromium } from 'playwright';
import { readFile, mkdir, writeFile } from 'node:fs/promises';
import { existsSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

// CLAUDE.md Step 8 v6 rule 5 — caption denylist (App Store / Play compliance).
// Match → fail compose. Per-game extensions go in compositions/<game>-v6.json
// under "caption_denylist_extra" if needed.
const CAPTION_DENYLIST = [
  /\bno ads?\b/i,
  /\bad-?free\b/i,
  /\bno timers?\b/i,
  /\bfree every (arrow|move|level|step)\b/i,
  /\buninterrupted\b/i,
  /\bpremium experience\b/i,
  /\bad-removal\b/i,
];

const __dirname = dirname(fileURLToPath(import.meta.url));

const SIZES = {
  'ios-6.9':         { width: 1290, height: 2796 },
  'ios-6.7':         { width: 1320, height: 2868 },
  'ipad-13':         { width: 2064, height: 2752 },
  'play-1080x1920':  { width: 1080, height: 1920 },
};

function parseArgs(argv) {
  const out = { game: null, sizes: ['ios-6.9', 'ipad-13', 'play-1080x1920'], comps: null };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === '--sizes') out.sizes = argv[++i].split(',').map(s => s.trim());
    else if (a === '--comps') out.comps = new Set(argv[++i].split(',').map(s => s.trim()));
    else if (!out.game && !a.startsWith('--')) out.game = a;
  }
  if (!out.game) {
    console.error('usage: node capture.mjs <game> [--sizes ...] [--comps ...]');
    process.exit(1);
  }
  return out;
}

/**
 * Drive the real game to a specific marketing state and capture a PNG.
 *
 * comp.url        — base URL of the live game (e.g. https://.../arrow-puzzle-testing/)
 * comp.viewport   — { width, height } — game's natural viewport (e.g. 414×896 phone)
 * comp.localStorage — { ns_key: value } — namespace-prefixed keys to seed BEFORE first paint
 * comp.actions    — [ { kind: 'click'|'wait'|'sleep', selector|ms } ] — UI actions after boot
 * comp.ready      — selector to wait for before capturing
 * comp.urlReset   — boolean — load URL with `?reset=1` first to clear prior storage
 */
async function captureOne(browser, comp, outFile) {
  const ctx = await browser.newContext({
    viewport: comp.viewport,
    deviceScaleFactor: 1,
    isMobile: false,
    userAgent: 'StratosFactoryCapture/1.0 (+factory v6)',
  });
  const page = await ctx.newPage();
  page.on('pageerror', e => console.warn(`  [game pageerror] ${e.message}`));

  const seedUrl = comp.urlReset ? (comp.url + (comp.url.includes('?') ? '&' : '?') + 'reset=1') : comp.url;

  // Pass 1: load the game (with reset=1 if requested) and clear/seed localStorage.
  await page.goto(seedUrl, { waitUntil: 'domcontentloaded' });
  if (comp.localStorage) {
    await page.evaluate((seed) => {
      Object.entries(seed).forEach(([k, v]) => localStorage.setItem(k, JSON.stringify(v)));
    }, comp.localStorage);
  }

  // Pass 2: reload without reset so seeded values take effect on a clean boot.
  await page.goto(comp.url, { waitUntil: 'networkidle' });

  // Guard 3: post-load seed read-back (#102). Catches namespace-prefix
  // mismatches like the v6 `arrow_puzzle:` vs `arrow_puzzle_` bug — every
  // seeded key MUST persist across the reload.
  if (comp.localStorage) {
    const readBack = await page.evaluate((keys) => {
      const out = {};
      keys.forEach(k => { out[k] = localStorage.getItem(k); });
      return out;
    }, Object.keys(comp.localStorage));
    for (const [k, expected] of Object.entries(comp.localStorage)) {
      const actual = readBack[k];
      const expectedStr = JSON.stringify(expected);
      if (actual !== expectedStr) {
        throw new Error(`SEED_NOT_PERSISTED: ${k} seeded=${expectedStr} read=${actual}`);
      }
    }
  }

  // Run any UI actions (click navigation, wait for transitions, etc.).
  for (const action of (comp.actions || [])) {
    if (action.kind === 'click') {
      // Dispatch the click via DOM directly. Playwright's strict click
      // refuses when invisible canvas overlays sit above the target's
      // bounding box (AP's #game-canvas is fixed-positioned even on menu).
      // The button's onclick handler fires correctly via .click() on the
      // element — we don't need Playwright's pointer-event simulation here.
      // Optional `text` filter: among matching selectors, pick the one whose
      // text content contains `text` (used for level-tile clicks where the
      // tile has no data-level attribute, only a numeric child span).
      const clicked = await page.evaluate(({ selector, text }) => {
        const els = Array.from(document.querySelectorAll(selector));
        if (!els.length) return false;
        let target;
        if (text == null) {
          target = els[0];
        } else {
          const want = String(text);
          // Match if any whitespace-separated token equals `want`, OR if the
          // first numeric run inside textContent equals `want` (covers
          // tiles where the number is concatenated with other glyphs).
          target = els.find(e => {
            const txt = (e.textContent || '').trim();
            if (txt.split(/\s+/).includes(want)) return true;
            const numMatch = txt.match(/\d+/);
            return numMatch && numMatch[0] === want;
          });
        }
        if (!target) return false;
        target.click();
        return true;
      }, { selector: action.selector, text: action.text ?? null });
      if (!clicked) throw new Error(`click target not found: ${action.selector}${action.text != null ? ` text=${action.text}` : ''}`);
    } else if (action.kind === 'wait') {
      await page.locator(action.selector).first().waitFor({ state: 'visible', timeout: 8000 });
    } else if (action.kind === 'sleep') {
      await page.waitForTimeout(action.ms);
    }
  }

  // Final readiness signal.
  if (comp.ready) {
    await page.locator(comp.ready).first().waitFor({ state: 'visible', timeout: 8000 });
  }
  await page.waitForTimeout(comp.settle || 600);

  // Guard 2: assert_screen — confirm we landed on the intended screen, not
  // an adjacent one (#102). The v6 AP failure captured the tutorial when the
  // spec asked for the menu; the ready selector existed on both surfaces so
  // it didn't catch the divergence. assert_screen is the screen-identity check.
  if (comp.assert_screen) {
    const present = await page.evaluate((sel) => !!document.querySelector(sel), comp.assert_screen);
    if (!present) {
      throw new Error(`WRONG_SCREEN_CAPTURED: assert_screen=${comp.assert_screen} not found at capture time`);
    }
  }

  await page.screenshot({ path: outFile, fullPage: false, type: 'png' });
  console.log(`  ✓ capture ${comp.id} → ${outFile}`);
  await ctx.close();
}

/**
 * Wrap a captured PNG with the marketing-template chrome at the target size.
 * Same chrome as v4 (template/marketing.html unchanged); we just inject the
 * capture as an <img> inside the device-frame instead of loading a scene
 * iframe.
 */
async function composeOne(browser, templateUrl, capturePngPath, comp, brand, viewport, outFile) {
  const ctx = await browser.newContext({
    viewport,
    deviceScaleFactor: 1,
    isMobile: false,
  });
  const page = await ctx.newPage();
  page.on('pageerror', e => console.warn(`  [template pageerror] ${e.message}`));

  // Read the capture as a base64 data URL so the template page can reference
  // it without serving a static dir. Keeps the pipeline single-process.
  const capturePng = await readFile(capturePngPath);
  const captureDataUrl = `data:image/png;base64,${capturePng.toString('base64')}`;

  await page.goto(templateUrl, { waitUntil: 'networkidle' });

  const heroSize  = Math.round(viewport.width * 0.118);
  const subSize   = Math.round(viewport.width * 0.028);
  const brandSize = Math.round(viewport.width * 0.022);

  await page.evaluate(({ comp, brand, heroSize, subSize, brandSize, sceneAspect, captureDataUrl }) => {
    const r = document.documentElement.style;
    r.setProperty('--hero-size', heroSize + 'px');
    r.setProperty('--sub-size',  subSize  + 'px');
    r.setProperty('--brand-size', brandSize + 'px');

    // Apply non-iframe path: replace the device-screen content with an <img>
    // pointing at the captured PNG. Maintains exactly the chrome treatment
    // v4 produced; only the inside-the-device content changes.
    const ds = document.getElementById('device-screen');

    // Match v4 device sizing math: keep capture aspect.
    const vw = window.innerWidth;
    const vh = window.innerHeight;
    const aspect = sceneAspect[0] / sceneAspect[1];
    let dW = Math.round(vw * 0.72);
    let dH = Math.round(dW / aspect);
    const maxH = Math.round(vh * 0.62);
    if (dH > maxH) { dH = maxH; dW = Math.round(dH * aspect); }
    ds.style.width = dW + 'px';
    ds.style.height = dH + 'px';
    ds.innerHTML = `<img src="${captureDataUrl}" style="width:100%;height:100%;display:block;object-fit:cover" alt="capture">`;

    // Now apply the rest of the shot (caption + gradient + brand) via
    // existing template hook, but skip scene_url since we already injected.
    window.__applyShot({
      caption: comp.caption,
      sub: comp.sub,
      gradient: comp.gradient,
      accent: comp.accent || brand.accent_glow,
      brand_name: brand.name,
      brand_tagline: brand.tagline,
      // Intentionally omit scene_url — the device-screen is already populated.
    });
  }, { comp, brand, heroSize, subSize, brandSize, sceneAspect: comp.viewport ? [comp.viewport.width, comp.viewport.height] : [414, 896], captureDataUrl });

  await page.evaluate(() => document.fonts && document.fonts.ready).catch(() => {});
  await page.waitForTimeout(200);

  await page.screenshot({ path: outFile, fullPage: false, type: 'png' });
  console.log(`  ✓ compose ${comp.id} @ ${viewport.width}×${viewport.height} → ${outFile}`);
  await ctx.close();
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  const specPath = resolve(__dirname, 'compositions', `${args.game}-v6.json`);
  if (!existsSync(specPath)) {
    console.error(`no v6 spec at ${specPath} — file the migration build-request first`);
    process.exit(1);
  }
  const spec = JSON.parse(await readFile(specPath, 'utf8'));
  const templateUrl = pathToFileURL(resolve(__dirname, 'template', 'marketing.html')).href;

  const filtered = args.comps
    ? spec.compositions.filter(c => args.comps.has(c.id) || args.comps.has(c.id.split('-')[0]))
    : spec.compositions;

  // Pre-flight: caption denylist (App Store / Play compliance). Fail fast
  // before launching a browser if any caption/sub matches a forbidden pattern.
  const denylistViolations = [];
  for (const comp of filtered) {
    const text = [comp.caption || '', comp.sub || ''].join(' ');
    for (const pattern of CAPTION_DENYLIST) {
      if (pattern.test(text)) {
        denylistViolations.push({ id: comp.id, pattern: pattern.toString(), text });
      }
    }
  }
  if (denylistViolations.length) {
    console.error('CAPTION_DENYLIST_VIOLATION — App Store / Play compliance:');
    for (const v of denylistViolations) {
      console.error(`  ${v.id}  matches ${v.pattern}  in: ${v.text.replace(/\n/g, ' / ')}`);
    }
    process.exit(1);
  }

  const captureDir = resolve(__dirname, 'output', 'capture', args.game);
  await mkdir(captureDir, { recursive: true });

  console.log(`[capture] ${args.game} — ${filtered.length} comp(s)`);
  const browser = await chromium.launch();
  const captureResults = []; // for Guard 1
  try {
    // Phase 1: capture each composition's real-game state once (size-independent).
    for (const comp of filtered) {
      const captureFile = join(captureDir, `${comp.id}.png`);
      try {
        await captureOne(browser, { ...comp, viewport: comp.viewport || { width: 414, height: 896 } }, captureFile);
        captureResults.push({ id: comp.id, file: captureFile, comp, ok: true });
      } catch (err) {
        console.error(`    ✗ capture ${comp.id} — ${err.message}`);
        captureResults.push({ id: comp.id, file: captureFile, comp, ok: false, error: err.message });
      }
    }

    // Guard 1: duplicate-PNG check (#102). Compare every pair of successful
    // captures whose specs differ in localStorage / actions / url. Identical
    // sha256 → SILENT_SEED_FAILURE. Catches the v6 AP failure where 3 menu
    // shots all rendered the same tutorial screen despite differing seeds.
    const successful = captureResults.filter(r => r.ok);
    const hashes = {};
    for (const r of successful) {
      const buf = await readFile(r.file);
      hashes[r.id] = createHash('sha256').update(buf).digest('hex');
    }
    const dupViolations = [];
    for (let i = 0; i < successful.length; i++) {
      for (let j = i + 1; j < successful.length; j++) {
        const a = successful[i], b = successful[j];
        const aSeed = JSON.stringify({ ls: a.comp.localStorage, ac: a.comp.actions, url: a.comp.url });
        const bSeed = JSON.stringify({ ls: b.comp.localStorage, ac: b.comp.actions, url: b.comp.url });
        if (aSeed !== bSeed && hashes[a.id] === hashes[b.id]) {
          dupViolations.push({ a: a.id, b: b.id, hash: hashes[a.id].slice(0, 12) });
        }
      }
    }
    if (dupViolations.length) {
      console.error('SILENT_SEED_FAILURE — captures with differing seeds rendered identical PNGs:');
      for (const v of dupViolations) {
        console.error(`  ${v.a} ≡ ${v.b}  (sha256=${v.hash}…)`);
      }
      console.error('  → seed is not reaching the game; check localStorage key namespace + theme value names');
      process.exit(2);
    }

    // Phase 2: compose each capture into the marketing template at every target size.
    console.log(`[compose] ${args.game} — ${filtered.length} comp(s) × ${args.sizes.length} size(s)`);
    for (const sizeKey of args.sizes) {
      const v = SIZES[sizeKey];
      if (!v) { console.warn(`  ! unknown size ${sizeKey}, skipping`); continue; }
      const outDir = resolve(__dirname, 'output', 'final', args.game, sizeKey);
      await mkdir(outDir, { recursive: true });
      console.log(`  ${sizeKey}`);
      for (const comp of filtered) {
        const captureFile = join(captureDir, `${comp.id}.png`);
        if (!existsSync(captureFile)) {
          console.warn(`    ! capture missing for ${comp.id}, skipping compose`);
          continue;
        }
        const outFile = join(outDir, `${comp.id}.png`);
        try {
          await composeOne(browser, templateUrl, captureFile, { ...comp, viewport: comp.viewport || { width: 414, height: 896 } }, spec.brand, v, outFile);
        } catch (err) {
          console.error(`    ✗ compose ${comp.id} — ${err.message}`);
        }
      }
    }
  } finally {
    await browser.close();
  }
}

main().catch(err => { console.error(err); process.exit(1); });
