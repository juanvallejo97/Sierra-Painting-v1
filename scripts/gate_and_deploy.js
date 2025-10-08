#!/usr/bin/env node
import path from 'node:path';
import fs from 'node:fs';
import { spawnSync } from 'node:child_process';
import dotenv from 'dotenv';

// Load .env when present so local runs pick up secrets from the file
const __dirname = path.dirname('');
const repoRoot = path.resolve(__dirname, '..');
const envPath = path.join(repoRoot, '.env');
if (fs.existsSync(envPath)) dotenv.config({ path: envPath });

const projectRoot = path.resolve(path.dirname(''));
const logPath = path.join(projectRoot, 'logs', 'token_validation_log.txt');

function fail(msg, code = 1) { console.error(msg); process.exit(code); }

if (!fs.existsSync(logPath)) fail(`Validation log not found: ${logPath}`, 4);
let j;
try { j = JSON.parse(fs.readFileSync(logPath, 'utf8')); } catch (e) { fail(`Failed to parse ${logPath}: ${e}`, 5); }
if (!(j.id && j.app)) { console.error('Token validation did not pass. Aborting deploy.'); process.exit(2); }

// Allow FIREBASE_PROJECT or fallback to FIREBASE_PROJECT_ID from .env
const proj = process.env.FIREBASE_PROJECT || process.env.FIREBASE_PROJECT_ID;
if (!proj) fail('FIREBASE_PROJECT required', 3);

// Prefer Application Default Credentials (GOOGLE_APPLICATION_CREDENTIALS) for CI/service accounts
// If not available, fall back to FIREBASE_TOKEN for backward compatibility.
const adcPath = process.env.GOOGLE_APPLICATION_CREDENTIALS;
const token = process.env.FIREBASE_TOKEN;

if (adcPath) {
	console.log('Using Application Default Credentials from', adcPath);
	console.log('Tokens validated; running firebase deploy for project', proj);
	const r = spawnSync('npx', ['firebase', 'deploy', '--project', proj, '--non-interactive'], { stdio: 'inherit' });
	if ((r.status ?? 1) !== 0) fail(`firebase deploy failed with exit code ${r.status}`, r.status || 1);
	console.log('✅ Deploy completed');
	process.exit(0);
}

if (!token) fail('FIREBASE_TOKEN required when GOOGLE_APPLICATION_CREDENTIALS is not set', 3);

console.log('Using FIREBASE_TOKEN from environment; running firebase deploy for project', proj);
const r = spawnSync('npx', ['firebase', 'deploy', '--project', proj, '--token', token, '--non-interactive'], { stdio: 'inherit' });
if ((r.status ?? 1) !== 0) fail(`firebase deploy failed with exit code ${r.status}`, r.status || 1);
console.log('✅ Deploy completed');
process.exit(0);
