# Field-Level Encryption Guide

**Version:** 1.0
**Last Updated:** 2025-10-12
**Status:** ⚠️ Implementation Ready (Master key setup required)

---

## Overview

Field-level encryption protects sensitive data at rest in Firestore using AES-256-GCM with envelope encryption. This ensures that even if an attacker gains access to the database, they cannot read encrypted fields without the master encryption key.

**Encrypted Fields:**
- `time_entries.notes` - May contain sensitive worker comments
- `customers.phone` - PII (personally identifiable information)
- `customers.email` - PII

**Why Encrypt at Field Level (Not Database Level)?**
- **Selective encryption**: Only sensitive fields encrypted (performance, cost)
- **Query capability**: Non-encrypted fields remain searchable
- **Compliance**: Meets GDPR/CCPA "privacy by design" requirements
- **Defense in depth**: Additional layer beyond Firestore security rules

---

## Security Architecture

### Envelope Encryption

Each field is encrypted using a two-layer approach:

```
┌──────────────────────────────────────────────────────────────┐
│  Plaintext: "+1-555-123-4567"                                │
└──────────────────────────────────────────────────────────────┘
                           │
                           ▼
┌──────────────────────────────────────────────────────────────┐
│  1. Generate random DEK (Data Encryption Key)                │
│     DEK = random 256 bits                                     │
└──────────────────────────────────────────────────────────────┘
                           │
                           ▼
┌──────────────────────────────────────────────────────────────┐
│  2. Encrypt plaintext with DEK                                │
│     Ciphertext = AES-256-GCM(plaintext, DEK, random IV)      │
└──────────────────────────────────────────────────────────────┘
                           │
                           ▼
┌──────────────────────────────────────────────────────────────┐
│  3. Encrypt DEK with master key                               │
│     EncryptedDEK = AES-256-GCM(DEK, MasterKey, random IV)    │
└──────────────────────────────────────────────────────────────┘
                           │
                           ▼
┌──────────────────────────────────────────────────────────────┐
│  4. Combine and encode as base64                              │
│     Result: "abc123def456..."                                 │
└──────────────────────────────────────────────────────────────┘
```

**Benefits:**
- **Unique DEK per field**: Each encrypted value uses different key (prevents pattern analysis)
- **Fast key rotation**: Only master key needs rotation, not every encrypted field
- **Tamper detection**: GCM auth tags prevent undetected modification

### Encrypted Format

Stored format: Base64-encoded binary containing:
```
[dataIV][dekIV][encryptedDEK][dekAuthTag][encryptedData][dataAuthTag]
```

| Component | Size | Description |
|-----------|------|-------------|
| dataIV | 16 bytes | Initialization vector for data encryption |
| dekIV | 16 bytes | Initialization vector for DEK encryption |
| encryptedDEK | 32 bytes | Data encryption key (encrypted with master key) |
| dekAuthTag | 16 bytes | Authentication tag for DEK (prevents tampering) |
| encryptedData | Variable | Encrypted plaintext |
| dataAuthTag | 16 bytes | Authentication tag for data (prevents tampering) |

**Total overhead**: 96 bytes + encrypted data length

---

## Setup Instructions

### Phase 1: Generate Master Key

**On your local machine (secure environment):**

```bash
# Generate 256-bit master key
openssl rand -hex 32

# Output example:
# a1b2c3d4e5f6...
```

**⚠️ SECURITY WARNING**: This key protects all encrypted data. Store securely!

---

### Phase 2: Configure Environment

#### Local Development

Create `functions/.env.local` (not committed to git):
```bash
ENCRYPTION_MASTER_KEY=a1b2c3d4e5f6... # Your generated key (64 hex chars)
```

#### Staging Environment

```bash
firebase functions:config:set \
  encryption.master_key="a1b2c3d4e5f6..." \
  --project sierra-painting-staging

# Deploy functions to pick up new config
firebase deploy --only functions --project sierra-painting-staging
```

#### Production Environment

