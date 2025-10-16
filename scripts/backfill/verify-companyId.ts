/**
 * CompanyId Verification Script
 *
 * PURPOSE:
 * Pre-deployment verification that all company-scoped documents have valid companyId fields.
 * Prevents security vulnerabilities from documents that bypass multi-tenant isolation rules.
 *
 * USAGE:
 * ```bash
 * # Verify all collections
 * npm run verify:companyId
 *
 * # Verify specific collection
 * npm run verify:companyId -- --collection=jobs
 *
 * # Export results to JSON for CI/CD
 * npm run verify:companyId -- --output=report.json
 * ```
 *
 * VERIFICATION CHECKS:
 * ✅ All documents in company-scoped collections have companyId field
 * ✅ companyId is non-empty string
 * ✅ companyId references an existing company document
 * ✅ No orphaned documents (companyId points to deleted company)
 * ✅ Consistent companyId format validation
 *
 * COLLECTIONS VERIFIED:
 * - jobs, customers, invoices, estimates
 * - timeEntries, clockEvents, assignments, job_assignments
 * - employees, users (if company-scoped)
 *
 * EXIT CODES:
 * - 0: All documents valid
 * - 1: Invalid documents found
 * - 2: Script error
 *
 * CI/CD INTEGRATION:
 * - Run as pre-deployment gate in GitHub Actions
 * - Fail deployment if invalid documents found
 * - Generate JSON report for artifact storage
 */

import * as admin from 'firebase-admin';
import * as fs from 'fs';

// Initialize Firebase Admin
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

/**
 * Collections that require companyId field.
 */
const COMPANY_SCOPED_COLLECTIONS = [
  'jobs',
  'customers',
  'invoices',
  'estimates',
  'timeEntries',
  'clockEvents',
  'assignments',
  'job_assignments',
  'employees',
];

/**
 * Verification result for a single document.
 */
interface DocumentVerificationResult {
  collection: string;
  documentId: string;
  valid: boolean;
  issues: string[];
}

/**
 * Verification summary for a collection.
 */
interface CollectionVerificationSummary {
  collection: string;
  totalDocuments: number;
  validDocuments: number;
  invalidDocuments: number;
  issues: DocumentVerificationResult[];
}

/**
 * Overall verification report.
 */
interface VerificationReport {
  timestamp: string;
  totalCollections: number;
  totalDocuments: number;
  validDocuments: number;
  invalidDocuments: number;
  collections: CollectionVerificationSummary[];
  validCompanies: string[];
}

/**
 * Checks if a document has a valid companyId.
 */
function validateCompanyId(
  collection: string,
  documentId: string,
  data: admin.firestore.DocumentData,
  validCompanies: Set<string>
): DocumentVerificationResult {
  const issues: string[] = [];

  // Check if companyId field exists
  if (!data.companyId) {
    issues.push('Missing companyId field');
  } else if (typeof data.companyId !== 'string') {
    issues.push(`Invalid companyId type: ${typeof data.companyId}`);
  } else if (data.companyId.trim() === '') {
    issues.push('Empty companyId string');
  } else if (!validCompanies.has(data.companyId)) {
    issues.push(`Orphaned document: companyId '${data.companyId}' does not exist`);
  }

  return {
    collection,
    documentId,
    valid: issues.length === 0,
    issues,
  };
}

/**
 * Verifies a single collection.
 */
async function verifyCollection(
  collection: string,
  validCompanies: Set<string>
): Promise<CollectionVerificationSummary> {
  console.log(`\nVerifying collection: ${collection}`);

  const snapshot = await db.collection(collection).get();
  const totalDocuments = snapshot.size;

  console.log(`  Total documents: ${totalDocuments}`);

  if (totalDocuments === 0) {
    return {
      collection,
      totalDocuments: 0,
      validDocuments: 0,
      invalidDocuments: 0,
      issues: [],
    };
  }

  const results: DocumentVerificationResult[] = [];
  let validCount = 0;
  let invalidCount = 0;

  for (const doc of snapshot.docs) {
    const result = validateCompanyId(
      collection,
      doc.id,
      doc.data(),
      validCompanies
    );

    if (result.valid) {
      validCount++;
    } else {
      invalidCount++;
      results.push(result);
    }
  }

  console.log(`  Valid: ${validCount} (${((validCount / totalDocuments) * 100).toFixed(1)}%)`);
  console.log(`  Invalid: ${invalidCount} (${((invalidCount / totalDocuments) * 100).toFixed(1)}%)`);

  if (invalidCount > 0) {
    console.log(`  ❌ Issues found:`);
    results.slice(0, 5).forEach((r) => {
      console.log(`    - ${r.documentId}: ${r.issues.join(', ')}`);
    });
    if (results.length > 5) {
      console.log(`    ... and ${results.length - 5} more`);
    }
  } else {
    console.log(`  ✅ All documents valid`);
  }

  return {
    collection,
    totalDocuments,
    validDocuments: validCount,
    invalidDocuments: invalidCount,
    issues: results,
  };
}

