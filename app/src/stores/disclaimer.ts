// src/stores/disclaimer.ts
// Pinia store for disclaimer acknowledgment state
// Manually persisted to localStorage (no plugin dependency)

import { defineStore } from 'pinia';
import { ref, computed } from 'vue';
import type { Ref, ComputedRef } from 'vue';

const STORAGE_KEY = 'sysndd-disclaimer';

/** Load persisted state from localStorage */
function loadPersistedState(): { isAcknowledged: boolean; acknowledgmentTimestamp: string | null } {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (raw) {
      const parsed = JSON.parse(raw);
      return {
        isAcknowledged: parsed.isAcknowledged === true,
        acknowledgmentTimestamp: parsed.acknowledgmentTimestamp ?? null,
      };
    }
  } catch {
    // Corrupted data — reset
    localStorage.removeItem(STORAGE_KEY);
  }
  return { isAcknowledged: false, acknowledgmentTimestamp: null };
}

/** Save state to localStorage */
function persistState(acknowledged: boolean, timestamp: string | null): void {
  try {
    localStorage.setItem(
      STORAGE_KEY,
      JSON.stringify({ isAcknowledged: acknowledged, acknowledgmentTimestamp: timestamp }),
    );
  } catch {
    // Storage full or unavailable — fail silently
  }
}

/**
 * Disclaimer Store — manages usage policy acknowledgment state.
 * Persisted to localStorage under key 'sysndd-disclaimer'.
 */
export const useDisclaimerStore = defineStore('disclaimer', () => {
  // Hydrate from localStorage
  const persisted = loadPersistedState();

  // State
  const isAcknowledged: Ref<boolean> = ref(persisted.isAcknowledged);
  const acknowledgmentTimestamp: Ref<string | null> = ref(persisted.acknowledgmentTimestamp);

  // Computed
  const formattedAcknowledgmentDate: ComputedRef<string> = computed(() => {
    if (!acknowledgmentTimestamp.value) return '';
    const date = new Date(acknowledgmentTimestamp.value);
    return date.toLocaleDateString(undefined, {
      year: 'numeric',
      month: 'long',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
    });
  });

  // Actions
  function saveAcknowledgment(): void {
    isAcknowledged.value = true;
    acknowledgmentTimestamp.value = new Date().toISOString();
    persistState(isAcknowledged.value, acknowledgmentTimestamp.value);
  }

  function reset(): void {
    isAcknowledged.value = false;
    acknowledgmentTimestamp.value = null;
    localStorage.removeItem(STORAGE_KEY);
  }

  return {
    isAcknowledged,
    acknowledgmentTimestamp,
    formattedAcknowledgmentDate,
    saveAcknowledgment,
    reset,
  };
});

export type DisclaimerStoreType = ReturnType<typeof useDisclaimerStore>;
