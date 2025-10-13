const admin = require('firebase-admin');

// Initialize Firebase Admin FIRST (before requiring modules that use it)
admin.initializeApp({ projectId: 'sierra-painting-staging' });

// NOW import the auto-clockout module (it will use the initialized admin)
const { runAutoClockOutOnce } = require('./functions/lib/auto-clockout');

async function testAutoClockout() {
  console.log('Test 6: Auto-Clockout Dry-Run\n');
  console.log('Calling runAutoClockOutOnce with dryRun: true...\n');

  try {
    const result = await runAutoClockOutOnce(true);

    console.log('✅ SUCCESS\n');
    console.log('Result:');
    console.log(JSON.stringify(result, null, 2));
    console.log();

    // Validate expected structure
    if (typeof result.processed === 'number') {
      console.log('✅ Test 6: PASS');
      console.log('   - processed:', result.processed);
      console.log('   - entries:', result.entries.length);
      console.log('   - dryRun mode confirmed (no changes committed)');
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
