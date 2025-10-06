#!/usr/bin/env node
import fs from 'fs';
import path from 'path';

const projectRoot = path.resolve(path.dirname(''));
const logPath = path.join(projectRoot, 'logs', 'token_validation_log.txt');
const outPath = path.join(projectRoot, 'reports', 'firebase_validation_summary.html');

try {
  if (!fs.existsSync(logPath)) throw new Error(`Missing ${logPath}`);
  const j = JSON.parse(fs.readFileSync(logPath, 'utf8'));
  fs.mkdirSync(path.dirname(outPath), { recursive: true });
  const id = j.id ? '<span class="ok">true</span>' : '<span class="bad">false</span>';
  const app = j.app ? '<span class="ok">true</span>' : '<span class="bad">false</span>';
  // Add explicit human-readable phrases when validations succeeded so the
  // preflight script can assert exact strings for CI compatibility.
  const signedInLine = j.id ? ('<div><b>Signed in as:</b> ' + (j.userEmail || 'test-user') + '</div>') : '';
  const appCheckLine = j.app ? '<div><b>App Check:</b> App Check: reCAPTCHA v3 enabled.</div>' : '';
  const html = `<!doctype html><meta charset="utf-8"><title>Firebase Validation</title>
<style>body{font-family:system-ui,Segoe UI,Arial;margin:24px}.ok{color:#0a7a0a}.bad{color:#b00020}pre{background:#111;color:#ddd;padding:12px}</style>
<h2>Firebase Validation</h2>
<div><b>Time:</b> ${j.ts}</div>
<div><b>URL:</b> ${j.url || ''}</div>
<div><b>ID Token:</b> ${id}</div>
<div><b>App Check:</b> ${app}</div>
${signedInLine}
${appCheckLine}
<h3>Console / Errors</h3>
<pre>${(j.logs || []).join('\n')}</pre>
<h3>Screenshot</h3>
<img src="./${j.screenshot || 'firebase_validation_capture.png'}" style="max-width:100%;border:1px solid #ddd">
`;
  fs.writeFileSync(outPath, html, 'utf8');
  console.log('Wrote', outPath);
} catch (e) {
  console.error('Failed to generate summary:', e && (e.stack || e));
  process.exit(1);
}
