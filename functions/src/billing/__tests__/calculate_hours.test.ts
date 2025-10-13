/**
 * Tests for calculate_hours.ts
 *
 * Test Coverage:
 * - calculateEntryHours(): Duration calculation and rounding
 * - roundHours(): Rounding modes (nearest, up, down)
 * - calculateHours(): Multiple entries aggregation
 * - groupEntriesByJob(): Job grouping
 * - groupEntriesByWorker(): Worker grouping
 * - validateTimeEntryForBilling(): Billing validation rules
 */

import {
  calculateEntryHours,
  roundHours,
  calculateHours,
  groupEntriesByJob,
  groupEntriesByWorker,
  validateTimeEntryForBilling,
  validateTimeEntriesForBilling,
  calculateHoursByJob,
  calculateHoursByWorker,
  TimeEntry,
} from '../calculate_hours';

// Mock Firestore Timestamp
class MockTimestamp {
  constructor(private date: Date) {}
  toDate() {
    return this.date;
  }
}

describe('roundHours', () => {
  describe('nearest mode (default)', () => {
    it('should round 3.12 hours to 3.00 hours (15-minute precision)', () => {
      expect(roundHours(3.12, 0.25, 'nearest')).toBe(3.0);
    });

    it('should round 3.20 hours to 3.25 hours', () => {
      expect(roundHours(3.20, 0.25, 'nearest')).toBe(3.25);
    });

    it('should round 3.40 hours to 3.50 hours', () => {
      expect(roundHours(3.40, 0.25, 'nearest')).toBe(3.5);
    });

    it('should round 3.87 hours to 3.75 hours', () => {
      expect(roundHours(3.87, 0.25, 'nearest')).toBe(3.75);
    });

    it('should handle exact quarter hours', () => {
      expect(roundHours(2.25, 0.25, 'nearest')).toBe(2.25);
      expect(roundHours(2.50, 0.25, 'nearest')).toBe(2.5);
      expect(roundHours(2.75, 0.25, 'nearest')).toBe(2.75);
    });
  });

  describe('up mode (always round up)', () => {
    it('should round 3.01 hours up to 3.25 hours', () => {
      expect(roundHours(3.01, 0.25, 'up')).toBe(3.25);
    });

    it('should round 3.12 hours up to 3.25 hours', () => {
      expect(roundHours(3.12, 0.25, 'up')).toBe(3.25);
    });

    it('should not change exact quarter hours', () => {
      expect(roundHours(3.25, 0.25, 'up')).toBe(3.25);
      expect(roundHours(3.50, 0.25, 'up')).toBe(3.5);
    });

    it('should handle small values', () => {
      expect(roundHours(0.01, 0.25, 'up')).toBe(0.25);
      expect(roundHours(0.10, 0.25, 'up')).toBe(0.25);
    });
  });

  describe('down mode (always round down)', () => {
    it('should round 3.24 hours down to 3.00 hours', () => {
      expect(roundHours(3.24, 0.25, 'down')).toBe(3.0);
    });

    it('should round 3.87 hours down to 3.75 hours', () => {
      expect(roundHours(3.87, 0.25, 'down')).toBe(3.75);
    });

    it('should not change exact quarter hours', () => {
      expect(roundHours(3.25, 0.25, 'down')).toBe(3.25);
      expect(roundHours(3.50, 0.25, 'down')).toBe(3.5);
    });

    it('should handle small values', () => {
      expect(roundHours(0.24, 0.25, 'down')).toBe(0.0);
      expect(roundHours(0.10, 0.25, 'down')).toBe(0.0);
    });
  });

  describe('custom precision', () => {
    it('should support 6-minute precision (0.1 hours)', () => {
      expect(roundHours(3.14, 0.1, 'nearest')).toBe(3.1);
      expect(roundHours(3.16, 0.1, 'nearest')).toBe(3.2);
    });

    it('should support hourly precision (1.0 hours)', () => {
      expect(roundHours(3.4, 1.0, 'nearest')).toBe(3.0);
      expect(roundHours(3.6, 1.0, 'nearest')).toBe(4.0);
    });

    it('should support 30-minute precision (0.5 hours)', () => {
      expect(roundHours(3.2, 0.5, 'nearest')).toBe(3.0);
      expect(roundHours(3.3, 0.5, 'nearest')).toBe(3.5);
      expect(roundHours(3.7, 0.5, 'nearest')).toBe(3.5);
    });
  });

  describe('edge cases', () => {
    it('should throw error for negative or zero roundTo', () => {
      expect(() => roundHours(3.5, 0, 'nearest')).toThrow('roundTo must be positive');
      expect(() => roundHours(3.5, -0.25, 'nearest')).toThrow('roundTo must be positive');
    });

    it('should handle zero hours', () => {
      expect(roundHours(0, 0.25, 'nearest')).toBe(0);
      expect(roundHours(0, 0.25, 'up')).toBe(0);
      expect(roundHours(0, 0.25, 'down')).toBe(0);
    });

    it('should handle large values', () => {
      expect(roundHours(40.12, 0.25, 'nearest')).toBe(40.0);
      expect(roundHours(40.875, 0.25, 'nearest')).toBe(41.0); // Exact midpoint rounds up
      expect(roundHours(40.87, 0.25, 'nearest')).toBe(40.75); // Below midpoint rounds down
    });
  });
});

