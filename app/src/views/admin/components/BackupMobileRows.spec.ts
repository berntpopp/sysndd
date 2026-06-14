import { describe, expect, it } from 'vitest';
import { mount } from '@vue/test-utils';
import BackupMobileRows from './BackupMobileRows.vue';

describe('BackupMobileRows', () => {
  it('renders backup metadata and emits row actions', async () => {
    const item = {
      filename: 'manual_2026-05-01.sql.gz',
      size_bytes: 2048,
      created_at: '2026-05-01T10:30:00Z',
      table_count: 12,
    };

    const wrapper = mount(BackupMobileRows, {
      props: { items: [item] },
    });

    expect(wrapper.text()).toContain('manual_2026-05-01.sql.gz');
    expect(wrapper.text()).toContain('2 KB');
    expect(wrapper.text()).toContain('manual');

    await wrapper
      .get('button[aria-label="Download backup manual_2026-05-01.sql.gz"]')
      .trigger('click');
    await wrapper
      .get('button[aria-label="Restore backup manual_2026-05-01.sql.gz"]')
      .trigger('click');
    await wrapper
      .get('button[aria-label="Delete backup manual_2026-05-01.sql.gz"]')
      .trigger('click');

    expect(wrapper.emitted('download')).toEqual([[item]]);
    expect(wrapper.emitted('restore')).toEqual([[item]]);
    expect(wrapper.emitted('delete')).toEqual([[item]]);
  });

  it('uses the canonical inventory formatters (DRY) for size and type', () => {
    // After the DRY refactor the row delegates formatFileSize/formatDate/
    // getBackupType to ../composables/useBackupInventory instead of
    // re-implementing them locally.
    const item = {
      filename: 'pre-restore_2026-05-01.sql',
      size_bytes: 1048576,
      created_at: '2026-05-01T10:30:00Z',
      table_count: null,
    };

    const wrapper = mount(BackupMobileRows, {
      props: { items: [item] },
    });

    // Canonical formatFileSize: 1 MB (1048576 bytes).
    expect(wrapper.text()).toContain('1 MB');
    // Canonical getBackupType: pre-restore prefix.
    expect(wrapper.text()).toContain('pre-restore');
    // table_count null -> the tables chip is hidden.
    expect(wrapper.text()).not.toContain('tables');
  });
});
