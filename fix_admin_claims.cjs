/**
 * Fix admin claims - Run this to set custom claims for admin user
 *
 * This uses Application Default Credentials (ADC) from Firebase CLI
 * Run: firebase login first, then: node fix_admin_claims.cjs
 */

const { initializeApp } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');

// Initialize with project ID (uses ADC automatically)
const app = initializeApp({
  projectId: 'sierra-painting-staging'
});

const auth = getAuth(app);

async function fixAdminClaims() {
  const adminUid = 'yqLJSx5NH1YHKa9WxIOhCrqJcPp1';
  const workerUid = 'd5POlAllCoacEAN5uajhJfzcIJu2';
  const companyId = 'test-company-staging';

  console.log('Setting custom claims...\n');

  try {
    // Set admin claims
    await auth.setCustomUserClaims(adminUid, {
      role: 'admin',
      companyId: companyId,
      updatedAt: Date.now(),
    });
    console.log('✅ Admin claims set:');
    console.log(`   UID: ${adminUid}`);
    console.log(`   Role: admin`);
    console.log(`   Company: ${companyId}\n`);

    // Set worker claims
    await auth.setCustomUserClaims(workerUid, {
      role: 'worker',
      companyId: companyId,
      updatedAt: Date.now(),
    });
    console.log('✅ Worker claims set:');
    console.log(`   UID: ${workerUid}`);
    console.log(`   Role: worker`);
    console.log(`   Company: ${companyId}\n`);

    console.log('⚠️  IMPORTANT: Users must log out and log back in for changes to take effect!\n');
    console.log('Next steps:');
    console.log('1. Log out of the admin dashboard');
    console.log('2. Log back in');
    console.log('3. Hard refresh (Ctrl+Shift+R)');
    console.log('4. Navigate to Admin → Time Entry Review');
    console.log('5. Dashboard should now load successfully!\n');

    process.exit(0);
  } catch (error) {
    console.error('❌ Error:', error.message);
    console.error('\nTroubleshooting:');
    console.error('- Make sure you ran: firebase login');
    console.error('- Make sure you have admin access to: sierra-painting-staging');
    console.error('- Try: gcloud auth application-default login\n');
    process.exit(1);
  }
}

fixAdminClaims();