describe('calculateEntryHours', () => {
  it('should calculate hours for 8-hour shift', () => {
    const clockIn = new Date('2025-10-11T08:00:00Z');
    const clockOut = new Date('2025-10-11T16:00:00Z');

    const entry: TimeEntry = {
      id: 'entry-1',
      companyId: 'company-1',
      workerId: 'worker-1',
      jobId: 'job-1',
      clockIn: new MockTimestamp(clockIn) as any,
      clockOut: new MockTimestamp(clockOut) as any,
      status: 'approved',
    };

    expect(calculateEntryHours(entry)).toBe(8.0);
  });

  it('should calculate hours for 4.5-hour shift', () => {
    const clockIn = new Date('2025-10-11T09:00:00Z');
    const clockOut = new Date('2025-10-11T13:30:00Z');

    const entry: TimeEntry = {
      id: 'entry-2',
      companyId: 'company-1',
      workerId: 'worker-1',
      jobId: 'job-1',
      clockIn: new MockTimestamp(clockIn) as any,
      clockOut: new MockTimestamp(clockOut) as any,
      status: 'approved',
    };

    expect(calculateEntryHours(entry)).toBe(4.5);
  });

  it('should round 3 hours 10 minutes to 3.25 hours', () => {
    const clockIn = new Date('2025-10-11T09:00:00Z');
    const clockOut = new Date('2025-10-11T12:10:00Z'); // 3h 10m = 3.167 hours

    const entry: TimeEntry = {
      id: 'entry-3',
      companyId: 'company-1',
      workerId: 'worker-1',
      jobId: 'job-1',
      clockIn: new MockTimestamp(clockIn) as any,
      clockOut: new MockTimestamp(clockOut) as any,
      status: 'approved',
    };

    // 3.167 hours rounds to 3.25 (nearest 15 minutes)
    expect(calculateEntryHours(entry)).toBe(3.25);
  });

  it('should support up rounding mode', () => {
    const clockIn = new Date('2025-10-11T09:00:00Z');
    const clockOut = new Date('2025-10-11T12:05:00Z'); // 3h 5m = 3.083 hours

    const entry: TimeEntry = {
      id: 'entry-4',
      companyId: 'company-1',
      workerId: 'worker-1',
      jobId: 'job-1',
      clockIn: new MockTimestamp(clockIn) as any,
      clockOut: new MockTimestamp(clockOut) as any,
      status: 'approved',
    };

    // 3.083 hours rounds up to 3.25
    expect(calculateEntryHours(entry, 0.25, 'up')).toBe(3.25);
  });

  it('should support down rounding mode', () => {
    const clockIn = new Date('2025-10-11T09:00:00Z');
    const clockOut = new Date('2025-10-11T12:20:00Z'); // 3h 20m = 3.333 hours

    const entry: TimeEntry = {
      id: 'entry-5',
      companyId: 'company-1',
      workerId: 'worker-1',
      jobId: 'job-1',
      clockIn: new MockTimestamp(clockIn) as any,
      clockOut: new MockTimestamp(clockOut) as any,
      status: 'approved',
    };

    // 3.333 hours rounds down to 3.25
    expect(calculateEntryHours(entry, 0.25, 'down')).toBe(3.25);
  });

  it('should handle entries with plain Date objects (not Firestore Timestamps)', () => {
    const clockIn = new Date('2025-10-11T08:00:00Z');
    const clockOut = new Date('2025-10-11T12:00:00Z');

    const entry: TimeEntry = {
      id: 'entry-6',
      companyId: 'company-1',
      workerId: 'worker-1',
      jobId: 'job-1',
      clockIn: clockIn as any, // Plain Date, no toDate() method
      clockOut: clockOut as any,
      status: 'approved',
    };

    expect(calculateEntryHours(entry)).toBe(4.0);
  });

  describe('validation errors', () => {
    it('should throw error if clockIn is missing', () => {
      const entry: TimeEntry = {
        id: 'entry-7',
        companyId: 'company-1',
        workerId: 'worker-1',
        jobId: 'job-1',
        clockIn: null as any,
        clockOut: new MockTimestamp(new Date()) as any,
        status: 'approved',
      };

      expect(() => calculateEntryHours(entry)).toThrow('missing clock-in or clock-out time');
    });

    it('should throw error if clockOut is missing', () => {
      const entry: TimeEntry = {
        id: 'entry-8',
        companyId: 'company-1',
        workerId: 'worker-1',
        jobId: 'job-1',
        clockIn: new MockTimestamp(new Date()) as any,
        clockOut: null as any,
        status: 'approved',
      };

      expect(() => calculateEntryHours(entry)).toThrow('missing clock-in or clock-out time');
    });

    it('should throw error if clockOut is before clockIn', () => {
      const clockIn = new Date('2025-10-11T12:00:00Z');
      const clockOut = new Date('2025-10-11T08:00:00Z'); // Before clockIn

      const entry: TimeEntry = {
        id: 'entry-9',
        companyId: 'company-1',
        workerId: 'worker-1',
        jobId: 'job-1',
        clockIn: new MockTimestamp(clockIn) as any,
        clockOut: new MockTimestamp(clockOut) as any,
        status: 'approved',
      };

      expect(() => calculateEntryHours(entry)).toThrow('clock-out before clock-in');
    });
  });
});

