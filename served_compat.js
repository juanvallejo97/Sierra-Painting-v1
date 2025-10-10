// Expose a global FlutterLoader constructor if runtime provided a loader instance only
(function(){
  try {
    if (typeof FlutterLoader === 'undefined' && window._flutter && window._flutter.loader) {
      // Provide a small wrapper that matches the constructor used by bootstrap
      class _CompatFlutterLoader {
        constructor() {
          // delegate to the runtime-provided loader instance
          this._delegate = window._flutter.loader;
        }
        load(opts) {
          // mirror the loader.load signature
          return this._delegate.load(opts);
        }
      }
      window.FlutterLoader = _CompatFlutterLoader;
    }
  } catch (e) {
    console.warn('compat_loader.js failed to initialize FlutterLoader shim', e);
  }
})();
