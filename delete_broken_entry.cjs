const admin = require('firebase-admin');

// Initialize Firebase Admin
const serviceAccount = require('./firebase-service-account-staging.json');
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'sierra-painting-staging'
});

const db = admin.firestore();

async function deleteEntry() {
  try {
    const entryId = 'MNXwb81mBuromgvYJXD';
    console.log(`Attempting to delete time entry: ${entryId}`);

    await db.collection('time_entries').doc(entryId).delete();

    console.log('✅ Successfully deleted broken time entry');
    process.exit(0);
  } catch (error) {
    console.error('❌ Error deleting entry:', error);
    process.exit(1);
  }
}

deleteEntry();
