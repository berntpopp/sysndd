<template>
  <b-nav-item
    :link-attrs="item.linkAttr"
    :href="item.link"
    :target="item.target"
  >
    <img
      :src="item.imgSrc"
      height="34"
      :width="item.width"
      :alt="item.alt"
      :rel="relAttribute"
      @error="handleImageError"
    >
  </b-nav-item>
</template>

<script>
export default {
  props: {
    item: {
      type: Object,
      required: true,
    },
  },
  computed: {
    relAttribute() {
      return this.item.target === '_blank' ? 'noopener' : '';
    },
  },
  methods: {
    handleImageError(e) {
      e.target.src = '/brain-neurodevelopmental-disorders-sysndd-logo.png';
    },
  },
};
</script>

<style scoped>
/* Style for this component, if any. */
</style>
