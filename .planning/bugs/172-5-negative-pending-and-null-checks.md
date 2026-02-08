# Fix Proposal: Defensive Data Handling (#172, Bugs 5+6)

## Problems

**Bug 5:** `ReReviewBarChart.vue` computes Pending as `submitted_count - approved_count`. If data is inconsistent (`approved > submitted`), this produces negative bar values.

**Bug 6:** Leaderboard data processing calls `.map()` on `response.data.data` without null-checking. If the API returns an error shape, the page crashes.

## Root Cause

Missing input validation at the boundary between API responses and UI rendering. The frontend trusts that API data is always well-formed.

## Proposed Fix

### Create a response validation utility

**Add to `app/src/utils/apiUtils.ts`:**

```typescript
/**
 * Safely extract an array from an API response, returning [] on any failure.
 * Prevents crashes from malformed or error responses.
 */
export function safeArray<T>(data: unknown): T[] {
  return Array.isArray(data) ? data : [];
}

/**
 * Clamp a number to a minimum of 0. Prevents negative chart values
 * from data inconsistencies.
 */
export function clampPositive(n: number): number {
  return Math.max(0, n ?? 0);
}
```

### Apply in AdminStatistics.vue

```typescript
import { safeArray } from '@/utils/apiUtils';

// Leaderboard (line 466)
const data = safeArray<LeaderboardItem>(response.data?.data);
leaderboardData.value = data.map((item) => ({
  user_name: item.display_name || 'Unknown',
  entity_count: item.entity_count ?? 0,
}));

// Re-review leaderboard (line 510)
const data = safeArray<ReReviewItem>(response.data?.data);
reReviewLeaderboardData.value = data.map((item) => ({ ... }));
```

### Apply in ReReviewBarChart.vue

```typescript
import { clampPositive } from '@/utils/apiUtils';

// Pending dataset (line 63)
data: props.reviewers.map((r) => clampPositive(r.submitted_count - r.approved_count)),
```

## Why

| Principle | How Applied |
|-----------|-------------|
| **Defensive Programming** | Validate at system boundaries (API → UI) |
| **DRY** | `safeArray` and `clampPositive` reusable across all admin views |
| **Fail Gracefully** | Empty array + 0 instead of crash + NaN |
| **KISS** | One-liner utilities, no complex validation framework |

## Files Changed

- `app/src/utils/apiUtils.ts` (NEW)
- `app/src/views/admin/AdminStatistics.vue` (use `safeArray`)
- `app/src/views/admin/components/charts/ReReviewBarChart.vue` (use `clampPositive`)
