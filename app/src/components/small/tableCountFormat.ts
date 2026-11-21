// Count wording shared by the table headers and the pager.
import { formatShowingRange } from '@/utils/displayFormat';

export { formatCount, formatShowingRange } from '@/utils/displayFormat';

/** Range for page `page` (1-based) of `perPage` rows when `shown` rows are on screen. */
export function formatPageRange(page: number, perPage: number, shown: number, total: number) {
  const first = (Math.max(page || 1, 1) - 1) * perPage + 1;
  return formatShowingRange(first, first + shown - 1, total);
}
