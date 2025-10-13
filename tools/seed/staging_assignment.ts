/**
 * Staging Assignment Seeder
 *
 * PURPOSE:
 * Idempotently ensures exactly ONE active assignment exists for the test user.
 * Safe to run multiple times - deactivates old assignments before creating new one.
 *
 * USAGE:
 *   npx ts-node tools/seed/staging_assignment.ts
 *
 * REQUIRES:
 *   - Firebase Admin SDK credentials (GOOGLE_APPLICATION_CREDENTIALS or ADC)
 *   - Project set to sierra-painting-staging
 */

import { initializeApp, applicationDefault } from 'firebase-admin/app';
import { getFirestore, FieldValue, Timestamp } from 'firebase-admin/firestore';

// Initialize Firebase Admin
initializeApp({ credential: applicationDefault() });
const db = getFirestore();

// Test configuration (matches STAGING_VALIDATION_REPORT.md)
const CONFIG = {
  companyId: 'test-company-staging',
  userId: 'd5P01AlLCoaEAN5ua3hJFzcIJu2', // Test worker UID from staging
  jobId: 'test-job-staging-123',
  jobName: 'Staging Test Job Site',
  jobAddress: '1234 Test Ave, Albany, NY 12203',
  jobLocation: {
    lat: 42.6526, // Albany, NY
    lng: -73.7562,
    radiusM: 100, // 100m geofence
  },
};

async function run() {
  console.log('🌱 Seeding staging assignment...\n');

  try {
    // Step 1: Upsert job
    console.log(`📍 Ensuring job exists: ${CONFIG.jobId}`);
    await db
      .collection('jobs')
      .doc(CONFIG.jobId)
      .set(
        {
          companyId: CONFIG.companyId,
          name: CONFIG.jobName,
          address: CONFIG.jobAddress,
          location: {
            latitude: CONFIG.jobLocation.lat,
            longitude: CONFIG.jobLocation.lng,
            geofenceRadius: CONFIG.jobLocation.radiusM,
          },
          status: 'active',
          createdAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
    console.log('✅ Job ready\n');

    // Step 2: Deactivate ALL existing assignments for this user
    console.log(`🔄 Deactivating old assignments for user: ${CONFIG.userId}`);
    const existingAssignments = await db
      .collection('assignments')
      .where('userId', '==', CONFIG.userId)
      .where('companyId', '==', CONFIG.companyId)
      .where('active', '==', true)
      .get();

    if (!existingAssignments.empty) {
      const batch = db.batch();
      existingAssignments.docs.forEach((doc) => {
        batch.update(doc.ref, {
          active: false,
          updatedAt: FieldValue.serverTimestamp(),
        });
      });
      await batch.commit();
      console.log(`   Deactivated ${existingAssignments.size} assignment(s)`);
    } else {
      console.log('   No active assignments found');
    }

    // Step 3: Create new active assignment (this week)
    console.log(`\n✨ Creating new active assignment`);
    const now = new Date();
    const weekStart = new Date(now);
    weekStart.setDate(now.getDate() - now.getDay()); // Start of week (Sunday)
    weekStart.setHours(0, 0, 0, 0);

    const weekEnd = new Date(weekStart);
    weekEnd.setDate(weekStart.getDate() + 6); // End of week (Saturday)
    weekEnd.setHours(23, 59, 59, 999);

    const assignmentRef = await db.collection('assignments').add({
      userId: CONFIG.userId,
      companyId: CONFIG.companyId,
      jobId: CONFIG.jobId,
      active: true,
      startDate: Timestamp.fromDate(weekStart),
      endDate: Timestamp.fromDate(weekEnd),
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });

    console.log('✅ Assignment created:', assignmentRef.id);

    // Step 4: Summary
    console.log('\n📊 Summary:');
    console.log(`   Company: ${CONFIG.companyId}`);
    console.log(`   User: ${CONFIG.userId}`);
    console.log(`   Job: ${CONFIG.jobId} (${CONFIG.jobName})`);
    console.log(
      `   Location: ${CONFIG.jobLocation.lat}, ${CONFIG.jobLocation.lng}`,
    );
    console.log(`   Geofence: ${CONFIG.jobLocation.radiusM}m`);
    console.log(
      `   Active: ${weekStart.toLocaleDateString()} - ${weekEnd.toLocaleDateString()}`,
    );
    console.log('\n✅ Staging assignment seeded successfully!');
    console.log(
      '\n💡 Next step: Run E2E smoke test with this user to verify clock-in flow',
    );
  } catch (error) {
    console.error('\n❌ Error seeding assignment:', error);
    process.exit(1);
  }
}

// Execute
run()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error('Fatal error:', error);
    process.exit(1);
  });
