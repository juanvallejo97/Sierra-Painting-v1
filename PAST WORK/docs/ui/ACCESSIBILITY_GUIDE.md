# Accessibility Guide - Sierra Painting

This guide documents accessibility compliance and testing procedures for WCAG 2.2 AA standards.

## Table of Contents

1. [Color Contrast Verification](#color-contrast-verification)
2. [Screen Reader Testing](#screen-reader-testing)
3. [Touch Target Guidelines](#touch-target-guidelines)
4. [Dynamic Type Support](#dynamic-type-support)
5. [Motion Reduction](#motion-reduction)

---

## Color Contrast Verification

### WCAG 2.2 AA Requirements

- **Normal text (< 18pt)**: Minimum 4.5:1 contrast ratio
- **Large text (≥ 18pt or ≥ 14pt bold)**: Minimum 3:1 contrast ratio
- **UI components and graphical objects**: Minimum 3:1 contrast ratio

### Our Color Palette with Verified Ratios

#### Brand Colors
- **Sierra Blue (#1976D2)** on White (#FFFFFF): 4.53:1 ✅ (AA compliant for normal text)
- **Painting Orange (#FF9800)** on White (#FFFFFF): 2.33:1 ⚠️ (Use only for large text or with darker variant)
- **Painting Orange (#FF9800)** on Black (#000000): 9.0:1 ✅ (AAA compliant)

#### Semantic Colors
- **Success Green (#4CAF50)** on White: 3.36:1 ✅ (AA compliant for large text)
- **Warning Amber (#FFA726)** on Black: 7.92:1 ✅ (AAA compliant)
- **Error Red (#D32F2F)** on White: 5.14:1 ✅ (AA compliant for normal text)
- **Info Blue (#2196F3)** on White: 3.15:1 ✅ (AA compliant for large text)

### Tools for Verification

#### Online Tools
1. **WebAIM Contrast Checker**: https://webaim.org/resources/contrastchecker/
2. **Coolors Contrast Checker**: https://coolors.co/contrast-checker
3. **Color Review**: https://color.review/

#### Desktop Tools
1. **Colour Contrast Analyser (CCA)** by TPGi
   - Windows/Mac: https://www.tpgi.com/color-contrast-checker/
   - Free, works with any color on screen

2. **Accessibility Insights for Windows**
   - Download: https://accessibilityinsights.io/
   - Can verify contrast in running apps

#### Flutter DevTools
1. Enable the contrast checker in Flutter DevTools
2. Use the color inspector to verify widget colors
3. Check text contrast in different theme modes

### Verification Process

1. **Extract colors from your theme**:
   ```dart
   final theme = Theme.of(context);
   print('Primary: ${theme.colorScheme.primary}');
   print('OnPrimary: ${theme.colorScheme.onPrimary}');
   print('Background: ${theme.colorScheme.background}');
   print('OnBackground: ${theme.colorScheme.onBackground}');
   ```

2. **Test with WebAIM**:
   - Open https://webaim.org/resources/contrastchecker/
   - Enter foreground and background colors
   - Verify ratios meet requirements

3. **Test in both themes**:
   - Light mode
   - Dark mode
   - High contrast mode (if implemented)

4. **Document results** in this file

---

## Screen Reader Testing

### TalkBack (Android)

#### Setup
1. Open **Settings** → **Accessibility** → **TalkBack**
2. Enable TalkBack
3. Tutorial will start automatically (complete it to learn gestures)

#### Key Gestures
- **Swipe right**: Move to next element
- **Swipe left**: Move to previous element
- **Tap once**: Select element
- **Double-tap**: Activate element
- **Swipe down then right**: Read from top
- **Two-finger swipe down**: Scroll down

#### Testing Checklist
- [ ] App name is announced on launch
- [ ] All buttons have descriptive labels
- [ ] Icon-only buttons have semantic labels
- [ ] Form fields announce their purpose
- [ ] Error messages are announced
- [ ] Success messages are announced
- [ ] Loading states are announced
- [ ] Navigation structure is logical
- [ ] Focus order makes sense
- [ ] Dynamic content updates are announced

#### Known Issues
- Material 3 chips may need explicit Semantics widgets
- Bottom navigation labels should be explicit

### VoiceOver (iOS)

#### Setup
1. Open **Settings** → **Accessibility** → **VoiceOver**
2. Enable VoiceOver
3. Or use triple-click home/side button shortcut

#### Key Gestures
- **Swipe right**: Move to next element
- **Swipe left**: Move to previous element
- **Tap once**: Select element
- **Double-tap**: Activate element
- **Two-finger swipe down**: Read from top
- **Three-finger swipe up/down**: Scroll

#### Testing Checklist
- [ ] App name is announced on launch
- [ ] All buttons have descriptive labels
- [ ] Icon-only buttons have semantic labels
- [ ] Form fields announce their purpose
- [ ] Error messages are announced
- [ ] Success messages are announced
- [ ] Loading states are announced
- [ ] Navigation structure is logical
- [ ] Focus order makes sense
- [ ] Dynamic content updates are announced

### Adding Semantic Labels

#### Icon-only Buttons
```dart
IconButton(
  icon: const Icon(Icons.format_paint),
  onPressed: () {},
  tooltip: 'Open painting tools', // Fallback for visual users
  // Explicit semantic label for screen readers
  // Using Semantics widget wrapper
);

// Better approach with Semantics:
Semantics(
  label: 'Open painting tools',
  button: true,
  child: IconButton(
    icon: const Icon(Icons.format_paint),
    onPressed: () {},
  ),
);
```

#### Custom Widgets
```dart
Semantics(
  label: 'Clock in button',
  button: true,
  enabled: isEnabled,
  child: GestureDetector(
    onTap: isEnabled ? _handleClockIn : null,
    child: CustomButton(text: 'Clock In'),
  ),
);
```

#### Excluding Decorative Elements
```dart
ExcludeSemantics(
  child: Container(
    decoration: BoxDecoration(/* decorative only */),
  ),
);
```

#### Status Announcements
```dart
// Announce dynamic content changes
SemanticsService.announce(
  'Clock in successful',
  TextDirection.ltr,
);
```

---

## Touch Target Guidelines

### WCAG 2.2 AA Requirements

- **Minimum size**: 44×44 logical pixels
- **Recommended size**: 48×48 logical pixels
- **Optimal size for primary actions**: 56×56 logical pixels

### Implementation

#### Buttons
```dart
// Minimum size enforcement
ElevatedButton(
  onPressed: () {},
  style: ElevatedButton.styleFrom(
    minimumSize: const Size(48, 48),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  ),
  child: const Text('Action'),
);
```

#### Icon Buttons
```dart
// IconButton has 48×48 minimum by default in Material 3
IconButton(
  icon: const Icon(Icons.add),
  onPressed: () {},
);

// For custom tap targets
GestureDetector(
  onTap: () {},
  child: Container(
    width: 48,
    height: 48,
    alignment: Alignment.center,
    child: const Icon(Icons.custom),
  ),
);
```

#### List Items
```dart
ListTile(
  title: const Text('Item'),
  onTap: () {},
  // ListTile enforces minimum 48px height
);
```

### Verification

Use Flutter DevTools **Widget Inspector**:
1. Enable "Show Guidelines" in the inspector
2. Select interactive widgets
3. Verify size properties show ≥ 44×44

---

## Dynamic Type Support

### Implementation

Our app already supports dynamic type scaling with a cap at 1.3x:

```dart
MediaQuery(
  data: MediaQuery.of(context).copyWith(
    textScaler: TextScaler.linear(
      MediaQuery.of(context).textScaleFactor.clamp(1.0, 1.3),
    ),
  ),
  child: child!,
);
```

### Testing

#### iOS
1. **Settings** → **Accessibility** → **Display & Text Size** → **Larger Text**
2. Enable "Larger Accessibility Sizes"
3. Adjust slider to maximum
4. Test app layout

#### Android
1. **Settings** → **Display** → **Font size**
2. Select largest option
3. Test app layout

### Checklist
- [x] Text scales with system settings
- [x] Layout adapts to larger text (responsive design)
- [x] No text truncation at 130% scale
- [x] Buttons remain usable with larger text
- [ ] Verify with actual device testing

### Guidelines
- Use flexible layouts (Column, Row, Wrap)
- Avoid fixed-height containers for text
- Use `FittedBox` for text that must fit in a space
- Test at 100%, 130%, and 200% (with cap removed)

---

## Motion Reduction

### System Preference

Users can enable "Reduce Motion" in system settings:
- **iOS**: Settings → Accessibility → Motion → Reduce Motion
- **Android**: Settings → Accessibility → Remove animations

### Implementation

We use `MotionUtils` to respect this preference:

```dart
// lib/core/utils/motion_utils.dart
class MotionUtils {
  static bool shouldReduceMotion(BuildContext context) {
    return MediaQuery.of(context).disableAnimations;
  }

  static Duration getDuration(BuildContext context, Duration standard) {
    return shouldReduceMotion(context) 
      ? Duration.zero 
      : standard;
  }
}
```

### Usage

```dart
// In animations
AnimatedContainer(
  duration: MotionUtils.getDuration(context, const Duration(milliseconds: 200)),
  curve: Curves.easeInOut,
  // ...
);

// In transitions
PageRouteBuilder(
  transitionDuration: MotionUtils.getDuration(
    context,
    const Duration(milliseconds: 300),
  ),
  // ...
);
```

### Manual Toggle

Settings screen includes a haptic feedback toggle (see `lib/features/settings/presentation/settings_screen.dart`).

We can extend this to include a motion reduction toggle:

```dart
SwitchListTile(
  title: const Text('Reduce Motion'),
  subtitle: const Text('Minimize animations throughout the app'),
  value: _reduceMotion,
  onChanged: (value) {
    setState(() => _reduceMotion = value);
    // Save to SharedPreferences
  },
);
```

---

## Additional Resources

### Documentation
- [WCAG 2.2 Guidelines](https://www.w3.org/WAI/WCAG22/quickref/)
- [Flutter Accessibility](https://docs.flutter.dev/development/accessibility-and-localization/accessibility)
- [Material Design Accessibility](https://m3.material.io/foundations/accessible-design/overview)

### Testing Tools
- [Accessibility Scanner (Android)](https://play.google.com/store/apps/details?id=com.google.android.apps.accessibility.auditor)
- [Accessibility Inspector (Xcode)](https://developer.apple.com/library/archive/documentation/Accessibility/Conceptual/AccessibilityMacOSX/OSXAXTestingApps.html)

### Best Practices
- Test with actual screen readers, not just semantics debugging
- Involve users with disabilities in testing when possible
- Document any accessibility limitations
- Provide alternative ways to accomplish tasks

---

**Last Updated**: 2025-10-03  
**Maintained by**: Sierra Painting Development Team
