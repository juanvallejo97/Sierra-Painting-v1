/**
 * Field-Level Encryption Service
 *
 * Provides encryption/decryption for sensitive fields in Firestore documents.
 * Uses envelope encryption pattern with AES-256-GCM.
 *
 * SECURITY:
 * - Authenticated encryption (AES-256-GCM) prevents tampering
 * - Envelope encryption: each field encrypted with unique DEK (Data Encryption Key)
 * - DEK encrypted with master key (stored in environment variable)
 * - IV/nonce randomly generated per encryption operation (prevents pattern analysis)
 *
 * USAGE:
 * ```typescript
 * // Encrypt sensitive field before storing
 * const encryptedPhone = await encryptField(customer.phone);
 * await db.collection('customers').doc(id).set({
 *   ...customer,
 *   phone: encryptedPhone,
 *   phoneEncrypted: true, // Flag for decryption on read
 * });
 *
 * // Decrypt on read
 * const doc = await db.collection('customers').doc(id).get();
 * const phone = doc.data()!.phoneEncrypted
 *   ? await decryptField(doc.data()!.phone)
 *   : doc.data()!.phone;
 * ```
 *
 * ENCRYPTED FORMAT:
 * Base64-encoded string: {iv}:{encryptedDEK}:{encryptedData}:{authTag}
 * Example: "a1b2c3d4:e5f6g7h8:i9j0k1l2:m3n4o5p6"
 *
 * FIELDS TO ENCRYPT:
 * - time_entries.notes (may contain sensitive worker comments)
 * - customers.phone (PII)
 * - customers.email (PII)
 * - users.phoneNumber (PII)
 *
 * FUTURE: Migrate master key from env var to Cloud KMS for automatic rotation.
 */

import * as crypto from 'crypto';
import {logger} from 'firebase-functions/v2';

/**
 * Encryption algorithm configuration
 */
const ALGORITHM = 'aes-256-gcm';
const IV_LENGTH = 16; // bytes (128 bits)
const AUTH_TAG_LENGTH = 16; // bytes (128 bits)
const DEK_LENGTH = 32; // bytes (256 bits)
const MASTER_KEY_LENGTH = 32; // bytes (256 bits)

/**
 * Get master encryption key from environment
 *
 * SECURITY: Master key should be:
 * - 256 bits (64 hex characters)
 * - Randomly generated (use `openssl rand -hex 32`)
 * - Stored in Firebase Functions config or Secret Manager
 * - Never committed to version control
 *
 * @returns Master key buffer
 * @throws Error if master key not configured or invalid length
 */
function getMasterKey(): Buffer {
  const masterKeyHex = process.env.ENCRYPTION_MASTER_KEY;

  if (!masterKeyHex) {
    throw new Error(
      'ENCRYPTION_MASTER_KEY not configured. ' +
      'Set environment variable with 256-bit key (64 hex chars). ' +
      'Generate with: openssl rand -hex 32'
    );
  }

  const masterKey = Buffer.from(masterKeyHex, 'hex');

  if (masterKey.length !== MASTER_KEY_LENGTH) {
    throw new Error(
      `Invalid ENCRYPTION_MASTER_KEY length: ${masterKey.length} bytes. ` +
      `Expected ${MASTER_KEY_LENGTH} bytes (64 hex characters).`
    );
  }

  return masterKey;
}

/**
 * Encrypt a field value using envelope encryption
 *
 * Process:
 * 1. Generate random Data Encryption Key (DEK)
 * 2. Encrypt plaintext with DEK using AES-256-GCM
 * 3. Encrypt DEK with master key
 * 4. Return combined base64 string: {iv}:{encryptedDEK}:{ciphertext}:{authTag}
 *
 * @param plaintext - Value to encrypt (will be converted to string)
 * @returns Base64-encoded encrypted string
 * @throws Error if encryption fails
 */
export async function encryptField(plaintext: string | null | undefined): Promise<string | null> {
  // Handle null/undefined
  if (plaintext === null || plaintext === undefined) {
    return null;
  }

  try {
    const masterKey = getMasterKey();

    // Generate random DEK for this field
    const dek = crypto.randomBytes(DEK_LENGTH);

    // Generate random IV for data encryption
    const dataIv = crypto.randomBytes(IV_LENGTH);

    // Encrypt plaintext with DEK
    const dataCipher = crypto.createCipheriv(ALGORITHM, dek, dataIv);
    const encryptedData = Buffer.concat([
      dataCipher.update(plaintext, 'utf8'),
      dataCipher.final(),
    ]);
    const dataAuthTag = dataCipher.getAuthTag();

    // Encrypt DEK with master key
    const dekIv = crypto.randomBytes(IV_LENGTH);
    const dekCipher = crypto.createCipheriv(ALGORITHM, masterKey, dekIv);
    const encryptedDEK = Buffer.concat([
      dekCipher.update(dek),
      dekCipher.final(),
    ]);
    const dekAuthTag = dekCipher.getAuthTag();

    // Combine into single base64 string
    // Format: {dataIv}:{dekIv}:{encryptedDEK}:{dekAuthTag}:{encryptedData}:{dataAuthTag}
    const combined = Buffer.concat([
      dataIv,
      dekIv,
      encryptedDEK,
      dekAuthTag,
      encryptedData,
      dataAuthTag,
    ]);

    return combined.toString('base64');
  } catch (error) {
    logger.error('Encryption failed', {error});
    throw new Error(`Field encryption failed: ${error instanceof Error ? error.message : 'unknown error'}`);
  }
}

