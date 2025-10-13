/**
 * Setup test data for Clock In/Out validation
 *
 * Version: 2.0 (Canonical Schema - Option B Stability Patch)
 * Last Updated: 2025-10-12
 *
 * Creates:
 * - User documents (canonical fields only: userId, displayName, email, photoURL, timestamps)
 * - Job document with nested geofence (geofence.{lat, lng, radiusM})
 * - Assignment linking worker to job (canonical field names)
 * - Custom claims (companyId, role, active) in Firebase Auth JWT
 *
 * IMPORTANT: This script uses canonical v2.0 schemas documented in docs/schemas/
 * All field names match the TypeScript interfaces in functions/src/types.ts
 *
 * See:
 * - docs/schemas/user.md
 * - docs/schemas/job.md
 * - docs/schemas/assignment.md
 */

const admin = require('firebase-admin');

admin.initializeApp({
  projectId: 'sierra-painting-staging'
});

const db = admin.firestore();

const WORKER_UID = 'd5POlAllCoacEAN5uajhJfzcIJu2';
const ADMIN_UID = 'yqLJSx5NH1YHKa9WxIOhCrqJcPp1';
const COMPANY_ID = 'test-company-staging';
const JOB_ID = 'test-job-staging';

async function setupTestData() {
  console.log('🚀 Setting up test data for sierra-painting-staging...\n');

  try {
    // 1. Create/update worker user document
    // NOTE: companyId, role, active are set via custom claims, NOT in Firestore
    console.log('1️⃣  Creating worker user document...');
    await db.collection('users').doc(WORKER_UID).set({
      userId: WORKER_UID,
      email: 'worker@test.com',
      displayName: 'Test Worker',
      photoURL: null,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    }, { merge: true });
    console.log('   ✅ Worker user document created');

    // 2. Create/update admin user document
    // NOTE: companyId, role, active are set via custom claims, NOT in Firestore
    console.log('\n2️⃣  Creating admin user document...');
    await db.collection('users').doc(ADMIN_UID).set({
      userId: ADMIN_UID,
      email: 'admin@test.com',
      displayName: 'Test Admin',
      photoURL: null,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    }, { merge: true });
    console.log('   ✅ Admin user document created');

    // 3. Create/update company document
    console.log('\n3️⃣  Creating company document...');
    await db.collection('companies').doc(COMPANY_ID).set({
      name: 'Test Company',
      timezone: 'America/Los_Angeles',
      active: true,
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    }, { merge: true });
    console.log('   ✅ Company document created');

    // 4. Create/update job document with geofence
    // NOTE: Geofence uses canonical nested structure: {lat, lng, radiusM}
    console.log('\n4️⃣  Creating job document with geofence...');
    await db.collection('jobs').doc(JOB_ID).set({
      jobId: JOB_ID,
      companyId: COMPANY_ID,
      name: 'SF Painted Ladies',
      address: '710 Steiner St, San Francisco, CA 94117',
      active: true,
      geofence: {
        lat: 37.7793,
        lng: -122.4193,
        radiusM: 150
      },
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    }, { merge: true });
    console.log('   ✅ Job document created with geofence');
    console.log('      Location: 37.7793, -122.4193 (Radius: 150m)');

    // 5. Create/update assignment
    console.log('\n5️⃣  Creating assignment...');
    const assignmentId = `${WORKER_UID}_${JOB_ID}`;
    await db.collection('assignments').doc(assignmentId).set({
      assignmentId: assignmentId,
      companyId: COMPANY_ID,
      userId: WORKER_UID,
      jobId: JOB_ID,
      active: true,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    }, { merge: true });
    console.log('   ✅ Assignment created');
    console.log('      Worker → Job: d5POl...u2 → test-job-staging');

    // 6. Set custom claims (camelCase: companyId, role, active)
    console.log('\n6️⃣  Setting custom claims...');
    await admin.auth().setCustomUserClaims(WORKER_UID, {
      companyId: COMPANY_ID,
      role: 'worker',
      active: true
    });
    console.log('   ✅ Worker claims set (companyId, role, active)');

    await admin.auth().setCustomUserClaims(ADMIN_UID, {
      companyId: COMPANY_ID,
      role: 'admin',
      active: true
    });
    console.log('   ✅ Admin claims set (companyId, role, active)');

    console.log('\n' + '='.repeat(60));
    console.log('✅ ALL TEST DATA SETUP COMPLETE!');
    console.log('='.repeat(60));

    console.log('\n📋 Summary:');
    console.log('   • Users: worker@test.com, admin@test.com');
    console.log('   • Company: test-company-staging');
    console.log('   • Job: SF Painted Ladies (test-job-staging)');
    console.log('   • Assignment: worker → job (active)');
    console.log('   • Custom claims: Set for both users');

    console.log('\n🧪 Next Steps:');
    console.log('   1. Users must sign out and back in for claims to take effect');
    console.log('   2. Open http://localhost:9030 in incognito');
    console.log('   3. Login as worker@test.com');
    console.log('   4. Click Clock In (use mock location: 37.7793, -122.4193)');

  } catch (error) {
    console.error('\n❌ Error setting up test data:', error);
    process.exit(1);
  }

  process.exit(0);
}

setupTestData();
