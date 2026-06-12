<!-- components/tables/PhenotypeFilterToolbar.vue -->
<!--
  PhenotypeFilterToolbar.vue

  Presentational multi-select control for the phenotype search table
  (extracted from TablesPhenotypes.vue, WP2 / #395). It renders the
  treeselect-like tag input + searchable dropdown for HPO phenotype IDs and
  emits semantic events; the parent (`TablesPhenotypes.vue`) still owns the
  filter state and the API calls, so the table's user-visible behavior is
  unchanged.
-->
<template>
  <div class="phenotype-select-container">
    <div class="phenotype-select-control" @click="openDropdown">
      <div class="phenotype-tags">
        <span v-for="phenotypeId in selectedIds" :key="phenotypeId" class="phenotype-tag">
          {{ getPhenotypeName(phenotypeId) }}
          <i class="bi bi-x tag-remove" @click.stop="$emit('remove', phenotypeId)" />
        </span>
        <span v-if="selectedIds.length === 0" class="phenotype-placeholder">
          Select phenotypes...
        </span>
      </div>

      <div class="phenotype-controls">
        <i
          v-if="selectedIds.length > 0"
          v-b-tooltip.hover
          class="bi bi-x-lg control-icon clear-icon"
          title="Clear all"
          @click.stop="$emit('clear-all')"
        />
        <BDropdown
          ref="phenotypeDropdownRef"
          no-caret
          variant="link"
          size="sm"
          class="phenotype-dropdown-trigger"
          menu-class="phenotype-dropdown-menu"
          @shown="focusSearchInput"
        >
          <template #button-content>
            <i class="bi bi-chevron-down control-icon" />
          </template>
          <BDropdownForm @submit.prevent>
            <BFormInput
              ref="phenotypeSearchInput"
              v-model="phenotypeSearch"
              placeholder="Search phenotypes..."
              size="sm"
              class="mb-2"
              autocomplete="off"
            />
          </BDropdownForm>
          <BDropdownDivider />
          <div class="phenotype-options-list">
            <BDropdownItemButton
              v-for="option in filteredPhenotypeOptions"
              :key="option.phenotype_id"
              :active="isPhenotypeSelected(option.phenotype_id)"
              @click="$emit('toggle', option.phenotype_id)"
            >
              <i
                v-if="isPhenotypeSelected(option.phenotype_id)"
                class="bi bi-check-square me-2 text-primary"
              />
              <i v-else class="bi bi-square me-2 text-muted" />
              {{ option.HPO_term }}
            </BDropdownItemButton>
            <BDropdownText v-if="filteredPhenotypeOptions.length === 0">
              No matching phenotypes
            </BDropdownText>
          </div>
        </BDropdown>
      </div>
    </div>
    <BSpinner v-if="phenotypeOptions.length === 0" small class="ms-2" label="Loading..." />
  </div>
</template>

<script>
export default {
  name: 'PhenotypeFilterToolbar',
  props: {
    /** Full HPO phenotype option list ({ phenotype_id, HPO_term }). */
    phenotypeOptions: { type: Array, default: () => [] },
    /** Currently selected HPO IDs. */
    selectedIds: { type: Array, default: () => [] },
  },
  emits: ['toggle', 'remove', 'clear-all'],
  data() {
    return {
      // Search term for the dropdown filter (local presentation state).
      phenotypeSearch: '',
    };
  },
  computed: {
    /**
     * Filter phenotype options based on the search term.
     * Shows first 50 results for performance.
     */
    filteredPhenotypeOptions() {
      if (!Array.isArray(this.phenotypeOptions) || this.phenotypeOptions.length === 0) {
        return [];
      }
      const search = this.phenotypeSearch.toLowerCase().trim();
      if (!search) {
        // Return first 50 when no search term
        return this.phenotypeOptions.slice(0, 50);
      }
      return this.phenotypeOptions
        .filter(
          (opt) =>
            opt.HPO_term.toLowerCase().includes(search) ||
            opt.phenotype_id.toLowerCase().includes(search)
        )
        .slice(0, 50);
    },
  },
  methods: {
    /**
     * Check if a phenotype is currently selected.
     * @param {string} phenotypeId - HPO ID to check
     * @returns {boolean} True if selected
     */
    isPhenotypeSelected(phenotypeId) {
      return this.selectedIds.includes(phenotypeId);
    },
    /**
     * Get phenotype display name from ID.
     * @param {string} phenotypeId - HPO ID
     * @returns {string} HPO term name or the ID if not found
     */
    getPhenotypeName(phenotypeId) {
      if (!Array.isArray(this.phenotypeOptions) || this.phenotypeOptions.length === 0) {
        return phenotypeId;
      }
      const phenotype = this.phenotypeOptions.find((opt) => opt.phenotype_id === phenotypeId);
      return phenotype ? phenotype.HPO_term : phenotypeId;
    },
    /**
     * Open the phenotype dropdown programmatically.
     */
    openDropdown() {
      if (this.$refs.phenotypeDropdownRef) {
        this.$refs.phenotypeDropdownRef.show();
      }
    },
    /**
     * Focus the search input when the dropdown opens.
     */
    focusSearchInput() {
      this.$nextTick(() => {
        if (this.$refs.phenotypeSearchInput) {
          this.$refs.phenotypeSearchInput.focus();
        }
      });
    },
  },
};
</script>

<style scoped>
/* Styles for PhenotypeFilterToolbar.vue (extracted from TablesPhenotypes.vue). */

/* Phenotype Select Container - Treeselect-like styling */
.phenotype-select-container {
  display: flex;
  align-items: center;
}

.phenotype-select-control {
  display: flex;
  align-items: center;
  justify-content: space-between;
  min-height: 38px;
  padding: 4px 8px;
  border: 1px solid #ced4da;
  border-radius: 4px;
  background: #fff;
  cursor: pointer;
  flex: 1;
  transition:
    border-color 0.15s ease-in-out,
    box-shadow 0.15s ease-in-out;
}

.phenotype-select-control:hover {
  border-color: #80bdff;
}

.phenotype-select-control:focus-within {
  border-color: #80bdff;
  box-shadow: 0 0 0 0.2rem rgba(0, 123, 255, 0.25);
}

.phenotype-tags {
  display: flex;
  flex-wrap: wrap;
  gap: 4px;
  flex: 1;
  align-items: center;
}

.phenotype-tag {
  display: inline-flex;
  align-items: center;
  padding: 2px 8px;
  background: #e9f5ff;
  border: 1px solid #b8daff;
  border-radius: 3px;
  font-size: 0.85rem;
  color: #004085;
  max-width: 200px;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.phenotype-tag .tag-remove {
  margin-left: 6px;
  cursor: pointer;
  opacity: 0.6;
  font-size: 0.75rem;
}

.phenotype-tag .tag-remove:hover {
  opacity: 1;
  color: #dc3545;
}

.phenotype-placeholder {
  color: #6c757d;
  font-size: 0.9rem;
}

.phenotype-controls {
  display: flex;
  align-items: center;
  gap: 4px;
  margin-left: 8px;
}

.control-icon {
  color: #6c757d;
  cursor: pointer;
  font-size: 0.85rem;
  padding: 2px;
}

.control-icon:hover {
  color: #495057;
}

.clear-icon:hover {
  color: #dc3545;
}

.phenotype-dropdown-trigger {
  padding: 0;
  margin: 0;
}

.phenotype-dropdown-trigger :deep(.btn) {
  padding: 0 4px;
  border: none;
  background: transparent;
  box-shadow: none;
}

.phenotype-dropdown-trigger :deep(.btn:focus) {
  box-shadow: none;
}

:deep(.phenotype-dropdown-menu) {
  min-width: 350px;
  max-width: 450px;
  margin-top: 4px;
}

.phenotype-options-list {
  max-height: 250px;
  overflow-y: auto;
}

.phenotype-options-list :deep(.dropdown-item) {
  font-size: 0.875rem;
  white-space: normal;
  word-wrap: break-word;
  padding: 8px 16px;
}

.phenotype-options-list :deep(.dropdown-item.active) {
  background-color: #e9f5ff;
  color: #004085;
}
</style>
