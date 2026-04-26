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
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

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

  // Run any UI actions (click navigation, wait for transitions, etc.).
  for (const action of (comp.actions || [])) {
    if (action.kind === 'click') {
      // Dispatch the click via DOM directly. Playwright's strict click
      // refuses when invisible canvas overlays sit above the target's
      // bounding box (AP's #game-canvas is fixed-positioned even on menu).
      // The button's onclick handler fires correctly via .click() on the
      // element — we don't need Playwright's pointer-event simulation here.
      const clicked = await page.evaluate((selector) => {
        const el = document.querySelector(selector);
        if (!el) return false;
        el.click();
        return true;
      }, action.selector);
      if (!clicked) throw new Error(`click target not found: ${action.selector}`);
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

  const captureDir = resolve(__dirname, 'output', 'capture', args.game);
  await mkdir(captureDir, { recursive: true });

  console.log(`[capture] ${args.game} — ${filtered.length} comp(s)`);
  const browser = await chromium.launch();
  try {
    // Phase 1: capture each composition's real-game state once (size-independent).
    for (const comp of filtered) {
      const captureFile = join(captureDir, `${comp.id}.png`);
      try {
        await captureOne(browser, { ...comp, viewport: comp.viewport || { width: 414, height: 896 } }, captureFile);
      } catch (err) {
        console.error(`    ✗ capture ${comp.id} — ${err.message}`);
      }
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
