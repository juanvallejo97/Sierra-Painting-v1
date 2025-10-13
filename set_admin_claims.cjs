/**
 * Set custom claims for admin user
 * Run with: node set_admin_claims.cjs
 */

const admin = require('firebase-admin');

// Initialize Firebase Admin
admin.initializeApp({
  projectId: 'sierra-painting-staging',
});

async function setAdminClaims() {
  const adminUid = 'yqLJSx5NH1YHKa9WxIOhCrqJcPp1';
  const companyId = 'test-company-staging';

  try {
    // Set custom claims
    await admin.auth().setCustomUserClaims(adminUid, {
      role: 'admin',
      companyId: companyId,
      updatedAt: Date.now(),
    });

    console.log('✅ Admin claims set successfully!');
    console.log(`   UID: ${adminUid}`);
    console.log(`   Role: admin`);
    console.log(`   Company: ${companyId}`);
    console.log('');
    console.log('⚠️  User must log out and log in again for claims to take effect.');

    process.exit(0);
  } catch (error) {
    console.error('❌ Error setting claims:', error);
    process.exit(1);
  }
}

setAdminClaims();
