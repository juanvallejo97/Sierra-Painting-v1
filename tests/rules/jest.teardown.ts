// @ts-nocheck
// If you use rules-unit-testing's initializeTestEnvironment, prefer env.cleanup().
// This is a safety net to close any stray client apps.
let safeGetApps: any = null;
let safeDeleteApp: any = null;
try {
  // Dynamic import so this file doesn't cause top-level type errors in non-Firestore test runs
  // eslint-disable-next-line @typescript-eslint/no-var-requires
  const fb = require('firebase/app');
  safeGetApps = fb.getApps;
  safeDeleteApp = fb.deleteApp;
} catch (e) {
  // Not available in this environment, that's fine
}

export default async function globalTeardown() {
  if (safeGetApps && safeDeleteApp) {
    const apps = safeGetApps();
    await Promise.all(apps.map((a: any) => safeDeleteApp(a)));
  }
}
