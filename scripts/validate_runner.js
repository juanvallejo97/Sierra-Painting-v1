#!/usr/bin/env node
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { requireKeys } from './loadEnv.mjs';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
// Ensure minimal keys when running locally
requireKeys(['TEST_EMAIL','TEST_PASS']);

const args = process.argv.slice(2);
const node = process.execPath;
const validator = path.resolve(process.cwd(), 'scripts', 'validate_tokens.js');
const allArgs = [validator, ...args];
console.log('Invoking validator with', allArgs.join(' '));
const r = spawnSync(node, allArgs, { stdio: 'inherit' });
process.exit(r.status ?? 1);
