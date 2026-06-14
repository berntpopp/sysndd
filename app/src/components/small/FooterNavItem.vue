<template>
  <BNavItem
    class="footer-link"
    :link-attrs="linkAttributes"
    :href="item.link"
    :target="item.target"
  >
    <img
      :src="item.imgSrc"
      height="34"
      :width="item.width"
      :alt="item.alt"
      :class="logoClasses"
      @error="handleImageError"
    />
  </BNavItem>
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
    linkAttributes() {
      return {
        ...this.item.linkAttr,
        ...(this.item.target === '_blank' ? { rel: 'noopener' } : {}),
      };
    },
    logoClasses() {
      return [
        'footer-logo',
        {
          'footer-logo--icon': ['github', 'openapi', 'mcp'].includes(this.item.id),
          'footer-logo--license': this.item.id === 'cc-license',
          'footer-logo--partner': ['dfg', 'unibe', 'ern-ithaca'].includes(this.item.id),
        },
      ];
    },
  },
  methods: {
    handleImageError(e) {
      e.target.src = '/img/icons/android-chrome-192x192.png';
    },
  },
};
</script>

<style scoped>
:deep(.nav-link),
.footer-link {
  display: inline-flex;
}
</style>
