const admin = require('firebase-admin');

if (!admin.apps.length) {
  admin.initializeApp({ projectId: 'sierra-painting-staging' });
}

// Import the adminAutoClockOutOnce function
const { adminAutoClockOutOnce } = require('./functions/lib/ops/auto_clock_out');

async function testAutoClockout() {
  console.log('Test 6: Auto-Clockout Dry-Run\n');
  console.log('Calling adminAutoClockOutOnce with dryRun: true...\n');

  try {
    const result = await adminAutoClockOutOnce({ dryRun: true });

    console.log('✅ SUCCESS\n');
    console.log('Result:');
    console.log(JSON.stringify(result, null, 2));
    console.log();

    // Validate expected structure
    if (result.success && result.dryRun === true) {
      console.log('✅ Test 6: PASS');
      console.log('   - success: true ✅');
      console.log('   - dryRun: true ✅');
      console.log('   - processed:', result.processed || 0);
      process.exit(0);
    } else {
      console.log('❌ Test 6: FAIL - Unexpected result structure');
      process.exit(1);
    }
  } catch (err) {
    console.error('❌ Test 6: FAIL\n');
    console.error('Error:', err.message);
    if (err.stack) {
      console.error('Stack:', err.stack);
    }
    process.exit(1);
  }
}

testAutoClockout();
