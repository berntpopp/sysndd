<template>
  <b-container fluid>
    <!-- https://stackoverflow.com/questions/64487119/how-to-style-the-button-in-bootstrap-vue-dropdown-like-a-circle
   style based on https://codepen.io/Akrinu10/pen/vQJMVB -->
    <b-dropdown
      v-b-tooltip.hover.left
      variant="primary"
      toggle-class="rounded-circle px-2"
      class="float"
      no-caret
      dropup
      title="Help us improve this page. We value your feedback."
    >
      <template #button-content>
        <b-icon
          icon="emoji-smile"
          scale="1"
        />
      </template>

      <b-dropdown-item
        v-b-tooltip.hover.left
        title="Cite this page."
        @click="copyURLCitation(path)"
      >
        <b-icon
          icon="chat-left-quote-fill"
          scale="1"
        />
      </b-dropdown-item>

      <b-dropdown-item
        v-b-tooltip.hover.left
        title="Fill out our form and tell us why you like this entry."
        :href="
          'https://docs.google.com/forms/d/e/1FAIpQLSdhfXPurTlJxIpocAasi7av-OoN-49QPt3gQac2HQhV49BXxA/viewform?usp=pp_url&entry.2050768323=' +
            path
        "
        target="_blank"
      >
        <b-icon
          icon="hand-thumbs-up"
          scale="1"
        />
      </b-dropdown-item>

      <b-dropdown-item
        v-b-tooltip.hover.left
        title="Fill out our form and tell us how to improve this entry."
        :href="
          'https://docs.google.com/forms/d/e/1FAIpQLSduPUP28WiFmhGTeWPPJoc18leskmdEReGB_Lv68sjY5n9w5g/viewform?usp=pp_url&entry.2050768323=' +
            path
        "
        target="_blank"
      >
        <b-icon
          icon="hand-thumbs-down"
          scale="1"
        />
      </b-dropdown-item>

      <b-dropdown-item
        v-b-tooltip.hover.left
        title="View our documentation."
        href="https://berntpopp.github.io/sysndd/"
        target="_blank"
      >
        <b-icon
          icon="book-fill"
          scale="1"
        />
      </b-dropdown-item>

      <b-dropdown-item
        v-b-tooltip.hover.left
        title="Get help on our GitHub discussions page."
        href="https://github.com/berntpopp/sysndd/discussions"
        target="_blank"
      >
        <b-icon
          icon="question-circle-fill"
          scale="1"
        />
      </b-dropdown-item>
    </b-dropdown>
  </b-container>
</template>

<script>
import toastMixin from '@/assets/js/mixins/toastMixin';

export default {
  name: 'HelperBadge',
  mixins: [toastMixin],
  data() {
    return {
      name: 'HelperBadge',
      path: '',
    };
  },
  watch: {
    // used to refresh navbar on login push
    $route() {
      this.getParentPageInfo();
    },
  },
  mounted() {
    // Set the initial number of items
    this.getParentPageInfo();
  },
  methods: {
    getParentPageInfo() {
      this.path = this.$route.path;
    },
    // based on https://stackoverflow.com/questions/58733960/copy-url-to-clipboard-via-button-click-in-a-vuejs-component
    async copyURLCitation(path) {
      try {
        // first compose date
        // based on https://stackoverflow.com/questions/1531093/how-do-i-get-the-current-date-in-javascript
        let today = new Date();
        const dd = String(today.getDate()).padStart(2, '0');
        const mm = String(today.getMonth() + 1).padStart(2, '0');
        const yyyy = today.getFullYear();
        today = `${yyyy}-${mm}-${dd}`;

        // compose URL
        const url = `https://sysndd.dbmr.unibe.ch${path}`;

        // compose citation string
        const citation = `SysNDD, the expert curated database of gene disease relationships in neurodevelopmental disorders; ${url} (accessed ${today}).`;

        // make the snapshot
        const snapshotResponse = await this.createInternetArchiveSnapshot(url);

        // copy to clipboard
        // TODO: update with job_id success info when in API response
        await navigator.clipboard.writeText(citation);
        this.makeToast(`Thank you! Internet archive job_id: ${snapshotResponse.job_id}`, 'Citation copied', 'success');
      } catch (e) {
        this.makeToast(e, 'Cannot copy', 'danger');
      }
    },
    async createInternetArchiveSnapshot(url) {
      try {
        // compose API URL
        const apiUrl = `${process.env.VUE_APP_API_URL}/api/external/internet_archive?parameter_url=${url}`;

        // make the API call
        const response = await this.axios.get(apiUrl);

        // return respone
        return response.data;
      } catch (e) {
        this.makeToast(e, 'Cannot copy', 'danger');
      }
      return null;
    },
  },
};
</script>

<style scoped>
.float {
  position: fixed;
  width: 35px;
  height: 35px;
  bottom: 60px;
  right: 20px;
  background-color: #0c9;
  color: #fff;
  border-radius: 50px;
  text-align: center;
  box-shadow: 2px 2px 3px #999;
}
:deep(.dropdown-menu) {
  background-color: transparent !important;
  min-width: 50px;
  border: 0px;
  outline: 0px;
}
:deep(.dropdown-item:hover) {
  background-color: #fff !important;
  color: #000 !important;
}
</style>
