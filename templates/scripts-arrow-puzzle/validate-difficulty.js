#!/usr/bin/env node
/**
 * validate-difficulty.js — schema-check the procedural difficulty config.
 *
 * Arrow Puzzle does NOT use per-level JSON files. Levels are generated
 * procedurally by `games/arrow-puzzle/src/levels/level-loader.js` from the
 * `DIFFICULTY` table in `games/arrow-puzzle/src/config/difficulty-config.js`.
 *
 * This validator catches the kinds of bad edits a coding agent is most likely
 * to introduce when working on level/difficulty issues:
 *
 *   - non-monotonic `maxLevel` (tiers must cover ascending ranges)
 *   - grid sizes outside [3, 16]
 *   - arrow ranges that are non-positive or inverted
 *   - missing required fields
 *   - the table doesn't end with an `Infinity` cap
 *
 * Deployed by the Stratos Games Factory.
 */

import { pathToFileURL } from 'node:url';
import { resolve } from 'node:path';

const CONFIG_PATH = resolve(
  process.cwd(),
  'games/arrow-puzzle/src/config/difficulty-config.js'
);

async function loadDifficulty() {
  const mod = await import(pathToFileURL(CONFIG_PATH).href);
  if (!mod.DIFFICULTY || !Array.isArray(mod.DIFFICULTY)) {
    throw new Error(`difficulty-config.js does not export an array \`DIFFICULTY\``);
  }
  return mod.DIFFICULTY;
}

function validate(table) {
  const errors = [];
  const required = ['maxLevel', 'arrows', 'cols', 'rows', 'maxDepth', 'maxTurns', 'label'];

  if (table.length === 0) {
    errors.push('DIFFICULTY table is empty');
    return errors;
  }

  let prevMax = -Infinity;
  for (let i = 0; i < table.length; i++) {
    const tier = table[i];
    const where = `tier[${i}]`;

    for (const key of required) {
      if (!(key in tier)) {
        errors.push(`${where} missing required key \`${key}\``);
      }
    }

    if (typeof tier.maxLevel !== 'number') {
      errors.push(`${where}.maxLevel must be a number (got ${typeof tier.maxLevel})`);
    } else if (tier.maxLevel <= prevMax) {
      errors.push(`${where}.maxLevel (${tier.maxLevel}) is not strictly greater than previous tier (${prevMax})`);
    }
    prevMax = tier.maxLevel;

    if (!Array.isArray(tier.arrows) || tier.arrows.length !== 2) {
      errors.push(`${where}.arrows must be a [min, max] array`);
    } else {
      const [lo, hi] = tier.arrows;
      if (typeof lo !== 'number' || typeof hi !== 'number') {
        errors.push(`${where}.arrows must contain numbers`);
      } else if (lo <= 0 || hi <= 0) {
        errors.push(`${where}.arrows must be positive (got [${lo}, ${hi}])`);
      } else if (lo > hi) {
        errors.push(`${where}.arrows min (${lo}) > max (${hi})`);
      }
    }

    for (const dim of ['cols', 'rows']) {
      const v = tier[dim];
      if (typeof v !== 'number') {
        errors.push(`${where}.${dim} must be a number`);
      } else if (v < 3 || v > 16) {
        errors.push(`${where}.${dim} (${v}) out of range [3, 16]`);
      }
    }

    for (const k of ['maxDepth', 'maxTurns']) {
      if (typeof tier[k] !== 'number' || tier[k] < 0) {
        errors.push(`${where}.${k} must be a non-negative number`);
      }
    }

    if (typeof tier.label !== 'string' || tier.label.length === 0) {
      errors.push(`${where}.label must be a non-empty string`);
    }
  }

  // The last tier should cover all higher levels — i.e. its maxLevel should be Infinity
  const last = table[table.length - 1];
  if (last && Number.isFinite(last.maxLevel)) {
    errors.push(`final tier.maxLevel is finite (${last.maxLevel}); the table must end with maxLevel: Infinity`);
  }

  return errors;
}

async function main() {
  let table;
  try {
    table = await loadDifficulty();
  } catch (err) {
    console.error(`validate-difficulty: failed to load config: ${err.message}`);
    return 1;
  }

  const errors = validate(table);
  if (errors.length > 0) {
    console.error('validate-difficulty: schema errors:');
    for (const e of errors) console.error(`  ✗ ${e}`);
    return 1;
  }

  console.log(`validate-difficulty: ✓ ${table.length} difficulty tier(s) valid`);
  return 0;
}

process.exit(await main());
