// assets/js/mixins/toastMixin.js
export default {
      methods: {
      makeToast(event, title = null, variant = null) {
            this.$bvToast.toast('' + event, {
                  title: title,
                  toaster: 'b-toaster-top-right',
                  variant: variant,
                  solid: true
            })
      }
    },
}