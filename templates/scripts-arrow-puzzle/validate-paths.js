#!/usr/bin/env node
/**
 * validate-paths.js — refuse to commit anything in forbidden paths.
 *
 * Deployed by the Stratos Games Factory. Catches both daemon mistakes and
 * direct human pushes that accidentally drag in build output, native
 * artifacts, or shared kits that need separate review.
 *
 * Reads either:
 *   1. The list of files in `git diff --cached` (default — for pre-commit / CI), or
 *   2. The full working tree diff if `--working-tree` is passed.
 *
 * Exits 0 if the diff is clean. Exits 1 with a clear message otherwise.
 */

import { execSync } from 'node:child_process';

const FORBIDDEN_PATTERNS = [
  // Build output
  { pattern: /^docs(\/|$)/,        why: 'Vite build output — never commit by hand' },
  { pattern: /^dist(\/|$)/,        why: 'build output' },
  { pattern: /^build(\/|$)/,       why: 'build output' },
  // Cross-game shared kit (needs separate human review)
  { pattern: /^packages(\/|$)/,    why: 'cross-game shared kit, needs human review' },
  // Frozen reference
  { pattern: /^prototypes(\/|$)/,  why: 'frozen behavioral reference, do not edit' },
  // Dependencies
  { pattern: /^node_modules(\/|$)/, why: 'dependency tree' },
  // Lockfiles — only block automated edits, not deliberate ones
  // (we leave package-lock alone here so manual upgrades still work)
];

function listChangedFiles() {
  const args = process.argv.slice(2);
  let cmd;
  if (args.includes('--working-tree')) {
    cmd = 'git diff --name-only HEAD';
  } else if (args.includes('--all')) {
    cmd = 'git diff --name-only HEAD && git ls-files --others --exclude-standard';
  } else {
    // default: staged changes (pre-commit / pre-push use case)
    cmd = 'git diff --name-only --cached';
  }
  const out = execSync(cmd, { encoding: 'utf8' });
  return out
    .split('\n')
    .map(s => s.trim())
    .filter(Boolean);
}

function main() {
  const files = listChangedFiles();
  if (files.length === 0) {
    console.log('validate-paths: nothing changed, nothing to check.');
    return 0;
  }

  const violations = [];
  for (const f of files) {
    for (const { pattern, why } of FORBIDDEN_PATTERNS) {
      if (pattern.test(f)) {
        violations.push({ file: f, why });
        break;
      }
    }
  }

  if (violations.length > 0) {
    console.error('validate-paths: forbidden paths in diff:');
    for (const v of violations) {
      console.error(`  ✗ ${v.file}  (${v.why})`);
    }
    console.error('');
    console.error('These paths are owned by the build pipeline or other');
    console.error('humans. Reset them with:');
    console.error(`  git checkout HEAD -- ${violations.map(v => v.file).join(' ')}`);
    return 1;
  }

  console.log(`validate-paths: ✓ ${files.length} file(s) clean`);
  return 0;
}

process.exit(main());
