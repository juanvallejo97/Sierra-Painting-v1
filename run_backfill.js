/**
 * Run Backfill Normalizer - One-Time Script
 *
 * USAGE:
 * 1. Ensure Firebase credentials are set:
 *    - Set GOOGLE_APPLICATION_CREDENTIALS env var, OR
 *    - Run from authenticated Firebase CLI session
 *
 * 2. Run from functions directory:
 *    node ../run_backfill.js
 *
 * 3. Expected output:
 *    BACKFILL_RESULT: {"processed":150,"updated":8,"errors":0}
 */

const admin = require('firebase-admin');
const { backfillNormalizeTimeEntries } = require('./functions/lib/utils/schema_normalizer.js');

// Initialize Firebase Admin
admin.initializeApp({
  projectId: 'sierra-painting-staging',
});

console.log('Starting backfill normalizer...');
console.log('Project:', admin.instanceId().app.options.projectId);

backfillNormalizeTimeEntries()
  .then(result => {
    console.log('BACKFILL_RESULT:', JSON.stringify(result));
    console.log('\n✅ Backfill complete:');
    console.log(`   - Processed: ${result.processed} entries`);
    console.log(`   - Updated: ${result.updated} entries`);
    console.log(`   - Errors: ${result.errors}`);

    if (result.errors === 0) {
      console.log('\n✅ SUCCESS: No errors encountered');
      process.exit(0);
    } else {
      console.log('\n⚠️  WARNING: Errors encountered');
      process.exit(1);
    }
  })
  .catch(error => {
    console.error('❌ ERROR:', error.message);
    console.error(error.stack);
    process.exit(1);
  });
