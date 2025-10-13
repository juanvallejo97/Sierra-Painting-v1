/**
 * Calculate Hours from Time Entries
 *
 * PURPOSE:
 * Helper functions for calculating billable hours from time entries.
 * Handles duration calculations, break time subtraction, and rounding.
 *
 * FEATURES:
 * - Calculate duration between clock-in and clock-out
 * - Subtract break time from total duration
 * - Round to configurable precision (default: 0.25 hours = 15 minutes)
 * - Group entries by job for invoice generation
 * - Support for different rounding modes (up, down, nearest)
 *
 * ROUNDING POLICY:
 * - Default: Round to nearest 15 minutes (0.25 hours)
 * - Example: 3.12 hours → 3.00 hours
 * - Example: 3.20 hours → 3.25 hours
 * - Example: 3.40 hours → 3.50 hours
 *
 * BREAK TIME:
 * - TODO: Implement break time tracking
 * - Currently breaks are not subtracted (assumed included in clock-out time)
 * - Future: Query breakIds and subtract total break duration
 */

export interface TimeEntry {
  id: string;
  companyId: string;
  workerId: string;
  jobId: string;
  clockIn: any; // Firestore Timestamp
  clockOut: any; // Firestore Timestamp
  breakIds?: string[];
  status: string;
  invoiceId?: string;
}

/**
 * Calculate billable hours for a single time entry
 *
 * @param entry - Time entry with clockIn and clockOut
 * @param roundTo - Rounding precision in hours (default: 0.25 = 15 minutes)
 * @param roundingMode - How to round: 'nearest', 'up', 'down' (default: 'nearest')
 * @returns Billable hours rounded to specified precision
 */
export function calculateEntryHours(
  entry: TimeEntry,
  roundTo: number = 0.25,
  roundingMode: 'nearest' | 'up' | 'down' = 'nearest'
): number {
  // Validate clock times
  if (!entry.clockIn || !entry.clockOut) {
    throw new Error(`Time entry ${entry.id} missing clock-in or clock-out time`);
  }

  // Convert Firestore Timestamps to Date objects
  const clockIn = entry.clockIn.toDate ? entry.clockIn.toDate() : new Date(entry.clockIn);
  const clockOut = entry.clockOut.toDate ? entry.clockOut.toDate() : new Date(entry.clockOut);

  // Calculate duration in milliseconds
  const durationMs = clockOut.getTime() - clockIn.getTime();

  if (durationMs < 0) {
    throw new Error(`Time entry ${entry.id} has clock-out before clock-in`);
  }

  // Convert to hours
  const durationHours = durationMs / (1000 * 60 * 60);

  // TODO: Subtract break time
  // For now, breaks are not implemented

  // Round to specified precision
  return roundHours(durationHours, roundTo, roundingMode);
}

/**
 * Round hours to specified precision
 *
 * @param hours - Raw hours value
 * @param roundTo - Rounding precision (e.g., 0.25 for 15-minute increments)
 * @param mode - Rounding mode: 'nearest', 'up', 'down'
 * @returns Rounded hours
 */
export function roundHours(
  hours: number,
  roundTo: number = 0.25,
  mode: 'nearest' | 'up' | 'down' = 'nearest'
): number {
  if (roundTo <= 0) {
    throw new Error('roundTo must be positive');
  }

  switch (mode) {
    case 'up':
      return Math.ceil(hours / roundTo) * roundTo;
    case 'down':
      return Math.floor(hours / roundTo) * roundTo;
    case 'nearest':
    default:
      return Math.round(hours / roundTo) * roundTo;
  }
}

/**
 * Calculate total billable hours for multiple time entries
 *
 * @param entries - Array of time entries
 * @param roundTo - Rounding precision
 * @param roundingMode - Rounding mode
 * @returns Total hours (sum of individual rounded hours)
 */
export function calculateHours(
  entries: TimeEntry[],
  roundTo: number = 0.25,
  roundingMode: 'nearest' | 'up' | 'down' = 'nearest'
): number {
  if (!entries || entries.length === 0) {
    return 0;
  }

  // Calculate hours for each entry and sum
  const totalHours = entries.reduce((total, entry) => {
    const entryHours = calculateEntryHours(entry, roundTo, roundingMode);
    return total + entryHours;
  }, 0);

  return totalHours;
}