**Use Google Secret Manager (recommended):**

```bash
# Create secret
echo -n "a1b2c3d4e5f6..." | gcloud secrets create encryption-master-key \
  --data-file=- \
  --project=sierra-painting-prod

# Grant Cloud Functions access
gcloud secrets add-iam-policy-binding encryption-master-key \
  --member="serviceAccount:PROJECT_ID@appspot.gserviceaccount.com" \
  --role="roles/secretmanager.secretAccessor" \
  --project=sierra-painting-prod

# Update functions to use secret
# In functions/src/index.ts:
import {defineSecret} from 'firebase-functions/params';

const encryptionKey = defineSecret('ENCRYPTION_MASTER_KEY');

export const myFunction = onCall(
  {secrets: [encryptionKey]},
  async (request) => {
    // Secret available as process.env.ENCRYPTION_MASTER_KEY
  }
);
```

---

## Usage Examples

### Encrypting Time Entry Notes

**Backend (Cloud Functions):**

```typescript
import {encryptFields, decryptFields} from './middleware/encryption';

// Clock out function
export const clockOut = onCall(async (request) => {
  const {notes} = request.data;

  // Encrypt notes before storing
  const timeEntry = {
    userId: request.auth!.uid,
    clockOutTime: Timestamp.now(),
    notes: notes,
    // ... other fields
  };

  const encrypted = await encryptFields(timeEntry, ['notes']);

  await db.collection('time_entries').doc(entryId).update(encrypted);

  return {success: true};
});

// Get time entries function
export const getTimeEntries = onCall(async (request) => {
  const snapshot = await db.collection('time_entries')
    .where('userId', '==', request.auth!.uid)
    .get();

  const entries = [];
  for (const doc of snapshot.docs) {
    const data = doc.data();

    // Decrypt if encrypted
    const decrypted = data._encrypted
      ? await decryptFields(data, data._encrypted)
      : data;

    entries.push({id: doc.id, ...decrypted});
  }

  return entries;
});
```

**Frontend (Flutter):**

```dart
// No changes needed! Encryption transparent to client.
final response = await api.clockOut(
  ClockOutRequest(
    entryId: entryId,
    notes: 'Worker left early due to illness',
  ),
);
```

---

### Encrypting Customer PII

**Backend:**

```typescript
import {encryptField, decryptField} from './middleware/encryption';

// Create customer
export const createCustomer = onCall(async (request) => {
  const {name, phone, email, address} = request.data;

  // Encrypt PII fields
  const customer = {
    companyId: request.auth!.token.companyId,
    name: name,
    phone: await encryptField(phone),
    email: await encryptField(email),
    address: address, // Not encrypted (needed for geofencing)
    createdAt: Timestamp.now(),
    _encrypted: ['phone', 'email'], // Track encrypted fields
  };

  const docRef = await db.collection('customers').add(customer);

  return {id: docRef.id};
});

// Get customer details
export const getCustomer = onCall(async (request) => {
  const doc = await db.collection('customers')
    .doc(request.data.customerId)
    .get();

  if (!doc.exists) {
    throw new HttpsError('not-found', 'Customer not found');
  }

  const data = doc.data()!;

  // Decrypt PII fields
  const customer = {
    id: doc.id,
    ...data,
    phone: data._encrypted?.includes('phone')
      ? await decryptField(data.phone)
      : data.phone,
    email: data._encrypted?.includes('email')
      ? await decryptField(data.email)
      : data.email,
  };

  delete customer._encrypted; // Remove metadata

  return customer;
});
```

---

### Batch Operations

**Encrypting multiple fields:**

```typescript
import {encryptFields} from './middleware/encryption';

const customer = {
  name: 'John Doe',
  phone: '+1-555-123-4567',
  email: 'john@example.com',
  address: '123 Main St',
};

// Encrypt phone and email only
const encrypted = await encryptFields(customer, ['phone', 'email']);

// Result:
// {
//   name: 'John Doe',
//   phone: 'abc123def456...', // encrypted
//   email: 'xyz789ghi012...', // encrypted
//   address: '123 Main St',
//   _encrypted: ['phone', 'email']
// }
```

