<template>
  <div class="position-relative autocomplete-container">
    <BFormInput
      :id="inputId"
      v-model="searchQuery"
      :size="size"
      :placeholder="placeholder"
      :state="state"
      :disabled="disabled"
      :required="required"
      autocomplete="off"
      :aria-describedby="helpId"
      :aria-required="required"
      :aria-invalid="state === false"
      @input="onInput"
      @focus="onFocus"
      @blur="onBlur"
      @keydown="onKeydown"
    />

    <!-- Dropdown results -->
    <div
      v-if="showDropdown && results.length > 0"
      class="autocomplete-dropdown"
      role="listbox"
      :aria-label="`${label} search results`"
    >
      <BListGroup flush>
        <BListGroupItem
          v-for="(item, index) in results"
          :key="getItemKey(item)"
          button
          :active="index === highlightedIndex"
          :aria-selected="index === highlightedIndex"
          class="autocomplete-item py-2 px-3"
          role="option"
          @mousedown.prevent="selectItem(item)"
          @mouseenter="highlightedIndex = index"
        >
          <slot name="item" :item="item" :index="index">
            <div class="d-flex justify-content-between align-items-start">
              <div>
                <span class="fw-bold text-primary">{{ getItemLabel(item) }}</span>
                <small v-if="getItemSecondary(item)" class="text-muted ms-2">
                  {{ getItemSecondary(item) }}
                </small>
              </div>
            </div>
            <small v-if="getItemDescription(item)" class="text-muted d-block text-truncate">
              {{ getItemDescription(item) }}
            </small>
          </slot>
        </BListGroupItem>
      </BListGroup>
    </div>

    <!-- Loading indicator -->
    <div
      v-if="loading"
      class="autocomplete-loading"
      aria-live="polite"
    >
      <BSpinner small />
      <span class="ms-2 text-muted small">Searching...</span>
    </div>

    <!-- No results message -->
    <div
      v-if="showDropdown && !loading && searchQuery.length >= minChars && results.length === 0"
      class="autocomplete-no-results"
    >
      <small class="text-muted">No results found</small>
    </div>
  </div>
</template>

<script lang="ts">
import { defineComponent, ref, watch, type PropType } from 'vue';
import { BFormInput, BListGroup, BListGroupItem, BSpinner } from 'bootstrap-vue-next';

