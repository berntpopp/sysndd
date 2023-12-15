<!-- TableSearchInput.vue -->
<template>
  <div class="search-input-container">
    <b-form-input
      :value="value"
      :placeholder="placeholder"
      size="sm"
      type="search"
      class="mb-1 border-dark"
      :debounce="debounceTime"
      @input="updateValue($event)"
    />
  </div>
</template>

<script>
export default {
  name: 'SearchInput',
  props: {
    value: {
      type: String,
      default: 'Search...',
    },
    placeholder: {
      type: String,
      default: 'Search...',
    },
    debounceTime: {
      type: Number,
      default: 500,
    },
  },
  methods: {
    updateValue(value) {
      // Implement debounce logic here if necessary
      this.$emit('input', value);
    },
  },
};
</script>
