export type ReReviewAssignmentFilter = 'assigned' | 'unassigned' | null;

export interface ReReviewBatchRow {
  user_id?: number | null;
  user_name?: string | null;
  re_review_batch?: number | string | null;
  [key: string]: unknown;
}

export interface ReReviewBatchFilters {
  text?: string | null;
  userName?: string | null;
  assignment?: ReReviewAssignmentFilter;
}

export interface ReReviewSort {
  key?: string | null;
  order?: 'asc' | 'desc' | string | null;
}

export function filterReReviewBatches<T extends ReReviewBatchRow>(
  rows: T[],
  filters: ReReviewBatchFilters
): T[] {
  const searchTerm = filters.text?.toLowerCase() ?? '';

  return rows.filter((row) => {
    if (searchTerm) {
      const userName = (row.user_name || '').toLowerCase();
      const batchId = String(row.re_review_batch || '');
      if (!userName.includes(searchTerm) && !batchId.includes(searchTerm)) {
        return false;
      }
    }

    if (filters.userName && row.user_name !== filters.userName) {
      return false;
    }

    if (filters.assignment === 'assigned') {
      return Boolean(row.user_id);
    }

    if (filters.assignment === 'unassigned') {
      return !row.user_id;
    }

    return true;
  });
}

export function sortReReviewBatches<T extends ReReviewBatchRow>(
  rows: T[],
  sortBy: ReReviewSort[]
): T[] {
  const [sort] = Array.isArray(sortBy) ? sortBy : [];
  if (!sort?.key) return rows;

  const order = sort.order === 'desc' ? -1 : 1;
  return [...rows].sort((a, b) => {
    const aValue = a[sort.key as keyof T];
    const bValue = b[sort.key as keyof T];
    if (aValue === bValue) return 0;
    if (aValue === null || aValue === undefined) return 1;
    if (bValue === null || bValue === undefined) return -1;
    if (typeof aValue === 'number' && typeof bValue === 'number') {
      return (aValue - bValue) * order;
    }
    return (
      String(aValue).localeCompare(String(bValue), undefined, {
        numeric: true,
        sensitivity: 'base',
      }) * order
    );
  });
}
