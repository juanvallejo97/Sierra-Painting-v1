/**
 * Firestore Rules Unit Tests
 * 
 * Tests security rules with schema validation for:
 * - Authentication requirements
 * - Owner-based access control
 * - Schema validation (required fields, types)
 * - Server timestamp enforcement
 */

import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
  RulesTestEnvironment,
} from '@firebase/rules-unit-testing';
import * as fs from 'fs';
import * as path from 'path';

let testEnv: RulesTestEnvironment;

beforeAll(async () => {
  // Initialize test environment with rules from project root
  // Use local emulator on default ports
  testEnv = await initializeTestEnvironment({
    projectId: 'sierra-painting-test',
    firestore: {
      rules: fs.readFileSync(
        path.join(__dirname, '../../../firestore.rules'),
        'utf8'
      ),
      host: 'localhost',
      port: 8080,
    },
  });
});

afterAll(async () => {
  await testEnv.cleanup();
});

afterEach(async () => {
  await testEnv.clearFirestore();
});

describe('Firestore Rules - Authentication', () => {
  test('Deny read/write by default for unauthenticated users', async () => {
    const unauthedDb = testEnv.unauthenticatedContext().firestore();
    
    await assertFails(unauthedDb.collection('jobs').get());
    await assertFails(unauthedDb.collection('jobs').doc('job1').get());
    await assertFails(
      unauthedDb.collection('jobs').doc('job1').set({
        orgId: 'org1',
        status: 'active',
        ownerId: 'user1',
      })
    );
  });

  test('Deny write without auth even if data is valid', async () => {
    const unauthedDb = testEnv.unauthenticatedContext().firestore();
    
    await assertFails(
      unauthedDb.collection('jobs').add({
        orgId: 'org1',
        status: 'pending',
        ownerId: 'user1',
        title: 'Test Job',
      })
    );
  });
});

describe('Firestore Rules - Jobs Collection (Owner CRUD)', () => {
  test('Owner can create job with valid schema', async () => {
    const ownerDb = testEnv
      .authenticatedContext('owner1', {
        orgs: { org1: true },
      })
      .firestore();

    await assertSucceeds(
      ownerDb.collection('jobs').doc('job1').set({
        orgId: 'org1',
        status: 'pending',
        ownerId: 'owner1',
        title: 'Paint House',
        description: 'Full interior paint',
      })
    );
  });

  test('Owner can read their own job', async () => {
    const ownerDb = testEnv
      .authenticatedContext('owner1', {
        orgs: { org1: true },
      })
      .firestore();

    // Setup: create job with security rules disabled
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().collection('jobs').doc('job1').set({
        orgId: 'org1',
        status: 'pending',
        ownerId: 'owner1',
        title: 'Paint House',
      });
    });

    // Test: owner can read
    await assertSucceeds(ownerDb.collection('jobs').doc('job1').get());
  });

  test('Owner can update their own job', async () => {
    const ownerDb = testEnv
      .authenticatedContext('owner1', {
        orgs: { org1: true },
      })
      .firestore();

    // Setup: create job
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().collection('jobs').doc('job1').set({
        orgId: 'org1',
        status: 'pending',
        ownerId: 'owner1',
        title: 'Paint House',
      });
    });

    // Test: owner can update
    await assertSucceeds(
      ownerDb.collection('jobs').doc('job1').update({
        status: 'in_progress',
        orgId: 'org1',
        ownerId: 'owner1',
      })
    );
  });

  test('Owner can delete their own job', async () => {
    const ownerDb = testEnv
      .authenticatedContext('owner1', {
        orgs: { org1: true },
      })
      .firestore();

    // Setup: create job
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().collection('jobs').doc('job1').set({
        orgId: 'org1',
        status: 'pending',
        ownerId: 'owner1',
        title: 'Paint House',
      });
    });

    // Test: owner can delete
    await assertSucceeds(ownerDb.collection('jobs').doc('job1').delete());
  });
});

