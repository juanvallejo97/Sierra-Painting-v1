# UI Overhaul Requirements Checklist

This document tracks the requirements and implementation status for the UI overhaul project.

## Performance Items (from frontend_secrets.txt)

### Const Widgets
- [ ] All static Text/Icon widgets marked as const
- [ ] All component primitives use const constructors
- [ ] Theme configuration uses const values where possible

### State Management
- [ ] State changes localized (minimal rebuild scope)
- [ ] Consumer/ref.watch() placed deep in widget tree
- [ ] No unnecessary setState() calls

### Lists & Scrolling
- [ ] All lists use ListView.builder pattern
- [ ] Fixed-height lists use itemExtent
- [ ] Pagination implemented for large datasets
- [ ] Lazy loading for images outside viewport

### Heavy Work Isolation
- [ ] CPU-intensive work moved to isolates
- [ ] JSON parsing uses compute()
- [ ] Image processing offloaded from UI thread

### Image Optimization
- [ ] Image caching implemented
- [ ] Correct image sizes (cacheWidth/cacheHeight)
- [ ] Modern formats (WebP) where possible
- [ ] Lazy image loading

### Performance Monitoring
- [ ] Frame times tracked
- [ ] Navigation timings logged
- [ ] Critical screen load metrics
- [ ] Performance markers in structured logs

### Optimistic Updates
- [ ] Write operations update UI immediately
- [ ] Rollback on error implemented
- [ ] Clear error messaging for failed operations

## UI System Items

### Design Tokens
- [x] Color palette (warm, professional)
  - Sierra Blue (primary)
  - Painting Orange (accent)
  - Success Green
  - Warning Amber
  - Error Red
  - Info Blue
- [x] Typography scale (Material 3)
- [x] Spacing scale (4, 8, 16, 24, 32, 48)
- [x] Border radii (4, 8, 12, 16, full)
- [x] Elevation levels (0, 1, 2, 4, 8)
- [x] Motion durations (100, 150, 200, 300, 500ms)
- [x] Touch target sizes (44, 48, 56)

### Theme System
- [x] Light theme with Material 3
- [x] Dark theme with Material 3
- [x] High contrast modes
- [x] System theme detection
- [ ] Theme persistence (SharedPreferences)
- [ ] Theme toggle in settings

### Component Primitives
- [x] AppButton (filled, outlined, text variants)
- [x] AppInput (with validation)
- [x] AppCard (with tap handling)
- [x] AppListItem (consistent spacing)
- [x] AppSkeleton (loading states)
- [x] AppBadge (status indicators)

### Additional Components Needed
- [ ] AppEmpty (zero-state content)
- [ ] AppError (error states)
- [ ] GlobalSyncIndicator
- [ ] SyncStatusDialog
- [ ] ValidatedTextField (enhanced)
- [ ] HapticFeedback service

## Navigation & Routes

### Route Coverage
- [ ] /login - Public route
- [ ] /timeclock - Authenticated route
- [ ] /estimates - Authenticated route
- [ ] /invoices - Authenticated route
- [ ] /admin - Admin-only route
- [ ] All routes documented in routes.md
- [ ] Route reachability tests

### Deep Links
- [ ] Android manifest configured
- [ ] iOS Info.plist configured
- [ ] Deep link handlers implemented
- [ ] Deep link validation tests

### Navigation Patterns
- [ ] Back-stack behavior verified
- [ ] Bottom navigation works correctly
- [ ] Drawer navigation consistent
- [ ] Tab navigation smooth
- [ ] Prefetch next-likely screens

## Accessibility (WCAG 2.2 AA)

### Color Contrast
- [x] 4.5:1 ratio for normal text
- [x] 3:1 ratio for large text (18pt+)
- [x] 3:1 ratio for UI components
- [ ] Contrast verified with tools

### Touch Targets
- [x] Minimum 44px touch targets
- [x] Adequate spacing between elements
- [ ] Touch target verification tests

### Motion & Animations
- [x] MotionUtils respects reduced motion
- [x] Durations respond to system settings
- [x] Curves adjust for accessibility
- [ ] Manual toggle in settings
- [ ] All animations use MotionUtils