**Decrypting multiple fields:**

```typescript
import {decryptFields} from './middleware/encryption';

const doc = await db.collection('customers').doc(id).get();
const data = doc.data()!;

// Decrypt all fields marked as encrypted
const decrypted = await decryptFields(data, data._encrypted || []);

// Result: Original plaintext values restored, _encrypted removed
```

---

## Testing

### Run Unit Tests

```bash
cd functions
npm test -- encryption.test.ts
```

### Manual Testing

**1. Test encryption/decryption:**

```typescript
// functions/src/test/test-encryption.ts
import {encryptField, decryptField} from '../middleware/encryption';

(async () => {
  process.env.ENCRYPTION_MASTER_KEY = 'a1b2c3d4...'; // Your test key

  const plaintext = 'sensitive data';
  console.log('Plaintext:', plaintext);

  const encrypted = await encryptField(plaintext);
  console.log('Encrypted:', encrypted);

  const decrypted = await decryptField(encrypted!);
  console.log('Decrypted:', decrypted);

  console.assert(plaintext === decrypted, 'Decryption failed!');
  console.log('✅ Encryption test passed');
})();
```

**2. Test with Firestore emulator:**

```bash
# Start emulators
firebase emulators:start --only functions,firestore

# In another terminal
curl -X POST http://localhost:5001/PROJECT_ID/us-east4/testEncryption \
  -H "Content-Type: application/json" \
  -d '{"data": {"value": "test"}}'
```

---

## Key Rotation

**When to rotate:**
- Annually (proactive security)
- After employee departure (if they had key access)
- After security incident

**Process:**

1. **Generate new master key:**
   ```bash
   openssl rand -hex 32
   ```

2. **Deploy re-encryption function:**
   ```typescript
   export const rotateEncryptionKey = onCall(
     {secrets: ['OLD_KEY', 'NEW_KEY']},
     async (request) => {
       // Admin-only
       if (request.auth!.token.role !== 'admin') {
         throw new HttpsError('permission-denied', 'Admin only');
       }

       const collections = ['time_entries', 'customers'];

       for (const collectionName of collections) {
         const snapshot = await db.collection(collectionName)
           .where('_encrypted', '!=', null)
           .get();

         for (const doc of snapshot.docs) {
           const data = doc.data();

           // Decrypt with old key
           process.env.ENCRYPTION_MASTER_KEY = process.env.OLD_KEY;
           const decrypted = await decryptFields(data, data._encrypted);

           // Re-encrypt with new key
           process.env.ENCRYPTION_MASTER_KEY = process.env.NEW_KEY;
           const reencrypted = await encryptFields(decrypted, data._encrypted);

           await doc.ref.update(reencrypted);
         }
       }

       return {success: true, rotatedDocs: snapshot.size};
     }
   );
   ```

3. **Run rotation:**
   ```bash
   firebase functions:call rotateEncryptionKey --data '{}'
   ```

4. **Update environment:**
   ```bash
   firebase functions:config:set encryption.master_key="NEW_KEY"
   firebase deploy --only functions
   ```

---

## Performance Impact

### Encryption Overhead

| Operation | Overhead | Notes |
|-----------|----------|-------|
| Encrypt single field | ~1-2 ms | Includes random key generation |
| Decrypt single field | ~1 ms | Slightly faster than encryption |
| Batch encrypt (5 fields) | ~5-10 ms | Parallelizable |
| Storage overhead | +96 bytes per field | IV, DEK, auth tags |

**Recommendation**: Encrypt only truly sensitive fields. Do NOT encrypt:
- IDs (needed for queries)
- Timestamps (needed for sorting)
- Public data (address, job site location)

### Firestore Query Limitations

**⚠️ Cannot query on encrypted fields:**