describe('Firestore Rules - Jobs Collection (Non-Owner Access)', () => {
  test('Non-owner cannot create job with different ownerId', async () => {
    const userDb = testEnv
      .authenticatedContext('user2', {
        orgs: { org1: true },
      })
      .firestore();

    await assertFails(
      userDb.collection('jobs').doc('job1').set({
        orgId: 'org1',
        status: 'pending',
        ownerId: 'owner1', // Different from authenticated user
        title: 'Paint House',
      })
    );
  });

  test('Non-owner cannot update job owned by someone else', async () => {
    const userDb = testEnv
      .authenticatedContext('user2', {
        orgs: { org1: true },
      })
      .firestore();

    // Setup: create job owned by owner1
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().collection('jobs').doc('job1').set({
        orgId: 'org1',
        status: 'pending',
        ownerId: 'owner1',
        title: 'Paint House',
      });
    });

    // Test: user2 cannot update
    await assertFails(
      userDb.collection('jobs').doc('job1').update({
        status: 'in_progress',
      })
    );
  });

  test('Non-owner cannot delete job owned by someone else', async () => {
    const userDb = testEnv
      .authenticatedContext('user2', {
        orgs: { org1: true },
      })
      .firestore();

    // Setup: create job owned by owner1
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().collection('jobs').doc('job1').set({
        orgId: 'org1',
        status: 'pending',
        ownerId: 'owner1',
        title: 'Paint House',
      });
    });

    // Test: user2 cannot delete
    await assertFails(userDb.collection('jobs').doc('job1').delete());
  });

  test('User in same org can read job', async () => {
    const userDb = testEnv
      .authenticatedContext('user2', {
        orgs: { org1: true },
      })
      .firestore();

    // Setup: create job
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().collection('jobs').doc('job1').set({
        orgId: 'org1',
        status: 'pending',
        ownerId: 'owner1',
        title: 'Paint House',
      });
    });

    // Test: user in same org can read
    await assertSucceeds(userDb.collection('jobs').doc('job1').get());
  });

  test('User in different org cannot read job', async () => {
    const userDb = testEnv
      .authenticatedContext('user2', {
        orgs: { org2: true },
      })
      .firestore();

    // Setup: create job in org1
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().collection('jobs').doc('job1').set({
        orgId: 'org1',
        status: 'pending',
        ownerId: 'owner1',
        title: 'Paint House',
      });
    });

    // Test: user in different org cannot read
    await assertFails(userDb.collection('jobs').doc('job1').get());
  });
});

describe('Firestore Rules - Jobs Schema Validation', () => {
  test('Reject job creation without required orgId field', async () => {
    const ownerDb = testEnv
      .authenticatedContext('owner1', {
        orgs: { org1: true },
      })
      .firestore();

    await assertFails(
      ownerDb.collection('jobs').doc('job1').set({
        status: 'pending',
        ownerId: 'owner1',
        title: 'Paint House',
        // Missing orgId
      })
    );
  });

  test('Reject job creation without required status field', async () => {
    const ownerDb = testEnv
      .authenticatedContext('owner1', {
        orgs: { org1: true },
      })
      .firestore();

    await assertFails(
      ownerDb.collection('jobs').doc('job1').set({
        orgId: 'org1',
        ownerId: 'owner1',
        title: 'Paint House',
        // Missing status
      })
    );
  });

  test('Reject job creation without required ownerId field', async () => {
    const ownerDb = testEnv
      .authenticatedContext('owner1', {
        orgs: { org1: true },
      })
      .firestore();

    await assertFails(
      ownerDb.collection('jobs').doc('job1').set({
        orgId: 'org1',
        status: 'pending',
        title: 'Paint House',
        // Missing ownerId
      })
    );
  });

  test('Reject job creation with null orgId', async () => {
    const ownerDb = testEnv
      .authenticatedContext('owner1', {
        orgs: { org1: true },
      })
      .firestore();

    await assertFails(
      ownerDb.collection('jobs').doc('job1').set({
        orgId: null,
        status: 'pending',
        ownerId: 'owner1',
        title: 'Paint House',
      })
    );
  });

  test('Reject job update that changes ownerId', async () => {
    const ownerDb = testEnv
      .authenticatedContext('owner1', {
        orgs: { org1: true },
      })
      .firestore();

    // Setup: create job
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().collection('jobs').doc('job1').set({
        orgId: 'org1',
        status: 'pending',
        ownerId: 'owner1',
        title: 'Paint House',
      });
    });

    // Test: cannot change ownerId
    await assertFails(
      ownerDb.collection('jobs').doc('job1').update({
        ownerId: 'different_owner',
        status: 'in_progress',
        orgId: 'org1',
      })
    );
  });
});

