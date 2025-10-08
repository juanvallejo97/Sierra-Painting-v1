import * as logger from "firebase-functions/logger";
import { onRequest } from "firebase-functions/v2/https";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { defineString } from "firebase-functions/params";
import fetch from "node-fetch";
// Example API endpoint kept hot via minInstances
export const api = onRequest({ region: "us-central1", concurrency: 80, timeoutSeconds: 30, memory: "512MiB", minInstances: 1 }, async (req, res) => {
    res.set("Cache-Control", "private, max-age=0, no-store");
    res.status(200).send({ ok: true });
});
// Background worker (no minInstances)
export const taskWorker = onRequest({ region: "us-central1", concurrency: 20, timeoutSeconds: 60, memory: "512MiB" }, async (_req, res) => {
    // lazy import heavy deps if needed
    res.status(200).send({ worker: "ok" });
});
// Warmup job: ping `api` every 5 minutes to keep JIT warm during traffic dips
const API_URL = defineString("WARM_URL");
export const warm = onSchedule({
    schedule: "every 5 minutes",
    region: "us-central1",
    timeZone: "Etc/UTC"
}, async () => {
    const url = API_URL.value();
    if (!url)
        return;
    try {
        const r = await fetch(url, { method: "GET", headers: { "User-Agent": "warm-bot" } });
        logger.info("warm ping", { status: r.status });
    }
    catch (e) {
        logger.warn("warm ping failed", { error: String(e) });
    }
});
