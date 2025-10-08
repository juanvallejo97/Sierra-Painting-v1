// @ts-nocheck
// Increase timeouts for emulator startup/cleanup
// jest is provided by the test runtime
(global as any).jest?.setTimeout?.(30000);
