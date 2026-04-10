// @ts-check
// Playwright config for Arrow Puzzle — deployed by the Stratos Games Factory.
// Do not hand-edit; changes are overwritten by scripts/deploy-brain.sh.

import { defineConfig, devices } from '@playwright/test';

const port = Number(process.env.PORT || 4173);
const baseURL = process.env.BASE_URL || `http://127.0.0.1:${port}`;

export default defineConfig({
  testDir: './tests/e2e',
  timeout: 30 * 1000,
  expect: { timeout: 5000 },
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 1 : 0,
  workers: 1,
  reporter: [['list'], ['html', { open: 'never', outputFolder: 'playwright-report' }]],
  outputDir: 'test-results',
  use: {
    baseURL,
    trace: 'retain-on-failure',
    screenshot: 'only-on-failure',
    video: 'retain-on-failure',
  },
  projects: [
    { name: 'chromium', use: { ...devices['Desktop Chrome'] } },
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