describe('calculateHours', () => {
  it('should return 0 for empty array', () => {
    expect(calculateHours([])).toBe(0);
  });

  it('should return 0 for null/undefined', () => {
    expect(calculateHours(null as any)).toBe(0);
    expect(calculateHours(undefined as any)).toBe(0);
  });

  it('should sum hours for multiple entries', () => {
    const entries: TimeEntry[] = [
      {
        id: 'entry-1',
        companyId: 'company-1',
        workerId: 'worker-1',
        jobId: 'job-1',
        clockIn: new MockTimestamp(new Date('2025-10-11T08:00:00Z')) as any,
        clockOut: new MockTimestamp(new Date('2025-10-11T12:00:00Z')) as any, // 4 hours
        status: 'approved',
      },
      {
        id: 'entry-2',
        companyId: 'company-1',
        workerId: 'worker-1',
        jobId: 'job-1',
        clockIn: new MockTimestamp(new Date('2025-10-11T13:00:00Z')) as any,
        clockOut: new MockTimestamp(new Date('2025-10-11T17:00:00Z')) as any, // 4 hours
        status: 'approved',
      },
    ];

    expect(calculateHours(entries)).toBe(8.0);
  });

  it('should round each entry individually then sum', () => {
    const entries: TimeEntry[] = [
      {
        id: 'entry-1',
        companyId: 'company-1',
        workerId: 'worker-1',
        jobId: 'job-1',
        clockIn: new MockTimestamp(new Date('2025-10-11T08:00:00Z')) as any,
        clockOut: new MockTimestamp(new Date('2025-10-11T11:10:00Z')) as any, // 3h 10m → 3.25
        status: 'approved',
      },
      {
        id: 'entry-2',
        companyId: 'company-1',
        workerId: 'worker-1',
        jobId: 'job-1',
        clockIn: new MockTimestamp(new Date('2025-10-11T13:00:00Z')) as any,
        clockOut: new MockTimestamp(new Date('2025-10-11T16:05:00Z')) as any, // 3h 5m → 3.00
        status: 'approved',
      },
    ];

    // 3.25 + 3.00 = 6.25
    expect(calculateHours(entries)).toBe(6.25);
  });

  it('should apply rounding mode to all entries', () => {
    const entries: TimeEntry[] = [
      {
        id: 'entry-1',
        companyId: 'company-1',
        workerId: 'worker-1',
        jobId: 'job-1',
        clockIn: new MockTimestamp(new Date('2025-10-11T08:00:00Z')) as any,
        clockOut: new MockTimestamp(new Date('2025-10-11T11:10:00Z')) as any, // 3h 10m → up: 3.25
        status: 'approved',
      },
      {
        id: 'entry-2',
        companyId: 'company-1',
        workerId: 'worker-1',
        jobId: 'job-1',
        clockIn: new MockTimestamp(new Date('2025-10-11T13:00:00Z')) as any,
        clockOut: new MockTimestamp(new Date('2025-10-11T16:05:00Z')) as any, // 3h 5m → up: 3.25
        status: 'approved',
      },
    ];

    // Both round up: 3.25 + 3.25 = 6.50
    expect(calculateHours(entries, 0.25, 'up')).toBe(6.5);
  });
});

