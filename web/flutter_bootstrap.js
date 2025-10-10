const swMeta = document.querySelector('meta[name="flutter-service-worker-version"]');
const serviceWorkerVersion = swMeta ? swMeta.content : null;

const loader = new FlutterLoader();
loader.load({
  serviceWorker: serviceWorkerVersion ? { serviceWorkerVersion } : undefined,
  onEntrypointLoaded: async (engineInitializer) => {
    try {
      const appRunner = await engineInitializer.initializeEngine();
      await appRunner.runApp();
    } catch (e) {
      console.error('Flutter bootstrap failed:', e);
    }
  },
});
