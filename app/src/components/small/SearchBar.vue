<!-- SearchBar.vue -->
<template>
  <b-input-group class="mb-2 p-2">
    <b-form-input
      v-model="search_input"
      autofocus
      class="border-dark"
      list="search-list"
      type="search"
      placeholder="Search by genes, entities and diseases using names or identifiers"
      size="md"
      autocomplete="off"
      debounce="300"
      @update="loadSearchInfo"
      @keydown.native="handleSearchInputKeydown"
    />

    <b-form-datalist
      id="search-list"
      :options="search_keys"
    />

    <b-input-group-append>
      <b-button
        variant="outline-dark"
        size="md"
        :disabled="search_input.length < 2"
        @click="handleSearchInputKeydown"
      >
        <b-icon icon="search" />
      </b-button>
    </b-input-group-append>
  </b-input-group>
</template>

<script>
// Import the apiService to make the API calls
import apiService from '@/assets/js/services/apiService';

export default {
  data() {
    return {
      search_input: '',
      search_object: {},
      search_keys: [],
    };
  },
  watch: {
    search_input: 'loadSearchInfo',
  },
  methods: {
    async loadSearchInfo() {
      if (this.search_input.length > 0) {
        try {
          const response_search = await apiService.fetchSearchInfo(this.search_input);
          [this.search_object] = response_search;
          this.search_keys = Object.keys(response_search[0]);
        } catch (e) {
          this.makeToast(e, 'Error', 'danger');
        }
      }
    },
    handleSearchInputKeydown(event) {
      if ((event.key === 'Enter' || event.which === 1) && this.search_input.length > 0) {
        if (this.search_object[this.search_input] !== undefined) {
          this.$router.push(this.search_object[this.search_input][0].link);
        } else {
          this.$router.push(`/Search/${this.search_input}`);
        }
        this.search_input = '';
        this.search_keys = [];
      }
    },
  },
};
</script>
