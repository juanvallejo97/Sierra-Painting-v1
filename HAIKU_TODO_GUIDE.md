# HAIKU TODO GUIDE

This document lists all skeleton files created with `HAIKU TODO` markers.
Use Haiku LLM to fill in the implementation details marked with these comments.

## Story A: Offline Clock-in (COMPLETE except Cloud Functions)

### ✅ COMPLETED
- [x] Branding integration (D'Sierra red theme, logos)
- [x] Enhanced TimeEntry domain model with offline fields
- [x] Rebuilt TimeclockScreen with comprehensive UI
- [x] Build verification passed

### 📝 HAIKU TODO: Cloud Functions Trigger

**File:** `functions/src/timeclock/onTimeEntryCreate.ts`

**Tasks:**
1. Implement fraud detection logic:
   - Check if origin === 'offline' → set needsReview = true
   - Check if clockInGeofenceValid === false → flag
   - Check if gpsMissing === true → flag
   - Check if entry duration > 24 hours → reject
   - Check for duplicate clientEventId (idempotency)

2. Add telemetry events:
   - time_entry_created
   - time_entry_flagged

3. Implement admin notifications:
   - Create Firestore notification document OR
   - Send email via SendGrid OR
   - Post to Slack webhook

**Test Command:**
```bash
npm --prefix functions run build
firebase emulators:start --only functions
```

---

## Story B: Weekly Schedule Screen

### 📝 HAIKU TODO: Worker Schedule Implementation

**File:** `lib/features/schedule/presentation/worker_schedule_screen.dart`

**Tasks:**
1. Create JobAssignment domain model:
   - Add `fromFirestore()` and `toFirestore()` methods
   - Move to `lib/features/schedule/domain/job_assignment.dart`

2. Implement Firestore query in `workerAssignmentsProvider`:
   ```dart
   FirebaseFirestore.instance
     .collection('companies/$companyId/job_assignments')
     .where('workerId', isEqualTo: workerId)
     .where('shiftStart', isGreaterThanOrEqualTo: DateTime.now())
     .orderBy('shiftStart')
     .snapshots()
   ```

3. Build calendar week selector:
   - Format as "Feb 10 - Feb 16, 2025"
   - Calculate Monday-Sunday range
   - Add prev/next week navigation

4. Implement filter logic:
   - Today: shiftStart is same day as DateTime.now()
   - Week: shiftStart is in selected week range
   - All: all upcoming assignments

5. Format shift times:
   - Display as "8:00 AM - 5:00 PM (9h)"
   - Calculate duration in hours

6. Add "TODAY" badge logic:
   ```dart
   final isToday = DateUtils.isSameDay(assignment.shiftStart, DateTime.now());
   ```

7. Wire up navigation:
   ```dart
   Navigator.pushNamed(context, '/job-details', arguments: assignment.jobId);
   ```

**Dependencies Needed:**
- None (all already in pubspec.yaml)

---

## Story C: Job Management with Geo-location

### 📝 HAIKU TODO: Location Picker Implementation

**File:** `lib/features/jobs/presentation/job_location_picker.dart`

**Tasks:**
1. Add dependencies:
   ```yaml
   # pubspec.yaml
   dependencies:
     google_maps_flutter: ^2.6.0
   ```

2. Implement Google Maps widget:
   ```dart
   GoogleMap(
     initialCameraPosition: CameraPosition(
       target: LatLng(lat, lng),
       zoom: 15,
     ),
     markers: {
       Marker(
         markerId: MarkerId('job-location'),
         position: LatLng(lat, lng),
         draggable: true,
         onDragEnd: (newPosition) {
           // Update _selectedLocation
         },
       ),
     },
     circles: {
       Circle(
         circleId: CircleId('geofence'),
         center: LatLng(lat, lng),
         radius: 75, // meters
         fillColor: Colors.blue.withOpacity(0.2),
         strokeColor: Colors.blue,
         strokeWidth: 2,
       ),
     },
   )
   ```

3. Add Google Places autocomplete:
   - Use `google_places_flutter` package OR
   - Use `flutter_google_places_hoc081098` package

4. Create geocoding Cloud Function:
   ```typescript
   // functions/src/maps/geocode.ts
   export const geocodeAddress = onCall(async (request) => {
     const { address } = request.data;
     // Use Google Geocoding API
     const result = await geocode(address);
     return {
       lat: result.lat,
       lng: result.lng,
       formattedAddress: result.formatted_address,
     };
   });
   ```

5. Wire up search to geocoding

**Testing:**
- Need Google Maps API key in Firebase config
- Add to `.env`: `GOOGLE_MAPS_API_KEY=your_key_here`

---

## Story D: Admin Dashboard Home

### 📝 HAIKU TODO: Dashboard KPIs

**File:** `lib/features/admin/presentation/admin_home_screen.dart`

**Tasks:**
1. Implement KPI Firestore queries:
   ```dart
   // Active workers (clocked in right now)
   final activeWorkers = await FirebaseFirestore.instance
     .collection('companies/$companyId/time_entries')
     .where('status', isEqualTo: 'active')
     .get()
     .then((snap) => snap.docs.length);

   // Pending time entries
   final pendingTimeEntries = await FirebaseFirestore.instance
     .collection('companies/$companyId/time_entries')
     .where('status', isEqualTo: 'pending')
     .get()
     .then((snap) => snap.docs.length);

   // Active jobs
   final activeJobs = await FirebaseFirestore.instance
     .collection('companies/$companyId/jobs')
     .where('status', isEqualTo: 'active')
     .get()
     .then((snap) => snap.docs.length);

   // Weekly revenue (sum of invoices paid this week)
   final weekStart = DateTime.now().subtract(Duration(days: 7));
   final invoicesSnap = await FirebaseFirestore.instance
     .collection('companies/$companyId/invoices')
     .where('status', isEqualTo: 'paid_cash')
     .where('paidAt', isGreaterThanOrEqualTo: Timestamp.fromDate(weekStart))
     .get();
   final weeklyRevenue = invoicesSnap.docs
     .map((doc) => (doc.data()['amount'] as num).toDouble())
     .fold(0.0, (sum, amount) => sum + amount);
   ```

2. Add skeleton loading states:
   - Use `Shimmer` package OR
   - Use animated containers with grey background

3. Build recent activity feed:
   - Query last 10 events from activity log
   - Display as timeline with icons

4. Wire up quick action buttons:
   - Create Job → `/admin/jobs/create`
   - Invite Worker → `/admin/employees/invite`
   - New Invoice → `/admin/invoices/create`
   - View Reports → `/admin/reports`

**Performance Note:**
- Consider caching KPIs in a separate collection updated by Cloud Functions

---

## Story F: Professional Invoice System

### 📝 HAIKU TODO: Enhanced Invoice Form

**File:** `lib/features/invoices/presentation/invoice_create_screen.dart`

**Tasks:**
1. Implement auto-generated invoice numbers:
   ```dart
   // Query highest invoice number for current month
   final now = DateTime.now();
   final monthStart = DateTime(now.year, now.month, 1);
   final monthEnd = DateTime(now.year, now.month + 1, 0);
   
   final invoicesSnap = await FirebaseFirestore.instance
     .collection('companies/$companyId/invoices')
     .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(monthStart))
     .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(monthEnd))
     .orderBy('createdAt', descending: true)
     .limit(1)
     .get();
   
   int nextNumber = 1;
   if (invoicesSnap.docs.isNotEmpty) {
     final lastNumber = invoicesSnap.docs.first.data()['number'] as String;
     // Parse "INV-202502-0005" → 5
     final parts = lastNumber.split('-');
     nextNumber = int.parse(parts[2]) + 1;
   }
   
   final invoiceNumber = 'INV-${now.year}${now.month.toString().padLeft(2, '0')}-${nextNumber.toString().padLeft(4, '0')}';
   ```

2. Implement PDF generation with D'Sierra branding:
   - Use `pdf` package
   - Add D'Sierra logo to header
   - Use red accent colors
   - Create template: `lib/features/invoices/data/invoice_pdf_template.dart`

3. Wire up email sending:
   ```dart
   // Call Cloud Function
   final result = await FirebaseFunctions.instance
     .httpsCallable('sendInvoiceEmail')
     .call({
       'invoiceId': invoiceId,
       'recipientEmail': customerEmail,
     });
   ```

4. Create Cloud Function for email:
   ```typescript
   // functions/src/billing/send_invoice_email.ts
   export const sendInvoiceEmail = onCall(async (request) => {
     // Generate PDF
     // Send via SendGrid
     // Update invoice status to 'sent'
   });
   ```

**Dependencies:**
```yaml
dependencies:
  pdf: ^3.10.4
  printing: ^5.11.0
```

---

## Story G: Marketing Landing Page

### 📝 HAIKU TODO: Landing Page Polish

**File:** `lib/features/marketing/presentation/landing_page.dart`

**Tasks:**
1. Add smooth scroll to sections:
   ```dart
   final ScrollController _scrollController = ScrollController();
   
   void _scrollToContact() {
     _scrollController.animateTo(
       _contactSectionKey.currentContext!.findRenderObject()!.paintBounds.top,
       duration: Duration(milliseconds: 500),
       curve: Curves.easeInOut,
     );
   }
   ```

2. Build testimonials carousel:
   ```dart
   PageView.builder(
     itemCount: testimonials.length,
     itemBuilder: (context, index) {
       return TestimonialCard(testimonial: testimonials[index]);
     },
   )
   ```

3. Implement contact form submission:
   ```dart
   // Call Cloud Function to create lead
   await FirebaseFunctions.instance
     .httpsCallable('createLead')
     .call({
       'name': nameController.text,
       'email': emailController.text,
       'phone': phoneController.text,
       'message': messageController.text,
     });
   ```

4. Add responsive breakpoints:
   - Mobile: < 600px (single column)
   - Tablet: 600-900px (2 columns)
   - Desktop: > 900px (3 columns)

5. SEO optimization (for web):
   - Add meta tags in `web/index.html`
   - Add structured data (JSON-LD)
   - Optimize images

**Cloud Function:**
```typescript
// functions/src/leads/createLead.ts (already exists)
// Just wire up the call from UI
```

---

## Build & Test Commands

### Flutter
```bash
# Analyze code
flutter analyze --no-pub

# Build web
flutter build web --release

# Run on emulator
flutter run -d chrome

# Run specific screen
flutter run -d chrome --target lib/features/marketing/presentation/landing_page.dart
```

### Cloud Functions
```bash
# Build TypeScript
npm --prefix functions run build

# Run emulators
firebase emulators:start

# Deploy single function
firebase deploy --only functions:onTimeEntryCreate

# Deploy all
firebase deploy
```

### Testing Strategy
1. Start with Story A Cloud Functions trigger (most critical)
2. Then Story B (worker schedule - most frequently used)
3. Then Story D (admin dashboard - high visibility)
4. Then Story F (invoice system - revenue-critical)
5. Then Story C (job location picker - nice-to-have)
6. Finally Story G (landing page - marketing)

---

## Estimated Haiku Time Budget

| Story | File | Estimated Time | Complexity |
|-------|------|----------------|------------|
| A | onTimeEntryCreate.ts | 15-20 min | Medium |
| B | worker_schedule_screen.dart | 20-30 min | Medium |
| C | job_location_picker.dart | 30-40 min | High (Google Maps) |
| D | admin_home_screen.dart | 15-20 min | Low |
| F | invoice_create_screen.dart | 25-35 min | Medium-High (PDF) |
| G | landing_page.dart | 15-20 min | Low |

**Total:** ~2-3 hours with Haiku

---

## Priority Order for Haiku

1. **Story A** - Cloud Functions trigger (security-critical)
2. **Story B** - Worker schedule (daily use)
3. **Story D** - Admin dashboard (visibility)
4. **Story F** - Invoice system (revenue)
5. **Story C** - Job location picker
6. **Story G** - Landing page

---

## Notes for Haiku

- All skeletons compile successfully ✅
- All type signatures are in place ✅
- All imports are correct ✅
- UI structure is complete ✅
- Just need to fill in business logic marked with `// HAIKU TODO:`
- Search for "HAIKU TODO" in each file to find all work items
- Each TODO has clear instructions and example code
- Test incrementally as you complete each story

Good luck! 🚀
