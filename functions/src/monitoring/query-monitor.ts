/**
 * Query Performance Monitor - Cloud Function
 *
 * PURPOSE:
 * Monitors Firestore query performance in production and logs slow queries.
 * Tracks P95 latency over time and alerts on performance degradation.
 *
 * DEPLOYMENT:
 * - Scheduled Cloud Function (runs every 5 minutes via Cloud Scheduler)
 * - Callable HTTPS function for manual monitoring
 * - Logs to Cloud Logging for alerting integration
 *
 * PERFORMANCE THRESHOLDS:
 * - WARN: >500ms
 * - ERROR: >900ms (exceeds cold query target)
 * - CRITICAL: >1500ms (severe degradation)
 *
 * MONITORED QUERIES:
 * - Story B: job_assignments (worker schedule)
 * - Story D: time_entries (admin dashboard)
 * - Story D: invoices (weekly revenue)
 * - Story C: jobs (active jobs)
 * - All collections with composite indexes
 *
 * METRICS STORED:
 * - Collection name
 * - Query description
 * - Latency (ms)
 * - Timestamp
 * - Document count returned
 * - Index used (if available)
 *
 * ALERTING:
 * - Cloud Logging severity: INFO, WARN, ERROR
 * - Integrate with Cloud Monitoring for alert policies
 * - Slack/email alerts via Cloud Functions or Pub/Sub
 */

import { onRequest } from 'firebase-functions/v2/https';
import { onSchedule } from 'firebase-functions/v2/scheduler';
import * as admin from 'firebase-admin';
import * as logger from 'firebase-functions/logger';

interface QueryMetric {
  collection: string;
  queryDescription: string;
  latencyMs: number;
  docCount: number;
  timestamp: admin.firestore.Timestamp;
  companyId?: string;
  threshold: 'OK' | 'WARN' | 'ERROR' | 'CRITICAL';
}

/**
 * Measures query execution time and returns metrics.
 */
async function measureQuery(
  queryFn: () => Promise<admin.firestore.QuerySnapshot>,
  collection: string,
  description: string,
  companyId?: string
): Promise<QueryMetric> {
  const start = Date.now();
  const snapshot = await queryFn();
  const end = Date.now();
  const latencyMs = end - start;

  // Determine threshold
  let threshold: 'OK' | 'WARN' | 'ERROR' | 'CRITICAL' = 'OK';
  if (latencyMs > 1500) {
    threshold = 'CRITICAL';
  } else if (latencyMs > 900) {
    threshold = 'ERROR';
  } else if (latencyMs > 500) {
    threshold = 'WARN';
  }

  return {
    collection,
    queryDescription: description,
    latencyMs,
    docCount: snapshot.size,
    timestamp: admin.firestore.Timestamp.now(),
    companyId,
    threshold,
  };
}

/**
 * Logs query metrics with appropriate severity.
 */
function logMetric(metric: QueryMetric): void {
  const logData = {
    collection: metric.collection,
    query: metric.queryDescription,
    latencyMs: metric.latencyMs,
    docCount: metric.docCount,
    threshold: metric.threshold,
    companyId: metric.companyId || 'N/A',
  };

  switch (metric.threshold) {
    case 'CRITICAL':
      logger.error(`[Query Monitor] CRITICAL: ${metric.queryDescription}`, logData);
      break;
    case 'ERROR':
      logger.error(`[Query Monitor] ERROR: ${metric.queryDescription}`, logData);
      break;
    case 'WARN':
      logger.warn(`[Query Monitor] WARN: ${metric.queryDescription}`, logData);
      break;
    default:
      logger.info(`[Query Monitor] OK: ${metric.queryDescription}`, logData);
  }
}

/**
 * Stores query metrics in Firestore for historical analysis.
 */
async function storeMetric(metric: QueryMetric): Promise<void> {
  await admin.firestore()
    .collection('_monitoring')
    .doc('query_metrics')
    .collection('samples')
    .add(metric);
}

/**
 * Runs performance monitoring for all critical queries.
 */
async function runPerformanceMonitoring(
  companyId: string
): Promise<QueryMetric[]> {
  const db = admin.firestore();
  const metrics: QueryMetric[] = [];

  logger.info(`[Query Monitor] Running performance checks for company: ${companyId}`);

  try {
    // 1. Story B: Worker Schedule - job_assignments
    const metric1 = await measureQuery(
      async () => db.collection('job_assignments')
        .where('companyId', '==', companyId)
        .where('workerId', '==', `worker-${companyId}`) // Use sample worker
        .orderBy('shiftStart', 'desc')
        .limit(20)
        .get(),
      'job_assignments',
      'Worker schedule (recent shifts)',
      companyId
    );
    metrics.push(metric1);
    logMetric(metric1);
    await storeMetric(metric1);

    // 2. Story D: Admin Dashboard - time_entries (pending)
    const metric2 = await measureQuery(
      async () => db.collection('timeEntries')
        .where('companyId', '==', companyId)
        .where('status', '==', 'active')
        .orderBy('clockInAt', 'desc')
        .limit(50)
        .get(),
      'timeEntries',
      'Admin dashboard (pending entries)',
      companyId
    );
    metrics.push(metric2);
    logMetric(metric2);
    await storeMetric(metric2);

    // 3. Story D: Weekly Revenue - invoices (paid)
    const lastWeek = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000);
    const metric3 = await measureQuery(
      async () => db.collection('invoices')
        .where('companyId', '==', companyId)
        .where('status', '==', 'paid_cash')
        .where('paidAt', '>=', lastWeek)
        .orderBy('paidAt', 'desc')
        .get(),
      'invoices',
      'Weekly revenue (paid invoices)',
      companyId
    );
    metrics.push(metric3);
    logMetric(metric3);
    await storeMetric(metric3);

    // 4. Story C: Active Jobs - jobs query
    const metric4 = await measureQuery(
      async () => db.collection('jobs')
        .where('companyId', '==', companyId)
        .where('active', '==', true)
        .orderBy('name', 'asc')
        .get(),
      'jobs',
      'Active jobs (sorted by name)',
      companyId
    );
    metrics.push(metric4);
    logMetric(metric4);
    await storeMetric(metric4);

    // 5. Employees - active employees
    const metric5 = await measureQuery(
      async () => db.collection('employees')
        .where('companyId', '==', companyId)
        .where('status', '==', 'active')
        .orderBy('createdAt', 'desc')
        .get(),
      'employees',
      'Active employees',
      companyId
    );
    metrics.push(metric5);
    logMetric(metric5);
    await storeMetric(metric5);

    logger.info(`[Query Monitor] Completed monitoring for ${companyId}. Metrics: ${metrics.length}`);
  } catch (error) {
    logger.error(`[Query Monitor] Error during monitoring for ${companyId}:`, error);
    throw error;
  }

  return metrics;
}

