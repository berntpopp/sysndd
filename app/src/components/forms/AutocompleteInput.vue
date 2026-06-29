<template>
  <div ref="containerRef" class="position-relative autocomplete-container">
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
      role="combobox"
      aria-autocomplete="list"
      :aria-expanded="showDropdown"
      :aria-controls="listboxId"
      :aria-activedescendant="activeOptionId"
      @input="onInput"
      @focus="onFocus"
      @blur="onBlur"
      @keydown="onKeydown"
    />

    <Teleport to="body">
      <!-- Dropdown results -->
      <div
        v-if="showDropdown && results.length > 0"
        :id="listboxId"
        ref="dropdownRef"
        class="autocomplete-dropdown"
        role="listbox"
        :style="popupStyle"
        :aria-label="`${label} search results`"
      >
        <div
          v-for="(item, index) in results"
          :id="optionId(index)"
          :key="getItemKey(item)"
          :aria-selected="index === highlightedIndex"
          class="autocomplete-item"
          :class="{ 'autocomplete-item--active': index === highlightedIndex }"
          role="option"
          @mousedown.prevent="selectItem(item)"
          @mouseenter="highlightedIndex = index"
        >
          <slot name="item" :item="item" :index="index">
            <div class="autocomplete-item__main">
              <span class="autocomplete-item__label">{{ getItemLabel(item) }}</span>
              <span v-if="getItemSecondary(item)" class="autocomplete-item__secondary">
                {{ getItemSecondary(item) }}
              </span>
            </div>
            <small v-if="getItemDescription(item)" class="autocomplete-item__description">
              {{ getItemDescription(item) }}
            </small>
          </slot>
        </div>
      </div>

      <!-- Loading indicator -->
      <div v-if="loading" class="autocomplete-loading" :style="popupStyle" aria-live="polite">
        <BSpinner small />
        <span class="ms-2 text-muted small">Searching...</span>
      </div>

      <!-- No results message -->
      <div
        v-if="showDropdown && !loading && searchQuery.length >= minChars && results.length === 0"
        class="autocomplete-no-results"
        :style="popupStyle"
      >
        <small class="text-muted">{{ noResultsMessage }}</small>
      </div>
    </Teleport>
  </div>
</template>

<script lang="ts">
import {
  computed,
  defineComponent,
  nextTick,
  onBeforeUnmount,
  ref,
  watch,
  type CSSProperties,
  type PropType,
} from 'vue';
import { BFormInput, BSpinner } from 'bootstrap-vue-next';

let autocompleteInstanceCounter = 0;