/**
 * Decrypt a field value encrypted with encryptField()
 *
 * Process:
 * 1. Parse base64 string into components
 * 2. Decrypt DEK using master key
 * 3. Decrypt ciphertext using DEK
 * 4. Verify authentication tags (prevents tampering)
 *
 * @param encryptedValue - Base64-encoded encrypted string from encryptField()
 * @returns Decrypted plaintext string
 * @throws Error if decryption fails or authentication fails
 */
export async function decryptField(encryptedValue: string | null | undefined): Promise<string | null> {
  // Handle null/undefined
  if (encryptedValue === null || encryptedValue === undefined) {
    return null;
  }

  try {
    const masterKey = getMasterKey();

    // Parse combined buffer
    const combined = Buffer.from(encryptedValue, 'base64');

    let offset = 0;
    const dataIv = combined.subarray(offset, offset + IV_LENGTH);
    offset += IV_LENGTH;

    const dekIv = combined.subarray(offset, offset + IV_LENGTH);
    offset += IV_LENGTH;

    const encryptedDEK = combined.subarray(offset, offset + DEK_LENGTH);
    offset += DEK_LENGTH;

    const dekAuthTag = combined.subarray(offset, offset + AUTH_TAG_LENGTH);
    offset += AUTH_TAG_LENGTH;

    const encryptedData = combined.subarray(offset, combined.length - AUTH_TAG_LENGTH);
    const dataAuthTag = combined.subarray(combined.length - AUTH_TAG_LENGTH);

    // Decrypt DEK with master key
    const dekDecipher = crypto.createDecipheriv(ALGORITHM, masterKey, dekIv);
    dekDecipher.setAuthTag(dekAuthTag);
    const dek = Buffer.concat([
      dekDecipher.update(encryptedDEK),
      dekDecipher.final(),
    ]);

    // Decrypt data with DEK
    const dataDecipher = crypto.createDecipheriv(ALGORITHM, dek, dataIv);
    dataDecipher.setAuthTag(dataAuthTag);
    const plaintext = Buffer.concat([
      dataDecipher.update(encryptedData),
      dataDecipher.final(),
    ]);

    return plaintext.toString('utf8');
  } catch (error) {
    logger.error('Decryption failed', {error});
    throw new Error(`Field decryption failed: ${error instanceof Error ? error.message : 'unknown error'}`);
  }
}

/**
 * Batch encrypt multiple fields in a document
 *
 * Useful for encrypting entire documents before storing.
 *
 * @param data - Object with fields to encrypt
 * @param fieldsToEncrypt - Array of field names to encrypt
 * @returns New object with encrypted fields and metadata flags
 *
 * @example
 * const encrypted = await encryptFields(customer, ['phone', 'email']);
 * // Result: { ...customer, phone: "abc123...", email: "def456...", _encrypted: ['phone', 'email'] }
 */
export async function encryptFields<T extends Record<string, any>>(
  data: T,
  fieldsToEncrypt: Array<keyof T>
): Promise<T & {_encrypted: string[]}> {
  const result = {...data, _encrypted: [] as string[]};

  for (const field of fieldsToEncrypt) {
    if (data[field] !== null && data[field] !== undefined) {
      result[field] = await encryptField(String(data[field])) as any;
      result._encrypted.push(String(field));
    }
  }

  return result;
}

/**
 * Batch decrypt multiple fields in a document
 *
 * @param data - Object with encrypted fields
 * @returns New object with decrypted fields (no metadata flags)
 *
 * @example
 * const decrypted = await decryptFields(doc.data(), doc.data()._encrypted || []);
 */
export async function decryptFields<T extends Record<string, any>>(
  data: T,
  fieldsToDecrypt: string[]
): Promise<Omit<T, '_encrypted'>> {
  const result = {...data} as any;

  for (const field of fieldsToDecrypt) {
    if (result[field]) {
      result[field] = await decryptField(String(result[field]));
    }
  }

  // Remove metadata flag
  delete result._encrypted;

  return result as Omit<T, '_encrypted'>;
}

/**
 * Generate a new random master key
 *
 * This is a utility function for initial setup or key rotation.
 * The generated key should be stored in Firebase Functions config or Secret Manager.
 *
 * @returns 256-bit master key as hex string (64 characters)
 *
 * @example
 * const newKey = generateMasterKey();
 * // Set environment variable: ENCRYPTION_MASTER_KEY={newKey}
 */
export function generateMasterKey(): string {
  return crypto.randomBytes(MASTER_KEY_LENGTH).toString('hex');
}
