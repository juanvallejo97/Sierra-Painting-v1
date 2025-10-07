import puppeteer from 'puppeteer';

const url = process.argv[2] || 'https://to-do-app-ac602--staging-o0wll2hn.web.app';

(async () => {
  const browser = await puppeteer.launch({headless: 'new'});
  const page = await browser.newPage();
  page.on('console', msg => {
    const args = msg.args();
    Promise.all(args.map(a => a.jsonValue().catch(()=>a.toString()))).then(vals => {
      const text = vals.map(v => (typeof v === 'string' ? v : JSON.stringify(v))).join(' ');
      console.log(`[console.${msg.type()}]`, text);
    });
  });
  page.on('pageerror', err => console.log('[pageerror]', err.message));
  page.on('requestfailed', req => console.log('[requestfailed]', req.url(), req.failure()?.errorText));

  console.log('Navigating to', url);
  await page.goto(url, {waitUntil: 'networkidle2', timeout: 60000});

  // Poll diagnostics for up to 20s
  const start = Date.now();
  while (Date.now() - start < 20000) {
    const diag = await page.evaluate(() => ({
      ready: !!window.flutterReady,
      pre: (window.__preInitErrors && window.__preInitErrors.length) ? window.__preInitErrors : [],
      hasFirebase: typeof window.firebase !== 'undefined',
      appCheckFlag: typeof self !== 'undefined' && typeof self.FIREBASE_APPCHECK_DEBUG_TOKEN !== 'undefined' ? self.FIREBASE_APPCHECK_DEBUG_TOKEN : 'undefined',
      readyState: document.readyState
    }));
    console.log('DIAG', JSON.stringify(diag));
    if (diag.ready) break;
    await new Promise(r => setTimeout(r, 1000));
  }

  await browser.close();
})();
