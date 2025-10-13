/**
 * Firestore Setup Verification Script
 *
 * Checks if required data exists for Clock In/Out to work:
 * 1. User document with companyId
 * 2. Active assignment for worker
 * 3. Job document with geofence
 */

const admin = require('firebase-admin');

// Initialize Firebase Admin
const serviceAccount = require('./firebase-service-account-staging.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'sierra-painting-staging'
});

const db = admin.firestore();

const WORKER_UID = 'd5POlAllCoacEAN5uajhJfzcIJu2';
const COMPANY_ID = 'test-company-staging';
const JOB_ID = 'test-job-staging';

async function verifySetup() {
  console.log('🔍 Verifying Firestore Setup for Clock In/Out...\n');

  let allChecksPass = true;

  // 1. Check user document
  console.log('1️⃣  Checking user document...');
  try {
    const userDoc = await db.collection('users').doc(WORKER_UID).get();

    if (!userDoc.exists) {
      console.log('   ❌ User document NOT FOUND: /users/' + WORKER_UID);
      console.log('   📝 Need to create user document with companyId field');
      allChecksPass = false;
    } else {
      const userData = userDoc.data();
      const companyId = userData.companyId;

      if (!companyId) {
        console.log('   ❌ User document EXISTS but missing companyId field');
        console.log('   📝 Need to add: { companyId: "' + COMPANY_ID + '" }');
        allChecksPass = false;
      } else if (companyId !== COMPANY_ID) {
        console.log('   ⚠️  User has different companyId: ' + companyId);
        console.log('   📝 Expected: ' + COMPANY_ID);
      } else {
        console.log('   ✅ User document exists with correct companyId: ' + companyId);
      }
    }
  } catch (error) {
    console.log('   ❌ Error checking user: ' + error.message);
    allChecksPass = false;
  }

  // 2. Check assignment
  console.log('\n2️⃣  Checking assignment...');
  try {
    const assignmentsQuery = await db.collection('assignments')
      .where('userId', '==', WORKER_UID)
      .where('companyId', '==', COMPANY_ID)
      .where('active', '==', true)
      .limit(1)
      .get();

    if (assignmentsQuery.empty) {
      console.log('   ❌ NO active assignment found');
      console.log('   📝 Need to create assignment document:');
      console.log('      {');
      console.log('        userId: "' + WORKER_UID + '",');
      console.log('        companyId: "' + COMPANY_ID + '",');
      console.log('        jobId: "' + JOB_ID + '",');
      console.log('        active: true');
      console.log('      }');
      allChecksPass = false;
    } else {
      const assignment = assignmentsQuery.docs[0];
      const assignmentData = assignment.data();
      console.log('   ✅ Active assignment found: ' + assignment.id);
      console.log('      userId: ' + assignmentData.userId);
      console.log('      companyId: ' + assignmentData.companyId);
      console.log('      jobId: ' + assignmentData.jobId);
      console.log('      active: ' + assignmentData.active);
    }
  } catch (error) {
    console.log('   ❌ Error checking assignments: ' + error.message);
    allChecksPass = false;
  }

  // 3. Check job document
  console.log('\n3️⃣  Checking job document...');
  try {
    const jobDoc = await db.collection('jobs').doc(JOB_ID).get();

    if (!jobDoc.exists) {
      console.log('   ❌ Job document NOT FOUND: /jobs/' + JOB_ID);
      console.log('   📝 Need to create job document with geofence');
      allChecksPass = false;
    } else {
      const jobData = jobDoc.data();
      const geofence = jobData.geofence;

      if (!geofence) {
        console.log('   ❌ Job exists but missing geofence field');
        allChecksPass = false;
      } else {
        console.log('   ✅ Job document exists: ' + (jobData.name || JOB_ID));
        console.log('      Geofence: lat ' + geofence.latitude + ', lng ' + geofence.longitude + ', radius ' + geofence.radiusMeters + 'm');
      }
    }
  } catch (error) {
    console.log('   ❌ Error checking job: ' + error.message);
    allChecksPass = false;
  }

  // 4. Check for existing active time entry
  console.log('\n4️⃣  Checking for active time entry...');
  try {
    const activeEntriesQuery = await db.collection('timeEntries')
      .where('userId', '==', WORKER_UID)
      .where('companyId', '==', COMPANY_ID)
      .where('clockOutAt', '==', null)
      .limit(1)
      .get();

    if (activeEntriesQuery.empty) {
      console.log('   ℹ️  No active time entry (worker not clocked in) - OK');
    } else {
      const entry = activeEntriesQuery.docs[0];
      const entryData = entry.data();
      console.log('   ⚠️  Worker already clocked in!');
      console.log('      Entry ID: ' + entry.id);
      console.log('      Clock In: ' + entryData.clockInAt?.toDate?.());
      console.log('      Job ID: ' + entryData.jobId);
    }
  } catch (error) {
    console.log('   ❌ Error checking time entries: ' + error.message);
  }

  // Summary
  console.log('\n' + '='.repeat(60));
  if (allChecksPass) {
    console.log('✅ ALL CHECKS PASSED - Clock In/Out should work!');
  } else {
    console.log('❌ SETUP INCOMPLETE - Fix issues above before testing Clock In');
  }
  console.log('='.repeat(60));

  process.exit(allChecksPass ? 0 : 1);
}

verifySetup().catch(error => {
  console.error('💥 Verification script failed:', error);
  process.exit(1);
});
