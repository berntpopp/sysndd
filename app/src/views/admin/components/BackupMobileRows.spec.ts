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

    await wrapper.get('button[aria-label="Download backup manual_2026-05-01.sql.gz"]').trigger('click');
    await wrapper.get('button[aria-label="Restore backup manual_2026-05-01.sql.gz"]').trigger('click');
    await wrapper.get('button[aria-label="Delete backup manual_2026-05-01.sql.gz"]').trigger('click');

    expect(wrapper.emitted('download')).toEqual([[item]]);
    expect(wrapper.emitted('restore')).toEqual([[item]]);
    expect(wrapper.emitted('delete')).toEqual([[item]]);
  });
});
