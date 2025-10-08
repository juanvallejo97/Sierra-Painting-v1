import fetch from "node-fetch";
const site = process.env.SMOKE_URL || process.env.STAGING_URL;
if (!site) throw new Error("SMOKE_URL/STAGING_URL not set");
const res = await fetch(site, { redirect: "follow" });
if (res.status < 200 || res.status >= 400) throw new Error(`Hosting not healthy: ${res.status}`);
const html = await res.text();
if (!html.includes("<title") && !html.includes("flutter")) {
  throw new Error("Unexpected payload (app shell markers missing)");
}
console.log("Hosting OK:", res.status);