export default defineComponent({
  name: 'AutocompleteInput',

  components: {
    BFormInput,
    BListGroup,
    BListGroupItem,
    BSpinner,
  },

  props: {
    /**
     * v-model value (the selected item's ID)
     */
    modelValue: {
      type: String as PropType<string | null>,
      default: null,
    },

    /**
     * Display value (human-readable label for selected item)
     */
    displayValue: {
      type: String,
      default: '',
    },

    /**
     * Search results array
     */
    results: {
      type: Array as PropType<Record<string, unknown>[]>,
      default: () => [],
    },

    /**
     * Loading state
     */
    loading: {
      type: Boolean,
      default: false,
    },

    /**
     * Input label (for aria)
     */
    label: {
      type: String,
      required: true,
    },

    /**
     * Input ID
     */
    inputId: {
      type: String,
      required: true,
    },

    /**
     * Help text ID (for aria-describedby)
     */
    helpId: {
      type: String,
      default: undefined,
    },

    /**
     * Placeholder text
     */
    placeholder: {
      type: String,
      default: 'Search...',
    },

    /**
     * Input size
     */
    size: {
      type: String as PropType<'sm' | 'md' | 'lg'>,
      default: 'sm',
    },

    /**
     * Validation state
     */
    state: {
      type: Boolean as PropType<boolean | null>,
      default: null,
    },

    /**
     * Disabled state
     */
    disabled: {
      type: Boolean,
      default: false,
    },

    /**
     * Required field
     */
    required: {
      type: Boolean,
      default: false,
    },

    /**
     * Minimum characters before search triggers
     */
    minChars: {
      type: Number,
      default: 2,
    },

    /**
     * Debounce delay in ms
     */
    debounce: {
      type: Number,
      default: 300,
    },

    /**
     * Key field for result items
     */
    itemKey: {
      type: String,
      default: 'id',
    },

    /**
     * Label field for result items
     */
    itemLabel: {
      type: String,
      default: 'label',
    },

    /**
     * Secondary label field (optional)
     */
    itemSecondary: {
      type: String,
      default: '',
    },

    /**
     * Description field (optional)
     */
    itemDescription: {
      type: String,
      default: '',
    },
  },

  emits: ['update:modelValue', 'update:displayValue', 'search', 'select', 'blur'],

  setup(props, { emit }) {
    const searchQuery = ref(props.displayValue || '');
    const showDropdown = ref(false);
    const highlightedIndex = ref(-1);
    let debounceTimer: ReturnType<typeof setTimeout> | null = null;

    // Watch for external displayValue changes
    watch(
      () => props.displayValue,
      (newValue) => {
        if (newValue !== searchQuery.value) {
          searchQuery.value = newValue;
        }
      }
    );

    // Item accessor functions
    const getItemKey = (item: Record<string, unknown>): string => {
      return String(item[props.itemKey] || '');
    };

    const getItemLabel = (item: Record<string, unknown>): string => {
      return String(item[props.itemLabel] || '');
    };

    const getItemSecondary = (item: Record<string, unknown>): string => {
      if (!props.itemSecondary) return '';
      return String(item[props.itemSecondary] || '');
    };

    const getItemDescription = (item: Record<string, unknown>): string => {
      if (!props.itemDescription) return '';
      return String(item[props.itemDescription] || '');
    };

    // Input handler with debounce
    const onInput = () => {
      if (debounceTimer) clearTimeout(debounceTimer);

      // Clear selection if user modifies the input
      if (props.modelValue && searchQuery.value !== props.displayValue) {
        emit('update:modelValue', null);
        emit('update:displayValue', '');
      }

      debounceTimer = setTimeout(() => {
        if (searchQuery.value.length >= props.minChars) {
          emit('search', searchQuery.value);
          showDropdown.value = true;
          highlightedIndex.value = props.results.length > 0 ? 0 : -1;
        } else {
          showDropdown.value = false;
        }
      }, props.debounce);
    };

    // Focus handler
    const onFocus = () => {
      if (props.results.length > 0 && searchQuery.value.length >= props.minChars) {
        showDropdown.value = true;
      }
    };

    // Blur handler with delayed close (allows click on dropdown)
    const onBlur = () => {
      setTimeout(() => {
        showDropdown.value = false;
        emit('blur');
      }, 150);
    };

    // Keyboard navigation
    const onKeydown = (event: KeyboardEvent) => {
      if (!showDropdown.value || props.results.length === 0) {
        // Open dropdown on arrow down if we have results
        if (event.key === 'ArrowDown' && props.results.length > 0) {
          showDropdown.value = true;
          highlightedIndex.value = 0;
          event.preventDefault();
        }
        return;
      }

      switch (event.key) {
        case 'ArrowDown':
          event.preventDefault();
          highlightedIndex.value = Math.min(
            highlightedIndex.value + 1,
            props.results.length - 1
          );
          break;

        case 'ArrowUp':
          event.preventDefault();
          highlightedIndex.value = Math.max(highlightedIndex.value - 1, 0);
          break;

        case 'Enter':
          event.preventDefault();
          if (highlightedIndex.value >= 0 && highlightedIndex.value < props.results.length) {
            selectItem(props.results[highlightedIndex.value]);
          }
          break;

        case 'Escape':
          showDropdown.value = false;
          break;

        case 'Tab':
          showDropdown.value = false;
          break;
      }
    };

    // Select item handler
    const selectItem = (item: Record<string, unknown>) => {
      const id = getItemKey(item);
      const label = getItemLabel(item);

      searchQuery.value = label;
      showDropdown.value = false;
      highlightedIndex.value = -1;

      emit('update:modelValue', id);
      emit('update:displayValue', label);
      emit('select', item);
    };

    // Watch results to update highlighted index
    watch(
      () => props.results,
      (newResults) => {
        if (newResults.length > 0 && showDropdown.value) {
          highlightedIndex.value = 0;
        } else {
          highlightedIndex.value = -1;
        }
      }
    );

    return {
      searchQuery,
      showDropdown,
      highlightedIndex,
      getItemKey,
      getItemLabel,
      getItemSecondary,
      getItemDescription,
      onInput,
      onFocus,
      onBlur,
      onKeydown,
      selectItem,
    };
  },
});
</script>

<style scoped>
.autocomplete-container {
  position: relative;
}

.autocomplete-dropdown {
  position: absolute;
  top: 100%;
  left: 0;
  right: 0;
  z-index: 1050;
  max-height: 250px;
  overflow-y: auto;
  background: white;
  border: 1px solid #dee2e6;
  border-top: none;
  border-radius: 0 0 0.375rem 0.375rem;
  box-shadow: 0 4px 8px rgba(0, 0, 0, 0.15);
}

.autocomplete-item {
  cursor: pointer;
  transition: background-color 0.15s ease-in-out;
}

.autocomplete-item:hover,
.autocomplete-item.active {
  background-color: #e9ecef;
}

.autocomplete-item .text-truncate {
  max-width: 100%;
}

.autocomplete-loading,
.autocomplete-no-results {
  position: absolute;
  top: 100%;
  left: 0;
  right: 0;
  padding: 0.5rem;
  background: white;
  border: 1px solid #dee2e6;
  border-top: none;
  border-radius: 0 0 0.375rem 0.375rem;
  display: flex;
  align-items: center;
  justify-content: center;
}
</style>
