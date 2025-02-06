<template>
  <b-input-group class="mb-2 p-2 search-bar-container">
    <b-form-input
      v-model="search_input"
      autofocus
      :class="inNavbar ? 'navbar-search' : 'border-dark'"
      list="search-list"
      type="search"
      :placeholder="placeholderString"
      :size="inNavbar ? 'sm' : 'md'"
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
        :variant="inNavbar ? 'outline-primary' : 'outline-dark'"
        :size="inNavbar ? 'sm' : 'md'"
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
  props: {
    placeholderString: {
      type: String,
      required: true,
      default: '...',
    },
    inNavbar: {
      type: Boolean,
      required: true,
      default: false,
    },
  },
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
    // Function to load search information from the API.
    // This function is triggered when the user types into the search input.
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
    // Function to handle keydown events on the search input.
    // This function listens for the 'Enter' key and performs a search action.
    async handleSearchInputKeydown(event) {
      // Only proceed if the key is Enter or if it's a click (event.which === 1)
      // and ensure search_input is nonempty and we are not already navigating.
      if ((event.key === 'Enter' || event.which === 1)
          && this.search_input.length > 0
          && !this._isNavigating) {
        // Set flag so duplicate calls are ignored
        this._isNavigating = true;
        let targetLink = '';
        if (this.search_object[this.search_input] !== undefined) {
          targetLink = this.search_object[this.search_input][0].link;
        } else {
          targetLink = `/Search/${this.search_input}`;
        }

        this.$router.push(targetLink)
          .catch((err) => {
            // Only ignore NavigationDuplicated errors; throw others.
            if (err.name !== 'NavigationDuplicated') {
              throw err;
            }
          })
          .finally(() => {
            this._isNavigating = false;
          });

        // Clear search input and keys
        this.search_input = '';
        this.search_keys = [];
      }
    },
  },
};
</script>

<!-- Add "scoped" attribute to limit CSS to this component only -->
<style scoped>
.navbar-search {
  width: 300px;
  min-width: 100px; /* Adjust min-width to prevent the button from disappearing */
}

.search-bar-container {
  flex-wrap: nowrap; /* Ensure the search bar and button stay on the same line */
}
</style>
