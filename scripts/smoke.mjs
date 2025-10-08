// Lightweight post-deploy smoke test
// Uses the global fetch (Node 18+) so no extra dependency required
const site = process.env.SMOKE_URL || "https://<your-staging-hosting-domain>";
try {
  const res = await fetch(site, { redirect: "manual" });
  if (res.status < 200 || res.status >= 400) {
    console.error(`Hosting not healthy: ${res.status}`);
    process.exit(1);
  }
  console.log("Hosting OK:", res.status);
  process.exit(0);
} catch (e) {
  console.error("Smoke test failed:", e.message || e);
  process.exit(2);
}
