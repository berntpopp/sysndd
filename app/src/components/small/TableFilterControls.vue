<template>
  <div>
    <!-- Search inputs, filter buttons, etc. -->
    <b-form-input
      v-if="showFilterControls"
      v-model="filterContent"
      placeholder="Search any field..."
      @input="onFilterInput"
    />
    <!-- ...other filter controls -->
  </div>
</template>

<script>
export default {
  props: {
    showFilterControls: {
      type: Boolean,
      required: true,
      default: true,
    },
    initialFilterContent: {
      type: String,
      required: true,
      default: '',
    },
  },
  data() {
    return {
      filterContent: this.initialFilterContent,
    };
  },
  methods: {
    onFilterInput() {
      this.$emit('update-filter', this.filterContent);
    },
  },
};
</script>