/**
 * Scheduled Cloud Function - runs every 5 minutes.
 *
 * Monitors query performance for all active companies.
 */
export const queryMonitorScheduled = onSchedule({
  schedule: 'every 5 minutes',
  timeZone: 'America/New_York',
  region: 'us-east4',
}, async (_event) => {
  logger.info('[Query Monitor] Scheduled run starting...');

  try {
    // Get list of active companies
    const companiesSnapshot = await admin.firestore()
      .collection('companies')
      .limit(10) // Monitor first 10 companies per run
      .get();

    if (companiesSnapshot.empty) {
      logger.warn('[Query Monitor] No companies found to monitor');
      return;
    }

    // Run monitoring for each company
    for (const companyDoc of companiesSnapshot.docs) {
      await runPerformanceMonitoring(companyDoc.id);
    }

    logger.info(`[Query Monitor] Scheduled run complete. Monitored ${companiesSnapshot.size} companies.`);
  } catch (error) {
    logger.error('[Query Monitor] Scheduled run failed:', error);
    throw error;
  }
});

/**
 * HTTPS Callable Function - manual monitoring trigger.
 *
 * Useful for on-demand performance checks and testing.
 *
 * @param data.companyId - Company ID to monitor (optional, monitors all if not provided)
 * @returns Query metrics for monitored companies
 */
export const queryMonitorManual = onRequest({
  region: 'us-east4',
  cors: true,
}, async (req, res) => {
  logger.info('[Query Monitor] Manual run triggered');

  try {
    const companyId = req.query.companyId as string | undefined;

    if (companyId) {
      // Monitor specific company
      const metrics = await runPerformanceMonitoring(companyId);
      res.status(200).json({
        success: true,
        company: companyId,
        metrics,
        summary: {
          total: metrics.length,
          ok: metrics.filter((m) => m.threshold === 'OK').length,
          warn: metrics.filter((m) => m.threshold === 'WARN').length,
          error: metrics.filter((m) => m.threshold === 'ERROR').length,
          critical: metrics.filter((m) => m.threshold === 'CRITICAL').length,
        },
      });
    } else {
      // Monitor all companies
      const companiesSnapshot = await admin.firestore()
        .collection('companies')
        .limit(10)
        .get();

      const allMetrics: QueryMetric[] = [];
      for (const companyDoc of companiesSnapshot.docs) {
        const metrics = await runPerformanceMonitoring(companyDoc.id);
        allMetrics.push(...metrics);
      }

      res.status(200).json({
        success: true,
        companiesMonitored: companiesSnapshot.size,
        metrics: allMetrics,
        summary: {
          total: allMetrics.length,
          ok: allMetrics.filter((m) => m.threshold === 'OK').length,
          warn: allMetrics.filter((m) => m.threshold === 'WARN').length,
          error: allMetrics.filter((m) => m.threshold === 'ERROR').length,
          critical: allMetrics.filter((m) => m.threshold === 'CRITICAL').length,
        },
      });
    }
  } catch (error) {
    logger.error('[Query Monitor] Manual run failed:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to run query monitoring',
    });
  }
});

/**
 * Calculates P95 latency from stored metrics.
 *
 * @param collection Collection name
 * @param queryDescription Query description
 * @param hoursBack Number of hours to look back (default: 24)
 * @returns P95 latency in milliseconds
 */
export async function calculateP95Latency(
  collection: string,
  queryDescription: string,
  hoursBack: number = 24
): Promise<number> {
  const cutoff = new Date(Date.now() - hoursBack * 60 * 60 * 1000);

  const snapshot = await admin.firestore()
    .collection('_monitoring')
    .doc('query_metrics')
    .collection('samples')
    .where('collection', '==', collection)
    .where('queryDescription', '==', queryDescription)
    .where('timestamp', '>=', cutoff)
    .get();

  if (snapshot.empty) {
    return 0;
  }

  const latencies = snapshot.docs
    .map((doc) => doc.data().latencyMs as number)
    .sort((a, b) => a - b);

  const p95Index = Math.ceil(latencies.length * 0.95) - 1;
  return latencies[p95Index];
}