describe('Firestore Rules - Admin Access', () => {
  test('Admin can read any job in their org', async () => {
    const adminDb = testEnv
      .authenticatedContext('admin1', {
        roles: { admin: true },
        orgs: { org1: true },
      })
      .firestore();

    // Setup: create job
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().collection('jobs').doc('job1').set({
        orgId: 'org1',
        status: 'pending',
        ownerId: 'owner1',
        title: 'Paint House',
      });
    });

    // Test: admin can read
    await assertSucceeds(adminDb.collection('jobs').doc('job1').get());
  });

  test('Admin can update any job', async () => {
    const adminDb = testEnv
      .authenticatedContext('admin1', {
        roles: { admin: true },
        orgs: { org1: true },
      })
      .firestore();

    // Setup: create job
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().collection('jobs').doc('job1').set({
        orgId: 'org1',
        status: 'pending',
        ownerId: 'owner1',
        title: 'Paint House',
      });
    });

    // Test: admin can update
    await assertSucceeds(
      adminDb.collection('jobs').doc('job1').update({
        status: 'completed',
      })
    );
  });

  test('Admin can delete any job', async () => {
    const adminDb = testEnv
      .authenticatedContext('admin1', {
        roles: { admin: true },
        orgs: { org1: true },
      })
      .firestore();

    // Setup: create job
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().collection('jobs').doc('job1').set({
        orgId: 'org1',
        status: 'pending',
        ownerId: 'owner1',
        title: 'Paint House',
      });
    });

    // Test: admin can delete
    await assertSucceeds(adminDb.collection('jobs').doc('job1').delete());
  });
});

describe('Firestore Rules - Other Collections (Existing)', () => {
  test('Unauthenticated cannot read users collection', async () => {
    const unauthedDb = testEnv.unauthenticatedContext().firestore();
    
    await assertFails(unauthedDb.collection('users').doc('user1').get());
  });

  test('Authenticated user can read their own user document', async () => {
    const userDb = testEnv.authenticatedContext('user1').firestore();

    // Setup: create user
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().collection('users').doc('user1').set({
        email: 'user1@test.com',
        orgId: 'org1',
      });
    });

    // Test: user can read own document
    await assertSucceeds(userDb.collection('users').doc('user1').get());
  });

  test('User cannot read another user document', async () => {
    const userDb = testEnv.authenticatedContext('user1').firestore();

    // Setup: create another user
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().collection('users').doc('user2').set({
        email: 'user2@test.com',
        orgId: 'org1',
      });
    });

    // Test: user1 cannot read user2
    await assertFails(userDb.collection('users').doc('user2').get());
  });
});

