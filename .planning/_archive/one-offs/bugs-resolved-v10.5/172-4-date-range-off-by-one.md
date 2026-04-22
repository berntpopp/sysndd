# Fix Proposal: Previous Period Date Range Off-by-One (#172, Bug 4)

## Problem

The comparison period calculation computes range length as `endDate - startDate` (in days), but for inclusive date ranges this is off by one.

```typescript
// AdminStatistics.vue:549-584
const rangeLength = Math.abs(
  (endDateObj.getTime() - startDateObj.getTime()) / (1000 * 60 * 60 * 24)
);
// Jan 10 to Jan 20 → rangeLength = 10 (should be 11 for inclusive)
```

The previous period then uses this wrong length, making it 1 day shorter than the current period. The percentage-change delta is skewed.

## Proposed Fix

Extract date utility functions to keep the logic DRY and testable.

**Add to `app/src/utils/dateUtils.ts`:**

```typescript
const MS_PER_DAY = 86_400_000;

/** Inclusive day count between two dates. */
export function inclusiveDayCount(start: Date, end: Date): number {
  return Math.round(Math.abs(end.getTime() - start.getTime()) / MS_PER_DAY) + 1;
}

/** Compute previous period of equal length ending the day before start. */
export function previousPeriod(start: Date, end: Date): { start: Date; end: Date } {
  const days = inclusiveDayCount(start, end);
  const prevEnd = new Date(start);
  prevEnd.setDate(prevEnd.getDate() - 1);
  const prevStart = new Date(prevEnd);
  prevStart.setDate(prevStart.getDate() - days + 1);
  return { start: prevStart, end: prevEnd };
}
```

**Update `calculateTrendDelta()` in AdminStatistics.vue:**

```typescript
import { previousPeriod } from '@/utils/dateUtils';

const { start: prevStart, end: prevEnd } = previousPeriod(
  new Date(startDate.value),
  new Date(endDate.value)
);
```

## Why

| Principle | How Applied |
|-----------|-------------|
| **DRY** | Date math extracted to reusable utility |
| **Testable** | Pure functions, easy to verify edge cases (month boundaries, leap years) |
| **KISS** | `+1` for inclusive range is the standard fix |

## Files Changed

- `app/src/utils/dateUtils.ts` (NEW)
- `app/src/views/admin/AdminStatistics.vue` (use utility)
