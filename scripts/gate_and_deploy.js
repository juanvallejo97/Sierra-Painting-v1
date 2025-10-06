#!/usr/bin/env node
import path from 'node:path';
import fs from 'node:fs';
import { spawnSync } from 'node:child_process';

const projectRoot = path.resolve(path.dirname(''));
const logPath = path.join(projectRoot, 'logs', 'token_validation_log.txt');

function fail(msg, code = 1) { console.error(msg); process.exit(code); }

if (!fs.existsSync(logPath)) fail(`Validation log not found: ${logPath}`, 4);
let j;
try { j = JSON.parse(fs.readFileSync(logPath, 'utf8')); } catch (e) { fail(`Failed to parse ${logPath}: ${e}`, 5); }
if (!(j.id && j.app)) { console.error('Token validation did not pass. Aborting deploy.'); process.exit(2); }

const token = process.env.FIREBASE_TOKEN;
const proj = process.env.FIREBASE_PROJECT;
if (!token) fail('FIREBASE_TOKEN required', 3);
if (!proj) fail('FIREBASE_PROJECT required', 3);

console.log('Tokens validated; running firebase deploy for project', proj);
const r = spawnSync('npx', ['firebase', 'deploy', '--project', proj, '--token', token, '--non-interactive'], { stdio: 'inherit' });
if ((r.status ?? 1) !== 0) fail(`firebase deploy failed with exit code ${r.status}`, r.status || 1);
console.log('✅ Deploy completed');
process.exit(0);
