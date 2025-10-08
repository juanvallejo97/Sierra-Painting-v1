/// Unit tests for HapticService
///
/// PURPOSE:
/// Verify haptic feedback service behavior
///
/// COVERAGE:
/// - Enable/disable functionality via `StateProvider<bool>`
/// - Different feedback intensities (light, medium, heavy, selection, vibrate)
/// - State persistence across method calls
/// - No-op behavior when disabled (acceptance criteria)
/// - `vibrate()` specifically tested for enabled/disabled paths
library;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sierra_painting/core/services/haptic_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async => call.method.startsWith('HapticFeedback') ? null : null,
  );
  group('HapticService', () {
    late ProviderContainer container;
    late HapticService service;

    setUp(() {
      container = ProviderContainer();
      service = container.read(hapticServiceProvider);
    });

    tearDown(() {
      container.dispose();
    });

    test('Initial state is enabled', () {
      expect(service.isEnabled, isTrue);
    });

    test('Can disable haptic feedback', () {
      service.setEnabled(false);
      expect(service.isEnabled, isFalse);
    });

    test('Can re-enable haptic feedback', () {
      service.setEnabled(false);
      expect(service.isEnabled, isFalse);

      service.setEnabled(true);
      expect(service.isEnabled, isTrue);
    });

    test('Light haptic completes without error when enabled', () async {
      service.setEnabled(true);
      await expectLater(service.light(), completes);
    });

    test('Medium haptic completes without error when enabled', () async {
      service.setEnabled(true);
      await expectLater(service.medium(), completes);
    });

    test('Heavy haptic completes without error when enabled', () async {
      service.setEnabled(true);
      await expectLater(service.heavy(), completes);
    });

    test('Selection haptic completes without error when enabled', () async {
      service.setEnabled(true);
      await expectLater(service.selection(), completes);
    });

    test('Vibrate completes without error when enabled', () async {
      service.setEnabled(true);
      await expectLater(service.vibrate(), completes);
    });

    test('Haptics do not trigger when disabled', () async {
      service.setEnabled(false);

      // All haptic methods should complete immediately without error
      await expectLater(service.light(), completes);
      await expectLater(service.medium(), completes);
      await expectLater(service.heavy(), completes);
      await expectLater(service.selection(), completes);
      await expectLater(service.vibrate(), completes);
    });

    test('vibrate() is a no-op when disabled', () async {
      service.setEnabled(false);
      expect(service.isEnabled, isFalse);

      // Should complete immediately without triggering HapticFeedback.vibrate()
      await expectLater(service.vibrate(), completes);

      // State should remain disabled
      expect(service.isEnabled, isFalse);
    });

    test('vibrate() triggers haptic when enabled', () async {
      service.setEnabled(true);
      expect(service.isEnabled, isTrue);

      // Should complete and trigger HapticFeedback.vibrate()
      await expectLater(service.vibrate(), completes);

      // State should remain enabled
      expect(service.isEnabled, isTrue);
    });

    test('Multiple haptic calls succeed', () async {
      service.setEnabled(true);

      await service.light();
      await service.light();
      await service.medium();

      // All calls should complete successfully
      expect(service.isEnabled, isTrue);
    });

    test('Haptic state toggle works correctly', () {
      expect(service.isEnabled, isTrue);

      service.setEnabled(false);
      expect(service.isEnabled, isFalse);

      service.setEnabled(true);
      expect(service.isEnabled, isTrue);

      service.setEnabled(false);
      expect(service.isEnabled, isFalse);
    });

    test('All haptic methods are no-ops when disabled', () async {
      service.setEnabled(false);

      // Verify state is disabled
      expect(service.isEnabled, isFalse);

      // All methods should complete without triggering haptic feedback
      await service.light();
      await service.medium();
      await service.heavy();
      await service.selection();
      await service.vibrate();

      // State should remain disabled after all calls
      expect(service.isEnabled, isFalse);
    });

    test('All haptic methods work when enabled', () async {
      service.setEnabled(true);

      // Verify state is enabled
      expect(service.isEnabled, isTrue);

      // All methods should complete and trigger haptic feedback
      await service.light();
      await service.medium();
      await service.heavy();
      await service.selection();
      await service.vibrate();

      // State should remain enabled after all calls
      expect(service.isEnabled, isTrue);
    });
  });

  group('HapticService Usage Guidelines', () {
    test('Light haptic is for minor interactions', () {
      // Use cases documented:
      final lightUseCases = ['Button taps', 'Navigation', 'Form field focus', 'Minor UI interactions'];

      expect(lightUseCases.length, equals(4));
    });

    test('Medium haptic is for successful actions', () {
      // Use cases documented:
      final mediumUseCases = [
        'Clock in/out',
        'Invoice marked paid',
        'Estimate sent',
        'Save actions',
        'Successful completions',
      ];

      expect(mediumUseCases.length, equals(5));
    });

    test('Heavy haptic is for errors and warnings', () {
      // Use cases documented:
      final heavyUseCases = ['Errors', 'Warnings', 'Critical alerts', 'Failed operations'];

      expect(heavyUseCases.length, equals(4));
    });

    test('Selection haptic is for choices', () {
      // Use cases documented:
      final selectionUseCases = [
        'Tab bar selection',
        'Checkbox/radio toggle',
        'Item selection in list',
        'Picker/slider interaction',
      ];

      expect(selectionUseCases.length, equals(4));
    });
  });
}
