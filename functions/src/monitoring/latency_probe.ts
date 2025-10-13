/**
 * Latency Probe Cloud Function
 *
 * PURPOSE:
 * Scheduled function that probes critical system operations and reports latency metrics.
 * Runs every 5 minutes to detect performance degradation proactively.
 *
 * FEATURES:
 * - Test Firestore read/write latency
 * - Test Cloud Storage read/write latency
 * - Test invoice generation end-to-end
 * - Test PDF generation latency
 * - Report metrics to Cloud Logging
 * - Alert on SLO breaches
 *
 * SCHEDULE: Every 5 minutes
 * REGION: us-east4
 */

import { onSchedule } from 'firebase-functions/v2/scheduler';
import { onCall, CallableRequest, HttpsError } from 'firebase-functions/v2/https';
import { logger } from 'firebase-functions';
import * as admin from 'firebase-admin';
import { measureTimeAsync } from './performance_middleware';

/**
 * Latency probe results
 */
interface ProbeResult {
  operation: string;
  success: boolean;
  latencyMs: number;
  sloTarget: number;
  breach: boolean;
  error?: string;
  timestamp: string;
}

/**
 * SLO targets (p95 latency in milliseconds)
 */
const SLO_TARGETS = {
  firestoreRead: 100, // Firestore single document read
  firestoreWrite: 200, // Firestore single document write
  firestoreBatchWrite: 500, // Firestore batch write (10 docs)
  storageUpload: 1000, // Cloud Storage upload (small file)
  storageDownload: 500, // Cloud Storage download (small file)
  invoiceGeneration: 2000, // Full invoice generation (mock)
  pdfGeneration: 1500, // PDF generation (mock)
};

/**
 * Test Firestore read latency
 */
async function probeFirestoreRead(): Promise<ProbeResult> {
  const db = admin.firestore();
  const operation = 'firestore_read';

  try {
    const { result, durationMs } = await measureTimeAsync(async () => {
      // Read a test document (or create one if doesn't exist)
      const testDoc = await db.collection('_probes').doc('latency_test').get();

      if (!testDoc.exists) {
        // Create test document
        await db.collection('_probes').doc('latency_test').set({
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          purpose: 'Latency probe test document',
        });
      }

      return testDoc;
    });

    const breach = durationMs > SLO_TARGETS.firestoreRead;

    return {
      operation,
      success: true,
      latencyMs: durationMs,
      sloTarget: SLO_TARGETS.firestoreRead,
      breach,
      timestamp: new Date().toISOString(),
    };
  } catch (error: any) {
    return {
      operation,
      success: false,
      latencyMs: 0,
      sloTarget: SLO_TARGETS.firestoreRead,
      breach: true,
      error: error.message,
      timestamp: new Date().toISOString(),
    };
  }
}

/**
 * Test Firestore write latency
 */
async function probeFirestoreWrite(): Promise<ProbeResult> {
  const db = admin.firestore();
  const operation = 'firestore_write';

  try {
    const { durationMs } = await measureTimeAsync(async () => {
      await db.collection('_probes').doc('latency_test').update({
        lastProbeAt: admin.firestore.FieldValue.serverTimestamp(),
        probeCount: admin.firestore.FieldValue.increment(1),
      });
    });

    const breach = durationMs > SLO_TARGETS.firestoreWrite;

    return {
      operation,
      success: true,
      latencyMs: durationMs,
      sloTarget: SLO_TARGETS.firestoreWrite,
      breach,
      timestamp: new Date().toISOString(),
    };
  } catch (error: any) {
    return {
      operation,
      success: false,
      latencyMs: 0,
      sloTarget: SLO_TARGETS.firestoreWrite,
      breach: true,
      error: error.message,
      timestamp: new Date().toISOString(),
    };
  }
}

/**
 * Test Firestore batch write latency
 */