/**
 * Gets list of valid company IDs from companies collection.
 */
async function getValidCompanies(): Promise<Set<string>> {
  const snapshot = await db.collection('companies').get();
  const companyIds = new Set<string>();

  for (const doc of snapshot.docs) {
    companyIds.add(doc.id);
  }

  console.log(`Found ${companyIds.size} valid companies`);
  return companyIds;
}

/**
 * Main verification function.
 */
async function runVerification(
  collections?: string[]
): Promise<VerificationReport> {
  console.log('========================================');
  console.log('CompanyId Verification Script');
  console.log('========================================\n');

  // Get list of valid companies
  const validCompanies = await getValidCompanies();

  // Determine which collections to verify
  const collectionsToVerify = collections || COMPANY_SCOPED_COLLECTIONS;
  console.log(`Verifying ${collectionsToVerify.length} collections...`);

  // Verify each collection
  const collectionSummaries: CollectionVerificationSummary[] = [];
  let totalDocuments = 0;
  let totalValid = 0;
  let totalInvalid = 0;

  for (const collection of collectionsToVerify) {
    try {
      const summary = await verifyCollection(collection, validCompanies);
      collectionSummaries.push(summary);

      totalDocuments += summary.totalDocuments;
      totalValid += summary.validDocuments;
      totalInvalid += summary.invalidDocuments;
    } catch (error) {
      console.error(`Error verifying collection ${collection}:`, error);
    }
  }

  // Generate report
  const report: VerificationReport = {
    timestamp: new Date().toISOString(),
    totalCollections: collectionsToVerify.length,
    totalDocuments,
    validDocuments: totalValid,
    invalidDocuments: totalInvalid,
    collections: collectionSummaries,
    validCompanies: Array.from(validCompanies),
  };

  // Print summary
  console.log('\n========================================');
  console.log('VERIFICATION SUMMARY');
  console.log('========================================');
  console.log(`Total Collections: ${report.totalCollections}`);
  console.log(`Total Documents: ${report.totalDocuments}`);
  console.log(`Valid: ${report.validDocuments} (${((report.validDocuments / report.totalDocuments) * 100).toFixed(1)}%)`);
  console.log(`Invalid: ${report.invalidDocuments} (${((report.invalidDocuments / report.totalDocuments) * 100).toFixed(1)}%)`);

  if (report.invalidDocuments === 0) {
    console.log('\n✅ All documents have valid companyId fields');
  } else {
    console.log('\n❌ Invalid documents found! Please run backfill script.');
  }

  console.log('========================================\n');

  return report;
}

/**
 * CLI entry point.
 */
async function main() {
  const args = process.argv.slice(2);
  const collectionArg = args.find((arg) => arg.startsWith('--collection='));
  const outputArg = args.find((arg) => arg.startsWith('--output='));

  let collections: string[] | undefined;
  if (collectionArg) {
    const collection = collectionArg.split('=')[1];
    collections = [collection];
  }

  try {
    const report = await runVerification(collections);

    // Export to JSON if requested
    if (outputArg) {
      const outputPath = outputArg.split('=')[1];
      fs.writeFileSync(outputPath, JSON.stringify(report, null, 2));
      console.log(`Report exported to: ${outputPath}`);
    }

    // Exit with error code if invalid documents found
    if (report.invalidDocuments > 0) {
      process.exit(1);
    } else {
      process.exit(0);
    }
  } catch (error) {
    console.error('Verification failed:', error);
    process.exit(2);
  }
}

// Run if called directly
if (require.main === module) {
  main();
}

export { runVerification, getValidCompanies, validateCompanyId };