describe('groupEntriesByJob', () => {
  it('should group entries by jobId', () => {
    const entries: TimeEntry[] = [
      {
        id: 'entry-1',
        companyId: 'company-1',
        workerId: 'worker-1',
        jobId: 'job-1',
        clockIn: new MockTimestamp(new Date()) as any,
        clockOut: new MockTimestamp(new Date()) as any,
        status: 'approved',
      },
      {
        id: 'entry-2',
        companyId: 'company-1',
        workerId: 'worker-1',
        jobId: 'job-2',
        clockIn: new MockTimestamp(new Date()) as any,
        clockOut: new MockTimestamp(new Date()) as any,
        status: 'approved',
      },
      {
        id: 'entry-3',
        companyId: 'company-1',
        workerId: 'worker-2',
        jobId: 'job-1',
        clockIn: new MockTimestamp(new Date()) as any,
        clockOut: new MockTimestamp(new Date()) as any,
        status: 'approved',
      },
    ];

    const grouped = groupEntriesByJob(entries);

    expect(Object.keys(grouped).length).toBe(2);
    expect(grouped['job-1'].length).toBe(2);
    expect(grouped['job-2'].length).toBe(1);
    expect(grouped['job-1'][0].id).toBe('entry-1');
    expect(grouped['job-1'][1].id).toBe('entry-3');
    expect(grouped['job-2'][0].id).toBe('entry-2');
  });

  it('should handle empty array', () => {
    const grouped = groupEntriesByJob([]);
    expect(Object.keys(grouped).length).toBe(0);
  });
});

describe('groupEntriesByWorker', () => {
  it('should group entries by workerId', () => {
    const entries: TimeEntry[] = [
      {
        id: 'entry-1',
        companyId: 'company-1',
        workerId: 'worker-1',
        jobId: 'job-1',
        clockIn: new MockTimestamp(new Date()) as any,
        clockOut: new MockTimestamp(new Date()) as any,
        status: 'approved',
      },
      {
        id: 'entry-2',
        companyId: 'company-1',
        workerId: 'worker-2',
        jobId: 'job-1',
        clockIn: new MockTimestamp(new Date()) as any,
        clockOut: new MockTimestamp(new Date()) as any,
        status: 'approved',
      },
      {
        id: 'entry-3',
        companyId: 'company-1',
        workerId: 'worker-1',
        jobId: 'job-2',
        clockIn: new MockTimestamp(new Date()) as any,
        clockOut: new MockTimestamp(new Date()) as any,
        status: 'approved',
      },
    ];

    const grouped = groupEntriesByWorker(entries);

    expect(Object.keys(grouped).length).toBe(2);
    expect(grouped['worker-1'].length).toBe(2);
    expect(grouped['worker-2'].length).toBe(1);
    expect(grouped['worker-1'][0].id).toBe('entry-1');
    expect(grouped['worker-1'][1].id).toBe('entry-3');
    expect(grouped['worker-2'][0].id).toBe('entry-2');
  });

  it('should handle empty array', () => {
    const grouped = groupEntriesByWorker([]);
    expect(Object.keys(grouped).length).toBe(0);
  });
});

