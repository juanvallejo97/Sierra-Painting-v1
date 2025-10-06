#!/usr/bin/env node
import admin from 'firebase-admin';
import fs from 'fs';
import path from 'path';
import dotenv from 'dotenv';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(__dirname, '..');
const envPath = path.join(repoRoot, '.env');
if (fs.existsSync(envPath)) dotenv.config({ path: envPath });

const email = process.env.TEST_EMAIL || 'user@sierra.dev';
const pass = process.env.TEST_PASS || 'TestPass123!';
const authEmulator = process.env.AUTH_EMULATOR_PORT || process.env.FIREBASE_AUTH_EMULATOR_PORT || '9099';

process.env.FIREBASE_AUTH_EMULATOR_HOST = `127.0.0.1:${authEmulator}`;

admin.initializeApp({ projectId: process.env.FIREBASE_PROJECT_ID || 'demo-project' });
const auth = admin.auth();

(async ()=>{
  try {
    // Delete if exists
    try { const u = await auth.getUserByEmail(email); await auth.deleteUser(u.uid); } catch(e){}
    const u = await auth.createUser({ email, password: pass });
    console.log('Created user', u.uid, email);
    process.exit(0);
  } catch (e) {
    console.error('create_user failed', e);
    process.exit(2);
  }
})();