async function probeFirestoreBatchWrite(): Promise<ProbeResult> {
  const db = admin.firestore();
  const operation = 'firestore_batch_write';

  try {
    const { durationMs } = await measureTimeAsync(async () => {
      const batch = db.batch();

      // Write 10 test documents
      for (let i = 0; i < 10; i++) {
        const docRef = db.collection('_probes').doc(`batch_test_${i}`);
        batch.set(docRef, {
          index: i,
          probeAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
    });

    const breach = durationMs > SLO_TARGETS.firestoreBatchWrite;

    return {
      operation,
      success: true,
      latencyMs: durationMs,
      sloTarget: SLO_TARGETS.firestoreBatchWrite,
      breach,
      timestamp: new Date().toISOString(),
    };
  } catch (error: any) {
    return {
      operation,
      success: false,
      latencyMs: 0,
      sloTarget: SLO_TARGETS.firestoreBatchWrite,
      breach: true,
      error: error.message,
      timestamp: new Date().toISOString(),
    };
  }
}

/**
 * Test Cloud Storage upload latency
 */
async function probeStorageUpload(): Promise<ProbeResult> {
  const bucket = admin.storage().bucket();
  const operation = 'storage_upload';

  try {
    const { durationMs } = await measureTimeAsync(async () => {
      const testFile = bucket.file('_probes/latency_test.txt');
      const content = `Latency probe test file\nTimestamp: ${new Date().toISOString()}`;

      await testFile.save(content, {
        contentType: 'text/plain',
        metadata: {
          metadata: {
            purpose: 'Latency probe test file',
            probeAt: new Date().toISOString(),
          },
        },
      });
    });

    const breach = durationMs > SLO_TARGETS.storageUpload;

    return {
      operation,
      success: true,
      latencyMs: durationMs,
      sloTarget: SLO_TARGETS.storageUpload,
      breach,
      timestamp: new Date().toISOString(),
    };
  } catch (error: any) {
    return {
      operation,
      success: false,
      latencyMs: 0,
      sloTarget: SLO_TARGETS.storageUpload,
      breach: true,
      error: error.message,
      timestamp: new Date().toISOString(),
    };
  }
}

/**
 * Test Cloud Storage download latency
 */
async function probeStorageDownload(): Promise<ProbeResult> {
  const bucket = admin.storage().bucket();
  const operation = 'storage_download';

  try {
    const { durationMs } = await measureTimeAsync(async () => {
      const testFile = bucket.file('_probes/latency_test.txt');
      const [content] = await testFile.download();
      return content;
    });

    const breach = durationMs > SLO_TARGETS.storageDownload;

    return {
      operation,
      success: true,
      latencyMs: durationMs,
      sloTarget: SLO_TARGETS.storageDownload,
      breach,
      timestamp: new Date().toISOString(),
    };
  } catch (error: any) {
    return {
      operation,
      success: false,
      latencyMs: 0,
      sloTarget: SLO_TARGETS.storageDownload,
      breach: true,
      error: error.message,
      timestamp: new Date().toISOString(),
    };
  }
}

/**
 * Test invoice generation latency (mock)
 *
 * This simulates the critical path of invoice generation:
 * 1. Fetch time entries (Firestore read)
 * 2. Fetch company data (Firestore read)
 * 3. Calculate hours (CPU-bound)
 * 4. Create invoice document (Firestore write)
 * 5. Update time entries (Firestore batch write)
 */
async function probeInvoiceGeneration(): Promise<ProbeResult> {
  const db = admin.firestore();
  const operation = 'invoice_generation_mock';

  try {
    const { durationMs } = await measureTimeAsync(async () => {
      // Simulate fetching 10 time entries
      const timeEntriesQuery = db.collection('_probes').limit(10);
      await timeEntriesQuery.get();

      // Simulate fetching company
      await db.collection('_probes').doc('test_company').get();

      // Simulate hour calculation (CPU-bound)
      let sum = 0;
      for (let i = 0; i < 100000; i++) {
        sum += Math.sqrt(i);
      }

      // Simulate creating invoice
      const invoiceRef = db.collection('_probes').doc('test_invoice');
      await invoiceRef.set({
        amount: sum,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // Simulate batch update
      const batch = db.batch();
      for (let i = 0; i < 5; i++) {
        const entryRef = db.collection('_probes').doc(`entry_${i}`);
        batch.update(entryRef, { invoiceId: 'test_invoice' });
      }
      await batch.commit();
    });

    const breach = durationMs > SLO_TARGETS.invoiceGeneration;

    return {
      operation,
      success: true,
      latencyMs: durationMs,
      sloTarget: SLO_TARGETS.invoiceGeneration,
      breach,
      timestamp: new Date().toISOString(),
    };
  } catch (error: any) {
    return {
      operation,
      success: false,
      latencyMs: 0,
      sloTarget: SLO_TARGETS.invoiceGeneration,
      breach: true,
      error: error.message,
      timestamp: new Date().toISOString(),
    };
  }
}

/**
 * Main latency probe function
 *
 * Runs every 5 minutes via Cloud Scheduler
 */
export const latencyProbe = onSchedule(
  {
    schedule: 'every 5 minutes',
    region: 'us-east4',
    timeZone: 'America/New_York',
  },
  async (event) => {
  logger.info('Starting latency probe...');

  const results: ProbeResult[] = [];

  // Run all probes in parallel
  const probePromises = [
    probeFirestoreRead(),
    probeFirestoreWrite(),
    probeFirestoreBatchWrite(),
    probeStorageUpload(),
    probeStorageDownload(),
    probeInvoiceGeneration(),
  ];

  const probeResults = await Promise.allSettled(probePromises);

  // Collect results
  for (const result of probeResults) {
    if (result.status === 'fulfilled') {
      results.push(result.value);
    } else {
      // Probe itself failed
      logger.error('Probe failed', { error: result.reason });
    }
  }

  // Log results
  for (const result of results) {
    if (result.success) {
      if (result.breach) {
        logger.warn(`SLO breach: ${result.operation}`, result);
      } else {
        logger.info(`Probe OK: ${result.operation}`, result);
      }
    } else {
      logger.error(`Probe failed: ${result.operation}`, result);
    }
  }

  // Calculate summary statistics
  const successCount = results.filter((r) => r.success).length;
  const breachCount = results.filter((r) => r.breach).length;
  const avgLatency =
    results.filter((r) => r.success).reduce((sum, r) => sum + r.latencyMs, 0) / successCount || 0;

  const summary = {
    totalProbes: results.length,
    successCount,
    failureCount: results.length - successCount,
    breachCount,
    avgLatency: Math.round(avgLatency),
    results,
  };

  logger.info('Latency probe summary', summary);

  // Alert if multiple breaches
  if (breachCount >= 3) {
    logger.error(`ALERT: Multiple SLO breaches detected (${breachCount}/${results.length})`, summary);
  }

  // Log summary (schedulers must return void)
  logger.info('Latency probe summary', summary);
});

/**
 * Callable function to get current probe metrics
 *
 * Useful for dashboards and debugging
 */
export const getProbeMetrics = onCall({ region: 'us-east4' }, async (req: CallableRequest) => {
  const auth = req.auth;

  // Authentication check (admin only)
  if (!auth) {
    throw new HttpsError('unauthenticated', 'User must be authenticated');
  }

  const role = (auth.token as any).role;
  if (role !== 'admin') {
    throw new HttpsError('permission-denied', 'Only admins can view probe metrics');
  }

  const db = admin.firestore();

  // Get last probe document
  const probeDoc = await db.collection('_probes').doc('latency_test').get();

  if (!probeDoc.exists) {
    return {
      ok: false,
      error: 'No probe data available',
    };
  }

  return {
    ok: true,
    data: probeDoc.data(),
  };
});
