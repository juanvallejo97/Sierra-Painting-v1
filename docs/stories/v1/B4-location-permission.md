# B4: Location Permission UX

**Epic**: B (Time Clock) | **Priority**: P0 | **Sprint**: V1 | **Est**: S | **Risk**: L

## User Story
As a Painter, I WANT to understand why location permission is needed, SO THAT I feel comfortable granting it.

## Dependencies
- **B1** (Clock-in): Location permission requested during clock-in

## Acceptance Criteria (BDD)

### Success Scenario: Permission Dialog
**GIVEN** I am clocking in for the first time  
**WHEN** the app requests location permission  
**THEN** I see a custom dialog explaining why location is needed  
**AND** I see options "Allow" and "Deny"  
**AND** the explanation mentions: job site verification, accurate time tracking

### Success Scenario: Permission Granted
**GIVEN** the location permission dialog is shown  
**WHEN** I tap "Allow"  
**THEN** system permission dialog appears  
**AND** after granting, clock-in proceeds with location

### Success Scenario: Permission Denied
**GIVEN** the location permission dialog is shown  
**WHEN** I tap "Deny"  
**THEN** clock-in proceeds anyway (not blocked)  
**AND** I see "Location not captured" message  
**AND** entry is saved with `gpsMissing=true`

### Edge Case: Previously Denied
**GIVEN** I denied location permission in the past  
**WHEN** I try to clock in again  
**THEN** I see message "Enable location in Settings for job site verification"  
**AND** clock-in still proceeds without blocking

### Accessibility
- Dialog text is readable (16sp minimum)
- Clear button labels ("Allow", "Deny")
- Screen reader support

### Performance
- **Target**: Dialog shown within 100ms of clock-in tap
- **Metric**: Time from tap to dialog rendered

## UI Components

### Custom Permission Rationale Dialog
```dart
AlertDialog(
  title: Text('Location Permission'),
  content: Text(
    'We use your location to verify you\'re at the job site. '
    'This helps ensure accurate time tracking and payroll.\n\n'
    'Your location is only captured when you clock in or out. '
    'We use coarse location (city block level) for privacy.'
  ),
  actions: [
    TextButton(
      onPressed: () => Navigator.pop(context, false),
      child: Text('Deny'),
    ),
    ElevatedButton(
      onPressed: () => Navigator.pop(context, true),
      child: Text('Allow'),
    ),
  ],
)
```

## Definition of Done (DoD)
- [ ] Custom permission rationale dialog implemented
- [ ] Dialog shown before system permission request
- [ ] Clock-in not blocked by permission denial
- [ ] "Enable in Settings" message shown for previously denied
- [ ] E2E test: deny permission → clock-in still works
- [ ] Demo: first clock-in → see custom dialog → grant/deny → appropriate behavior

## Notes

### Implementation Tips
- Use `geolocator` package's `checkPermission()` to detect status
- Show custom dialog only on `denied` or `deniedForever` status
- Use `openAppSettings()` to deep-link to Settings if needed
- Don't repeatedly ask for permission (respect user's choice)

### References
- [Geolocator Package](https://pub.dev/packages/geolocator)
- [Android Location Permissions](https://developer.android.com/training/location/permissions)
- [iOS Location Permissions](https://developer.apple.com/documentation/corelocation)
