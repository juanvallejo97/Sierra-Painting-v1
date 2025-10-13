# Job Schema

**Collection:** `/jobs/{jobId}`
**Version:** 2.0
**Last Updated:** 2025-10-12

---

## Overview

Represents a job site where workers can clock in/out. Each job has a geofence (GPS boundary) that workers must be within to clock in.

**Purpose:**
- Define work site locations with GPS coordinates
- Enforce geofence boundaries for time tracking
- Track job status and metadata

---

## Canonical Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `jobId` | `string` | ✅ | Document ID, unique job identifier |
| `companyId` | `string` | ✅ | Company that owns this job |
| `name` | `string` | ✅ | Job site name/description |
| `address` | `string` | ✅ | Physical address of job site |
| `geofence` | `Geofence` | ✅ | GPS boundary definition (nested object) |
| `active` | `boolean` | ✅ | Whether job is currently accepting clock ins |
| `createdAt` | `Timestamp` | ✅ | Job creation timestamp |
| `updatedAt` | `Timestamp` | ✅ | Last update timestamp |

---

## Geofence Nested Object

**CRITICAL:** Geofence is a **nested object**, not top-level fields.

```typescript
geofence: {
  lat: number;      // Latitude in degrees (-90 to 90)
  lng: number;      // Longitude in degrees (-180 to 180)
  radiusM: number;  // Radius in meters (minimum 75m, maximum 250m)
}
```

**Example:**
```json
{
  "jobId": "job-sf-painted-ladies",
  "companyId": "company-sierra-painting",
  "name": "SF Painted Ladies Exterior",
  "address": "710 Steiner St, San Francisco, CA 94117",
  "geofence": {
    "lat": 37.7793,
    "lng": -122.4193,
    "radiusM": 150
  },
  "active": true,
  "createdAt": "2025-01-15T10:00:00Z",
  "updatedAt": "2025-01-15T10:00:00Z"
}
```

---

## Geofence Validation Rules

| Rule | Value | Rationale |
|------|-------|-----------|
| Minimum radius | 75m | Prevents overly strict geofences (GPS drift) |
| Maximum radius | 250m | Prevents overly permissive geofences |
| Default radius | 100m | Balanced for most job sites |
| Accuracy buffer | max(GPS accuracy, 15m) | Added to radius for validation |

**Formula:**
```
effectiveRadius = clamp(baseRadiusM, 75, 250) + max(gpsAccuracy, 15)
isWithinGeofence = haversineDistance(workerLoc, jobLoc) <= effectiveRadius
```

---

## TypeScript Interface

```typescript
// functions/src/types.ts
export interface Geofence {
  lat: number;
  lng: number;
  radiusM: number;
}

export interface Job {
  jobId: string;
  companyId: string;
  name: string;
  address: string;
  geofence: Geofence;  // ← NESTED OBJECT
  active: boolean;
  createdAt: FirebaseFirestore.Timestamp;
  updatedAt: FirebaseFirestore.Timestamp;
}
```

---

## Dart Model

```dart
// lib/core/models/job.dart
class Geofence {
  final double lat;
  final double lng;
  final double radiusM;

  Geofence({
    required this.lat,
    required this.lng,
    required this.radiusM,
  });

  factory Geofence.fromMap(Map<String, dynamic> map) {
    return Geofence(
      lat: (map['lat'] as num).toDouble(),
      lng: (map['lng'] as num).toDouble(),
      radiusM: (map['radiusM'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toMap() => {
    'lat': lat,
    'lng': lng,
    'radiusM': radiusM,
  };
}

class Job {
  final String jobId;
  final String companyId;
  final String name;
  final String address;
  final Geofence geofence;
  final bool active;
  final DateTime createdAt;
  final DateTime updatedAt;

  Job({
    required this.jobId,
    required this.companyId,
    required this.name,
    required this.address,
    required this.geofence,
    required this.active,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Job.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Job(
      jobId: doc.id,
      companyId: data['companyId'] as String,
      name: data['name'] as String,
      address: data['address'] as String,
      geofence: Geofence.fromMap(data['geofence'] as Map<String, dynamic>),
      active: data['active'] as bool,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }
}
```

---

## Firestore Security Rules

