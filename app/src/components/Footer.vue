/**
 * components/Footer.vue
 *
 * @description The footer component of the application.
 * @component Footer
 *
 * @script
 *   - Imports FOOTER_NAV_CONSTANTS from '@/assets/js/constants/footer_nav_constants' to avoid hardcoding URLs in this component.
 *   - Lazy-loads the FooterNavItem component to optimize performance.
 *   - Exports the Footer component.
 *   - Defines the name of the component as 'Footer'.
 *   - Registers the FooterNavItem component.
 *   - Defines the data property 'footerItems' as an array of items to be displayed in the footer.
 *
 * @style
 *   - Uses the 'scoped' attribute to limit the styles to this component only.
 *   - Sets a linear gradient background for the footer.
 */
<template>
  <!-- The footer component -->
  <div class="footer">
    <!-- Using bootstrap-vue navbar component to create the footer -->
    <b-navbar
      toggleable="sm"
      type="light"
      variant="light"
      fixed="bottom"
      class="py-0 bg-footer"
    >
      <!-- The navbar toggle button for smaller screen sizes -->
      <b-navbar-toggle target="footer-collapse" />
      <!-- The collapsible part of the navbar -->
      <b-collapse
        id="footer-collapse"
        is-nav
      >
        <!-- The navbar items, distributed evenly across the navbar -->
        <b-navbar-nav
          justified
          class="flex-grow-1"
        >
          <!-- A component for each item in the footer -->
          <FooterNavItem
            v-for="(item, index) in footerItems"
            :key="index.id"
            :item="item"
          />
        </b-navbar-nav>
      </b-collapse>
    </b-navbar>
  </div>
</template>

<script>
// Importing URLs from a constants file to avoid hardcoding them in this component
import FOOTER_NAV_CONSTANTS from '@/assets/js/constants/footer_nav_constants';

// Lazy-loading the FooterNavItem component to optimize performance
const FooterNavItem = () => import('@/components/small/FooterNavItem.vue');

export default {
  name: 'Footer',
  components: {
    FooterNavItem,
  },
  data() {
    return {
      // An array of items to be displayed in the footer.
      // Each item has an id, link, attributes for the link, image source, alt text, width, and target for the link.
      footerItems: FOOTER_NAV_CONSTANTS.NAV_ITEMS,
    };
  },
};
</script>

<!-- The "scoped" attribute limits the styles to this component only -->
<style scoped>
.bg-footer {
  /* A linear gradient background for the footer */
  background-image: linear-gradient(
    to top,
    #d5d4d0 0%,
    #d5d4d0 1%,
    #eeeeec 31%,
    #efeeec 75%,
    #e9e9e7 100%
  );
}
</style>
