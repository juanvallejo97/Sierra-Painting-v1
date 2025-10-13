/**
 * Set custom claims for test users
 */

const admin = require('firebase-admin');

// Initialize with service account
admin.initializeApp({
  projectId: 'sierra-painting-staging'
});

const WORKER_UID = 'd5POlAllCoacEAN5uajhJfzcIJu2';
const ADMIN_UID = 'yqLJSx5NH1YHKa9WxIOhCrqJcPp1';
const COMPANY_ID = 'test-company-staging';

async function setClaims() {
  console.log('Setting custom claims for test users...\n');

  try {
    // Set worker claims
    await admin.auth().setCustomUserClaims(WORKER_UID, {
      role: 'worker',
      companyId: COMPANY_ID
    });
    console.log('✅ Worker claims set: role=worker, companyId=' + COMPANY_ID);

    // Set admin claims
    await admin.auth().setCustomUserClaims(ADMIN_UID, {
      role: 'admin',
      companyId: COMPANY_ID
    });
    console.log('✅ Admin claims set: role=admin, companyId=' + COMPANY_ID);

    console.log('\n✅ Custom claims set successfully!');
    console.log('Note: Users will need to sign out and back in for claims to take effect.');
  } catch (error) {
    console.error('❌ Error setting claims:', error);
  }

  process.exit(0);
}

setClaims();
