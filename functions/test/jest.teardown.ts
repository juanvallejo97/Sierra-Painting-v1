import { getApps, deleteApp } from 'firebase/app';

export default async function globalTeardown() {
  try {
    const apps = typeof getApps === 'function' ? getApps() : [];
    await Promise.all(apps.map((a: any) => deleteApp(a)));
  } catch {
    // ignore errors during teardown
  }
}
