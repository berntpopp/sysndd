<!-- components/small/SearchCombobox.vue -->
<!-- WAI-ARIA 1.2 combobox with listbox popup for search suggestions -->
<template>
  <div class="search-combobox" :class="{ 'search-combobox--navbar': inNavbar }">
    <div class="search-combobox__input-group">
      <input
        :id="inputId"
        ref="inputRef"
        v-model="query"
        type="search"
        class="form-control"
        :class="inNavbar ? 'form-control-sm navbar-search' : 'border-dark'"
        :placeholder="placeholderString"
        autocomplete="off"
        role="combobox"
        aria-autocomplete="list"
        :aria-expanded="isOpen"
        :aria-controls="listboxId"
        :aria-activedescendant="activeDescendantId"
        @input="onInput"
        @keydown="onKeydown"
        @focus="onFocus"
        @blur="onBlur"
      />
      <button
        class="btn"
        :class="inNavbar ? 'btn-outline-primary btn-sm' : 'btn-outline-dark'"
        :disabled="query.length < 2"
        aria-label="Search"
        @mousedown.prevent="onSubmit"
      >
        <i class="bi bi-search" aria-hidden="true" />
      </button>
    </div>

    <!-- Suggestion listbox -->
    <ul
      v-show="isOpen && suggestions.length > 0"
      :id="listboxId"
      ref="listboxRef"
      role="listbox"
      class="search-combobox__listbox"
      :aria-label="'Search suggestions for ' + query"
    >
      <li
        v-for="(item, index) in suggestions"
        :id="optionId(index)"
        :key="item.label"
        role="option"
        class="search-combobox__option"
        :class="{ 'search-combobox__option--active': index === activeIndex }"
        :aria-selected="index === activeIndex"
        @mousedown.prevent="selectSuggestion(item)"
        @mouseenter="activeIndex = index"
      >
        <i class="bi bi-search search-combobox__option-icon" aria-hidden="true" />
        <span class="search-combobox__option-label">{{ item.label }}</span>
      </li>
    </ul>

    <!-- Loading indicator for screen readers -->
    <div v-if="isLoading" class="visually-hidden" role="status" aria-live="polite">
      Loading suggestions...
    </div>
  </div>
</template>

<script>
import { useSearchSuggestions } from '@/composables/useSearchSuggestions';
import { useRouter } from 'vue-router';
import { ref, computed, nextTick } from 'vue';

let instanceCounter = 0;

