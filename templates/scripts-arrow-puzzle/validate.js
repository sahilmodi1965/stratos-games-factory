#!/usr/bin/env node
/**
 * validate.js — top-level validator for Arrow Puzzle.
 *
 * Runs every `validate-*.js` script in this directory in order.
 * Exits 0 only if all of them pass.
 *
 * Used by `npm run validate` and by the Stratos Games Factory daemon as a
 * post-Claude gate before opening a PR.
 *
 * Deployed by the Stratos Games Factory.
 */

import { spawnSync } from 'node:child_process';
import { readdirSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const HERE = dirname(fileURLToPath(import.meta.url));
const SELF = 'validate.js';

const checks = readdirSync(HERE)
  .filter(f => f.startsWith('validate-') && f.endsWith('.js'))
  .sort();

if (checks.length === 0) {
  console.error('validate: no validate-*.js scripts found in', HERE);
  process.exit(1);
}

let failed = 0;
for (const check of checks) {
  console.log(`\n→ ${check}`);
  const res = spawnSync('node', [resolve(HERE, check), ...process.argv.slice(2)], {
    stdio: 'inherit',
  });
  if (res.status !== 0) {
    console.error(`  ✗ ${check} exited ${res.status}`);
    failed++;
  }
}

if (failed > 0) {
  console.error(`\nvalidate: ${failed} check(s) failed`);
  process.exit(1);
}
console.log(`\nvalidate: ✓ all ${checks.length} check(s) passed`);
