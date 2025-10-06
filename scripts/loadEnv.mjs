import fs from 'fs';
import path from 'path';
import dotenv from 'dotenv';

const root = path.resolve(path.dirname(''));
const envPath = path.join(root, '.env');
if (fs.existsSync(envPath)) {
  const r = dotenv.config({ path: envPath });
  if (r.error) throw r.error;
} else {
  // no .env is okay in CI if secrets are provided. Don't throw.
}

// Helpful guard - ensure minimal required keys for validator/deploy when running locally
export function requireKeys(keys = []) {
  const missing = keys.filter(k => !process.env[k]);
  if (missing.length) {
    console.error('Missing required env keys:', missing.join(', '));
    process.exit(3);
  }
}

// usage: import { requireKeys } from './loadEnv.mjs'; requireKeys(['TEST_EMAIL','TEST_PASS']);
