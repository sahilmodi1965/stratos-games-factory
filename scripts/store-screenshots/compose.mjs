/**
 * Render template/marketing.html at the target store viewport with the
 * scene HTML loaded into the device-frame iframe. Outputs a store-compliant
 * PNG per (composition × viewport).
 *
 * Architecture: scenes are pure HTML+CSS+SVG (scenes/<game>/*.html), so no
 * live game runtime is involved — pivot 2026-04-25 per Sahil. ~10× faster
 * than driving the game live, and we get pixel-perfect control over each
 * scene independent of game state availability.
 *
 *   node compose.mjs arrow-puzzle [--sizes ios-6.5,play-1080x2400] [--comps 1,2]
 */

import { chromium } from 'playwright';
import { readFile, mkdir } from 'node:fs/promises';
import { existsSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const __dirname = dirname(fileURLToPath(import.meta.url));

// Store viewports (2026 spec — Sahariar review on PR #89, brain v2):
// - Apple: 6.9" iPhone (1290×2796) is the current submission size — auto-scales
//   to all smaller iPhones. iPad 13" (2064×2752) is MANDATORY for any app that
//   supports iPad (AP + BX wrap with Capacitor universal → both submit iPad).
// - Google Play: aspect ratio must be 16:9 ≤ ratio ≤ 9:16. 1080×1920 (clean
//   16:9 — actually 9:16 portrait, 0.5625) is compliant. 1080×2400 (the old
//   default) is 2.22:1 and violates the cap.
// Older spec sizes (ios-6.5, play-1080x2400) kept here as deprecated aliases
// only so legacy commands don't break — not in the default render set.
const SIZES = {
  'ios-6.9':         { width: 1290, height: 2796, label: 'iPhone 6.9" (App Store primary)' },
  'ios-6.7':         { width: 1320, height: 2868, label: 'iPhone 6.7" (App Store alt)' },
  'ipad-13':         { width: 2064, height: 2752, label: 'iPad 13" (App Store iPad primary)' },
  'play-1080x1920':  { width: 1080, height: 1920, label: 'Google Play phone (16:9 compliant)' },
  'play-tablet-7':   { width: 1200, height: 1920, label: 'Google Play 7" tablet' },
  'play-tablet-10':  { width: 1600, height: 2560, label: 'Google Play 10" tablet' },
  // deprecated — pre-2026 sizes, kept for backward-compat with older commands
  'ios-6.5':         { width: 1284, height: 2778, label: 'iOS 6.5" (DEPRECATED — use ios-6.9)' },
  'ios-5.5':         { width: 1242, height: 2208, label: 'iOS 5.5" (DEPRECATED)' },
  'play-1080x2400':  { width: 1080, height: 2400, label: 'Play 1080×2400 (DEPRECATED — violates Play aspect cap)' }
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
    console.error('usage: node compose.mjs <game> [--sizes ios-6.5,play-1080x2400] [--comps 1,2,3]');
    process.exit(1);
  }
  return out;
}

async function composeOne(browser, templateUrl, sceneUrl, sceneAspect, comp, brand, viewport, outFile) {
  const ctx = await browser.newContext({
    viewport,
    deviceScaleFactor: 1,
    isMobile: false
  });
  const page = await ctx.newPage();
  page.on('pageerror', e => console.warn(`  [page error] ${e.message}`));
  await page.goto(templateUrl, { waitUntil: 'networkidle' });

  const heroSize  = Math.round(viewport.width * 0.118);
  const subSize   = Math.round(viewport.width * 0.028);
  const brandSize = Math.round(viewport.width * 0.022);

  await page.evaluate(({ comp, brand, heroSize, subSize, brandSize, sceneUrl, sceneAspect }) => {
    const r = document.documentElement.style;
    r.setProperty('--hero-size', heroSize + 'px');
    r.setProperty('--sub-size',  subSize  + 'px');
    r.setProperty('--brand-size', brandSize + 'px');
    window.__applyShot({
      caption: comp.caption,
      sub: comp.sub,
      gradient: comp.gradient,
      accent: comp.accent || brand.accent_glow,
      brand_name: brand.name,
      brand_tagline: brand.tagline,
      scene_url: sceneUrl,
      scene_aspect: sceneAspect
    });
  }, { comp, brand, heroSize, subSize, brandSize, sceneUrl, sceneAspect });

  // Wait for iframe scene + Inter font load.
  await page.evaluate(() => new Promise(r => {
    const f = document.getElementById('scene');
    if (!f) return r();
    if (f.contentDocument && f.contentDocument.readyState === 'complete') return r();
    f.addEventListener('load', () => r(), { once: true });
    setTimeout(r, 4000);
  }));
  await page.evaluate(() => document.fonts && document.fonts.ready).catch(() => {});
  await page.waitForTimeout(200);

  await page.screenshot({ path: outFile, fullPage: false, type: 'png' });
  console.log(`  ✓ ${comp.id} @ ${viewport.width}×${viewport.height} → ${outFile}`);

  await ctx.close();
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  const specPath = resolve(__dirname, 'compositions', `${args.game}.json`);
  if (!existsSync(specPath)) { console.error(`no spec at ${specPath}`); process.exit(1); }
  const spec = JSON.parse(await readFile(specPath, 'utf8'));
  const templateUrl = pathToFileURL(resolve(__dirname, 'template', 'marketing.html')).href;
  const sceneAspect = spec.scene_aspect || [414, 896];

  const filtered = args.comps
    ? spec.compositions.filter(c => args.comps.has(c.id) || args.comps.has(c.id.split('-')[0]))
    : spec.compositions;

  console.log(`[compose] ${args.game} — ${filtered.length} comp(s) × ${args.sizes.length} size(s)`);
  const browser = await chromium.launch();
  try {
    for (const sizeKey of args.sizes) {
      const v = SIZES[sizeKey];
      if (!v) { console.warn(`  ! unknown size ${sizeKey}, skipping`); continue; }
      const outDir = resolve(__dirname, 'output', 'final', args.game, sizeKey);
      await mkdir(outDir, { recursive: true });
      console.log(`  ${v.label} (${sizeKey})`);
      for (const comp of filtered) {
        if (!comp.scene) { console.warn(`    ! ${comp.id} missing 'scene'`); continue; }
        const sceneAbs = resolve(__dirname, 'scenes', comp.scene);
        if (!existsSync(sceneAbs)) { console.warn(`    ! scene file missing: ${sceneAbs}`); continue; }
        const sceneUrl = pathToFileURL(sceneAbs).href;
        const outFile = join(outDir, `${comp.id}.png`);
        try { await composeOne(browser, templateUrl, sceneUrl, sceneAspect, comp, spec.brand, v, outFile); }
        catch (err) { console.error(`    ✗ ${comp.id} — ${err.message}`); }
      }
    }
  } finally {
    await browser.close();
  }
}

main().catch(err => { console.error(err); process.exit(1); });
