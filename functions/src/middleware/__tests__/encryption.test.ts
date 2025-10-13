/**
 * Tests for field-level encryption service
 */

import {
  encryptField,
  decryptField,
  encryptFields,
  decryptFields,
  generateMasterKey,
} from '../encryption';

describe('Field-Level Encryption', () => {
  // Set up test master key
  const TEST_MASTER_KEY = '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef'; // 64 hex chars = 256 bits

  beforeAll(() => {
    process.env.ENCRYPTION_MASTER_KEY = TEST_MASTER_KEY;
  });

  afterAll(() => {
    delete process.env.ENCRYPTION_MASTER_KEY;
  });

  describe('encryptField / decryptField', () => {
    it('should encrypt and decrypt a string', async () => {
      const plaintext = 'sensitive data';
      const encrypted = await encryptField(plaintext);
      expect(encrypted).toBeTruthy();
      expect(encrypted).not.toBe(plaintext);

      const decrypted = await decryptField(encrypted!);
      expect(decrypted).toBe(plaintext);
    });

    it('should handle phone numbers', async () => {
      const phoneNumber = '+1-555-123-4567';
      const encrypted = await encryptField(phoneNumber);
      const decrypted = await decryptField(encrypted!);
      expect(decrypted).toBe(phoneNumber);
    });

    it('should handle multiline text (notes)', async () => {
      const notes = 'Line 1\nLine 2\nLine 3 with special chars: !@#$%^&*()';
      const encrypted = await encryptField(notes);
      const decrypted = await decryptField(encrypted!);
      expect(decrypted).toBe(notes);
    });

    it('should handle empty string', async () => {
      const encrypted = await encryptField('');
      const decrypted = await decryptField(encrypted!);
      expect(decrypted).toBe('');
    });

    it('should handle null values', async () => {
      const encrypted = await encryptField(null);
      expect(encrypted).toBeNull();

      const decrypted = await decryptField(null);
      expect(decrypted).toBeNull();
    });

    it('should handle undefined values', async () => {
      const encrypted = await encryptField(undefined);
      expect(encrypted).toBeNull();

      const decrypted = await decryptField(undefined);
      expect(decrypted).toBeNull();
    });

    it('should produce different ciphertext for same plaintext', async () => {
      // Different IV each time = different ciphertext (prevents pattern analysis)
      const plaintext = 'same value';
      const encrypted1 = await encryptField(plaintext);
      const encrypted2 = await encryptField(plaintext);

      expect(encrypted1).not.toBe(encrypted2);

      // But both decrypt to same value
      const decrypted1 = await decryptField(encrypted1!);
      const decrypted2 = await decryptField(encrypted2!);
      expect(decrypted1).toBe(plaintext);
      expect(decrypted2).toBe(plaintext);
    });

    it('should reject tampered ciphertext', async () => {
      const plaintext = 'important data';
      const encrypted = await encryptField(plaintext);

      // Tamper with ciphertext (flip a bit)
      const tamperedBuffer = Buffer.from(encrypted!, 'base64');
      tamperedBuffer[20] ^= 0xFF; // Flip all bits in byte 20
      const tampered = tamperedBuffer.toString('base64');

      // Decryption should fail (auth tag mismatch)
      await expect(decryptField(tampered)).rejects.toThrow();
    });

    it('should fail without master key', async () => {
      delete process.env.ENCRYPTION_MASTER_KEY;

      await expect(encryptField('test')).rejects.toThrow('ENCRYPTION_MASTER_KEY not configured');

      // Restore for other tests
      process.env.ENCRYPTION_MASTER_KEY = TEST_MASTER_KEY;
    });

    it('should fail with invalid master key length', async () => {
      process.env.ENCRYPTION_MASTER_KEY = 'tooshort'; // Not 64 hex chars

      await expect(encryptField('test')).rejects.toThrow('Invalid ENCRYPTION_MASTER_KEY length');

      // Restore for other tests
      process.env.ENCRYPTION_MASTER_KEY = TEST_MASTER_KEY;
    });
  });

  describe('encryptFields / decryptFields', () => {
    it('should encrypt multiple fields in object', async () => {
      const customer = {
        id: 'cust-123',
        name: 'John Doe',
        phone: '+1-555-123-4567',
        email: 'john@example.com',
        address: '123 Main St',
      };

      const encrypted = await encryptFields(customer, ['phone', 'email']);

      // Check encrypted fields are different
      expect(encrypted.phone).not.toBe(customer.phone);
      expect(encrypted.email).not.toBe(customer.email);

      // Check unencrypted fields unchanged
      expect(encrypted.id).toBe(customer.id);
      expect(encrypted.name).toBe(customer.name);
      expect(encrypted.address).toBe(customer.address);

      // Check metadata
      expect(encrypted._encrypted).toEqual(['phone', 'email']);
    });

    it('should decrypt multiple fields in object', async () => {
      const customer = {
        id: 'cust-123',
        name: 'John Doe',
        phone: '+1-555-123-4567',
        email: 'john@example.com',
      };

      // Encrypt
      const encrypted = await encryptFields(customer, ['phone', 'email']);

      // Decrypt
      const decrypted = await decryptFields(encrypted, encrypted._encrypted);

      // Check decrypted values match original
      expect(decrypted.phone).toBe(customer.phone);
      expect(decrypted.email).toBe(customer.email);

      // Check metadata removed
      expect((decrypted as any)._encrypted).toBeUndefined();
    });

    it('should handle fields with null values', async () => {
      const data = {
        id: 'test',
        phone: null,
        email: 'test@example.com',
      };

      const encrypted = await encryptFields(data, ['phone', 'email']);

      // Null field not encrypted
      expect(encrypted.phone).toBeNull();
      expect(encrypted._encrypted).toEqual(['email']); // Only email encrypted

      const decrypted = await decryptFields(encrypted, encrypted._encrypted);
      expect(decrypted.phone).toBeNull();
      expect(decrypted.email).toBe(data.email);
    });

    it('should handle empty fields array', async () => {
      const data = {id: 'test', name: 'Test'};
      const encrypted = await encryptFields(data, []);

      expect(encrypted.id).toBe(data.id);
      expect(encrypted.name).toBe(data.name);
      expect(encrypted._encrypted).toEqual([]);
    });
  });

  describe('generateMasterKey', () => {
    it('should generate 64-character hex string', () => {
      const key = generateMasterKey();
      expect(key).toHaveLength(64);
      expect(key).toMatch(/^[0-9a-f]{64}$/);
    });

    it('should generate unique keys', () => {
      const key1 = generateMasterKey();
      const key2 = generateMasterKey();
      expect(key1).not.toBe(key2);
    });

    it('generated key should work for encryption', async () => {
      const newKey = generateMasterKey();
      process.env.ENCRYPTION_MASTER_KEY = newKey;

      const plaintext = 'test with new key';
      const encrypted = await encryptField(plaintext);
      const decrypted = await decryptField(encrypted!);

      expect(decrypted).toBe(plaintext);

      // Restore original key
      process.env.ENCRYPTION_MASTER_KEY = TEST_MASTER_KEY;
    });
  });

  describe('Real-world scenarios', () => {
    it('should handle time entry notes encryption', async () => {
      const timeEntry = {
        id: 'entry-123',
        userId: 'user-456',
        jobId: 'job-789',
        clockInTime: new Date().toISOString(),
        notes: 'Worker requested early dismissal due to weather conditions. Manager approved.',
      };

      const encrypted = await encryptFields(timeEntry, ['notes']);

      // Notes encrypted
      expect(encrypted.notes).not.toBe(timeEntry.notes);
      expect(encrypted._encrypted).toEqual(['notes']);

      // Other fields unchanged
      expect(encrypted.id).toBe(timeEntry.id);
      expect(encrypted.userId).toBe(timeEntry.userId);

      // Decrypt
      const decrypted = await decryptFields(encrypted, encrypted._encrypted);
      expect(decrypted.notes).toBe(timeEntry.notes);
    });

    it('should handle customer PII encryption', async () => {
      const customer = {
        id: 'cust-123',
        companyId: 'comp-456',
        name: 'Acme Corp',
        contactName: 'Jane Smith',
        phone: '+1-555-987-6543',
        email: 'jane@acme.com',
        address: '456 Business Blvd',
        city: 'San Francisco',
        state: 'CA',
        zip: '94102',
      };

      // Encrypt PII fields
      const encrypted = await encryptFields(customer, ['phone', 'email']);

      // PII encrypted
      expect(encrypted.phone).not.toBe(customer.phone);
      expect(encrypted.email).not.toBe(customer.email);

      // Other fields visible
      expect(encrypted.name).toBe(customer.name);
      expect(encrypted.address).toBe(customer.address);

      // Decrypt
      const decrypted = await decryptFields(encrypted, encrypted._encrypted);
      expect(decrypted.phone).toBe(customer.phone);
      expect(decrypted.email).toBe(customer.email);
    });

    it('should handle Unicode and special characters', async () => {
      const text = 'Hello 世界! 🎨 Special chars: <>&"\'';
      const encrypted = await encryptField(text);
      const decrypted = await decryptField(encrypted!);
      expect(decrypted).toBe(text);
    });

    it('should handle very long text', async () => {
      const longText = 'A'.repeat(10000); // 10KB of text
      const encrypted = await encryptField(longText);
      const decrypted = await decryptField(encrypted!);
      expect(decrypted).toBe(longText);
    });
  });

  describe('Key rotation simulation', () => {
    it('should fail to decrypt with wrong master key', async () => {
      const plaintext = 'secret data';

      // Encrypt with key1
      const key1 = generateMasterKey();
      process.env.ENCRYPTION_MASTER_KEY = key1;
      const encrypted = await encryptField(plaintext);

      // Try to decrypt with key2 (should fail)
      const key2 = generateMasterKey();
      process.env.ENCRYPTION_MASTER_KEY = key2;
      await expect(decryptField(encrypted!)).rejects.toThrow();

      // Restore original key
      process.env.ENCRYPTION_MASTER_KEY = TEST_MASTER_KEY;
    });
  });
});
