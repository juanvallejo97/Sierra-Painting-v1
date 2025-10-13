/**
 * Verify custom claims are set correctly
 * Run with: node verify_claims.cjs
 */

const { initializeApp } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');

const app = initializeApp({ projectId: 'sierra-painting-staging' });
const auth = getAuth(app);

async function verifyClaims() {
  const adminUid = 'yqLJSx5NH1YHKa9WxIOhCrqJcPp1';
  const workerUid = 'd5POlAllCoacEAN5uajhJfzcIJu2';

  console.log('Verifying custom claims...\n');

  try {
    // Check admin user
    const adminUser = await auth.getUser(adminUid);
    console.log('👤 Admin User:');
    console.log('   UID:', adminUser.uid);
    console.log('   Email:', adminUser.email);
    console.log('   Custom Claims:', JSON.stringify(adminUser.customClaims, null, 2));
    console.log('');

    // Check worker user
    const workerUser = await auth.getUser(workerUid);
    console.log('👤 Worker User:');
    console.log('   UID:', workerUser.uid);
    console.log('   Email:', workerUser.email);
    console.log('   Custom Claims:', JSON.stringify(workerUser.customClaims, null, 2));
    console.log('');

    // Validation
    if (adminUser.customClaims?.role === 'admin' && adminUser.customClaims?.companyId === 'test-company-staging') {
      console.log('✅ Admin claims are correct!');
    } else {
      console.log('❌ Admin claims are missing or incorrect!');
    }

    if (workerUser.customClaims?.role === 'worker' && workerUser.customClaims?.companyId === 'test-company-staging') {
      console.log('✅ Worker claims are correct!');
    } else {
      console.log('❌ Worker claims are missing or incorrect!');
    }

    console.log('\n⚠️  Remember: Users must log out and log back in for claims to take effect in their browser!');

    process.exit(0);
  } catch (error) {
    console.error('❌ Error:', error.message);
    process.exit(1);
  }
}

verifyClaims();
