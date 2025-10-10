import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sierra_painting/features/timeclock/domain/time_entry.dart';

void main() {
  group('TimeEntry', () {
    final now = DateTime(2025, 1, 15, 9, 0);
    final later = DateTime(2025, 1, 15, 17, 30); // 8.5 hours later
    final geoPoint = const GeoPoint(37.7749, -122.4194);

    test('creates instance with required fields', () {
      final entry = TimeEntry(
        orgId: 'org-1',
        userId: 'user-1',
        jobId: 'job-1',
        clockIn: now,
        clientId: 'client-1',
        createdAt: now,
        updatedAt: now,
      );

      expect(entry.orgId, 'org-1');
      expect(entry.userId, 'user-1');
      expect(entry.jobId, 'job-1');
      expect(entry.clockIn, now);
      expect(entry.clientId, 'client-1');
      expect(entry.source, 'mobile'); // default
      expect(entry.gpsMissing, false); // default
      expect(entry.id, isNull);
      expect(entry.clockOut, isNull);
      expect(entry.geo, isNull);
    });

    test('creates instance with all fields', () {
      final entry = TimeEntry(
        id: 'entry-1',
        orgId: 'org-1',
        userId: 'user-1',
        jobId: 'job-1',
        clockIn: now,
        clockOut: later,
        geo: geoPoint,
        gpsMissing: true,
        clientId: 'client-1',
        source: 'web',
        createdAt: now,
        updatedAt: later,
      );

      expect(entry.id, 'entry-1');
      expect(entry.clockOut, later);
      expect(entry.geo, geoPoint);
      expect(entry.gpsMissing, true);
      expect(entry.source, 'web');
    });

    group('durationHours', () {
      test('returns null when not clocked out', () {
        final entry = TimeEntry(
          orgId: 'org-1',
          userId: 'user-1',
          jobId: 'job-1',
          clockIn: now,
          clientId: 'client-1',
          createdAt: now,
          updatedAt: now,
        );

        expect(entry.durationHours, isNull);
      });

      test('calculates hours when clocked out', () {
        final entry = TimeEntry(
          orgId: 'org-1',
          userId: 'user-1',
          jobId: 'job-1',
          clockIn: now,
          clockOut: later, // 8.5 hours later
          clientId: 'client-1',
          createdAt: now,
          updatedAt: later,
        );

        expect(entry.durationHours, 8.5);
      });

      test('calculates fractional hours correctly', () {
        final clockOut = now.add(const Duration(hours: 2, minutes: 15));
        final entry = TimeEntry(
          orgId: 'org-1',
          userId: 'user-1',
          jobId: 'job-1',
          clockIn: now,
          clockOut: clockOut,
          clientId: 'client-1',
          createdAt: now,
          updatedAt: clockOut,
        );

        expect(entry.durationHours, closeTo(2.25, 0.01));
      });
    });

    group('isActive', () {
      test('returns true when not clocked out', () {
        final entry = TimeEntry(
          orgId: 'org-1',
          userId: 'user-1',
          jobId: 'job-1',
          clockIn: now,
          clientId: 'client-1',
          createdAt: now,
          updatedAt: now,
        );

        expect(entry.isActive, isTrue);
      });

      test('returns false when clocked out', () {
        final entry = TimeEntry(
          orgId: 'org-1',
          userId: 'user-1',
          jobId: 'job-1',
          clockIn: now,
          clockOut: later,
          clientId: 'client-1',
          createdAt: now,
          updatedAt: later,
        );

        expect(entry.isActive, isFalse);
      });
    });

    group('toFirestore', () {
      test('serializes all fields correctly', () {
        final entry = TimeEntry(
          id: 'entry-1',
          orgId: 'org-1',
          userId: 'user-1',
          jobId: 'job-1',
          clockIn: now,
          clockOut: later,
          geo: geoPoint,
          gpsMissing: true,
          clientId: 'client-1',
          source: 'web',
          createdAt: now,
          updatedAt: later,
        );

        final map = entry.toFirestore();

        expect(map['orgId'], 'org-1');
        expect(map['userId'], 'user-1');
        expect(map['jobId'], 'job-1');
        expect(map['clockIn'], isA<Timestamp>());
        expect((map['clockIn'] as Timestamp).toDate(), now);
        expect(map['clockOut'], isA<Timestamp>());
        expect((map['clockOut'] as Timestamp).toDate(), later);
        expect(map['geo'], geoPoint);
        expect(map['gpsMissing'], true);
        expect(map['clientId'], 'client-1');
        expect(map['source'], 'web');
        expect(map['createdAt'], isA<Timestamp>());
        expect(map['updatedAt'], isA<Timestamp>());
      });

      test('handles null clockOut', () {
        final entry = TimeEntry(
          orgId: 'org-1',
          userId: 'user-1',
          jobId: 'job-1',
          clockIn: now,
          clientId: 'client-1',
          createdAt: now,
          updatedAt: now,
        );

        final map = entry.toFirestore();

        expect(map['clockOut'], isNull);
      });

      test('handles null geo', () {
        final entry = TimeEntry(
          orgId: 'org-1',
          userId: 'user-1',
          jobId: 'job-1',
          clockIn: now,
          clientId: 'client-1',
          createdAt: now,
          updatedAt: now,
        );

        final map = entry.toFirestore();

        expect(map['geo'], isNull);
      });
    });

    group('copyWith', () {
      test('creates copy with updated fields', () {
        final entry = TimeEntry(
          orgId: 'org-1',
          userId: 'user-1',
          jobId: 'job-1',
          clockIn: now,
          clientId: 'client-1',
          createdAt: now,
          updatedAt: now,
        );

        final updated = entry.copyWith(clockOut: later, source: 'web');

        expect(updated.orgId, entry.orgId);
        expect(updated.userId, entry.userId);
        expect(updated.clockOut, later);
        expect(updated.source, 'web');
      });

      test('creates copy with all fields updated', () {
        final entry = TimeEntry(
          id: 'entry-1',
          orgId: 'org-1',
          userId: 'user-1',
          jobId: 'job-1',
          clockIn: now,
          clientId: 'client-1',
          createdAt: now,
          updatedAt: now,
        );

        final newGeo = const GeoPoint(40.7128, -74.0060);
        final updated = entry.copyWith(
          id: 'entry-2',
          orgId: 'org-2',
          userId: 'user-2',
          jobId: 'job-2',
          clockIn: later,
          clockOut: later.add(const Duration(hours: 1)),
          geo: newGeo,
          gpsMissing: true,
          clientId: 'client-2',
          source: 'web',
          createdAt: later,
          updatedAt: later,
        );

        expect(updated.id, 'entry-2');
        expect(updated.orgId, 'org-2');
        expect(updated.userId, 'user-2');
        expect(updated.jobId, 'job-2');
        expect(updated.clockIn, later);
        expect(updated.clockOut, later.add(const Duration(hours: 1)));
        expect(updated.geo, newGeo);
        expect(updated.gpsMissing, true);
        expect(updated.clientId, 'client-2');
        expect(updated.source, 'web');
      });

      test('preserves original values when no updates', () {
        final entry = TimeEntry(
          id: 'entry-1',
          orgId: 'org-1',
          userId: 'user-1',
          jobId: 'job-1',
          clockIn: now,
          clockOut: later,
          geo: geoPoint,
          gpsMissing: true,
          clientId: 'client-1',
          source: 'web',
          createdAt: now,
          updatedAt: later,
        );

        final copy = entry.copyWith();

        expect(copy.id, entry.id);
        expect(copy.orgId, entry.orgId);
        expect(copy.userId, entry.userId);
        expect(copy.jobId, entry.jobId);
        expect(copy.clockIn, entry.clockIn);
        expect(copy.clockOut, entry.clockOut);
        expect(copy.geo, entry.geo);
        expect(copy.gpsMissing, entry.gpsMissing);
        expect(copy.clientId, entry.clientId);
        expect(copy.source, entry.source);
      });
    });
  });
}
