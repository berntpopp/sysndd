<template>
  <div ref="containerRef" class="term-search">
    <TableSearchInput
      v-model="searchPattern"
      :placeholder="placeholder"
      :debounce-time="300"
      :loading="isSearching"
      @focus="showSuggestions = true"
    />

    <!-- Autocomplete suggestions dropdown -->
    <div
      v-if="showSuggestions && filteredSuggestions.length > 0 && searchPattern.length >= 2"
      class="suggestions-dropdown"
    >
      <div class="suggestions-header">
        <small class="text-muted">
          {{ filteredSuggestions.length }} suggestion{{
            filteredSuggestions.length !== 1 ? 's' : ''
          }}
        </small>
      </div>
      <ul class="suggestions-list">
        <li
          v-for="suggestion in filteredSuggestions.slice(0, 8)"
          :key="suggestion"
          class="suggestion-item"
          @mousedown.prevent="selectSuggestion(suggestion)"
        >
          <!-- eslint-disable-next-line vue/no-v-html -- content is generated internally by highlightMatch(), no user input -->
          <span class="suggestion-text" v-html="highlightMatch(suggestion)"></span>
        </li>
        <li v-if="filteredSuggestions.length > 8" class="suggestion-more">
          <small class="text-muted">+{{ filteredSuggestions.length - 8 }} more...</small>
        </li>
      </ul>
    </div>

    <!-- Status messages -->
    <small v-if="noResults && searchPattern" class="text-muted d-block mt-1">
      No genes match '{{ searchPattern }}'
    </small>
    <small v-else-if="searchPattern" class="text-muted d-block mt-1">
      Wildcards: * (any chars), ? (one char)
    </small>
  </div>
</template>

<script setup lang="ts">
import { computed, ref, onMounted, onUnmounted } from 'vue';
import TableSearchInput from '@/components/small/TableSearchInput.vue';

interface Props {
  modelValue: string;
  matchCount?: number;
  isSearching?: boolean;
  placeholder?: string;
  suggestions?: string[];
}

const props = withDefaults(defineProps<Props>(), {
  matchCount: 0,
  isSearching: false,
  placeholder: 'Search genes (e.g., PKD*, BRCA?)',
  suggestions: () => [],
});

const emit = defineEmits<{
  'update:modelValue': [value: string];
}>();

const containerRef = ref<HTMLElement | null>(null);
const showSuggestions = ref(false);

const searchPattern = computed({
  get: () => props.modelValue,
  set: (value) => emit('update:modelValue', value ?? ''),
});

const noResults = computed(
  () => props.matchCount === 0 && props.modelValue.length > 0 && !props.isSearching
);

/**
 * Convert wildcard pattern to regex for filtering suggestions
 */
function wildcardToRegex(pattern: string): RegExp | null {
  if (!pattern || pattern.trim() === '') return null;
  try {
    const escaped = pattern
      .replace(/[.+^${}()|[\]\\]/g, '\\$&')
      .replace(/\*/g, '.*')
      .replace(/\?/g, '.');
    return new RegExp(`^${escaped}`, 'i'); // Match from start
  } catch {
    return null;
  }
}

/**
 * Filter suggestions based on current search pattern
 */
const filteredSuggestions = computed(() => {
  if (!props.suggestions.length || !props.modelValue) return [];

  const regex = wildcardToRegex(props.modelValue);
  if (!regex) return [];

  return props.suggestions.filter((s) => regex.test(s)).sort((a, b) => a.localeCompare(b));
});

/**
 * Highlight the matching portion of a suggestion
 */
function highlightMatch(suggestion: string): string {
  const pattern = props.modelValue.replace(/[*?]/g, '');
  if (!pattern) return suggestion;

  const idx = suggestion.toLowerCase().indexOf(pattern.toLowerCase());
  if (idx === -1) return suggestion;

  const before = suggestion.slice(0, idx);
  const match = suggestion.slice(idx, idx + pattern.length);
  const after = suggestion.slice(idx + pattern.length);

  return `${before}<strong>${match}</strong>${after}`;
}

/**
 * Select a suggestion and close dropdown
 */
function selectSuggestion(suggestion: string) {
  searchPattern.value = suggestion;
  showSuggestions.value = false;
}

/**
 * Handle clicks outside to close dropdown
 */
function handleClickOutside(event: MouseEvent) {
  if (containerRef.value && !containerRef.value.contains(event.target as Node)) {
    showSuggestions.value = false;
  }
}

onMounted(() => {
  document.addEventListener('click', handleClickOutside);
});

onUnmounted(() => {
  document.removeEventListener('click', handleClickOutside);
});
</script>

<style scoped>
.term-search {
  min-width: 200px;
  position: relative;
}

.suggestions-dropdown {
  position: absolute;
  top: 100%;
  left: 0;
  right: 0;
  z-index: 1050;
  background: white;
  border: 1px solid var(--neutral-300, #e0e0e0);
  border-radius: 0.25rem;
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
  max-height: 280px;
  overflow-y: auto;
  margin-top: 2px;
}

.suggestions-header {
  padding: 0.375rem 0.75rem;
  border-bottom: 1px solid var(--neutral-200, #eeeeee);
  background: var(--neutral-50, #fafafa);
}

.suggestions-list {
  list-style: none;
  margin: 0;
  padding: 0;
}

.suggestion-item {
  padding: 0.5rem 0.75rem;
  cursor: pointer;
  transition: background-color 0.15s ease;
  font-family: monospace;
  font-size: 0.875rem;
}

.suggestion-item:hover {
  background-color: var(--medical-blue-50, #e3f2fd);
}

.suggestion-item:active {
  background-color: var(--medical-blue-100, #bbdefb);
}

.suggestion-text strong {
  color: var(--medical-blue-700, #1565c2);
}

.suggestion-more {
  padding: 0.375rem 0.75rem;
  text-align: center;
  background: var(--neutral-50, #fafafa);
  border-top: 1px solid var(--neutral-200, #eeeeee);
}
</style>