/**
 * Group time entries by job ID
 *
 * Useful for generating invoices with line items per job.
 *
 * @param entries - Array of time entries
 * @returns Object mapping jobId to array of time entries
 */
export function groupEntriesByJob(
  entries: TimeEntry[]
): Record<string, TimeEntry[]> {
  const grouped: Record<string, TimeEntry[]> = {};

  for (const entry of entries) {
    const jobId = entry.jobId;
    if (!grouped[jobId]) {
      grouped[jobId] = [];
    }
    grouped[jobId].push(entry);
  }

  return grouped;
}

/**
 * Group time entries by worker ID
 *
 * Useful for generating payroll reports or worker-specific invoices.
 *
 * @param entries - Array of time entries
 * @returns Object mapping workerId to array of time entries
 */
export function groupEntriesByWorker(
  entries: TimeEntry[]
): Record<string, TimeEntry[]> {
  const grouped: Record<string, TimeEntry[]> = {};

  for (const entry of entries) {
    const workerId = entry.workerId;
    if (!grouped[workerId]) {
      grouped[workerId] = [];
    }
    grouped[workerId].push(entry);
  }

  return grouped;
}

/**
 * Calculate hours grouped by job
 *
 * Returns total hours per job.
 *
 * @param entries - Array of time entries
 * @param roundTo - Rounding precision
 * @param roundingMode - Rounding mode
 * @returns Object mapping jobId to total hours
 */
export function calculateHoursByJob(
  entries: TimeEntry[],
  roundTo: number = 0.25,
  roundingMode: 'nearest' | 'up' | 'down' = 'nearest'
): Record<string, number> {
  const grouped = groupEntriesByJob(entries);
  const hoursByJob: Record<string, number> = {};

  for (const [jobId, jobEntries] of Object.entries(grouped)) {
    hoursByJob[jobId] = calculateHours(jobEntries, roundTo, roundingMode);
  }

  return hoursByJob;
}

/**
 * Calculate hours grouped by worker
 *
 * Returns total hours per worker.
 *
 * @param entries - Array of time entries
 * @param roundTo - Rounding precision
 * @param roundingMode - Rounding mode
 * @returns Object mapping workerId to total hours
 */
export function calculateHoursByWorker(
  entries: TimeEntry[],
  roundTo: number = 0.25,
  roundingMode: 'nearest' | 'up' | 'down' = 'nearest'
): Record<string, number> {
  const grouped = groupEntriesByWorker(entries);
  const hoursByWorker: Record<string, number> = {};

  for (const [workerId, workerEntries] of Object.entries(grouped)) {
    hoursByWorker[workerId] = calculateHours(workerEntries, roundTo, roundingMode);
  }

  return hoursByWorker;
}

/**
 * Validate time entry for billing
 *
 * Checks that entry is ready to be invoiced:
 * - Has clock-in and clock-out times
 * - Is approved
 * - Not already invoiced
 * - Clock-out is after clock-in
 *
 * @param entry - Time entry to validate
 * @returns Error message if invalid, null if valid
 */
export function validateTimeEntryForBilling(entry: TimeEntry): string | null {
  if (!entry.clockIn) {
    return `Entry ${entry.id} missing clock-in time`;
  }

  if (!entry.clockOut) {
    return `Entry ${entry.id} missing clock-out time (still active)`;
  }

  if (entry.status !== 'approved') {
    return `Entry ${entry.id} not approved (status: ${entry.status})`;
  }

  if (entry.invoiceId) {
    return `Entry ${entry.id} already invoiced (invoice: ${entry.invoiceId})`;
  }

  // Validate clock times
  const clockIn = entry.clockIn.toDate ? entry.clockIn.toDate() : new Date(entry.clockIn);
  const clockOut = entry.clockOut.toDate ? entry.clockOut.toDate() : new Date(entry.clockOut);

  if (clockOut <= clockIn) {
    return `Entry ${entry.id} has invalid times (clock-out not after clock-in)`;
  }

  return null; // Valid
}

/**
 * Validate all time entries for billing
 *
 * @param entries - Array of time entries
 * @returns Array of error messages (empty if all valid)
 */
export function validateTimeEntriesForBilling(entries: TimeEntry[]): string[] {
  const errors: string[] = [];

  for (const entry of entries) {
    const error = validateTimeEntryForBilling(entry);
    if (error) {
      errors.push(error);
    }
  }

  return errors;
}
