/** * components/HelperBadge.vue * * @description The HelperBadge component displays a dropdown menu
with various options for user assistance and feedback. * @component HelperBadge * * @example *
<HelperBadge />
* * @slot button-content - The content of the button that triggers the dropdown menu. * * @prop
{String} variant - The variant of the dropdown button. Default is "primary". * @prop {String}
toggle-class - The class to be applied to the dropdown button. Default is "rounded-circle px-2". *
@prop {Boolean} no-caret - Whether to hide the caret icon. Default is false. * @prop {Boolean}
dropup - Whether to show the dropdown menu above the button. Default is true. * @prop {String} title
- The title of the dropdown button. * * @event click - Emitted when a dropdown item is clicked. * *
@method copyURLCitation - Copies the URL citation to the clipboard. * @method
createInternetArchiveSnapshot - Creates a snapshot of the URL using the Internet Archive API. */
<template>
  <BContainer fluid>
    <!-- https://stackoverflow.com/questions/64487119/how-to-style-the-button-in-bootstrap-vue-dropdown-like-a-circle
   style based on https://codepen.io/Akrinu10/pen/vQJMVB -->
    <BDropdown
      v-b-tooltip.hover.left
      variant="primary"
      toggle-class="rounded-circle px-2"
      class="float"
      no-caret
      dropup
      title="Help us improve this page. We value your feedback."
      aria-label="Feedback and help menu"
    >
      <template #button-content>
        <i class="bi bi-emoji-smile" aria-hidden="true" />
        <span class="visually-hidden">Feedback and help</span>
      </template>

      <BDropdownItem v-b-tooltip.hover.left title="Cite this page." @click="copyURLCitation(path)">
        <i class="bi bi-chat-left-quote-fill" aria-hidden="true" /> Cite
      </BDropdownItem>

      <BDropdownItem
        v-b-tooltip.hover.left
        title="Fill out our form and tell us why you like this entry."
        :href="
          'https://docs.google.com/forms/d/e/1FAIpQLSdhfXPurTlJxIpocAasi7av-OoN-49QPt3gQac2HQhV49BXxA/viewform?usp=pp_url&entry.2050768323=' +
          path
        "
        target="_blank"
      >
        <i class="bi bi-hand-thumbs-up" aria-hidden="true" /> Like
      </BDropdownItem>

      <BDropdownItem
        v-b-tooltip.hover.left
        title="Fill out our form and tell us how to improve this entry."
        :href="
          'https://docs.google.com/forms/d/e/1FAIpQLSduPUP28WiFmhGTeWPPJoc18leskmdEReGB_Lv68sjY5n9w5g/viewform?usp=pp_url&entry.2050768323=' +
          path
        "
        target="_blank"
      >
        <i class="bi bi-hand-thumbs-down" aria-hidden="true" /> Improve
      </BDropdownItem>

      <BDropdownItem
        v-b-tooltip.hover.left
        title="View our documentation."
        href="https://berntpopp.github.io/sysndd/"
        target="_blank"
      >
        <i class="bi bi-book-fill" aria-hidden="true" /> Docs
      </BDropdownItem>

      <BDropdownItem
        v-b-tooltip.hover.left
        title="Get help on our GitHub discussions page."
        href="https://github.com/berntpopp/sysndd/discussions"
        target="_blank"
      >
        <i class="bi bi-question-circle-fill" aria-hidden="true" /> Help
      </BDropdownItem>
    </BDropdown>
  </BContainer>
</template>

<script>
import useToast from '@/composables/useToast';

export default {
  name: 'HelperBadge',
  setup() {
    const { makeToast } = useToast();
    return { makeToast };
  },
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
        this.makeToast(
          `Thank you! Internet archive job_id: ${snapshotResponse.job_id}`,
          'Citation copied',
          'success'
        );
      } catch (e) {
        this.makeToast(e, 'Cannot copy', 'danger');
      }
    },
    async createInternetArchiveSnapshot(url) {
      try {
        // compose API URL
        const apiUrl = `${import.meta.env.VITE_API_URL}/api/external/internet_archive?parameter_url=${url}`;

        // make the API call
        const response = await this.axios.get(apiUrl);

        // return response
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