```typescript
// ❌ This won't work (phone is encrypted)
db.collection('customers').where('phone', '==', '+1-555-123-4567').get();

// ✅ Query on non-encrypted field, decrypt results
const snapshot = await db.collection('customers')
  .where('name', '==', 'John Doe')
  .get();

for (const doc of snapshot.docs) {
  const data = doc.data();
  const phone = await decryptField(data.phone);
  if (phone === '+1-555-123-4567') {
    // Found match
  }
}
```

**Solution for searchable PII**: Store encrypted + hash:
```typescript
const phone = '+1-555-123-4567';
const customer = {
  phone: await encryptField(phone), // For display
  phoneHash: crypto.createHash('sha256').update(phone).digest('hex'), // For search
};

// Query by hash
db.collection('customers').where('phoneHash', '==', hashOf('+1-555-123-4567'));
```

---

## Troubleshooting

### Error: "ENCRYPTION_MASTER_KEY not configured"

**Cause**: Environment variable not set

**Fix (local):**
```bash
export ENCRYPTION_MASTER_KEY="a1b2c3d4..."
```

**Fix (production):**
```bash
firebase functions:config:set encryption.master_key="..."
firebase deploy --only functions
```

---

### Error: "Invalid ENCRYPTION_MASTER_KEY length"

**Cause**: Key is not 64 hex characters (256 bits)

**Fix**: Regenerate key with correct length:
```bash
openssl rand -hex 32  # Outputs 64 hex chars
```

---

### Error: "Field decryption failed"

**Possible causes:**
1. **Wrong master key**: Key changed but data encrypted with old key
2. **Data corruption**: Firestore document modified outside encryption API
3. **Tampering detected**: Auth tag mismatch (data was altered)

**Debug:**
```typescript
try {
  const decrypted = await decryptField(value);
} catch (error) {
  console.error('Decryption failed:', {
    error,
    encryptedValue: value?.substring(0, 20) + '...',
    valueLength: value?.length,
  });
  throw error;
}
```

---

## Compliance Checklist

- [x] **GDPR Article 32**: Technical measures to ensure data security (encryption at rest)
- [x] **CCPA Section 1798.81.5**: Reasonable security procedures (encryption of personal info)
- [x] **PCI-DSS 3.4**: Render PAN unreadable (applicable if storing card-on-file)
- [x] **HIPAA Security Rule**: Encryption of ePHI (if handling health data)
- [ ] **Key rotation policy**: Documented and tested (pending Phase 2)
- [ ] **Incident response**: Procedure for compromised key (pending)

---

## Future Enhancements

### Phase 2: Cloud KMS Integration

**Benefits:**
- Automatic key rotation
- Hardware security module (HSM) backing
- Audit logging (who accessed keys, when)

**Implementation:**
```typescript
import {KeyManagementServiceClient} from '@google-cloud/kms';

const kms = new KeyManagementServiceClient();

async function getMasterKeyFromKMS(): Promise<Buffer> {
  const [result] = await kms.decrypt({
    name: 'projects/PROJECT_ID/locations/us-east4/keyRings/encryption/cryptoKeys/master',
    ciphertext: Buffer.from(process.env.ENCRYPTED_DEK, 'base64'),
  });

  return Buffer.from(result.plaintext!);
}
```

### Phase 3: Client-Side Encryption

**Use case**: End-to-end encryption where server never sees plaintext

**Limitation**: Cannot use Cloud Functions to process data (search, analytics)

---

## References

- [NIST SP 800-57: Key Management](https://csrc.nist.gov/publications/detail/sp/800-57-part-1/rev-5/final)
- [OWASP Cryptographic Storage Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Cryptographic_Storage_Cheat_Sheet.html)
- [Node.js Crypto Documentation](https://nodejs.org/api/crypto.html)
- [Google Cloud KMS Documentation](https://cloud.google.com/kms/docs)

---

**Approved By:**
- Engineering: TBD
- Security: TBD
- Legal: TBD

**Next Review Date:** 2026-10-12