describe('Firestore Rules - Time Entries (Pagination & Query Patterns)', () => {
  test('User can create time entry in their job', async () => {
    const userDb = testEnv
      .authenticatedContext('user1', {
        orgs: { org1: true },
      })
      .firestore();

    // Setup: create job
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().collection('jobs').doc('job1').set({
        orgId: 'org1',
        status: 'active',
        ownerId: 'user1',
        title: 'Paint House',
      });
    });

    // Test: user can create time entry
    await assertSucceeds(
      userDb
        .collection('jobs')
        .doc('job1')
        .collection('timeEntries')
        .add({
          userId: 'user1',
          orgId: 'org1',
          clockIn: new Date(),
          jobId: 'job1',
        })
    );
  });

  test('User can read their own time entries', async () => {
    const userDb = testEnv
      .authenticatedContext('user1', {
        orgs: { org1: true },
      })
      .firestore();

    // Setup: create job and time entry
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().collection('jobs').doc('job1').set({
        orgId: 'org1',
        status: 'active',
        ownerId: 'user1',
        title: 'Paint House',
      });
      
      await context
        .firestore()
        .collection('jobs')
        .doc('job1')
        .collection('timeEntries')
        .doc('entry1')
        .set({
          userId: 'user1',
          orgId: 'org1',
          clockIn: new Date(),
          jobId: 'job1',
        });
    });

    // Test: user can read their time entry
    await assertSucceeds(
      userDb
        .collection('jobs')
        .doc('job1')
        .collection('timeEntries')
        .doc('entry1')
        .get()
    );
  });

  test('User cannot create time entry for another user', async () => {
    const userDb = testEnv
      .authenticatedContext('user1', {
        orgs: { org1: true },
      })
      .firestore();

    // Setup: create job
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().collection('jobs').doc('job1').set({
        orgId: 'org1',
        status: 'active',
        ownerId: 'user2',
        title: 'Paint House',
      });
    });

    // Test: user1 cannot create time entry for user2
    await assertFails(
      userDb
        .collection('jobs')
        .doc('job1')
        .collection('timeEntries')
        .add({
          userId: 'user2', // Different user
          orgId: 'org1',
          clockIn: new Date(),
          jobId: 'job1',
        })
    );
  });

  test('Admin can read any time entries in their org', async () => {
    const adminDb = testEnv
      .authenticatedContext('admin1', {
        roles: { admin: true },
        orgs: { org1: true },
      })
      .firestore();

    // Setup: create job and time entry
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().collection('jobs').doc('job1').set({
        orgId: 'org1',
        status: 'active',
        ownerId: 'user1',
        title: 'Paint House',
      });
      
      await context
        .firestore()
        .collection('jobs')
        .doc('job1')
        .collection('timeEntries')
        .doc('entry1')
        .set({
          userId: 'user1',
          orgId: 'org1',
          clockIn: new Date(),
          jobId: 'job1',
        });
    });

    // Test: admin can read any time entry
    await assertSucceeds(
      adminDb
        .collection('jobs')
        .doc('job1')
        .collection('timeEntries')
        .doc('entry1')
        .get()
    );
  });

  test('Time entries cannot be updated by client', async () => {
    const userDb = testEnv
      .authenticatedContext('user1', {
        orgs: { org1: true },
      })
      .firestore();

    // Setup: create job and time entry
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().collection('jobs').doc('job1').set({
        orgId: 'org1',
        status: 'active',
        ownerId: 'user1',
        title: 'Paint House',
      });
      
      await context
        .firestore()
        .collection('jobs')
        .doc('job1')
        .collection('timeEntries')
        .doc('entry1')
        .set({
          userId: 'user1',
          orgId: 'org1',
          clockIn: new Date(),
          jobId: 'job1',
        });
    });

    // Test: cannot update time entry (server-side only)
    await assertFails(
      userDb
        .collection('jobs')
        .doc('job1')
        .collection('timeEntries')
        .doc('entry1')
        .update({
          clockOut: new Date(),
        })
    );
  });

  test('Time entries cannot be deleted by client', async () => {
    const userDb = testEnv
      .authenticatedContext('user1', {
        orgs: { org1: true },
      })
      .firestore();

    // Setup: create job and time entry
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().collection('jobs').doc('job1').set({
        orgId: 'org1',
        status: 'active',
        ownerId: 'user1',
        title: 'Paint House',
      });
      
      await context
        .firestore()
        .collection('jobs')
        .doc('job1')
        .collection('timeEntries')
        .doc('entry1')
        .set({
          userId: 'user1',
          orgId: 'org1',
          clockIn: new Date(),
          jobId: 'job1',
        });
    });

    // Test: cannot delete time entry (server-side only)
    await assertFails(
      userDb
        .collection('jobs')
        .doc('job1')
        .collection('timeEntries')
        .doc('entry1')
        .delete()
    );
  });
});