```javascript
match /jobs/{jobId} {
  // Anyone in the same company can read jobs
  allow read: if authed()
    && resource.data.companyId == request.auth.token.companyId;

  // Only admins/managers can create jobs
  allow create: if authed()
    && hasAnyRole(['admin', 'manager'])
    && request.resource.data.companyId == request.auth.token.companyId
    && request.resource.data.keys().hasAll(['jobId', 'companyId', 'name', 'address', 'geofence', 'active'])
    && request.resource.data.geofence.keys().hasAll(['lat', 'lng', 'radiusM']);

  // Only admins/managers can update jobs
  allow update: if authed()
    && hasAnyRole(['admin', 'manager'])
    && resource.data.companyId == request.auth.token.companyId
    && request.resource.data.companyId == resource.data.companyId;

  // Only admins can delete jobs
  allow delete: if authed()
    && hasAnyRole(['admin'])
    && resource.data.companyId == request.auth.token.companyId;
}
```

---

## Cloud Function Usage

### Reading Geofence (CORRECT)

```typescript
// functions/src/timeclock.ts
const jobSnap = await db.collection('jobs').doc(jobId).get();
const job = jobSnap.data() as Job;

// Access nested geofence
const { lat, lng, radiusM } = job.geofence;

// Calculate distance
const distance = haversine(
  { lat: job.geofence.lat, lng: job.geofence.lng },
  { lat: workerLat, lng: workerLng }
);
```

### Legacy Fallback (Temporary - Remove by 2025-10-26)

```typescript
// Support old flat structure during migration
const gf = job.geofence ?? {
  lat: job.lat,  // Legacy field
  lng: job.lng,  // Legacy field
  radiusM: job.radiusM || job.radiusMeters  // Legacy fields
};

if (!gf.lat || !gf.lng || !gf.radiusM) {
  throw new functions.HttpsError('failed-precondition', 'Job geofence missing or invalid');
}
```

---

## Setup Script Example

```javascript
// tools/setup_test_data.cjs
await db.collection('jobs').doc('job-sf-painted-ladies').set({
  jobId: 'job-sf-painted-ladies',
  companyId: 'company-sierra-painting',
  name: 'SF Painted Ladies Exterior',
  address: '710 Steiner St, San Francisco, CA 94117',
  geofence: {
    lat: 37.7793,
    lng: -122.4193,
    radiusM: 150
  },
  active: true,
  createdAt: admin.firestore.FieldValue.serverTimestamp(),
  updatedAt: admin.firestore.FieldValue.serverTimestamp(),
});
```

---

## Queries

### Get Active Jobs for Company
```dart
final jobs = await db
  .collection('jobs')
  .where('companyId', isEqualTo: currentCompanyId)
  .where('active', isEqualTo: true)
  .orderBy('name')
  .get();
```

### Get Job by ID
```typescript
const jobRef = db.collection('jobs').doc(jobId);
const jobSnap = await jobRef.get();
if (!jobSnap.exists) {
  throw new Error('Job not found');
}
const job = jobSnap.data() as Job;
```

---

## Migration Notes

**Legacy Fields (DEPRECATED):**
- ~~`lat`~~ (top-level) → Use `geofence.lat`
- ~~`lng`~~ (top-level) → Use `geofence.lng`
- ~~`radiusM`~~ (top-level) → Use `geofence.radiusM`
- ~~`radiusMeters`~~ → Use `geofence.radiusM`
- ~~`latitude`~~ → Use `geofence.lat`
- ~~`longitude`~~ → Use `geofence.lng`

**Removal Date:** 2025-10-26

**Migration Script:** `tools/migrate_job_geofence.cjs`

---

## Validation

| Rule | Check |
|------|-------|
| Geofence latitude | -90 ≤ lat ≤ 90 |
| Geofence longitude | -180 ≤ lng ≤ 180 |
| Geofence radius | 75 ≤ radiusM ≤ 250 |
| Job name | 2-100 characters |
| Address | Not empty |

---

## Related Schemas

- [Assignment](./assignment.md) - Links workers to this job
- [TimeEntry](./time_entry.md) - Clock in/out records for this job

---

**See Also:**
- [Haversine Distance Formula](https://en.wikipedia.org/wiki/Haversine_formula)
- [GPS Accuracy & Drift](https://www.gps.gov/systems/gps/performance/accuracy/)
