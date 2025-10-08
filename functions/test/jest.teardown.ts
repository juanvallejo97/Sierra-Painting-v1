// Ensure any initialized firebase apps are deleted after tests to avoid leaked handles
// Works with firebase/app v9 modular
/* eslint-disable @typescript-eslint/no-var-requires */
const fbApp = require('firebase/app');

export default async function globalTeardown() {
  try {
    const apps = fbApp.getApps ? fbApp.getApps() : [];
    await Promise.all(apps.map((a: any) => fbApp.deleteApp(a)));
  } catch (e) {
    // ignore errors during teardown
    // console.warn('teardown error', e)
  }
}
