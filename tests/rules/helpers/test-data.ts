/**
 * Test Data Fixture Generators
 *
 * PURPOSE:
 * Provides factory functions for generating realistic test data for all Firestore collections.
 * Ensures consistent data structure across test files and reduces boilerplate.
 *
 * USAGE:
 * ```typescript
 * import { createJob, createInvoice, createTimeEntry } from './helpers/test-data';
 *
 * const job = createJob('company-a', { name: 'Paint House' });
 * const invoice = createInvoice('company-a', 'customer-1', { amount: 1500 });
 * ```
 *
 * CONVENTIONS:
 * - All fixtures include required companyId for multi-tenant isolation
 * - Timestamps use new Date() for current time (can be overridden)
 * - IDs are generated with predictable patterns for testing
 * - All fixtures include sensible defaults
 * - Partial overrides supported via optional parameters
 *
 * FIXTURE TYPES:
 * - Companies: Organization/tenant documents
 * - Jobs: Painting job sites with geolocation
 * - Customers: Customer contact information
 * - Invoices: Billing invoices with line items
 * - Estimates: Cost estimates/quotes
 * - Time Entries: Worker time tracking (function-write only)
 * - Clock Events: Append-only clock in/out events
 * - Assignments: Job assignments for workers
 * - Employees: Worker/staff profiles
 * - Users: User profile documents
 */

/**
 * Generates a unique test ID with prefix.
 *
 * @param prefix ID prefix (e.g., 'job', 'invoice')
 * @param suffix Optional suffix (defaults to timestamp)
 * @returns Unique test ID
 */
export function generateTestId(prefix: string, suffix?: string): string {
  return `${prefix}-${suffix || Date.now()}`;
}

/**
 * Company fixture generator.
 *
 * @param companyId Company identifier
 * @param overrides Optional field overrides
 * @returns Company document data
 */
export function createCompany(
  companyId: string,
  overrides: Partial<{
    name: string;
    timezone: string;
    address: string;
    phone: string;
    email: string;
    createdAt: Date;
    updatedAt: Date;
  }> = {}
) {
  return {
    name: overrides.name || `${companyId} Company`,
    timezone: overrides.timezone || 'America/New_York',
    address: overrides.address || '123 Main St, San Francisco, CA 94102',
    phone: overrides.phone || '+14155551234',
    email: overrides.email || `admin@${companyId}.test`,
    createdAt: overrides.createdAt || new Date(),
    updatedAt: overrides.updatedAt || new Date(),
  };
}

/**
 * Job fixture generator with geolocation.
 *
 * @param companyId Company identifier
 * @param overrides Optional field overrides
 * @returns Job document data
 */
export function createJob(
  companyId: string,
  overrides: Partial<{
    name: string;
    customerId: string;
    estimateId: string;
    location: any;
    lat: number;
    lng: number;
    radiusM: number;
    address: string;
    status: string;
    active: boolean;
    geofenceEnabled: boolean;
    assignedWorkerIds: string[];
    startDate: Date;
    endDate: Date;
    notes: string;
    estimatedCost: number;
    actualCost: number;
    createdAt: Date;
    updatedAt: Date;
  }> = {}
) {
  const lat = overrides.lat || 37.7749;
  const lng = overrides.lng || -122.4194;
  const radiusM = overrides.radiusM || 150;
  const address = overrides.address || '456 Oak Ave, San Francisco, CA';

  return {
    companyId,
    name: overrides.name || 'Paint Job',
    customerId: overrides.customerId,
    estimateId: overrides.estimateId,
    location: overrides.location || {
      latitude: lat,
      longitude: lng,
      address,
      environment: 'suburban',
    },
    // Top-level fields for Cloud Functions
    lat,
    lng,
    radiusM,
    address,
    status: overrides.status || 'pending',
    active: overrides.active !== undefined ? overrides.active : true,
    geofenceEnabled:
      overrides.geofenceEnabled !== undefined ? overrides.geofenceEnabled : true,
    assignedWorkerIds: overrides.assignedWorkerIds || [],
    startDate: overrides.startDate,
    endDate: overrides.endDate,
    notes: overrides.notes,
    estimatedCost: overrides.estimatedCost,
    actualCost: overrides.actualCost,
    createdAt: overrides.createdAt || new Date(),
    updatedAt: overrides.updatedAt || new Date(),
  };
}

