#!/usr/bin/env node
import { spawnSync } from 'child_process';
import net from 'net';
import path from 'path';
import { fileURLToPath } from 'url';
import fs from 'fs';
import dotenv from 'dotenv';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(__dirname, '..');
const envPath = path.join(repoRoot, '.env');
if (fs.existsSync(envPath)) dotenv.config({ path: envPath });

const node = process.execPath;

function run(cmd, args = []) {
  console.log('> ', [cmd, ...args].join(' '));
  const r = spawnSync(cmd, args, { stdio: 'inherit' });
  if (r.error) {
    console.error('Failed to run', cmd, r.error);
    process.exit(2);
  }
  return r.status;
}

function isPortOpen(port, host = '127.0.0.1', timeout = 1500) {
  return new Promise((res) => {
    const s = new net.Socket();
    let done = false;
    s.setTimeout(timeout);
    s.on('connect', () => { done = true; s.destroy(); res(true); });
    s.on('error', () => { if (!done) { done = true; res(false); } });
    s.on('timeout', () => { if (!done) { done = true; res(false); } });
    s.connect(port, host);
  });
}

(async () => {
  // 1) generate firebase config
  const genStatus = run(node, [path.join(__dirname, 'generate_firebase_config.js')]);
  if (genStatus !== 0) process.exit(genStatus);

  // 2) ensure Auth emulator is running
  const authPort = process.env.AUTH_EMULATOR_PORT || process.env.FIREBASE_AUTH_EMULATOR_PORT || process.env.AUTH_EMULATOR || '9099';
  const ok = await isPortOpen(Number(authPort));
  if (!ok) {
    console.error(`Auth emulator doesn't appear to be listening on port ${authPort}. Start it first: npx firebase emulators:start --only auth`);
    process.exit(3);
  }

  // 3) create the test user
  const createStatus = run(node, [path.join(__dirname, 'create_user.js')]);
  if (createStatus !== 0) process.exit(createStatus);

  // 4) run the validator
  const validateStatus = run(node, [path.join(__dirname, 'validate_runner.js'), '--headless=new', '--debug=true']);
  process.exit(validateStatus ?? 0);
})();