describe('calculateHoursByJob', () => {
  it('should calculate total hours per job', () => {
    const entries: TimeEntry[] = [
      {
        id: 'entry-1',
        companyId: 'company-1',
        workerId: 'worker-1',
        jobId: 'job-1',
        clockIn: new MockTimestamp(new Date('2025-10-11T08:00:00Z')) as any,
        clockOut: new MockTimestamp(new Date('2025-10-11T12:00:00Z')) as any, // 4 hours
        status: 'approved',
      },
      {
        id: 'entry-2',
        companyId: 'company-1',
        workerId: 'worker-2',
        jobId: 'job-1',
        clockIn: new MockTimestamp(new Date('2025-10-11T08:00:00Z')) as any,
        clockOut: new MockTimestamp(new Date('2025-10-11T12:00:00Z')) as any, // 4 hours
        status: 'approved',
      },
      {
        id: 'entry-3',
        companyId: 'company-1',
        workerId: 'worker-1',
        jobId: 'job-2',
        clockIn: new MockTimestamp(new Date('2025-10-11T13:00:00Z')) as any,
        clockOut: new MockTimestamp(new Date('2025-10-11T16:00:00Z')) as any, // 3 hours
        status: 'approved',
      },
    ];

    const hoursByJob = calculateHoursByJob(entries);

    expect(hoursByJob['job-1']).toBe(8.0); // 4 + 4
    expect(hoursByJob['job-2']).toBe(3.0);
  });
});

describe('calculateHoursByWorker', () => {
  it('should calculate total hours per worker', () => {
    const entries: TimeEntry[] = [
      {
        id: 'entry-1',
        companyId: 'company-1',
        workerId: 'worker-1',
        jobId: 'job-1',
        clockIn: new MockTimestamp(new Date('2025-10-11T08:00:00Z')) as any,
        clockOut: new MockTimestamp(new Date('2025-10-11T12:00:00Z')) as any, // 4 hours
        status: 'approved',
      },
      {
        id: 'entry-2',
        companyId: 'company-1',
        workerId: 'worker-1',
        jobId: 'job-2',
        clockIn: new MockTimestamp(new Date('2025-10-11T13:00:00Z')) as any,
        clockOut: new MockTimestamp(new Date('2025-10-11T16:00:00Z')) as any, // 3 hours
        status: 'approved',
      },
      {
        id: 'entry-3',
        companyId: 'company-1',
        workerId: 'worker-2',
        jobId: 'job-1',
        clockIn: new MockTimestamp(new Date('2025-10-11T08:00:00Z')) as any,
        clockOut: new MockTimestamp(new Date('2025-10-11T13:00:00Z')) as any, // 5 hours
        status: 'approved',
      },
    ];

    const hoursByWorker = calculateHoursByWorker(entries);

    expect(hoursByWorker['worker-1']).toBe(7.0); // 4 + 3
    expect(hoursByWorker['worker-2']).toBe(5.0);
  });
});