/**
 * Customer fixture generator.
 *
 * @param companyId Company identifier
 * @param overrides Optional field overrides
 * @returns Customer document data
 */
export function createCustomer(
  companyId: string,
  overrides: Partial<{
    name: string;
    email: string;
    phone: string;
    address: string;
    notes: string;
    createdAt: Date;
    updatedAt: Date;
  }> = {}
) {
  return {
    companyId,
    name: overrides.name || 'John Doe',
    email: overrides.email || 'john.doe@example.com',
    phone: overrides.phone || '+14155559876',
    address: overrides.address || '789 Elm St, San Francisco, CA',
    notes: overrides.notes,
    createdAt: overrides.createdAt || new Date(),
    updatedAt: overrides.updatedAt || new Date(),
  };
}

/**
 * Invoice item fixture generator.
 *
 * @param overrides Optional field overrides
 * @returns Invoice item data
 */
export function createInvoiceItem(
  overrides: Partial<{
    description: string;
    quantity: number;
    unitPrice: number;
    discount: number;
  }> = {}
) {
  return {
    description: overrides.description || 'Painting services',
    quantity: overrides.quantity || 1,
    unitPrice: overrides.unitPrice || 1000,
    discount: overrides.discount,
  };
}

/**
 * Invoice fixture generator.
 *
 * @param companyId Company identifier
 * @param customerId Customer identifier
 * @param overrides Optional field overrides
 * @returns Invoice document data
 */
export function createInvoice(
  companyId: string,
  customerId: string,
  overrides: Partial<{
    customerName: string;
    estimateId: string;
    jobId: string;
    status: string;
    number: string;
    amount: number;
    subtotal: number;
    tax: number;
    currency: string;
    items: any[];
    notes: string;
    dueDate: Date;
    paidAt: Date;
    createdAt: Date;
    updatedAt: Date;
  }> = {}
) {
  const subtotal = overrides.subtotal || overrides.amount || 1000;
  const tax = overrides.tax || subtotal * 0.08; // 8% tax
  const amount = overrides.amount || subtotal + tax;

  return {
    companyId,
    customerId,
    customerName: overrides.customerName || 'John Doe',
    estimateId: overrides.estimateId,
    jobId: overrides.jobId,
    status: overrides.status || 'draft',
    number: overrides.number || `INV-${new Date().getFullYear()}${(new Date().getMonth() + 1).toString().padStart(2, '0')}-0001`,
    amount,
    subtotal,
    tax,
    currency: overrides.currency || 'USD',
    items: overrides.items || [createInvoiceItem()],
    notes: overrides.notes,
    dueDate: overrides.dueDate || new Date(Date.now() + 30 * 24 * 60 * 60 * 1000), // 30 days from now
    paidAt: overrides.paidAt,
    createdAt: overrides.createdAt || new Date(),
    updatedAt: overrides.updatedAt || new Date(),
  };
}

/**
 * Estimate fixture generator.
 *
 * @param companyId Company identifier
 * @param customerId Customer identifier
 * @param overrides Optional field overrides
 * @returns Estimate document data
 */
export function createEstimate(
  companyId: string,
  customerId: string,
  overrides: Partial<{
    status: string;
    amount: number;
    items: any[];
    notes: string;
    validUntil: Date;
    createdAt: Date;
    updatedAt: Date;
  }> = {}
) {
  return {
    companyId,
    customerId,
    status: overrides.status || 'draft',
    amount: overrides.amount || 1500,
    items: overrides.items || [createInvoiceItem({ description: 'Estimate item' })],
    notes: overrides.notes,
    validUntil: overrides.validUntil || new Date(Date.now() + 90 * 24 * 60 * 60 * 1000), // 90 days
    createdAt: overrides.createdAt || new Date(),
    updatedAt: overrides.updatedAt || new Date(),
  };
}

/**
 * Time entry fixture generator (function-write only).
 *
 * @param companyId Company identifier
 * @param userId Worker user ID
 * @param jobId Job identifier
 * @param overrides Optional field overrides
 * @returns Time entry document data
 */
