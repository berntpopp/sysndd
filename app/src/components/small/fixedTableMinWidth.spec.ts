import { describe, expect, it } from 'vitest';
import { fixedTableMinWidth } from './fixedTableMinWidth';

describe('fixedTableMinWidth', () => {
  it('leaves room for every unsized column next to the fixed and percent ones', () => {
    // Manage Users: 40 px select, 26 % e-mail, unsized user name, 40 rem of fixed columns.
    const fields = [
      { thStyle: { width: '40px' } },
      { thStyle: { width: '26%' } },
      { key: 'user_name' },
      { thStyle: { width: '10rem' } },
      { thStyle: { width: '8rem' } },
      { thStyle: { width: '6rem' } },
      { thStyle: { width: '10rem' } },
      { thStyle: { width: '6rem' } },
    ];
    // (2.5 + 40 + 7) / 0.74
    expect(fixedTableMinWidth(fields)).toBe('66.89rem');
  });

  it('is undefined when nothing has a fixed width', () => {
    expect(fixedTableMinWidth([{ key: 'a' }, 'b', { thStyle: { width: '50%' } }])).toBeUndefined();
  });
});
