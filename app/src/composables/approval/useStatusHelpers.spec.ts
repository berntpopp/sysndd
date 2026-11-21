import { describe, expect, it } from 'vitest';
import CategoryIcon from '@/components/ui/CategoryIcon.vue';
import { statusLegendItems } from './useStatusHelpers';
import { reviewLegendItems } from '@/composables/review/useReviewHelpers';
import { LEGEND_ITEMS } from '@/views/review/reviewTableConfig';

// CUR-06: the legends showed stoplights while the cells render CategoryIcon.
describe.each([
  ['status approval', statusLegendItems],
  ['review approval', reviewLegendItems],
  ['re-review queue', LEGEND_ITEMS],
])('%s legend', (_name, items) => {
  it('draws the four categories with the CategoryIcon the cells use', () => {
    const categories = items.filter((item) => 'component' in item && item.component);
    expect(categories.map((item) => item.label)).toEqual([
      'Definitive',
      'Moderate',
      'Limited',
      'Refuted',
    ]);
    for (const item of categories) {
      expect('component' in item && item.component).toBe(CategoryIcon);
    }
    expect(items.some((item) => 'icon' in item && /stoplights-fill/.test(String(item.icon)))).toBe(
      false
    );
  });
});
