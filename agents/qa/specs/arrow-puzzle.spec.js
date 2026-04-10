// @ts-check
/**
 * Arrow Puzzle smoke test — the cheapest visual QA the factory can run.
 *
 * Asserts the built game actually loads and renders. Catches the class of
 * failures that structural validators can't see:
 *   - Asset path broken (the Vite base-path bug from the early factory days)
 *   - JS parse error or missing bundle
 *   - Console errors during startup
 *   - Main game container missing from the DOM
 *
 * Deployed by the Stratos Games Factory — do not hand-edit.
 */

import { test, expect } from '@playwright/test';

test('game loads without console errors', async ({ page }) => {
  const consoleErrors = [];

  page.on('console', (msg) => {
    if (msg.type() === 'error') {
      consoleErrors.push(msg.text());
    }
  });
  page.on('pageerror', (err) => {
    consoleErrors.push(`pageerror: ${err.message}`);
  });

  const response = await page.goto('/', { waitUntil: 'load', timeout: 10_000 });
  expect(response, 'page response should exist').not.toBeNull();
  expect(response?.status(), 'HTTP status should be < 400').toBeLessThan(400);

  // Give the game ~2s to finish its boot sequence (load config, wire up
  // event handlers, paint the first frame).
  await page.waitForTimeout(2000);

  // --- Title assertion ---
  const title = await page.title();
  expect(title.trim(), 'page title must not be empty').not.toBe('');

  // --- Container assertion ---
  // Arrow Puzzle renders into either #app (menu + overlays) or
  // #game-canvas (the playfield). We accept either.
  const appVisible = await page.locator('#app').isVisible().catch(() => false);
  const canvasVisible = await page.locator('#game-canvas').isVisible().catch(() => false);
  expect(
    appVisible || canvasVisible,
    'expected either #app or #game-canvas to be visible after boot'
  ).toBe(true);

  // --- Screenshot for the PR comment ---
  await page.screenshot({
    path: 'playwright-report/arrow-puzzle-smoke.png',
    fullPage: true,
  });

  // --- Console-error assertion comes LAST so the screenshot is always taken ---
  expect(
    consoleErrors,
    `console errors during boot:\n${consoleErrors.join('\n')}`
  ).toHaveLength(0);
});