describe('validateTimeEntryForBilling', () => {
  it('should return null for valid entry', () => {
    const entry: TimeEntry = {
      id: 'entry-1',
      companyId: 'company-1',
      workerId: 'worker-1',
      jobId: 'job-1',
      clockIn: new MockTimestamp(new Date('2025-10-11T08:00:00Z')) as any,
      clockOut: new MockTimestamp(new Date('2025-10-11T12:00:00Z')) as any,
      status: 'approved',
    };

    expect(validateTimeEntryForBilling(entry)).toBeNull();
  });

  it('should return error if clockIn is missing', () => {
    const entry: TimeEntry = {
      id: 'entry-1',
      companyId: 'company-1',
      workerId: 'worker-1',
      jobId: 'job-1',
      clockIn: null as any,
      clockOut: new MockTimestamp(new Date()) as any,
      status: 'approved',
    };

    const error = validateTimeEntryForBilling(entry);
    expect(error).toContain('missing clock-in time');
  });

  it('should return error if clockOut is missing (still active)', () => {
    const entry: TimeEntry = {
      id: 'entry-1',
      companyId: 'company-1',
      workerId: 'worker-1',
      jobId: 'job-1',
      clockIn: new MockTimestamp(new Date()) as any,
      clockOut: null as any,
      status: 'approved',
    };

    const error = validateTimeEntryForBilling(entry);
    expect(error).toContain('missing clock-out time');
    expect(error).toContain('still active');
  });

  it('should return error if status is not approved', () => {
    const entry: TimeEntry = {
      id: 'entry-1',
      companyId: 'company-1',
      workerId: 'worker-1',
      jobId: 'job-1',
      clockIn: new MockTimestamp(new Date('2025-10-11T08:00:00Z')) as any,
      clockOut: new MockTimestamp(new Date('2025-10-11T12:00:00Z')) as any,
      status: 'pending',
    };

    const error = validateTimeEntryForBilling(entry);
    expect(error).toContain('not approved');
    expect(error).toContain('status: pending');
  });

  it('should return error if already invoiced', () => {
    const entry: TimeEntry = {
      id: 'entry-1',
      companyId: 'company-1',
      workerId: 'worker-1',
      jobId: 'job-1',
      clockIn: new MockTimestamp(new Date('2025-10-11T08:00:00Z')) as any,
      clockOut: new MockTimestamp(new Date('2025-10-11T12:00:00Z')) as any,
      status: 'approved',
      invoiceId: 'invoice-123',
    };

    const error = validateTimeEntryForBilling(entry);
    expect(error).toContain('already invoiced');
    expect(error).toContain('invoice-123');
  });

  it('should return error if clockOut is not after clockIn', () => {
    const entry: TimeEntry = {
      id: 'entry-1',
      companyId: 'company-1',
      workerId: 'worker-1',
      jobId: 'job-1',
      clockIn: new MockTimestamp(new Date('2025-10-11T12:00:00Z')) as any,
      clockOut: new MockTimestamp(new Date('2025-10-11T12:00:00Z')) as any, // Same time
      status: 'approved',
    };

    const error = validateTimeEntryForBilling(entry);
    expect(error).toContain('invalid times');
    expect(error).toContain('clock-out not after clock-in');
  });
});

describe('validateTimeEntriesForBilling', () => {
  it('should return empty array for all valid entries', () => {
    const entries: TimeEntry[] = [
      {
        id: 'entry-1',
        companyId: 'company-1',
        workerId: 'worker-1',
        jobId: 'job-1',
        clockIn: new MockTimestamp(new Date('2025-10-11T08:00:00Z')) as any,
        clockOut: new MockTimestamp(new Date('2025-10-11T12:00:00Z')) as any,
        status: 'approved',
      },
      {
        id: 'entry-2',
        companyId: 'company-1',
        workerId: 'worker-1',
        jobId: 'job-1',
        clockIn: new MockTimestamp(new Date('2025-10-11T13:00:00Z')) as any,
        clockOut: new MockTimestamp(new Date('2025-10-11T17:00:00Z')) as any,
        status: 'approved',
      },
    ];

    const errors = validateTimeEntriesForBilling(entries);
    expect(errors.length).toBe(0);
  });

  it('should return all errors for invalid entries', () => {
    const entries: TimeEntry[] = [
      {
        id: 'entry-1',
        companyId: 'company-1',
        workerId: 'worker-1',
        jobId: 'job-1',
        clockIn: null as any, // Missing clockIn
        clockOut: new MockTimestamp(new Date()) as any,
        status: 'approved',
      },
      {
        id: 'entry-2',
        companyId: 'company-1',
        workerId: 'worker-1',
        jobId: 'job-1',
        clockIn: new MockTimestamp(new Date()) as any,
        clockOut: new MockTimestamp(new Date()) as any,
        status: 'pending', // Not approved
      },
      {
        id: 'entry-3',
        companyId: 'company-1',
        workerId: 'worker-1',
        jobId: 'job-1',
        clockIn: new MockTimestamp(new Date()) as any,
        clockOut: new MockTimestamp(new Date()) as any,
        status: 'approved',
        invoiceId: 'invoice-123', // Already invoiced
      },
    ];

    const errors = validateTimeEntriesForBilling(entries);
    expect(errors.length).toBe(3);
    expect(errors[0]).toContain('entry-1');
    expect(errors[0]).toContain('missing clock-in');
    expect(errors[1]).toContain('entry-2');
    expect(errors[1]).toContain('not approved');
    expect(errors[2]).toContain('entry-3');
    expect(errors[2]).toContain('already invoiced');
  });
});
