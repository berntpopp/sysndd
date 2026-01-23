<!-- TableSearchInput.vue -->
<template>
  <div class="search-input-container">
    <BFormInput
      :model-value="value"
      :placeholder="placeholder"
      size="sm"
      type="search"
      class="mb-1 border-dark search-input"
      :class="{ 'search-input-active': value && value.length > 0 }"
      :debounce="debounceTime"
      @update:model-value="updateValue($event)"
    />
    <button
      v-if="clearable && !loading && value && value.length > 0"
      type="button"
      class="search-clear-btn"
      aria-label="Clear search"
      @click="handleClear"
    >
      <i class="bi bi-x-circle-fill"></i>
    </button>
    <div
      v-if="loading"
      class="search-loading"
    >
      <span
        class="spinner-border spinner-border-sm"
        role="status"
        aria-label="Loading"
      ></span>
    </div>
  </div>
</template>

<script>
export default {
  name: 'SearchInput',
  props: {
    value: {
      type: String,
      default: '',
    },
    placeholder: {
      type: String,
      default: 'Search...',
    },
    debounceTime: {
      type: Number,
      default: 500,
    },
    clearable: {
      type: Boolean,
      default: true,
    },
    loading: {
      type: Boolean,
      default: false,
    },
  },
  methods: {
    updateValue(value) {
      this.$emit('input', value);
      this.$emit('update:modelValue', value);
    },
    handleClear() {
      this.$emit('input', '');
      this.$emit('update:modelValue', '');
      this.$emit('clear');
      // Focus back to input after clear
      this.$nextTick(() => {
        const input = this.$el.querySelector('input');
        if (input) {
          input.focus();
        }
      });
    },
  },
};
</script>
