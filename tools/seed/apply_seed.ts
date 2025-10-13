#!/usr/bin/env ts-node
/**
 * Deterministic Staging Seed Script
 *
 * PURPOSE:
 * Create reproducible demo data for sierra-painting-staging in <2 minutes.
 *
 * FEATURES:
 * - Deterministic IDs (no random generation)
 * - Idempotent (can run multiple times without duplicates)
 * - Dry-run mode (--check)
 * - Creates complete demo scenario
 *
 * USAGE:
 * npm run seed:staging           # Apply seed to staging
 * npm run seed:staging -- --check # Dry-run (show planned changes)
 *
 * DATA CREATED:
 * - Company: Sierra Painting – Staging Demo
 * - Users: demo-admin, demo-worker, demo-customer
 * - Job: Maple Ave Interior (Albany, NY with geofence)
 * - Assignment: Worker assigned to job (this week)
 * - Customer: Taylor Home
 */

import * as admin from 'firebase-admin';
import * as serviceAccount from '../../firebase-service-account-staging.json';

// Initialize Firebase Admin
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount as admin.ServiceAccount),
  projectId: 'sierra-painting-staging',
});

const db = admin.firestore();
const auth = admin.auth();

// Deterministic IDs (no random generation)
const IDS = {
  company: 'demo-company-staging',
  adminUid: 'staging-demo-admin-001',
  workerUid: 'staging-demo-worker-001',
  customerUid: 'staging-demo-customer-001',
  job: 'staging-demo-job-001',
  assignment: 'staging-demo-assignment-001',
  customer: 'staging-demo-customer-001',
};

const EMAILS = {
  admin: 'demo-admin@staging.test',
  worker: 'demo-worker@staging.test',
  customer: 'demo-customer@staging.test',
};

const PASSWORD = 'Demo123!'; // Demo password (not production)

// Get this week's date range (Monday to Sunday)
function getThisWeek(): { start: Date; end: Date } {
  const now = new Date();
  const dayOfWeek = now.getDay(); // 0 = Sunday
  const diff = dayOfWeek === 0 ? -6 : 1 - dayOfWeek; // Adjust to Monday

  const monday = new Date(now);
  monday.setDate(now.getDate() + diff);
  monday.setHours(0, 0, 0, 0);

  const sunday = new Date(monday);
  sunday.setDate(monday.getDate() + 6);
  sunday.setHours(23, 59, 59, 999);

  return { start: monday, end: sunday };
}

interface SeedData {
  company: any;
  users: Array<{ uid: string; email: string; data: any }>;
  job: any;
  assignment: any;
  customer: any;
}

/**
 * Generate seed data
 */
