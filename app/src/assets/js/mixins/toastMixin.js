// assets/js/mixins/toastMixin.js
export default {
      methods: {
            makeToast(event, title = null, variant = null, toaster = 'b-toaster-top-right', hide = false) {
                  this.$bvToast.toast('' + event, {
                        title: title,
                        toaster: toaster,
                        variant: variant,
                        solid: true,
                        noAutoHide: hide
                  })
            }
      },
}