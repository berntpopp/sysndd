<template>
  <b-container fluid>

  <!-- https://stackoverflow.com/questions/64487119/how-to-style-the-button-in-bootstrap-vue-dropdown-like-a-circle
   style based on https://codepen.io/Akrinu10/pen/vQJMVB -->
  <b-dropdown variant="primary" toggle-class="rounded-circle px-2" class="float" no-caret dropup
        v-b-tooltip.hover.left
        title="Help us improve this page. We value your feedback.">
    <template #button-content>
      <b-icon
        icon="emoji-smile"
        scale="1"
      >
      </b-icon>
    </template>

    <b-dropdown-item
      v-b-tooltip.hover.left
      title="Fill out our form and tell us why you like this entry."
      v-bind:href="'https://docs.google.com/forms/d/e/1FAIpQLSdhfXPurTlJxIpocAasi7av-OoN-49QPt3gQac2HQhV49BXxA/viewform?usp=pp_url&entry.2050768323=' + path"
      target="_blank"
    >
      <b-icon
        icon="hand-thumbs-up"
        scale="1"
      >
      </b-icon>
    </b-dropdown-item>

    <b-dropdown-item
      v-b-tooltip.hover.left
      title="Fill out our form and tell us how to improve this entry."
      v-bind:href="'https://docs.google.com/forms/d/e/1FAIpQLSduPUP28WiFmhGTeWPPJoc18leskmdEReGB_Lv68sjY5n9w5g/viewform?usp=pp_url&entry.2050768323=' + path"
      target="_blank"
    >
      <b-icon
        icon="hand-thumbs-down"
        scale="1"
    >
      </b-icon>
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
      >
      </b-icon>
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
      >
      </b-icon>
    </b-dropdown-item>

  </b-dropdown>

  </b-container>

</template>


<script>

  export default {
  name: 'HelperBadge',
  data() {
      return {
        name: 'HelperBadge',
        path: "",
      }
    },
watch: { // used to refresh navbar on login push
  $route() { 
      this.getParentPageInfo();
  } 
  },
    mounted() {
      // Set the initial number of items
      this.getParentPageInfo();
    },
    methods: {
      getParentPageInfo() {
        this.path = this.$route.path;
      },
    }
  };
</script>


<style scoped>
.float {
	position:fixed;
	width:35px;
	height:35px;
	bottom:60px;
	right:20px;
	background-color:#0C9;
	color:#FFF;
	border-radius:50px;
	text-align:center;
	box-shadow: 2px 2px 3px #999;
}
::v-deep .dropdown-menu {
  background-color: transparent !important; 
  min-width: 50px;
  border: 0px;
  outline: 0px;
}
::v-deep .dropdown-item:hover {
  background-color: #fff!important; 
  color: #000!important; 
}
</style>