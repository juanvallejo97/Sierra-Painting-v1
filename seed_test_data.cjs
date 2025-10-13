/**
 * Seed Test Data for Staging
 *
 * Creates minimal test data for clock-in flow:
 * - 1 Job with geofence
 * - 1 Assignment linking test user to job
 */

const admin = require('firebase-admin');

// Initialize Firebase Admin
try {
  const serviceAccount = require('./firebase-service-account-staging.json');
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    projectId: 'sierra-painting-staging'
  });
} catch (error) {
  console.error('Error: firebase-service-account-staging.json not found');
  console.error('Please download service account key from Firebase Console');
  process.exit(1);
}

const db = admin.firestore();

// Test data constants
const TEST_USER_ID = 'd5P01AlLCoaEAN5ua3hJFzcIJu2';
const TEST_COMPANY_ID = 'test-company-staging';
const TEST_JOB_ID = 'test-job-staging';

// Job location near test user's location (from console logs)
const JOB_LAT = 41.8825;
const JOB_LNG = -71.3945;

async function seedData() {
  console.log('🌱 Starting seed operation...\n');

  try {
    // 1. Create/Update Job
    console.log('1️⃣ Creating job document...');
    const jobRef = db.collection('jobs').doc(TEST_JOB_ID);
    await jobRef.set({
      companyId: TEST_COMPANY_ID,
      name: 'Test Job Site - Staging',
      address: '123 Test Street, Providence, RI',
      geofence: {
        lat: JOB_LAT,
        lng: JOB_LNG,
        radiusM: 150  // 150m radius to accommodate testing
      },
      status: 'active',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
    console.log(`   ✅ Job created: ${TEST_JOB_ID}\n`);

    // 2. Check if assignment already exists
    console.log('2️⃣ Checking for existing assignment...');
    const existingAssignments = await db.collection('assignments')
      .where('userId', '==', TEST_USER_ID)
      .where('jobId', '==', TEST_JOB_ID)
      .where('companyId', '==', TEST_COMPANY_ID)
      .limit(1)
      .get();

    if (!existingAssignments.empty) {
      console.log('   ⚠️  Assignment already exists, updating to active...');
      const assignmentDoc = existingAssignments.docs[0];
      await assignmentDoc.ref.update({
        active: true,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      console.log(`   ✅ Assignment updated: ${assignmentDoc.id}\n`);
    } else {
      // 3. Create new assignment
      console.log('3️⃣ Creating new assignment...');
      const assignmentRef = await db.collection('assignments').add({
        userId: TEST_USER_ID,
        companyId: TEST_COMPANY_ID,
        jobId: TEST_JOB_ID,
        active: true,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      console.log(`   ✅ Assignment created: ${assignmentRef.id}\n`);
    }

    // 4. Verify data
    console.log('4️⃣ Verifying seeded data...\n');

    const jobDoc = await jobRef.get();
    if (jobDoc.exists) {
      console.log('   ✅ Job document verified');
      console.log(`      - Name: ${jobDoc.data().name}`);
      console.log(`      - Location: ${jobDoc.data().geofence.lat}, ${jobDoc.data().geofence.lng}`);
      console.log(`      - Radius: ${jobDoc.data().geofence.radiusM}m`);
    }

    const assignments = await db.collection('assignments')
      .where('userId', '==', TEST_USER_ID)
      .where('companyId', '==', TEST_COMPANY_ID)
      .where('active', '==', true)
      .get();

    if (!assignments.empty) {
      console.log('   ✅ Assignment document verified');
      console.log(`      - User: ${assignments.docs[0].data().userId}`);
      console.log(`      - Job: ${assignments.docs[0].data().jobId}`);
      console.log(`      - Active: ${assignments.docs[0].data().active}`);
    }

    console.log('\n✨ Seed operation completed successfully!\n');
    console.log('📍 Next Steps:');
    console.log('   1. Refresh the browser (Ctrl+Shift+R)');
    console.log('   2. Try clock-in again');
    console.log('   3. Check console for "Found 1 assignments" log\n');

  } catch (error) {
    console.error('❌ Error during seed operation:', error);
    process.exit(1);
  } finally {
    process.exit(0);
  }
}

// Run seed
seedData();
