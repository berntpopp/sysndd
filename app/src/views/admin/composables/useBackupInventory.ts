// app/src/views/admin/composables/useBackupInventory.ts
import { ref, computed, watch } from 'vue';
import { listBackups, downloadBackup as downloadBackupFile } from '@/api/backup';
import { extractApiErrorMessage } from '@/utils/api-errors';

/**
 * A single database backup row in the inventory surface.
 */
export interface BackupItem {
  filename: string;
  size_bytes: number;
  created_at: string;
  table_count: number | null;
}

/**
 * Aggregate inventory metadata (totals shown in the table-shell header).
 */
export interface BackupMeta {
  total_count: number;
  total_size_bytes: number;
}

export interface UseBackupInventoryOptions {
  onToast?: ReturnType<typeof import('@/composables/useToast').default>['makeToast'];
}

/**
 * Unwrap R/Plumber array values (scalars arrive as single-element arrays).
 */
function unwrapValue<T>(val: T | T[]): T {
  return Array.isArray(val) && val.length === 1 ? val[0] : (val as T);
}

/**
 * Format a byte count to a human-readable size string.
 */
export function formatFileSize(bytes: number): string {
  if (!bytes || bytes === 0) return '0 B';
  const k = 1024;
  const sizes = ['B', 'KB', 'MB', 'GB', 'TB'];
  const i = Math.floor(Math.log(bytes) / Math.log(k));
  return parseFloat((bytes / Math.pow(k, i)).toFixed(1)) + ' ' + sizes[i];
}

/**
 * Format an ISO date string as "YYYY-MM-DD HH:mm".
 */
export function formatDate(dateString: string): string {
  if (!dateString) return '';
  const date = new Date(dateString);
  if (isNaN(date.getTime())) return dateString;
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, '0');
  const day = String(date.getDate()).padStart(2, '0');
  const hours = String(date.getHours()).padStart(2, '0');
  const minutes = String(date.getMinutes()).padStart(2, '0');
  return `${year}-${month}-${day} ${hours}:${minutes}`;
}

/**
 * Resolve the SysNDD backup "type" label from a filename prefix.
 */
export function getBackupType(filename: string): string | null {
  if (filename.startsWith('manual_')) return 'manual';
  if (filename.startsWith('pre-restore_')) return 'pre-restore';
  return null;
}

/**
 * Bootstrap badge variant matching the backup type prefix.
 */
export function getBackupTypeBadgeVariant(
  filename: string
): 'primary' | 'warning' | 'secondary' {
  if (filename.startsWith('manual_')) return 'primary';
  if (filename.startsWith('pre-restore_')) return 'warning';
  return 'secondary';
}

/**
 * Inventory state + filter/sort/pagination logic for the backup manager.
 *
 * Extracted from `ManageBackups.vue` so the view stays a thin shell. Owns the
 * raw backup list, derived filtered/sorted/paginated views, the quick-filter
 * counts, the list fetch, and the file download. Job orchestration lives in a
 * sibling composable (`useBackupJobs`).
 */
