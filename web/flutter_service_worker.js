// Kill-switch service worker for Sierra Painting
// Goal: remove any previously cached assets and unregister the SW so clients use network.
// This file is intentionally minimal and temporary.

self.addEventListener('install', (event) => {
  // Activate immediately
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  event.waitUntil((async () => {
    try {
      const keys = await caches.keys();
      await Promise.all(keys.map((k) => caches.delete(k)));
    } catch (e) {
      // ignore
    }
    try {
      // Unregister this SW so future loads are uncontrolled
      await self.registration.unregister();
    } catch (e) {
      // ignore
    }
    try {
      const clientsList = await self.clients.matchAll({ type: 'window', includeUncontrolled: true });
      for (const client of clientsList) {
        // Tell clients we nuked the SW; a navigation will pick up fresh network assets
        client.postMessage({ type: 'SW_KILLED' });
        // Best-effort reload
        client.navigate(client.url);
      }
    } catch (e) {
      // ignore
    }
  })());
});

self.addEventListener('fetch', (event) => {
  // Always pass-through to the network; no caching.
  event.respondWith(fetch(event.request));
});
