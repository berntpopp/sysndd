// app/src/views/admin/composables/__tests__/useBackupInventory.spec.ts
/**
 * Unit tests for the pure helpers + filter/pagination logic in
 * `useBackupInventory` — the inventory composable extracted from
 * `ManageBackups.vue` during refactor #346 WP6 (#399).
 */

import { describe, expect, it } from 'vitest';
import {
  useBackupInventory,
  formatFileSize,
  formatDate,
  getBackupType,
  getBackupTypeBadgeVariant,
  type BackupItem,
} from '../useBackupInventory';

function makeBackup(filename: string, overrides: Partial<BackupItem> = {}): BackupItem {
  return {
    filename,
    size_bytes: 1024,
    created_at: '2025-10-01T08:30:00Z',
    table_count: null,
    ...overrides,
  };
}

describe('useBackupInventory pure helpers', () => {
  it('formatFileSize renders human-readable sizes', () => {
    expect(formatFileSize(0)).toBe('0 B');
    expect(formatFileSize(1024)).toBe('1 KB');
    expect(formatFileSize(1536)).toBe('1.5 KB');
    expect(formatFileSize(1048576)).toBe('1 MB');
  });

  it('formatDate renders YYYY-MM-DD HH:mm and passes through unparseable input', () => {
    expect(formatDate('')).toBe('');
    expect(formatDate('not-a-date')).toBe('not-a-date');
    // Use a fixed local time to avoid timezone flake on the date portion.
    const out = formatDate('2025-10-01T12:34:00');
    expect(out).toMatch(/^2025-10-01 \d{2}:\d{2}$/);
  });

  it('getBackupType + badge variant key off the filename prefix', () => {
    expect(getBackupType('manual_2025.sql.gz')).toBe('manual');
    expect(getBackupType('pre-restore_2025.sql.gz')).toBe('pre-restore');
    expect(getBackupType('auto_2025.sql.gz')).toBeNull();

    expect(getBackupTypeBadgeVariant('manual_x')).toBe('primary');
    expect(getBackupTypeBadgeVariant('pre-restore_x')).toBe('warning');
    expect(getBackupTypeBadgeVariant('auto_x')).toBe('secondary');
  });
});

describe('useBackupInventory filtering and pagination', () => {
  it('quickFilters counts manual / automatic / pre-restore correctly', () => {
    const inv = useBackupInventory();
    inv.backups.value = [
      makeBackup('manual_a.sql.gz'),
      makeBackup('manual_b.sql'),
      makeBackup('auto_c.sql.gz'),
      makeBackup('pre-restore_d.sql.gz'),
    ];

    const counts = Object.fromEntries(inv.quickFilters.value.map((f) => [f.value, f.count]));
    expect(counts.manual).toBe(2);
    expect(counts.auto).toBe(1);
    expect(counts['pre-restore']).toBe(1);
  });

  it('search + type filters narrow the list and setTypeFilter toggles', () => {
    const inv = useBackupInventory();
    inv.backups.value = [
      makeBackup('manual_alpha.sql.gz'),
      makeBackup('manual_beta.sql'),
      makeBackup('auto_gamma.sql.gz'),
    ];

    inv.searchQuery.value = 'alpha';
    expect(inv.filteredBackups.value.map((b) => b.filename)).toEqual(['manual_alpha.sql.gz']);

    inv.searchQuery.value = '';
    inv.setTypeFilter('manual');
    expect(inv.filteredBackups.value).toHaveLength(2);
    // Toggling the same filter clears it.
    inv.setTypeFilter('manual');
    expect(inv.typeFilter.value).toBeNull();
    expect(inv.filteredBackups.value).toHaveLength(3);
  });

  it('compression filter splits .gz from .sql', () => {
    const inv = useBackupInventory();
    inv.backups.value = [makeBackup('a.sql.gz'), makeBackup('b.sql')];

    inv.compressionFilter.value = 'compressed';
    expect(inv.filteredBackups.value.map((b) => b.filename)).toEqual(['a.sql.gz']);
    inv.compressionFilter.value = 'uncompressed';
    expect(inv.filteredBackups.value.map((b) => b.filename)).toEqual(['b.sql']);
  });

  it('pagination slices the sorted list and reports the window bounds', () => {
    const inv = useBackupInventory();
    inv.perPage.value = 2;
    inv.backups.value = [
      makeBackup('a.sql', { created_at: '2025-10-01T00:00:00Z' }),
      makeBackup('b.sql', { created_at: '2025-10-02T00:00:00Z' }),
      makeBackup('c.sql', { created_at: '2025-10-03T00:00:00Z' }),
    ];

    // Default sort is created_at desc — newest first.
    expect(inv.paginatedBackups.value.map((b) => b.filename)).toEqual(['c.sql', 'b.sql']);
    expect(inv.paginationStart.value).toBe(1);
    expect(inv.paginationEnd.value).toBe(2);

    inv.currentPage.value = 2;
    expect(inv.paginatedBackups.value.map((b) => b.filename)).toEqual(['a.sql']);
    expect(inv.paginationEnd.value).toBe(3);
  });

  it('clearFilters resets all filters and the page', () => {
    const inv = useBackupInventory();
    inv.searchQuery.value = 'x';
    inv.typeFilter.value = 'manual';
    inv.compressionFilter.value = 'compressed';
    inv.currentPage.value = 4;

    inv.clearFilters();
    expect(inv.searchQuery.value).toBe('');
    expect(inv.typeFilter.value).toBeNull();
    expect(inv.compressionFilter.value).toBeNull();
    expect(inv.currentPage.value).toBe(1);
    expect(inv.hasActiveFilters.value).toBe(false);
  });
});