function generateSeedData(): SeedData {
  const thisWeek = getThisWeek();

  return {
    company: {
      id: IDS.company,
      data: {
        name: 'Sierra Painting – Staging Demo',
        timezone: 'America/New_York',
        requireGeofence: true,
        maxShiftHours: 12,
        autoApproveTime: false,
        autoApproveDays: null,
        defaultHourlyRate: '65.00',
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
    },
    users: [
      {
        uid: IDS.adminUid,
        email: EMAILS.admin,
        data: {
          displayName: 'Demo Admin',
          email: EMAILS.admin,
          companyId: IDS.company,
          role: 'admin',
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        },
      },
      {
        uid: IDS.workerUid,
        email: EMAILS.worker,
        data: {
          displayName: 'Demo Worker',
          email: EMAILS.worker,
          companyId: IDS.company,
          role: 'worker',
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        },
      },
      {
        uid: IDS.customerUid,
        email: EMAILS.customer,
        data: {
          displayName: 'Taylor Home',
          email: EMAILS.customer,
          companyId: IDS.company,
          role: 'customer',
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        },
      },
    ],
    job: {
      id: IDS.job,
      data: {
        companyId: IDS.company,
        name: 'Maple Ave Interior',
        description: 'Interior painting project',
        address: {
          street: '1234 Maple Ave',
          city: 'Albany',
          state: 'NY',
          zip: '12203',
          country: 'USA',
        },
        lat: 42.6526,
        lng: -73.7562,
        radiusM: 125,
        customerId: IDS.customer,
        status: 'active',
        startDate: admin.firestore.Timestamp.fromDate(thisWeek.start),
        endDate: admin.firestore.Timestamp.fromDate(
          new Date('2025-12-31T23:59:59Z')
        ),
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
    },
    assignment: {
      id: IDS.assignment,
      data: {
        companyId: IDS.company,
        userId: IDS.workerUid,
        jobId: IDS.job,
        active: true,
        startDate: admin.firestore.Timestamp.fromDate(thisWeek.start),
        endDate: admin.firestore.Timestamp.fromDate(thisWeek.end),
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
    },
    customer: {
      id: IDS.customer,
      data: {
        companyId: IDS.company,
        name: 'Taylor Home',
        email: EMAILS.customer,
        phone: '(518) 555-0100',
        address: {
          street: '1234 Maple Ave',
          city: 'Albany',
          state: 'NY',
          zip: '12203',
          country: 'USA',
        },
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
    },
  };
}

/**
 * Create or update user with custom claims
 */
async function upsertUser(
  uid: string,
  email: string,
  password: string,
  claims: Record<string, any>,
  dryRun: boolean
): Promise<void> {
  try {
    // Check if user exists
    const existingUser = await auth.getUser(uid).catch(() => null);

    if (existingUser) {
      if (dryRun) {
        console.log(`  [DRY-RUN] Would update user: ${email}`);
      } else {
        // Update existing user
        await auth.updateUser(uid, { email, password });
        await auth.setCustomUserClaims(uid, claims);
        console.log(`  ✓ Updated user: ${email}`);
      }
    } else {
      if (dryRun) {
        console.log(`  [DRY-RUN] Would create user: ${email}`);
      } else {
        // Create new user
        await auth.createUser({
          uid,
          email,
          password,
          emailVerified: true,
        });
        await auth.setCustomUserClaims(uid, claims);
        console.log(`  ✓ Created user: ${email}`);
      }
    }
  } catch (error) {
    console.error(`  ✗ Error with user ${email}:`, error);
    throw error;
  }
}

/**
 * Upsert Firestore document (idempotent)
 */
async function upsertDocument(
  collection: string,
  docId: string,
  data: any,
  dryRun: boolean
): Promise<void> {
  const ref = db.collection(collection).doc(docId);

  if (dryRun) {
    console.log(`  [DRY-RUN] Would upsert: ${collection}/${docId}`);
  } else {
    await ref.set(data, { merge: true });
    console.log(`  ✓ Upserted: ${collection}/${docId}`);
  }
}

/**
 * Apply seed data
 */
async function applySeed(dryRun: boolean): Promise<void> {
  console.log('🌱 Applying staging seed data...\n');

  if (dryRun) {
    console.log('📋 DRY-RUN MODE: No changes will be made\n');
  }

  const seed = generateSeedData();

  // 1. Create company
  console.log('1️⃣  Creating company...');
  await upsertDocument('companies', seed.company.id, seed.company.data, dryRun);

  // 2. Create users
  console.log('\n2️⃣  Creating users...');
  for (const user of seed.users) {
    await upsertUser(
      user.uid,
      user.email,
      PASSWORD,
      {
        company_id: IDS.company,
        role: user.data.role,
      },
      dryRun
    );

    // Create user document in Firestore
    await upsertDocument('users', user.uid, user.data, dryRun);
  }

  // 3. Create customer
  console.log('\n3️⃣  Creating customer...');
  await upsertDocument('customers', seed.customer.id, seed.customer.data, dryRun);

  // 4. Create job
  console.log('\n4️⃣  Creating job...');
  await upsertDocument('jobs', seed.job.id, seed.job.data, dryRun);

  // 5. Create assignment
  console.log('\n5️⃣  Creating assignment...');
  await upsertDocument('assignments', seed.assignment.id, seed.assignment.data, dryRun);

  console.log('\n✅ Seed complete!');

  if (!dryRun) {
    console.log('\n📝 Demo credentials:');
    console.log(`   Admin:    ${EMAILS.admin} / ${PASSWORD}`);
    console.log(`   Worker:   ${EMAILS.worker} / ${PASSWORD}`);
    console.log(`   Customer: ${EMAILS.customer} / ${PASSWORD}`);
    console.log('\n🎯 Ready for demo!');
  }
}

/**
 * Main entry point
 */
async function main(): Promise<void> {
  const args = process.argv.slice(2);
  const dryRun = args.includes('--check');

  try {
    await applySeed(dryRun);
    process.exit(0);
  } catch (error) {
    console.error('\n❌ Seed failed:', error);
    process.exit(1);
  }
}

// Run if executed directly
if (require.main === module) {
  main();
}

export { applySeed, generateSeedData };
