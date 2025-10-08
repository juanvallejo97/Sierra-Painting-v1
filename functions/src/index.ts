// functions/src/index.ts
import {
  onRequest,
  type Request,
  type Response,
  type HttpsOptions,
} from "firebase-functions/v2/https";
import { setGlobalOptions } from "firebase-functions/v2";

// Keep all Functions near your Firestore DB.
setGlobalOptions({ region: "us-east4" });

// Export feature modules (these should also inherit us-east4 from global options)
export { createLead } from "./leads/createLead";

// Small helper
const envInt = (key: string, fallback = 0) => {
  const v = process.env[key];
  const n = v ? Number(v) : NaN;
  return Number.isFinite(n) ? n : fallback;
};

// Public health endpoint (good for uptime checks / load balancer probes)
const healthOpts: HttpsOptions = {
  region: "us-east4",
  invoker: "public",
  timeoutSeconds: 10,
  memory: "128MiB",
  minInstances: envInt("HEALTHCHECK_MIN_INSTANCES", 0),
};

export const healthCheck = onRequest(healthOpts, (req: Request, res: Response) => {
  res.status(200).json({
    status: "ok",
    timestamp: new Date().toISOString(),
    version: process.env.npm_package_version ?? process.env.PACKAGE_VERSION ?? "dev",
    region: "us-east4",
  } as const);
});