export default {
  name: 'SearchCombobox',
  props: {
    placeholderString: {
      type: String,
      default: '...',
    },
    inNavbar: {
      type: Boolean,
      default: false,
    },
  },
  setup(_props) {
    const router = useRouter();
    const { query, suggestions, isLoading, clearSuggestions, getDirectLink } =
      useSearchSuggestions(300);

    const instanceId = ++instanceCounter;
    const inputId = `search-combobox-input-${instanceId}`;
    const listboxId = `search-combobox-listbox-${instanceId}`;

    const inputRef = ref(null);
    const listboxRef = ref(null);
    const activeIndex = ref(-1);
    const isOpen = ref(false);
    let isNavigating = false;

    const activeDescendantId = computed(() => {
      if (activeIndex.value >= 0 && activeIndex.value < suggestions.value.length) {
        return optionId(activeIndex.value);
      }
      return undefined;
    });

    function optionId(index) {
      return `${listboxId}-option-${index}`;
    }

    function openListbox() {
      if (suggestions.value.length > 0) {
        isOpen.value = true;
      }
    }

    function closeListbox() {
      isOpen.value = false;
      activeIndex.value = -1;
    }

    function onInput() {
      activeIndex.value = -1;
      if (query.value.length > 0) {
        // Open will happen reactively when suggestions arrive
        isOpen.value = suggestions.value.length > 0;
      } else {
        closeListbox();
      }
    }

    function onFocus() {
      if (query.value.length > 0 && suggestions.value.length > 0) {
        openListbox();
      }
    }

    function onBlur() {
      // Small delay to allow mousedown on listbox items to fire first
      setTimeout(() => {
        closeListbox();
      }, 150);
    }

    function scrollActiveIntoView() {
      nextTick(() => {
        if (!listboxRef.value) return;
        const activeEl = listboxRef.value.querySelector('[aria-selected="true"]');
        if (activeEl) {
          activeEl.scrollIntoView({ block: 'nearest' });
        }
      });
    }

    function navigateTo(link) {
      if (isNavigating) return;
      isNavigating = true;

      router
        .push(link)
        .catch((err) => {
          if (err.name !== 'NavigationDuplicated') throw err;
        })
        .finally(() => {
          isNavigating = false;
        });

      query.value = '';
      clearSuggestions();
      closeListbox();
    }

    function submitSearch() {
      if (query.value.length < 1) return;

      const directLink = getDirectLink(query.value);
      if (directLink) {
        navigateTo(directLink);
      } else {
        navigateTo(`/Search/${query.value}`);
      }
    }

    function selectSuggestion(item) {
      navigateTo(item.link);
    }

    function onSubmit() {
      submitSearch();
    }

    function onKeydown(event) {
      const len = suggestions.value.length;

      switch (event.key) {
        case 'ArrowDown':
          event.preventDefault();
          if (!isOpen.value && len > 0) {
            openListbox();
          }
          activeIndex.value = len > 0 ? (activeIndex.value + 1) % len : -1;
          scrollActiveIntoView();
          break;

        case 'ArrowUp':
          event.preventDefault();
          if (!isOpen.value && len > 0) {
            openListbox();
          }
          activeIndex.value = len > 0 ? (activeIndex.value - 1 + len) % len : -1;
          scrollActiveIntoView();
          break;

        case 'Enter':
          event.preventDefault();
          if (isOpen.value && activeIndex.value >= 0 && activeIndex.value < len) {
            selectSuggestion(suggestions.value[activeIndex.value]);
          } else {
            submitSearch();
          }
          break;

        case 'Escape':
          if (isOpen.value) {
            event.preventDefault();
            closeListbox();
          }
          break;

        default:
          break;
      }
    }

    return {
      query,
      suggestions,
      isLoading,
      inputRef,
      listboxRef,
      activeIndex,
      isOpen,
      inputId,
      listboxId,
      activeDescendantId,
      optionId,
      onInput,
      onFocus,
      onBlur,
      onKeydown,
      onSubmit,
      selectSuggestion,
    };
  },
  watch: {
    suggestions(newVal) {
      if (newVal.length > 0 && this.query.length > 0) {
        this.isOpen = true;
      } else {
        this.isOpen = false;
      }
      this.activeIndex = -1;
    },
  },
};
</script>

<style scoped>
.search-combobox {
  position: relative;
}

.search-combobox__input-group {
  display: flex;
  flex-wrap: nowrap;
}

.search-combobox__input-group input {
  border-top-right-radius: 0;
  border-bottom-right-radius: 0;
}

.search-combobox__input-group button {
  border-top-left-radius: 0;
  border-bottom-left-radius: 0;
}

.search-combobox__listbox {
  position: absolute;
  top: 100%;
  left: 0;
  right: 0;
  z-index: 1050;
  max-height: 280px;
  overflow-y: auto;
  margin: 0.25rem 0 0;
  padding: 0.25rem 0;
  list-style: none;
  background: #fff;
  border: 1px solid var(--neutral-300, #e0e0e0);
  border-radius: 0.375rem;
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.12);
}

.search-combobox__option {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  padding: 0.5rem 0.75rem;
  cursor: pointer;
  color: var(--neutral-800, #424242);
  font-size: 0.875rem;
  line-height: 1.4;
}

.search-combobox__option--active {
  background: var(--medical-blue-50, #e3f2fd);
  color: var(--medical-blue-900, #0d47a1);
}

.search-combobox__option:hover {
  background: var(--medical-blue-50, #e3f2fd);
}

.search-combobox__option-icon {
  flex-shrink: 0;
  font-size: 0.75rem;
  opacity: 0.5;
}

.search-combobox__option-label {
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

/* Navbar variant */
.search-combobox--navbar .navbar-search {
  width: 300px;
  min-width: 100px;
}

@media (prefers-reduced-motion: reduce) {
  .search-combobox__listbox {
    transition: none;
  }
}
</style>