### Screen Reader Support
- [ ] All interactive elements labeled
- [ ] Meaningful grouping and hierarchy
- [ ] Status announcements for dynamic content
- [ ] TalkBack/VoiceOver tested

### Dynamic Type
- [ ] Text scales with system settings
- [ ] Layout adapts to large text
- [ ] No text truncation at 200% scale

## Offline & Network Resilience

### Offline Queue
- [ ] Queue service integrated
- [ ] Pending operations visible
- [ ] Retry mechanism implemented
- [ ] Clear status messaging

### Sync Status
- [ ] Global sync indicator in app bar
- [ ] Individual item badges
- [ ] Sync progress visible
- [ ] Failed sync retry option
- [ ] Color-coded status (yellow/green/red)

### Network Handling
- [ ] Timeouts on all network calls
- [ ] Graceful degradation
- [ ] Offline mode messaging
- [ ] Queued actions persist

## Micro-interactions

### Haptic Feedback
- [ ] Clock in/out (medium)
- [ ] Invoice marked paid (medium)
- [ ] Estimate sent (medium)
- [ ] Form submission (light)
- [ ] Navigation toggle (light)
- [ ] Tab selection (selection)
- [ ] Error toast (heavy)
- [ ] Settings toggle to disable

### Visual Feedback
- [ ] Button press states
- [ ] Success animations (<200ms)
- [ ] Loading indicators
- [ ] Skeleton loaders
- [ ] Optimistic updates

### Subtle Motion
- [ ] 150-200ms transitions
- [ ] Gentle easing curves
- [ ] Never block input
- [ ] Professional feel

## Testing Requirements

### Unit Tests
- [ ] Theme switching logic
- [ ] Haptic service
- [ ] Validators
- [ ] Sync status calculations

### Widget Tests
- [ ] All component primitives
- [ ] Empty states
- [ ] Skeleton loaders
- [ ] Error screens
- [ ] Badges and indicators

### Integration Tests
- [ ] Route coverage
- [ ] Theme persistence
- [ ] Motion reduction
- [ ] Sync status updates
- [ ] Form validation flows

### Performance Tests
- [ ] Frame times < 16ms
- [ ] Screen render < 500ms
- [ ] No memory leaks
- [ ] No frame drops in profile mode

### Accessibility Tests
- [ ] TalkBack/VoiceOver navigation
- [ ] 44px touch targets verified
- [ ] Contrast ratios verified
- [ ] Screen reader labels
- [ ] Reduced motion respected

## Documentation

- [x] ui_overhaul_requirements.md created
- [ ] routes.md updated
- [ ] Design system documented
- [ ] Component usage examples
- [ ] Accessibility guidelines
- [ ] Performance benchmarks
- [ ] Rollback procedures
- [ ] Feature flag documentation

## Rollout & Safety

### Feature Flags
- [ ] ui_overhaul_enabled flag
- [ ] Theme switching flag
- [ ] Haptics flag
- [ ] Skeleton loaders flag
- [ ] Canary cohort toggle

### Metrics & Monitoring
- [ ] Frame times tracked
- [ ] Navigation timings logged
- [ ] Error rates monitored
- [ ] Performance regression alerts
- [ ] User feedback collection

### Rollback Plan
- [ ] Rollback steps documented
- [ ] Feature flags allow quick disable
- [ ] Previous theme system preserved
- [ ] Migration path clear

## Design Intent

### Professional + Family-Friendly
- [x] Warm color palette (blue + orange)
- [x] Clean, modern aesthetic
- [x] Trustworthy and approachable
- [x] Subtle, professional motion
- [ ] Consistent throughout app

### Performance First
- [ ] 60fps maintained
- [ ] <16ms frame build
- [ ] Smooth scrolling
- [ ] Fast initial load
- [ ] Responsive interactions

### No Breaking Changes
- [ ] API contracts unchanged
- [ ] Existing screens work
- [ ] Opt-in migration
- [ ] Backward compatibility
- [ ] Feature-flagged risks

---

**Status**: Foundation Phase Started  
**Last Updated**: 2025-10-03  
**Next Milestone**: Complete PR-01 (Design System & Tokens)
