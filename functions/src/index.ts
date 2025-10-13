// Initialize Firebase Admin SDK (required for all functions using Firestore/Auth)
import * as admin from 'firebase-admin';
admin.initializeApp();

// Health check function for smoke tests
export const healthCheck = async (req: any, res: any) => {
  res.status(200).json({
    status: 'ok',
    timestamp: new Date().toISOString(),
    version: process.env.npm_package_version || 'dev',
  });
};

// Auth functions
export { setUserRole } from './auth/setUserRole';

// Timeclock functions
export { clockIn, clockOut } from './timeclock';
export { autoClockOut, adminAutoClockOutOnce } from './auto-clockout';
export { editTimeEntry } from './edit-time-entry';

// Admin functions
export { bulkApproveTimeEntries } from './admin/bulk_approve';

// Billing functions
export { createInvoiceFromTime } from './create-invoice-from-time';
export { generateInvoice } from './billing/generate_invoice';
export { onInvoiceCreated, getInvoicePDFUrl, regenerateInvoicePDF } from './billing/invoice_pdf_functions';

// Monitoring functions
export { latencyProbe, getProbeMetrics } from './monitoring/latency_probe';

// Scheduled cleanup functions
export { dailyCleanup, manualCleanup } from './scheduled/ttl_cleanup';
import * as logger from "firebase-functions/logger";
import { onRequest } from "firebase-functions/v2/https";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { setGlobalOptions } from 'firebase-functions/v2/options';
import { defineString } from "firebase-functions/params";
import fetch from "node-fetch";

setGlobalOptions({ region: 'us-east4' });

// Example API endpoint kept hot via minInstances
export const api = onRequest(
  { region: "us-east4", concurrency: 80, timeoutSeconds: 30, memory: "512MiB", minInstances: 1 },
  async (req: any, res: any) => {
    res.set("Cache-Control", "private, max-age=0, no-store");
    res.status(200).send({ ok: true });
  }
);

// Background worker (no minInstances)
export const taskWorker = onRequest(
  { region: "us-east4", concurrency: 20, timeoutSeconds: 60, memory: "512MiB" },
  async (_req: any, res: any) => {
    // lazy import heavy deps if needed
    res.status(200).send({ worker: "ok" });
  }
);

// Warmup job: ping `api` every 5 minutes to keep JIT warm during traffic dips
const API_URL = defineString("WARM_URL");
export const warm = onSchedule(
  {
    schedule: "every 5 minutes",
    region: "us-east4",
  timeZone: "America/New_York"
  },
  async () => {
    const url = API_URL.value();
    if (!url) return;
    try {
      const r = await fetch(url, { method: "GET", headers: { "User-Agent": "warm-bot" } });
      logger.info("warm ping", { status: r.status });
    } catch (e) {
      logger.warn("warm ping failed", { error: String(e) });
    }
  }
);

// Enable HTTP keep-alive and set sensible timeouts/retries in client SDK
// Emit perf metrics (custom trace) around first API call
