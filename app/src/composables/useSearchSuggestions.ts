// composables/useSearchSuggestions.ts
// Composable for search suggestion state and API integration

import { ref, watch } from 'vue';
import type { Ref } from 'vue';
import apiService from '@/assets/js/services/apiService';

export interface SearchSuggestion {
  label: string;
  link: string;
}

export interface UseSearchSuggestionsReturn {
  query: Ref<string>;
  suggestions: Ref<SearchSuggestion[]>;
  isLoading: Ref<boolean>;
  fetchSuggestions: () => Promise<void>;
  clearSuggestions: () => void;
  getDirectLink: (input: string) => string | null;
}

/**
 * Composable that manages search suggestion state with debounced API calls.
 * Provides suggestions from the SysNDD search API for use in combobox components.
 *
 * @param debounceMs - Debounce delay in milliseconds (default: 300)
 */
export function useSearchSuggestions(debounceMs = 300): UseSearchSuggestionsReturn {
  const query: Ref<string> = ref('');
  const suggestions: Ref<SearchSuggestion[]> = ref([]);
  const isLoading: Ref<boolean> = ref(false);

  // Internal cache of the raw search object for direct link lookup
  let searchObject: Record<string, Array<{ link: string }>> = {};
  let debounceTimer: ReturnType<typeof setTimeout> | null = null;

  async function fetchSuggestions(): Promise<void> {
    if (query.value.length < 1) {
      clearSuggestions();
      return;
    }

    isLoading.value = true;
    try {
      const response = await apiService.fetchSearchInfo(query.value);
      [searchObject] = response as unknown as [Record<string, Array<{ link: string }>>];
      suggestions.value = Object.keys(searchObject).map((key) => ({
        label: key,
        link: searchObject[key][0].link,
      }));
    } catch {
      suggestions.value = [];
      searchObject = {};
    } finally {
      isLoading.value = false;
    }
  }

  function clearSuggestions(): void {
    suggestions.value = [];
    searchObject = {};
  }

  /**
   * Returns the direct navigation link if the input matches an exact suggestion,
   * otherwise returns null (caller should navigate to the search results page).
   */
  function getDirectLink(input: string): string | null {
    if (searchObject[input]?.[0]?.link) {
      return searchObject[input][0].link;
    }
    return null;
  }

  // Debounced watcher on query
  watch(query, () => {
    if (debounceTimer) clearTimeout(debounceTimer);

    if (query.value.length < 1) {
      clearSuggestions();
      return;
    }

    debounceTimer = setTimeout(() => {
      fetchSuggestions();
    }, debounceMs);
  });

  return {
    query,
    suggestions,
    isLoading,
    fetchSuggestions,
    clearSuggestions,
    getDirectLink,
  };
}

export default useSearchSuggestions;
