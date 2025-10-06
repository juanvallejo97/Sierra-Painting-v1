#!/usr/bin/env node
// scripts/validate_tokens.js
// Robust validator: spawn static server, probe tokens page, launch Puppeteer, capture ID + App Check tokens.
import { exec } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import net from 'node:net';
import puppeteer from 'puppeteer';
import { fileURLToPath } from 'node:url';
import { requireKeys } from './loadEnv.mjs';

const sleep = (ms) => new Promise(r => setTimeout(r, ms));

async function freePort(preferred = 5000) {
  const tryListen = (p) => new Promise((resolve, reject) => {
    const s = net.createServer().once('error', reject).once('listening', () => s.close(() => resolve(p))).listen(p, '127.0.0.1');
  });
  try { return await tryListen(preferred); } catch { // fallback
    return await new Promise((resolve) => {
      const s = net.createServer().listen(0, () => { const p = s.address().port; s.close(() => resolve(p)); });
    });
  }
}

async function probe(u, timeoutMs = 15000) {
  const start = Date.now();
  while (Date.now() - start < timeoutMs) {
    try {
      const res = await fetch(u, { redirect: 'manual', cache: 'no-store' });
      if (res.status === 200) return u;
      if ([301,302,307,308].includes(res.status)) {
        const loc = res.headers.get('location');
        if (loc) {
          const to = new URL(loc, u).toString();
          const r2 = await fetch(to, { cache: 'no-store' });
          if (r2.status === 200) return to;
        }
      }
    } catch (e) { /* ignore */ }
    await sleep(300);
  }
  return null;
}

function killProc(proc) {
  if (!proc || proc.killed) return;
  try {
    if (process.platform === 'win32') {
      exec(`taskkill /pid ${proc.pid} /f /t`);
    } else proc.kill('SIGTERM');
  } catch (e) { /* ignore */ }
}

