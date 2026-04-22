// @ts-check
// Playwright config for Arrow Puzzle — deployed by the Stratos Games Factory.
// Do not hand-edit; changes are overwritten by scripts/deploy-brain.sh.
//
// Two test surfaces:
//   1. Desktop smoke (`tests/e2e/smoke.spec.js`) — `chromium` project, the
//      historical one-click "does it boot" check.
//   2. Mobile-viewport visual gate (`tests/mobile-smoke.spec.js`) — iPhone 13
//      (webkit) + Pixel 5 (chromium) projects, screenshot-diff against
//      committed baselines under `tests/snapshots/mobile/`. See issue #190.

import { defineConfig, devices } from '@playwright/test';

const port = Number(process.env.PORT || 4173);
const baseURL = process.env.BASE_URL || `http://127.0.0.1:${port}`;

export default defineConfig({
  testDir: './tests',
  timeout: 30 * 1000,
  expect: { timeout: 5000 },
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 1 : 0,
  workers: 1,
  reporter: [['list'], ['html', { open: 'never', outputFolder: 'playwright-report' }]],
  outputDir: 'test-results',
  // Mobile-smoke baselines live under tests/snapshots/mobile/<spec>/<state>-<project>.png
  // (issue #190); desktop smoke spec uses Playwright's default location.
  snapshotPathTemplate: 'tests/snapshots/mobile/{testFileName}-snapshots/{arg}-{projectName}{ext}',
  use: {
    baseURL,
    trace: 'retain-on-failure',
    screenshot: 'only-on-failure',
    video: 'retain-on-failure',
  },
  projects: [
    {
      name: 'chromium',
      testMatch: /e2e\/.*\.spec\.js$/,
      use: { ...devices['Desktop Chrome'] },
    },
    {
      name: 'mobile-iphone-13',
      testMatch: /mobile-smoke\.spec\.js$/,
      use: { ...devices['iPhone 13'] },
    },
    {
      name: 'mobile-pixel-5',
      testMatch: /mobile-smoke\.spec\.js$/,
      use: { ...devices['Pixel 5'] },
    },
  ],
  webServer: {
    // `vite preview` serves the built docs/ at the configured base.
    // We rely on the local clone having already run `npm run build`.
    command: `npx vite preview --port ${port} --strictPort`,
    url: baseURL,
    reuseExistingServer: !process.env.CI,
    timeout: 60 * 1000,
    stdout: 'pipe',
    stderr: 'pipe',
  },
});