export default defineComponent({
  name: 'AutocompleteInput',

  components: {
    BFormInput,
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
     * Message shown when search returns no results
     */
    noResultsMessage: {
      type: String,
      default: 'No results found',
    },

    /**
     * Input size
     */
    size: {
      type: String as PropType<'sm' | 'lg'>,
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
    const instanceId = ++autocompleteInstanceCounter;
    const searchQuery = ref(props.displayValue || '');
    const showDropdown = ref(false);
    const highlightedIndex = ref(-1);
    const containerRef = ref<HTMLElement | null>(null);
    const dropdownRef = ref<HTMLElement | null>(null);
    const popupPosition = ref({
      top: 0,
      left: 0,
      width: 0,
      maxHeight: 280,
      placement: 'bottom' as 'bottom' | 'top',
    });
    let debounceTimer: ReturnType<typeof setTimeout> | null = null;
    const listboxId = `${props.inputId || `autocomplete-${instanceId}`}-listbox`;

    const optionId = (index: number) => `${listboxId}-option-${index}`;

    const activeOptionId = computed(() => {
      if (highlightedIndex.value >= 0 && highlightedIndex.value < props.results.length) {
        return optionId(highlightedIndex.value);
      }
      return undefined;
    });

    const popupStyle = computed<CSSProperties>(() => ({
      top: `${popupPosition.value.top}px`,
      left: `${popupPosition.value.left}px`,
      width: `${popupPosition.value.width}px`,
      maxHeight: `${popupPosition.value.maxHeight}px`,
    }));

    const updatePopupPosition = () => {
      const anchor = containerRef.value;
      if (!anchor) return;

      const rect = anchor.getBoundingClientRect();
      const viewportPadding = 12;
      const belowSpace = window.innerHeight - rect.bottom - viewportPadding;
      const aboveSpace = rect.top - viewportPadding;
      const placeAbove = belowSpace < 180 && aboveSpace > belowSpace;
      const maxHeight = Math.max(160, Math.min(320, placeAbove ? aboveSpace : belowSpace));

      popupPosition.value = {
        top: placeAbove ? Math.max(viewportPadding, rect.top - maxHeight - 4) : rect.bottom + 4,
        left: Math.max(
          viewportPadding,
          Math.min(rect.left, window.innerWidth - rect.width - viewportPadding)
        ),
        width: rect.width,
        maxHeight,
        placement: placeAbove ? 'top' : 'bottom',
      };
    };

    const openDropdown = async () => {
      showDropdown.value = true;
      await nextTick();
      updatePopupPosition();
    };

    const scrollHighlightedIntoView = async () => {
      await nextTick();
      const activeOption = dropdownRef.value?.querySelector<HTMLElement>('[aria-selected="true"]');
      activeOption?.scrollIntoView({ block: 'nearest' });
    };

    window.addEventListener('resize', updatePopupPosition);
    window.addEventListener('scroll', updatePopupPosition, true);

    onBeforeUnmount(() => {
      window.removeEventListener('resize', updatePopupPosition);
      window.removeEventListener('scroll', updatePopupPosition, true);
      if (debounceTimer) clearTimeout(debounceTimer);
    });

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
          openDropdown();
          highlightedIndex.value = props.results.length > 0 ? 0 : -1;
        } else {
          showDropdown.value = false;
        }
      }, props.debounce);
    };

    // Focus handler
    const onFocus = () => {
      if (props.results.length > 0 && searchQuery.value.length >= props.minChars) {
        openDropdown();
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
          openDropdown();
          highlightedIndex.value = 0;
          scrollHighlightedIntoView();
          event.preventDefault();
        }
        return;
      }

      switch (event.key) {
        case 'ArrowDown':
          event.preventDefault();
          highlightedIndex.value = Math.min(highlightedIndex.value + 1, props.results.length - 1);
          scrollHighlightedIntoView();
          break;

        case 'ArrowUp':
          event.preventDefault();
          highlightedIndex.value = Math.max(highlightedIndex.value - 1, 0);
          scrollHighlightedIntoView();
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
          nextTick(updatePopupPosition);
        } else {
          highlightedIndex.value = -1;
        }
      }
    );

    return {
      searchQuery,
      showDropdown,
      highlightedIndex,
      containerRef,
      dropdownRef,
      listboxId,
      activeOptionId,
      popupStyle,
      optionId,
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
  z-index: 30;
}
</style>

<style>
.autocomplete-dropdown {
  position: fixed;
  z-index: 3000;
  overflow-y: auto;
  margin: 0;
  padding: 0.25rem;
  background: #fff;
  border: 1px solid #cbd5e1;
  border-radius: 8px;
  box-shadow:
    0 18px 40px rgba(15, 23, 42, 0.14),
    0 4px 10px rgba(15, 23, 42, 0.08);
}

.autocomplete-item {
  cursor: pointer;
  padding: 0.55rem 0.65rem;
  border-radius: 6px;
  color: #172033;
  transition:
    background-color 0.12s ease-in-out,
    color 0.12s ease-in-out;
}

.autocomplete-item:hover,
.autocomplete-item--active {
  background: #e8f3ff;
  color: #0b4f86;
}

.autocomplete-item__main {
  display: flex;
  min-width: 0;
  align-items: baseline;
  justify-content: space-between;
  gap: 0.75rem;
}

.autocomplete-item__label {
  min-width: 0;
  overflow: hidden;
  color: inherit;
  font-size: 0.875rem;
  font-weight: 700;
  line-height: 1.25;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.autocomplete-item__secondary {
  flex: 0 0 auto;
  max-width: 42%;
  overflow: hidden;
  color: #526070;
  font-size: 0.75rem;
  font-weight: 700;
  line-height: 1.25;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.autocomplete-item__description {
  display: block;
  min-width: 0;
  margin-top: 0.2rem;
  overflow: hidden;
  color: #64748b;
  font-size: 0.75rem;
  line-height: 1.3;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.autocomplete-loading,
.autocomplete-no-results {
  position: fixed;
  z-index: 3000;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 0.65rem;
  border: 1px solid #cbd5e1;
  border-radius: 8px;
  background: #fff;
  box-shadow:
    0 18px 40px rgba(15, 23, 42, 0.14),
    0 4px 10px rgba(15, 23, 42, 0.08);
}

@media (max-width: 575.98px) {
  .autocomplete-item {
    padding: 0.65rem 0.7rem;
  }

  .autocomplete-item__main {
    flex-direction: column;
    align-items: flex-start;
    gap: 0.15rem;
  }

  .autocomplete-item__secondary {
    max-width: 100%;
  }
}
</style>
