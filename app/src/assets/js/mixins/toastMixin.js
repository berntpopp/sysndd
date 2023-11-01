// assets/js/mixins/toastMixin.js
export default {
  methods: {
    makeToast(event, title = null, variant = null, toaster = 'b-toaster-top-right', hide = false) {
      this.$bvToast.toast(event, {
        title,
        toaster,
        variant,
        solid: true,
        autoHideDelay: 2000,
      });
    },
  },
};
