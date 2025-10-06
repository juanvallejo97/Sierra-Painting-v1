#!/usr/bin/env node
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import dotenv from 'dotenv';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(__dirname, '..');
const envPath = path.join(repoRoot, '.env');
if (fs.existsSync(envPath)) dotenv.config({ path: envPath });

const cfg = {
  apiKey: process.env.FIREBASE_API_KEY || process.env.FIREBASE_APIKEY || '',
  authDomain: process.env.FIREBASE_AUTH_DOMAIN || '',
  projectId: process.env.FIREBASE_PROJECT_ID || process.env.FIREBASE_PROJECT || '',
  appId: process.env.FIREBASE_APP_ID || process.env.FIREBASE_APPID || '',
  recaptcha: (process.env.RECAPTCHA_SITE_KEY || process.env.RECAPTCHA_KEY || '')
};

// Include emulator settings when requested
// Normalize recaptcha: strip leading 'recaptcha:' and surrounding quotes
let rawRecaptcha = String(cfg.recaptcha || '').trim();
rawRecaptcha = rawRecaptcha.replace(/^recaptcha:\s*/i, '').replace(/^['"]|['"]$/g, '').trim();
cfg.recaptcha = rawRecaptcha;

if ((process.env.USE_EMULATORS || '').toLowerCase() === 'true') {
  const authPort = process.env.AUTH_EMULATOR_PORT || process.env.FIREBASE_AUTH_EMULATOR_PORT || '9099';
  cfg.emulator = {
    useEmulator: true,
    authHost: `http://localhost:${authPort}`
  };
  // When using emulators, avoid enabling reCAPTCHA to allow SDK debug mode
  cfg.recaptcha = '';
}

const outDir = __dirname;
fs.mkdirSync(outDir, { recursive: true });
// tokens.html expects scripts/firebase_config.json
const outPath = path.join(outDir, 'firebase_config.json');
fs.writeFileSync(outPath, JSON.stringify(cfg, null, 2));
console.log('Wrote', outPath);
