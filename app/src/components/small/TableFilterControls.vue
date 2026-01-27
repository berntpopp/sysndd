<!-- src/components/small/TableFilterControls.vue -->
<template>
  <div>
    <!-- Search inputs, filter buttons, etc. -->
    <BFormInput
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
      default: true,
    },
    initialFilterContent: {
      type: String,
      default: '',
    },
  },
  emits: ['update-filter'],
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
