<!-- components/small/TablePaginationControls.vue -->
<template>
  <div>
    <!-- Page Size Selector -->
    <b-input-group
      prepend="Per page"
      class="mb-1"
      size="sm"
    >
      <b-form-select
        id="per-page-select"
        v-model="localPerPage"
        :options="pageOptions"
        size="sm"
        @change="onPageSizeChange"
      />
    </b-input-group>

    <!-- Pagination -->
    <b-pagination
      v-model="localCurrentPage"
      :total-rows="totalRows"
      :per-page="localPerPage"
      align="fill"
      size="sm"
      class="my-0"
      limit="2"
      @change="onPageChange"
    />
  </div>
</template>

<script>
export default {
  props: {
    totalRows: {
      type: Number,
      default: null,
    },
    initialPerPage: {
      type: Number,
      default: 10,
    },
    pageOptions: {
      type: Array,
      default: () => [10, 25, 50, 100],
    },
  },
  data() {
    return {
      localCurrentPage: 1,
      localPerPage: this.initialPerPage,
    };
  },
  methods: {
    onPageChange(newPage) {
      this.$emit('page-change', newPage);
    },
    onPageSizeChange(newSize) {
      this.localPerPage = newSize;
      this.$emit('per-page-change', newSize);
    },
  },
};
</script>