export function createTimeEntry(
  companyId: string,
  userId: string,
  jobId: string,
  overrides: Partial<{
    status: string;
    clockIn: Date;
    clockOut: Date;
    clockInLat: number;
    clockInLng: number;
    clockOutLat: number;
    clockOutLng: number;
    clockInAccuracy: number;
    clockOutAccuracy: number;
    flagged: boolean;
    flagReasons: string[];
    notes: string;
    createdAt: Date;
    updatedAt: Date;
  }> = {}
) {
  return {
    companyId,
    userId,
    jobId,
    status: overrides.status || 'active',
    clockIn: overrides.clockIn || new Date(),
    clockOut: overrides.clockOut,
    clockInLat: overrides.clockInLat || 37.7749,
    clockInLng: overrides.clockInLng || -122.4194,
    clockOutLat: overrides.clockOutLat,
    clockOutLng: overrides.clockOutLng,
    clockInAccuracy: overrides.clockInAccuracy || 10,
    clockOutAccuracy: overrides.clockOutAccuracy,
    flagged: overrides.flagged || false,
    flagReasons: overrides.flagReasons || [],
    notes: overrides.notes,
    createdAt: overrides.createdAt || new Date(),
    updatedAt: overrides.updatedAt || new Date(),
  };
}

/**
 * Clock event fixture generator (append-only).
 *
 * @param companyId Company identifier
 * @param userId Worker user ID
 * @param jobId Job identifier
 * @param type Event type ('in' or 'out')
 * @param overrides Optional field overrides
 * @returns Clock event document data
 */
export function createClockEvent(
  companyId: string,
  userId: string,
  jobId: string,
  type: 'in' | 'out',
  overrides: Partial<{
    clientEventId: string;
    timestamp: Date;
    lat: number;
    lng: number;
    accuracy: number;
    offline: boolean;
    notes: string;
  }> = {}
) {
  return {
    companyId,
    userId,
    jobId,
    type,
    clientEventId: overrides.clientEventId || generateTestId('event'),
    timestamp: overrides.timestamp || new Date(),
    lat: overrides.lat || 37.7749,
    lng: overrides.lng || -122.4194,
    accuracy: overrides.accuracy || 10,
    offline: overrides.offline || false,
    notes: overrides.notes,
  };
}

/**
 * Assignment fixture generator.
 *
 * @param companyId Company identifier
 * @param userId Worker user ID
 * @param jobId Job identifier
 * @param overrides Optional field overrides
 * @returns Assignment document data
 */
export function createAssignment(
  companyId: string,
  userId: string,
  jobId: string,
  overrides: Partial<{
    active: boolean;
    startDate: Date;
    endDate: Date;
    role: string;
    notes: string;
    createdAt: Date;
    updatedAt: Date;
  }> = {}
) {
  return {
    companyId,
    userId,
    jobId,
    active: overrides.active !== undefined ? overrides.active : true,
    startDate: overrides.startDate || new Date(),
    endDate: overrides.endDate,
    role: overrides.role || 'worker',
    notes: overrides.notes,
    createdAt: overrides.createdAt || new Date(),
    updatedAt: overrides.updatedAt || new Date(),
  };
}

/**
 * Job assignment fixture generator (Story B: Worker Schedule).
 *
 * @param companyId Company identifier
 * @param workerId Worker user ID
 * @param jobId Job identifier
 * @param overrides Optional field overrides
 * @returns Job assignment document data
 */
export function createJobAssignment(
  companyId: string,
  workerId: string,
  jobId: string,
  overrides: Partial<{
    shiftStart: Date;
    shiftEnd: Date;
    notes: string;
    createdAt: Date;
  }> = {}
) {
  return {
    companyId,
    workerId,
    jobId,
    shiftStart: overrides.shiftStart || new Date(),
    shiftEnd: overrides.shiftEnd || new Date(Date.now() + 8 * 60 * 60 * 1000), // 8 hours
    notes: overrides.notes,
    createdAt: overrides.createdAt || new Date(),
  };
}

/**
 * Employee fixture generator.
 *
 * @param companyId Company identifier
 * @param overrides Optional field overrides
 * @returns Employee document data
 */
