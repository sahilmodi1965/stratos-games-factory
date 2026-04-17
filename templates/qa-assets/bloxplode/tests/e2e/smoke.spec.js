// @ts-check
/**
 * Bloxplode smoke test — deployed by the Stratos Games Factory.
 * Do not hand-edit.
 *
 * Asserts that www/ serves a loadable page with no startup console errors
 * and a visible game container. Cheapest visual QA we can run on a
 * bundler-free Capacitor web payload.
 */

import { test, expect } from '@playwright/test';

/**
 * Known-environmental console errors that fire in PR preview environments
 * (GitHub Pages previews without injected tier-2 secrets). These are NOT
 * regressions — they fire on every preview regardless of the PR's diff.
 *
 * Real errors (JS parse errors, missing bundles, actual game bugs) will
 * still fail the smoke because they don't match these patterns.
 *
 * Order: most-specific patterns first.
 */
const ENV_ERROR_ALLOWLIST = [
  // Firebase SDK can't initialize without FIREBASE_API_KEY injected at build
  // time. Production has the key; PR previews don't. Filtered so the smoke
  // only fails on *non*-Firebase runtime errors.
  /FIREBASE_API_KEY is not defined/i,
  /firebase.*not defined/i,
  // Generic 404s on resources the preview doesn't serve (Firebase config,
  // ads SDK endpoints, analytics beacons). Real asset-path bugs show up as
  // JS parse errors elsewhere, not as bare 404s.
  /Failed to load resource.*404/i,
];

const isEnvError = (msg) => ENV_ERROR_ALLOWLIST.some((rx) => rx.test(msg));

test('www/ loads without console errors', async ({ page }) => {
  const consoleErrors = [];

  page.on('console', (msg) => {
    if (msg.type() === 'error') {
      const text = msg.text();
      if (!isEnvError(text)) consoleErrors.push(text);
    }
  });
  page.on('pageerror', (err) => {
    const text = `pageerror: ${err.message}`;
    if (!isEnvError(text)) consoleErrors.push(text);
  });

  const response = await page.goto('/', { waitUntil: 'load', timeout: 10_000 });
  expect(response, 'page response should exist').not.toBeNull();
  expect(response?.status(), 'HTTP status should be < 400').toBeLessThan(400);

  await page.waitForTimeout(2000);

  const title = await page.title();
  expect(title.trim(), 'page title must not be empty').not.toBe('');

  // Bloxplode root menu (www/index.html) renders #main-menu with #menu-buttons-layer
  // + #stratos-splash. Gameplay screens use #level-grid-structure. Candidate list
  // accepts the menu selectors first (most PRs test from the root) and falls back
  // to generic game-container selectors for future-proofing.
  const candidates = [
    '#main-menu',
    '#menu-buttons-layer',
    '#stratos-splash',
    '#level-grid-structure',
    '#app',
    '#game',
    '#game-container',
    '#game-canvas',
    'canvas',
    'main',
  ];
  let foundAny = false;
  for (const sel of candidates) {
    const visible = await page.locator(sel).first().isVisible().catch(() => false);
    if (visible) {
      foundAny = true;
      break;
    }
  }
  expect(
    foundAny,
    `expected at least one of [${candidates.join(', ')}] to be visible after boot`
  ).toBe(true);

  await page.screenshot({
    path: 'playwright-report/bloxplode-smoke.png',
    fullPage: true,
  });

  expect(
    consoleErrors,
    `console errors during boot:\n${consoleErrors.join('\n')}`
  ).toHaveLength(0);
});