export function useBackupInventory(options: UseBackupInventoryOptions = {}) {
  const { onToast } = options;

  // Inventory state
  const backups = ref<BackupItem[]>([]);
  const meta = ref<BackupMeta>({ total_count: 0, total_size_bytes: 0 });
  const loading = ref(false);

  // Filter and pagination state
  const searchQuery = ref('');
  const typeFilter = ref<string | null>(null);
  const compressionFilter = ref<string | null>(null);
  const currentPage = ref(1);
  const perPage = ref(10);
  const pageOptions = [10, 25, 50, 100];
  const sortBy = ref<Array<{ key: string; order: 'asc' | 'desc' }>>([
    { key: 'created_at', order: 'desc' },
  ]);
  const mobileSortOptions = [
    { value: '-created_at', text: 'Newest first' },
    { value: '+created_at', text: 'Oldest first' },
    { value: '+filename', text: 'Filename ascending' },
    { value: '-filename', text: 'Filename descending' },
    { value: '-size_bytes', text: 'Largest first' },
    { value: '+size_bytes', text: 'Smallest first' },
  ];

  // Computed: Quick filter counts
  const quickFilters = computed(() => {
    const manual = backups.value.filter((b) => b.filename.startsWith('manual_')).length;
    const auto = backups.value.filter(
      (b) => !b.filename.startsWith('manual_') && !b.filename.startsWith('pre-restore_')
    ).length;
    const preRestore = backups.value.filter((b) =>
      b.filename.startsWith('pre-restore_')
    ).length;

    return [
      { label: 'Manual', value: 'manual', count: manual },
      { label: 'Automatic', value: 'auto', count: auto },
      { label: 'Pre-Restore', value: 'pre-restore', count: preRestore },
    ];
  });

  // Computed: Filtered backups
  const filteredBackups = computed(() => {
    let result = [...backups.value];

    // Search filter
    if (searchQuery.value) {
      const query = searchQuery.value.toLowerCase();
      result = result.filter((b) => b.filename.toLowerCase().includes(query));
    }

    // Type filter
    if (typeFilter.value === 'manual') {
      result = result.filter((b) => b.filename.startsWith('manual_'));
    } else if (typeFilter.value === 'auto') {
      result = result.filter(
        (b) => !b.filename.startsWith('manual_') && !b.filename.startsWith('pre-restore_')
      );
    } else if (typeFilter.value === 'pre-restore') {
      result = result.filter((b) => b.filename.startsWith('pre-restore_'));
    }

    // Compression filter
    if (compressionFilter.value === 'compressed') {
      result = result.filter((b) => b.filename.endsWith('.gz'));
    } else if (compressionFilter.value === 'uncompressed') {
      result = result.filter((b) => !b.filename.endsWith('.gz'));
    }

    return result;
  });

  const mobileSortValue = computed({
    get() {
      const current = sortBy.value[0] || { key: 'created_at', order: 'desc' as const };
      return `${current.order === 'desc' ? '-' : '+'}${current.key}`;
    },
    set(value: string) {
      sortBy.value = [
        {
          key: value.slice(1),
          order: value.startsWith('-') ? 'desc' : 'asc',
        },
      ];
      currentPage.value = 1;
    },
  });

  const sortedBackups = computed(() => {
    const current = sortBy.value[0] || { key: 'created_at', order: 'desc' as const };
    const multiplier = current.order === 'desc' ? -1 : 1;
    return [...filteredBackups.value].sort((left, right) => {
      const leftValue = left[current.key as keyof BackupItem];
      const rightValue = right[current.key as keyof BackupItem];
      if (typeof leftValue === 'number' && typeof rightValue === 'number') {
        return (leftValue - rightValue) * multiplier;
      }
      return String(leftValue ?? '').localeCompare(String(rightValue ?? '')) * multiplier;
    });
  });

  // Computed: Paginated backups
  const paginatedBackups = computed(() => {
    const start = (currentPage.value - 1) * perPage.value;
    const end = start + perPage.value;
    return sortedBackups.value.slice(start, end);
  });

  // Computed: Pagination display
  const paginationStart = computed(() => {
    if (filteredBackups.value.length === 0) return 0;
    return (currentPage.value - 1) * perPage.value + 1;
  });

  const paginationEnd = computed(() => {
    return Math.min(currentPage.value * perPage.value, filteredBackups.value.length);
  });

  // Computed: Has active filters
  const hasActiveFilters = computed(() => {
    return (
      searchQuery.value !== '' || typeFilter.value !== null || compressionFilter.value !== null
    );
  });

  // Set type filter from quick filter button
  function setTypeFilter(value: string) {
    if (typeFilter.value === value) {
      typeFilter.value = null;
    } else {
      typeFilter.value = value;
    }
    currentPage.value = 1;
  }

  // Clear all filters
  function clearFilters() {
    searchQuery.value = '';
    typeFilter.value = null;
    compressionFilter.value = null;
    currentPage.value = 1;
  }

  // Handle sort change
  function onSortChanged(ctx: { sortBy: string; sortDesc: boolean }) {
    sortBy.value = [{ key: ctx.sortBy, order: ctx.sortDesc ? 'desc' : 'asc' }];
  }

  // Fetch backup list from API
  async function fetchBackupList() {
    loading.value = true;
    try {
      const data = await listBackups();

      if (data && Array.isArray(data.data)) {
        backups.value = (data.data as unknown as Record<string, unknown>[]).map(
          (backup: Record<string, unknown>) => ({
            filename: unwrapValue(backup.filename) as string,
            size_bytes: Number(unwrapValue(backup.size_bytes)) || 0,
            created_at: unwrapValue(backup.created_at) as string,
            table_count: backup.table_count ? Number(unwrapValue(backup.table_count)) : null,
          })
        );
      } else {
        backups.value = [];
      }

      // Update meta
      if (data && data.meta) {
        meta.value = {
          total_count: Number(unwrapValue(data.meta.total_count)) || 0,
          total_size_bytes: Number(unwrapValue(data.meta.total_size_bytes)) || 0,
        };
      }
    } catch (error) {
      console.error('Failed to fetch backup list:', error);
      onToast?.('Failed to load backup list', 'Error', 'danger');
      backups.value = [];
    } finally {
      loading.value = false;
    }
  }

  // Download backup file
  async function downloadBackup(filename: string) {
    try {
      const blob = await downloadBackupFile(filename);

      const url = window.URL.createObjectURL(new Blob([blob]));
      const link = document.createElement('a');
      link.href = url;
      link.setAttribute('download', filename);
      document.body.appendChild(link);
      link.click();
      document.body.removeChild(link);
      window.URL.revokeObjectURL(url);
    } catch (error) {
      console.error('Download failed:', error);
      onToast?.(extractApiErrorMessage(error, 'Download failed'), 'Error', 'danger');
    }
  }

  // Reset to page 1 when filters change
  watch([searchQuery, typeFilter, compressionFilter], () => {
    currentPage.value = 1;
  });

  return {
    // State
    backups,
    meta,
    loading,
    searchQuery,
    typeFilter,
    compressionFilter,
    currentPage,
    perPage,
    pageOptions,
    sortBy,
    mobileSortOptions,
    // Computed
    quickFilters,
    filteredBackups,
    mobileSortValue,
    sortedBackups,
    paginatedBackups,
    paginationStart,
    paginationEnd,
    hasActiveFilters,
    // Formatters (re-exported for template use)
    formatFileSize,
    formatDate,
    getBackupType,
    getBackupTypeBadgeVariant,
    // Methods
    setTypeFilter,
    clearFilters,
    onSortChanged,
    fetchBackupList,
    downloadBackup,
  };
}
