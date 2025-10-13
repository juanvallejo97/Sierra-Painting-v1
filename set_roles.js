const admin = require('firebase-admin');

// Initialize Firebase Admin
const serviceAccount = require('./functions/service-account-staging.json');
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'sierra-painting-staging'
});

async function setUserRole(uid, role, companyId) {
  try {
    // Set custom claims
    await admin.auth().setCustomUserClaims(uid, {
      role: role,
      companyId: companyId
    });

    console.log(`✅ Successfully set ${role} role for UID: ${uid}`);
    console.log(`   Company ID: ${companyId}`);

    // Verify the claims were set
    const user = await admin.auth().getUser(uid);
    console.log(`   Verified claims:`, user.customClaims);

    return { success: true, uid, role, companyId };
  } catch (error) {
    console.error(`❌ Error setting role for ${uid}:`, error.message);
    return { success: false, uid, role, error: error.message };
  }
}

async function main() {
  console.log('Setting user roles for staging validation...\n');

  // Set admin role
  const adminResult = await setUserRole(
    'yqLJSx5NH1YHKa9WxIOhCrqJcPp1',
    'admin',
    'test-company-staging'
  );

  console.log('\n');

  // Set worker role
  const workerResult = await setUserRole(
    'd5POlAllCoacEAN5uajhJfzcIJu2',
    'worker',
    'test-company-staging'
  );

  console.log('\n=== Summary ===');
  console.log('Admin:', adminResult.success ? '✅ SUCCESS' : '❌ FAILED');
  console.log('Worker:', workerResult.success ? '✅ SUCCESS' : '❌ FAILED');

  process.exit(adminResult.success && workerResult.success ? 0 : 1);
}

main();
