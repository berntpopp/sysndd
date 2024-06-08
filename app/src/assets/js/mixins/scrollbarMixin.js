// src/mixins/scrollbarMixin.js

export default {
  methods: {
    updateScrollbar() {
      this.$nextTick(() => {
        console.log('1');
        if (this.$refs.scroll) {
          console.log('2');
          this.$refs.scroll.update();
        }
      });
    },
  },
};