export function createEmployee(
  companyId: string,
  overrides: Partial<{
    name: string;
    email: string;
    phone: string;
    role: string;
    status: string;
    hourlyRate: number;
    createdAt: Date;
    updatedAt: Date;
  }> = {}
) {
  return {
    companyId,
    name: overrides.name || 'Worker Name',
    email: overrides.email || 'worker@example.com',
    phone: overrides.phone || '+14155551234',
    role: overrides.role || 'worker',
    status: overrides.status || 'active',
    hourlyRate: overrides.hourlyRate || 25,
    createdAt: overrides.createdAt || new Date(),
    updatedAt: overrides.updatedAt || new Date(),
  };
}

/**
 * User profile fixture generator.
 *
 * @param uid User identifier
 * @param overrides Optional field overrides
 * @returns User document data
 */
export function createUser(
  uid: string,
  overrides: Partial<{
    displayName: string;
    email: string;
    photoURL: string;
    phone: string;
    createdAt: Date;
    updatedAt: Date;
  }> = {}
) {
  return {
    displayName: overrides.displayName || `User ${uid}`,
    email: overrides.email || `${uid}@example.com`,
    photoURL: overrides.photoURL,
    phone: overrides.phone,
    createdAt: overrides.createdAt || new Date(),
    updatedAt: overrides.updatedAt || new Date(),
  };
}

/**
 * Creates a batch of related test data for a complete scenario.
 *
 * @param companyId Company identifier
 * @param userId User identifier
 * @returns Object with related fixtures
 *
 * @example
 * const scenario = createTestScenario('company-a', 'worker-123');
 * await seedDocument('companies', 'company-a', scenario.company);
 * await seedDocument('jobs', 'job-1', scenario.job);
 * await seedDocument('customers', 'customer-1', scenario.customer);
 */
export function createTestScenario(companyId: string, userId: string) {
  const customerId = `customer-${companyId}`;
  const jobId = `job-${companyId}`;

  return {
    company: createCompany(companyId),
    user: createUser(userId, { email: `${userId}@${companyId}.test` }),
    employee: createEmployee(companyId, { email: `${userId}@${companyId}.test` }),
    customer: createCustomer(companyId, { name: 'Test Customer' }),
    job: createJob(companyId, { customerId, name: 'Test Paint Job' }),
    assignment: createAssignment(companyId, userId, jobId),
    jobAssignment: createJobAssignment(companyId, userId, jobId),
    timeEntry: createTimeEntry(companyId, userId, jobId),
    clockEvent: createClockEvent(companyId, userId, jobId, 'in'),
    invoice: createInvoice(companyId, customerId, {
      customerName: 'Test Customer',
      jobId,
    }),
    estimate: createEstimate(companyId, customerId),
  };
}

/**
 * Date utilities for testing time-based queries.
 */
export const DateHelpers = {
  /**
   * Get date N days ago.
   */
  daysAgo(days: number): Date {
    return new Date(Date.now() - days * 24 * 60 * 60 * 1000);
  },

  /**
   * Get date N days from now.
   */
  daysFromNow(days: number): Date {
    return new Date(Date.now() + days * 24 * 60 * 60 * 1000);
  },

  /**
   * Get start of today (midnight).
   */
  startOfToday(): Date {
    const now = new Date();
    return new Date(now.getFullYear(), now.getMonth(), now.getDate(), 0, 0, 0);
  },

  /**
   * Get end of today (23:59:59).
   */
  endOfToday(): Date {
    const now = new Date();
    return new Date(now.getFullYear(), now.getMonth(), now.getDate(), 23, 59, 59);
  },

  /**
   * Get start of this week (Monday).
   */
  startOfWeek(): Date {
    const now = new Date();
    const day = now.getDay();
    const diff = day === 0 ? 6 : day - 1; // Monday is 1, Sunday is 0
    const monday = new Date(now);
    monday.setDate(now.getDate() - diff);
    monday.setHours(0, 0, 0, 0);
    return monday;
  },

  /**
   * Get end of this week (Sunday).
   */
  endOfWeek(): Date {
    const start = DateHelpers.startOfWeek();
    const sunday = new Date(start);
    sunday.setDate(start.getDate() + 6);
    sunday.setHours(23, 59, 59, 999);
    return sunday;
  },
};
