/**
 * Firebase Storage Rules Tests
 *
 * Tests storage security rules for:
 * - Profile image uploads (user-owned)
 * - Project images (admin-only)
 * - Estimate/Invoice PDFs (admin-only)
 * - Job site photos (crew assignment-based)
 * - File type validation (images, PDFs)
 * - File size limits (10MB max)
 * - Authentication requirements
 *
 * Prerequisites:
 * - Storage emulator running: firebase emulators:start --only storage
 * - Run with: FIREBASE_STORAGE_EMULATOR_HOST=localhost:9199 npm test
 */

import {
  initializeTestEnvironment,
  RulesTestEnvironment,
  assertSucceeds,
  assertFails,
} from '@firebase/rules-unit-testing';
import * as fs from 'fs';
import * as path from 'path';

const RUN_RULES = !!process.env.FIREBASE_STORAGE_EMULATOR_HOST;

if (!RUN_RULES) {
  test('Storage rules tests skipped (FIREBASE_STORAGE_EMULATOR_HOST not set)', () => {
    expect(true).toBe(true);
  });
} else {
  // Resolve storage.rules path from project root
  const candidatePaths = [
    path.resolve(process.cwd(), 'storage.rules'),
    path.resolve(process.cwd(), '../storage.rules'),
    path.resolve(process.cwd(), '../../storage.rules'),
  ];
  const rulesPath = candidatePaths.find((p) => fs.existsSync(p));
  if (!rulesPath) {
    throw new Error('storage.rules not found in expected locations');
  }

  let testEnv: RulesTestEnvironment;
  const PROJECT_ID = 'sierra-painting-test';
  const COMPANY_ID = 'company-123';

  beforeAll(async () => {
    testEnv = await initializeTestEnvironment({
      projectId: PROJECT_ID,
      storage: {
        rules: fs.readFileSync(rulesPath, 'utf8'),
        host: 'localhost',
        port: 9199,
      },
      firestore: {
        host: 'localhost',
        port: 8080,
      },
    });
  });

  afterAll(async () => {
    await testEnv.cleanup();
  });

  afterEach(async () => {
    await testEnv.clearStorage();
    await testEnv.clearFirestore();
  });

  describe('Storage Rules - Authentication', () => {
    test('Deny all unauthenticated access', async () => {
      const unauthedStorage = testEnv.unauthenticatedContext().storage();

      await assertFails(
        unauthedStorage.ref('users/user1/profile/avatar.jpg').getDownloadURL()
      );

      await assertFails(
        unauthedStorage.ref('users/user1/profile/avatar.jpg').put(Buffer.from('test'))
      );
    });

    test('Allow authenticated read for profile images', async () => {
      const storage = testEnv.authenticatedContext('user1').storage();

      // Setup: Upload a file with security rules disabled
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await context
          .storage()
          .ref('users/user2/profile/avatar.jpg')
          .put(Buffer.from('profile image'));
      });

      // Test: user1 can read user2's profile image
      await assertSucceeds(
        storage.ref('users/user2/profile/avatar.jpg').getDownloadURL()
      );
    });
  });

  describe('Storage Rules - Profile Images', () => {
    test('User can upload their own profile image', async () => {
      const storage = testEnv.authenticatedContext('user1').storage();

      const imageBuffer = Buffer.from('fake image content');

      await assertSucceeds(
        storage.ref('users/user1/profile/avatar.jpg').put(imageBuffer, {
          contentType: 'image/jpeg',
        })
      );
    });

    test('User cannot upload to another user\'s profile', async () => {
      const storage = testEnv.authenticatedContext('user1').storage();

      const imageBuffer = Buffer.from('fake image content');

      await assertFails(
        storage.ref('users/user2/profile/avatar.jpg').put(imageBuffer, {
          contentType: 'image/jpeg',
        })
      );
    });

    test('Reject non-image file type for profile', async () => {
      const storage = testEnv.authenticatedContext('user1').storage();

      const pdfBuffer = Buffer.from('fake pdf content');

      await assertFails(
        storage.ref('users/user1/profile/document.pdf').put(pdfBuffer, {
          contentType: 'application/pdf',
        })
      );
    });

    test('Reject file over 10MB for profile', async () => {
      const storage = testEnv.authenticatedContext('user1').storage();

      // Create buffer larger than 10MB (10 * 1024 * 1024 + 1 bytes)
      const largeBuffer = Buffer.alloc(10 * 1024 * 1024 + 1);

      await assertFails(
        storage.ref('users/user1/profile/large.jpg').put(largeBuffer, {
          contentType: 'image/jpeg',
        })
      );
    });

    test('Allow file under 10MB for profile', async () => {
      const storage = testEnv.authenticatedContext('user1').storage();

      // Create buffer under 10MB (1MB)
      const smallBuffer = Buffer.alloc(1024 * 1024);

      await assertSucceeds(
        storage.ref('users/user1/profile/small.jpg').put(smallBuffer, {
          contentType: 'image/jpeg',
        })
      );
    });
  });

  describe('Storage Rules - Project Images (Admin Only)', () => {
    test('Admin can upload project images', async () => {
      const adminStorage = testEnv
        .authenticatedContext('admin1', {
          role: 'admin',
          companyId: COMPANY_ID,
        })
        .storage();

      const imageBuffer = Buffer.from('project image');

      await assertSucceeds(
        adminStorage.ref('projects/proj1/images/before.jpg').put(imageBuffer, {
          contentType: 'image/jpeg',
        })
      );
    });

    test('Non-admin cannot upload project images', async () => {
      const staffStorage = testEnv
        .authenticatedContext('staff1', {
          role: 'staff',
          companyId: COMPANY_ID,
        })
        .storage();

      const imageBuffer = Buffer.from('project image');

      await assertFails(
        staffStorage.ref('projects/proj1/images/before.jpg').put(imageBuffer, {
          contentType: 'image/jpeg',
        })
      );
    });

    test('Crew cannot upload project images', async () => {
      const crewStorage = testEnv
        .authenticatedContext('crew1', {
          role: 'crew',
          companyId: COMPANY_ID,
        })
        .storage();

      const imageBuffer = Buffer.from('project image');

      await assertFails(
        crewStorage.ref('projects/proj1/images/before.jpg').put(imageBuffer, {
          contentType: 'image/jpeg',
        })
      );
    });

    test('Authenticated users can read project images', async () => {
      const storage = testEnv.authenticatedContext('user1').storage();

      // Setup: Upload a project image with rules disabled
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await context
          .storage()
          .ref('projects/proj1/images/before.jpg')
          .put(Buffer.from('project image'));
      });

      // Test: Any authenticated user can read
      await assertSucceeds(
        storage.ref('projects/proj1/images/before.jpg').getDownloadURL()
      );
    });

    test('Reject non-image file type for projects', async () => {
      const adminStorage = testEnv
        .authenticatedContext('admin1', {
          role: 'admin',
          companyId: COMPANY_ID,
        })
        .storage();

      const pdfBuffer = Buffer.from('pdf content');

      await assertFails(
        adminStorage.ref('projects/proj1/images/document.pdf').put(pdfBuffer, {
          contentType: 'application/pdf',
        })
      );
    });
  });

  describe('Storage Rules - Estimate/Invoice PDFs (Admin Only)', () => {
    test('Admin can upload estimate PDFs', async () => {
      const adminStorage = testEnv
        .authenticatedContext('admin1', {
          role: 'admin',
          companyId: COMPANY_ID,
        })
        .storage();

      const pdfBuffer = Buffer.from('pdf content');

      await assertSucceeds(
        adminStorage.ref('estimates/est1/estimate.pdf').put(pdfBuffer, {
          contentType: 'application/pdf',
        })
      );
    });

    test('Non-admin cannot upload estimate PDFs', async () => {
      const managerStorage = testEnv
        .authenticatedContext('manager1', {
          role: 'manager',
          companyId: COMPANY_ID,
        })
        .storage();

      const pdfBuffer = Buffer.from('pdf content');

      await assertFails(
        managerStorage.ref('estimates/est1/estimate.pdf').put(pdfBuffer, {
          contentType: 'application/pdf',
        })
      );
    });

    test('Authenticated users can read estimate PDFs', async () => {
      const storage = testEnv.authenticatedContext('user1').storage();

      // Setup: Upload estimate PDF with rules disabled
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await context
          .storage()
          .ref('estimates/est1/estimate.pdf')
          .put(Buffer.from('pdf content'));
      });

      // Test: Any authenticated user can read
      await assertSucceeds(
        storage.ref('estimates/est1/estimate.pdf').getDownloadURL()
      );
    });

    test('Admin can upload invoice PDFs', async () => {
      const adminStorage = testEnv
        .authenticatedContext('admin1', {
          role: 'admin',
          companyId: COMPANY_ID,
        })
        .storage();

      const pdfBuffer = Buffer.from('invoice pdf');

      await assertSucceeds(
        adminStorage.ref('invoices/inv1/invoice.pdf').put(pdfBuffer, {
          contentType: 'application/pdf',
        })
      );
    });

    test('Reject non-PDF for estimates', async () => {
      const adminStorage = testEnv
        .authenticatedContext('admin1', {
          role: 'admin',
          companyId: COMPANY_ID,
        })
        .storage();

      const imageBuffer = Buffer.from('image content');

      await assertFails(
        adminStorage.ref('estimates/est1/image.jpg').put(imageBuffer, {
          contentType: 'image/jpeg',
        })
      );
    });
  });

  describe('Storage Rules - Job Site Photos (Crew Assignment)', () => {
    test('Admin can upload job site photos', async () => {
      const adminStorage = testEnv
        .authenticatedContext('admin1', {
          role: 'admin',
          companyId: COMPANY_ID,
        })
        .storage();

      const imageBuffer = Buffer.from('job photo');

      await assertSucceeds(
        adminStorage.ref('jobs/job1/photos/site1.jpg').put(imageBuffer, {
          contentType: 'image/jpeg',
        })
      );
    });

    test('Assigned crew can upload job site photos', async () => {
      const crewId = 'crew1';

      // Setup: Create job with assigned crew
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await context.firestore().collection('jobs').doc('job1').set({
          companyId: COMPANY_ID,
          status: 'active',
          assignedCrew: {
            [crewId]: true,
          },
        });
      });

      const crewStorage = testEnv
        .authenticatedContext(crewId, {
          role: 'crew',
          companyId: COMPANY_ID,
        })
        .storage();

      const imageBuffer = Buffer.from('job photo');

      await assertSucceeds(
        crewStorage.ref('jobs/job1/photos/site1.jpg').put(imageBuffer, {
          contentType: 'image/jpeg',
        })
      );
    });

    test('Unassigned crew cannot upload job site photos', async () => {
      const crew1 = 'crew1';
      const crew2 = 'crew2'; // Not assigned

      // Setup: Create job with only crew1 assigned
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await context.firestore().collection('jobs').doc('job1').set({
          companyId: COMPANY_ID,
          status: 'active',
          assignedCrew: {
            [crew1]: true,
            // crew2 not in list
          },
        });
      });

      const crew2Storage = testEnv
        .authenticatedContext(crew2, {
          role: 'crew',
          companyId: COMPANY_ID,
        })
        .storage();

      const imageBuffer = Buffer.from('job photo');

      await assertFails(
        crew2Storage.ref('jobs/job1/photos/site1.jpg').put(imageBuffer, {
          contentType: 'image/jpeg',
        })
      );
    });

    test('Staff cannot upload job site photos unless assigned', async () => {
      const staffId = 'staff1';

      // Setup: Create job without staff member assigned
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await context.firestore().collection('jobs').doc('job1').set({
          companyId: COMPANY_ID,
          status: 'active',
          assignedCrew: {
            crew1: true,
          },
        });
      });

      const staffStorage = testEnv
        .authenticatedContext(staffId, {
          role: 'staff',
          companyId: COMPANY_ID,
        })
        .storage();

      const imageBuffer = Buffer.from('job photo');

      await assertFails(
        staffStorage.ref('jobs/job1/photos/site1.jpg').put(imageBuffer, {
          contentType: 'image/jpeg',
        })
      );
    });

    test('Authenticated users can read job site photos', async () => {
      const storage = testEnv.authenticatedContext('user1').storage();

      // Setup: Upload job photo with rules disabled
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await context
          .storage()
          .ref('jobs/job1/photos/site1.jpg')
          .put(Buffer.from('job photo'));
      });

      // Test: Any authenticated user can read
      await assertSucceeds(
        storage.ref('jobs/job1/photos/site1.jpg').getDownloadURL()
      );
    });

    test('Reject non-image file type for job photos', async () => {
      const adminStorage = testEnv
        .authenticatedContext('admin1', {
          role: 'admin',
          companyId: COMPANY_ID,
        })
        .storage();

      const pdfBuffer = Buffer.from('pdf content');

      await assertFails(
        adminStorage.ref('jobs/job1/photos/document.pdf').put(pdfBuffer, {
          contentType: 'application/pdf',
        })
      );
    });

    test('Reject file over 10MB for job photos', async () => {
      const adminStorage = testEnv
        .authenticatedContext('admin1', {
          role: 'admin',
          companyId: COMPANY_ID,
        })
        .storage();

      // Create buffer larger than 10MB
      const largeBuffer = Buffer.alloc(10 * 1024 * 1024 + 1);

      await assertFails(
        adminStorage.ref('jobs/job1/photos/large.jpg').put(largeBuffer, {
          contentType: 'image/jpeg',
        })
      );
    });
  });

  describe('Storage Rules - Edge Cases', () => {
    test('Deny access to undefined paths', async () => {
      const storage = testEnv.authenticatedContext('user1').storage();

      await assertFails(
        storage.ref('random/path/file.txt').put(Buffer.from('content'))
      );
    });

    test('Admin cannot bypass file size limits', async () => {
      const adminStorage = testEnv
        .authenticatedContext('admin1', {
          role: 'admin',
          companyId: COMPANY_ID,
        })
        .storage();

      const largeBuffer = Buffer.alloc(10 * 1024 * 1024 + 1);

      await assertFails(
        adminStorage.ref('projects/proj1/images/huge.jpg').put(largeBuffer, {
          contentType: 'image/jpeg',
        })
      );
    });

    test('Admin cannot bypass file type restrictions', async () => {
      const adminStorage = testEnv
        .authenticatedContext('admin1', {
          role: 'admin',
          companyId: COMPANY_ID,
        })
        .storage();

      const textBuffer = Buffer.from('text content');

      await assertFails(
        adminStorage.ref('projects/proj1/images/file.txt').put(textBuffer, {
          contentType: 'text/plain',
        })
      );
    });

    test('Crew assignment check handles missing assignedCrew field', async () => {
      const crewId = 'crew1';

      // Setup: Create job WITHOUT assignedCrew field
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await context.firestore().collection('jobs').doc('job1').set({
          companyId: COMPANY_ID,
          status: 'active',
          // No assignedCrew field
        });
      });

      const crewStorage = testEnv
        .authenticatedContext(crewId, {
          role: 'crew',
          companyId: COMPANY_ID,
        })
        .storage();

      const imageBuffer = Buffer.from('job photo');

      await assertFails(
        crewStorage.ref('jobs/job1/photos/site1.jpg').put(imageBuffer, {
          contentType: 'image/jpeg',
        })
      );
    });
  });
}