(async () => {
  try {
    const __dirname = path.dirname(fileURLToPath(import.meta.url));
    const projectRoot = path.resolve(__dirname, '..');
    fs.mkdirSync(path.join(projectRoot, 'logs'), { recursive: true });
    fs.mkdirSync(path.join(projectRoot, 'reports'), { recursive: true });

    // Load .env when present and require keys for local runs
    // In CI, secrets are expected to be present as env vars
    if (!process.env.CI) requireKeys(['TEST_EMAIL','TEST_PASS']);

    const getArg = (k) => {
      const m = process.argv.find(a => a.startsWith(`--${k}=`));
      return m ? m.split('=')[1] : undefined;
    };

    const explicitPort = Number(getArg('port') || process.env.SERVE_PORT);
    const rawRecaptcha = getArg('recaptcha') || process.env.RECAPTCHA_SITE_KEY;
    const normalize = (v) => { if (typeof v === 'undefined' || v === null) return v; let s = String(v).trim(); s = s.replace(/^recaptcha:\s*/i, ''); s = s.replace(/^['"]|['"]$/g, ''); return s.trim(); };
    const recaptcha = normalize(rawRecaptcha);
    const rawHeadless = getArg('headless') || process.env.CI_HEADLESS || process.env.PUPPETEER_HEADLESS;
    const headless = rawHeadless || 'new';
    const appCheckDebug = getArg('appcheck-debug') || process.env.APP_CHECK_DEBUG_TOKEN;

    // Prefer system chrome if provided via env var
    const execPath = process.env.PUPPETEER_EXECUTABLE_PATH || process.env.CHROME_PATH || undefined;

    // Determine a port to use or reuse
    let port = explicitPort && explicitPort > 0 ? explicitPort : null;
    const isUp = async (p) => { try { const r = await fetch(`http://localhost:${p}/`, { cache: 'no-store' }); return r.ok; } catch { return false; } };
    if (!port) { if (await isUp(5000)) port = 5000; else if (await isUp(3000)) port = 3000; }
    if (!port) port = await freePort(5000);

    const spawnPort = (Number.isFinite(explicitPort) && explicitPort > 0) ? explicitPort : port;
    const serveCmd = `npx serve . -l ${spawnPort}`;
    console.log('Spawning static server:', serveCmd);
    const serveProc = exec(serveCmd, { cwd: projectRoot, windowsHide: true });
    let serveOut = '';
    serveProc.stdout?.on('data', c => { serveOut += String(c); process.stdout.write(String(c)); });
    serveProc.stderr?.on('data', c => { serveOut += String(c); process.stdout.write(String(c)); });
    serveProc.on('exit', (c,s) => console.log('serve exited', c, s));
    await sleep(900);
    try {
      const m = serveOut.match(/localhost:(\d{2,5})/) || serveOut.match(/127\.0\.0\.1:(\d{2,5})/);
      if (m && m[1]) port = Number(m[1]); else if (spawnPort !== port) port = spawnPort;
    } catch(e) { }

    // Probe candidate paths
    const candidates = [
      `http://localhost:${port}/scripts/tokens.html`,
      `http://127.0.0.1:${port}/scripts/tokens.html`,
      `http://localhost:${port}/scripts/tokens`,
      `http://localhost:${port}/tokens.html`,
    ];
    let pageUrl = null;
    for (const c of candidates) {
      const ok = await probe(c, 8000);
      if (ok) { pageUrl = ok; break; }
    }
    if (!pageUrl) {
      killProc(serveProc);
      const out = path.join(projectRoot, 'logs', 'token_validation_log.txt');
      fs.writeFileSync(out, JSON.stringify({ ts: new Date().toISOString(), error: `Timed out waiting for tokens page on port ${port}`, serveOut }, null, 2));
      console.error('Timed out waiting for tokens page');
      process.exit(1);
    }

    // Append query parameters for credentials/recaptcha/debug
    const urlObj = new URL(pageUrl);
    const params = urlObj.searchParams;
  if (process.env.TEST_EMAIL) params.set('email', normalize(process.env.TEST_EMAIL));
  if (process.env.TEST_PASS) params.set('pass', normalize(process.env.TEST_PASS));
  // Only pass a recaptcha site key to the page when not running emulators
  // and when an explicit App Check debug token is NOT being injected.
  const usingEmulator = (process.env.USE_EMULATORS || '').toLowerCase() === 'true' || false;
  if (recaptcha && !usingEmulator && typeof appCheckDebug === 'undefined') params.set('recaptcha', recaptcha);
    if (getArg('debug') === 'true' || getArg('debug') === '1') params.set('debug', 'true');
    pageUrl = urlObj.toString();
    console.log('Resolved pageUrl=', pageUrl);

    // Launch puppeteer with preferred options
    const launchOpts = { headless: headless, args: ['--no-sandbox', '--disable-setuid-sandbox'] };
    if (execPath) launchOpts.executablePath = execPath;
    console.log('Launching Puppeteer', JSON.stringify({ headless: launchOpts.headless, executablePath: launchOpts.executablePath ? '[provided]' : '[default]' }));
    const browser = await puppeteer.launch(launchOpts);
    const page = await browser.newPage();
    const consoleLines = [];
    page.on('console', m => { try { consoleLines.push(m.text()); } catch(e){} });
    // Capture network request failures and responses for debugging
    const netLogs = [];
    page.on('requestfailed', req => {
      try {
        const r = req;
        netLogs.push({ type: 'requestfailed', url: r.url(), method: r.method(), failure: r.failure() ? r.failure().errorText : null });
      } catch (e) {}
    });
    page.on('response', async res => {
      try {
        const req = res.request();
        netLogs.push({ type: 'response', url: res.url(), status: res.status(), method: req.method() });
      } catch (e) {}
    });

    // Inject App Check debug token before any script runs, if provided
    if (typeof appCheckDebug !== 'undefined' && appCheckDebug !== null) {
      const dbgVal = (appCheckDebug === 'true') ? true : String(appCheckDebug);
      try {
        await page.evaluateOnNewDocument((v) => { try { self.FIREBASE_APPCHECK_DEBUG_TOKEN = v; } catch(e){}; try { localStorage.setItem('FIREBASE_APPCHECK_DEBUG_TOKEN', String(v)); } catch(e){} }, dbgVal);
        console.log('Injected App Check debug token into page preload');
      } catch (e) { console.warn('Failed to inject debug token', e); }
    }

    await page.goto(pageUrl, { waitUntil: 'networkidle0' }).catch(e => { /* continue to polling */ });

    // Exponential backoff polling for #out text with max ~20s
    let content = '';
    let got = false;
    const maxTime = 20000; // 20s
    const start = Date.now();
    let delay = 200;
    while (Date.now() - start < maxTime) {
      try {
        content = await page.$eval('#out', el => el.innerText).catch(() => '');
        if (/ID Token|App Check Token|ERROR:/i.test(content)) { got = true; break; }
      } catch (e) { /* ignore */ }
      await sleep(delay);
      delay = Math.min(2000, Math.round(delay * 1.8));
    }

  // Capture screenshot and write log
    const shotPath = path.join(projectRoot, 'reports', 'firebase_validation_capture.png');
    await page.screenshot({ path: shotPath, fullPage: true }).catch(() => {});

  const consoleText = consoleLines.join('\n');
  const pageText = await page.content().catch(() => '');
  const idFound = /ID Token/i.test(content) || /Signed in as/i.test(consoleText) || /Signed in as/i.test(pageText);
  const appFound = /App Check Token/i.test(content) || /App Check: reCAPTCHA v3 enabled/i.test(consoleText) || /App Check: reCAPTCHA v3 enabled/i.test(pageText);

    const outLog = {
      ts: new Date().toISOString(),
      url: pageUrl,
      net: netLogs.slice(-200),
      id: !!idFound,
      app: !!appFound,
      logs: consoleLines.slice(-50),
      snippet: content ? content.slice(0, 1000) : '',
      screenshot: path.relative(projectRoot, shotPath),
    };
    const outPath = path.join(projectRoot, 'logs', 'token_validation_log.txt');
    fs.writeFileSync(outPath, JSON.stringify(outLog, null, 2));

    await browser.close();
    killProc(serveProc);

    console.log('Validation summary:', JSON.stringify({ id: outLog.id, app: outLog.app }));
    if (outLog.id && outLog.app) process.exit(0);
    process.exit(2);
  } catch (err) {
    try { fs.mkdirSync('logs', { recursive: true }); fs.writeFileSync('logs/token_validation_log.txt', JSON.stringify({ ts: new Date().toISOString(), error: String(err) }, null, 2)); } catch(e){}
    console.error('Validator error', err && (err.stack || err));
    process.exit(1);
  }
})()
;
