/**
 * Timeclock Unit Tests
 *
 * Tests for haversine distance calculation and geofence validation logic.
 */

import { describe, it, expect } from '@jest/globals';

/**
 * Haversine distance calculation (extracted from timeclock.ts for testing)
 */
const HAVERSINE = (a: {lat: number; lng: number}, b: {lat: number; lng: number}): number => {
  const toRad = (x: number) => x * Math.PI / 180;
  const R = 6371000; // Earth radius in meters
  const dLat = toRad(b.lat - a.lat);
  const dLng = toRad(b.lng - a.lng);
  const s1 = Math.sin(dLat / 2);
  const s2 = Math.sin(dLng / 2);
  const aa = s1 * s1 + Math.cos(toRad(a.lat)) * Math.cos(toRad(b.lat)) * s2 * s2;
  return 2 * R * Math.asin(Math.sqrt(aa));
};

describe('Haversine Distance Calculation', () => {
  it('should calculate 0 distance for same point', () => {
    const point = { lat: 37.7749, lng: -122.4194 };
    const distance = HAVERSINE(point, point);
    expect(distance).toBe(0);
  });

  it('should calculate ~111km for 1 degree latitude difference at equator', () => {
    const a = { lat: 0, lng: 0 };
    const b = { lat: 1, lng: 0 };
    const distance = HAVERSINE(a, b);
    // 1 degree latitude ≈ 111km at equator
    expect(distance).toBeGreaterThan(110000);
    expect(distance).toBeLessThan(112000);
  });

  it('should calculate correct distance between SF landmarks', () => {
    const paintedLadies = { lat: 37.7762, lng: -122.4330 };
    const goldenGateBridge = { lat: 37.8199, lng: -122.4783 };
    const distance = HAVERSINE(paintedLadies, goldenGateBridge);
    // Actual distance ≈ 6.5km
    expect(distance).toBeGreaterThan(6000);
    expect(distance).toBeLessThan(7000);
  });

  it('should calculate ~50m for typical job site geofence test', () => {
    const jobSite = { lat: 37.7793, lng: -122.4193 };
    const workerLocation = { lat: 37.7797, lng: -122.4193 };
    const distance = HAVERSINE(jobSite, workerLocation);
    // ~44m north of job site
    expect(distance).toBeGreaterThan(40);
    expect(distance).toBeLessThan(50);
  });

  it('should be symmetric (distance(A,B) === distance(B,A))', () => {
    const a = { lat: 37.7749, lng: -122.4194 };
    const b = { lat: 37.7762, lng: -122.4330 };
    const distanceAB = HAVERSINE(a, b);
    const distanceBA = HAVERSINE(b, a);
    expect(distanceAB).toBe(distanceBA);
  });

  it('should handle negative coordinates (southern/western hemispheres)', () => {
    const a = { lat: -33.8688, lng: 151.2093 }; // Sydney
    const b = { lat: -33.8675, lng: 151.2070 }; // Opera House
    const distance = HAVERSINE(a, b);
    // ~200m
    expect(distance).toBeGreaterThan(150);
    expect(distance).toBeLessThan(250);
  });

  it('should handle antipodal points (opposite sides of Earth)', () => {
    const a = { lat: 0, lng: 0 };
    const b = { lat: 0, lng: 180 };
    const distance = HAVERSINE(a, b);
    // Half Earth's circumference ≈ 20,000km
    expect(distance).toBeGreaterThan(19000000);
    expect(distance).toBeLessThan(21000000);
  });
});

describe('Geofence Validation Logic', () => {
  it('should pass geofence check when inside radius', () => {
    const jobSite = { lat: 37.7793, lng: -122.4193 };
    const workerLocation = { lat: 37.7793, lng: -122.4193 }; // Exact match
    const distance = HAVERSINE(jobSite, workerLocation);
    const effectiveRadius = 100;
    expect(distance).toBeLessThanOrEqual(effectiveRadius);
  });

  it('should fail geofence check when outside radius', () => {
    const jobSite = { lat: 37.7793, lng: -122.4193 };
    const workerLocation = { lat: 37.7893, lng: -122.4193 }; // 1.1km north
    const distance = HAVERSINE(jobSite, workerLocation);
    const effectiveRadius = 100;
    expect(distance).toBeGreaterThan(effectiveRadius);
  });

  it('should apply accuracy buffer correctly', () => {
    const jobSite = { lat: 37.7793, lng: -122.4193 };
    const workerLocation = { lat: 37.7797, lng: -122.4193 }; // ~44m north
    const distance = HAVERSINE(jobSite, workerLocation);

    const baseRadius = 75;
    const accuracy = 20;
    const effectiveRadius = baseRadius + Math.max(accuracy, 15);

    // Distance ~44m should be within effective radius (75 + 20 = 95m)
    expect(distance).toBeLessThanOrEqual(effectiveRadius);
  });

  it('should enforce minimum accuracy buffer of 15m', () => {
    const baseRadius = 75;
    const lowAccuracy = 5;
    const accuracyBuffer = Math.max(lowAccuracy, 15);
    const effectiveRadius = baseRadius + accuracyBuffer;

    expect(accuracyBuffer).toBe(15);
    expect(effectiveRadius).toBe(90);
  });

  it('should calculate effective radius with safety guards', () => {
    const radiusM = 100;
    const accuracy = 20;

    // Minimum 75m, cap at 250m
    const baseRadius = Math.max(75, Math.min(radiusM, 250));
    const accuracyBuffer = Math.max(accuracy, 15);
    const effectiveRadius = baseRadius + accuracyBuffer;

    expect(baseRadius).toBe(100);
    expect(accuracyBuffer).toBe(20);
    expect(effectiveRadius).toBe(120);
  });
});
