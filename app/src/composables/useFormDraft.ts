// composables/useFormDraft.ts
/**
 * Composable for form draft auto-save functionality.
 * Persists form state to localStorage with automatic save and restore.
 *
 * Features:
 * - Auto-save on changes (debounced)
 * - Draft detection on page load
 * - Restore from draft
 * - Clear draft after successful submission
 */

import { ref, computed, onUnmounted } from 'vue';

export interface DraftMetadata {
  savedAt: number;
  formKey: string;
}

export interface DraftData<T> {
  metadata: DraftMetadata;
  data: T;
}

const STORAGE_PREFIX = 'sysndd_draft_';
const AUTO_SAVE_DELAY = 30000; // 30 seconds
const DEBOUNCE_DELAY = 2000; // 2 seconds after last change

/**
 * Format relative time for display
 */
function formatRelativeTime(timestamp: number): string {
  const now = Date.now();
  const diff = now - timestamp;
  const seconds = Math.floor(diff / 1000);
  const minutes = Math.floor(seconds / 60);
  const hours = Math.floor(minutes / 60);
  const days = Math.floor(hours / 24);

  if (days > 0) return `${days} day${days > 1 ? 's' : ''} ago`;
  if (hours > 0) return `${hours} hour${hours > 1 ? 's' : ''} ago`;
  if (minutes > 0) return `${minutes} min${minutes > 1 ? 's' : ''} ago`;
  return 'just now';
}

/**
 * Check if draft is stale (older than 7 days)
 */
function isDraftStale(timestamp: number): boolean {
  const sevenDaysMs = 7 * 24 * 60 * 60 * 1000;
  return Date.now() - timestamp > sevenDaysMs;
}

/**
 * Main composable for form draft management
 * @param formKey - Unique key for this form (e.g., 'create-entity')
 */
export default function useFormDraft<T>(formKey: string) {
  const storageKey = `${STORAGE_PREFIX}${formKey}`;

  // State
  const hasDraft = ref(false);
  const lastSavedAt = ref<number | null>(null);
  const isSaving = ref(false);
  const autoSaveEnabled = ref(true);

  // Timers
  let autoSaveTimer: ReturnType<typeof setTimeout> | null = null;
  let debounceTimer: ReturnType<typeof setTimeout> | null = null;

  /**
   * Save data to localStorage
   */
  const saveDraft = (data: T): boolean => {
    try {
      const draftData: DraftData<T> = {
        metadata: {
          savedAt: Date.now(),
          formKey,
        },
        data,
      };

      localStorage.setItem(storageKey, JSON.stringify(draftData));
      lastSavedAt.value = draftData.metadata.savedAt;
      hasDraft.value = true;
      isSaving.value = false;
      return true;
    } catch (error) {
      console.error('Failed to save draft:', error);
      isSaving.value = false;
      return false;
    }
  };

  /**
   * Load draft from localStorage
   */
  const loadDraft = (): T | null => {
    try {
      const stored = localStorage.getItem(storageKey);
      if (!stored) return null;

      const draftData: DraftData<T> = JSON.parse(stored);

      // Check if draft is stale
      if (isDraftStale(draftData.metadata.savedAt)) {
        clearDraft();
        return null;
      }

      lastSavedAt.value = draftData.metadata.savedAt;
      hasDraft.value = true;
      return draftData.data;
    } catch (error) {
      console.error('Failed to load draft:', error);
      return null;
    }
  };

  /**
   * Clear draft from localStorage
   */
  const clearDraft = () => {
    try {
      localStorage.removeItem(storageKey);
      hasDraft.value = false;
      lastSavedAt.value = null;
    } catch (error) {
      console.error('Failed to clear draft:', error);
    }
  };

  /**
   * Check if a draft exists
   */
  const checkForDraft = (): boolean => {
    try {
      const stored = localStorage.getItem(storageKey);
      if (!stored) {
        hasDraft.value = false;
        return false;
      }

      const draftData: DraftData<T> = JSON.parse(stored);

      if (isDraftStale(draftData.metadata.savedAt)) {
        clearDraft();
        return false;
      }

      lastSavedAt.value = draftData.metadata.savedAt;
      hasDraft.value = true;
      return true;
    } catch {
      hasDraft.value = false;
      return false;
    }
  };

  /**
   * Schedule auto-save with debounce
   */
  const scheduleSave = (data: T) => {
    if (!autoSaveEnabled.value) return;

    // Clear existing timers
    if (debounceTimer) clearTimeout(debounceTimer);

    isSaving.value = true;

    // Debounce: save after user stops making changes
    debounceTimer = setTimeout(() => {
      saveDraft(data);
    }, DEBOUNCE_DELAY);
  };

  /**
   * Start periodic auto-save
   */
  const startAutoSave = (getDataFn: () => T) => {
    if (autoSaveTimer) clearInterval(autoSaveTimer);

    autoSaveTimer = setInterval(() => {
      if (autoSaveEnabled.value) {
        saveDraft(getDataFn());
      }
    }, AUTO_SAVE_DELAY);
  };

  /**
   * Stop auto-save
   */
  const stopAutoSave = () => {
    if (autoSaveTimer) {
      clearInterval(autoSaveTimer);
      autoSaveTimer = null;
    }
    if (debounceTimer) {
      clearTimeout(debounceTimer);
      debounceTimer = null;
    }
  };

  /**
   * Formatted last saved time
   */
  const lastSavedFormatted = computed(() => {
    if (!lastSavedAt.value) return null;
    return formatRelativeTime(lastSavedAt.value);
  });

  /**
   * Cleanup on unmount
   */
  onUnmounted(() => {
    stopAutoSave();
  });

  return {
    // State
    hasDraft,
    lastSavedAt,
    lastSavedFormatted,
    isSaving,
    autoSaveEnabled,

    // Methods
    saveDraft,
    loadDraft,
    clearDraft,
    checkForDraft,
    scheduleSave,
    startAutoSave,
    stopAutoSave,
  };
}
