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
};
</script>

<style scoped>
/* Style for this component, if any. */
</style>
