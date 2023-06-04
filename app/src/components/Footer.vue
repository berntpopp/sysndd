<template>
  <!-- The footer component -->
  <div class="footer">
    <!-- Using bootstrap-vue navbar component to create the footer -->
    <b-navbar
      toggleable="sm"
      type="light"
      variant="light"
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
import URLS from '@/assets/js/constants/constants';

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
      footerItems: [
        // cc license
        {
          id: 'cc-license',
          link: URLS.COMMON_LICENSE,
          linkAttr: { 'aria-label': 'license-link' },
          imgSrc: '/licensebuttons.netlby4.0_88x31.png',
          alt: 'Creative Commons License',
          width: '96.52',
          target: '_blank',
        },
        // GitHub
        {
          id: 'github',
          link: URLS.GITHUB,
          linkAttr: { 'aria-label': 'github-link' },
          imgSrc: '/GitHub-Mark-64px_white.png',
          alt: 'GitHub Logo',
          width: '34',
          target: '_blank',
        },
        // OpenAPI
        {
          id: 'openapi',
          link: URLS.API,
          linkAttr: { 'aria-label': 'api-link' },
          imgSrc: '/swagger.png',
          alt: 'OpenAPI Logo',
          width: '34',
          target: '_self',
        },
        // DFG
        {
          id: 'dfg',
          link: URLS.DFG,
          linkAttr: { 'aria-label': 'dfg-link' },
          imgSrc: '/dfg_logo_foerderung/dfg_logo_schriftzug_blau_foerderung_4c.png',
          alt: 'DFG gefördert Logo',
          width: '120',
          target: '_blank',
        },
        // UniBe
        {
          id: 'unibe',
          link: URLS.UNIBE,
          linkAttr: { 'aria-label': 'unibe-link' },
          imgSrc: '/ub_16pt_rgb_quer_2018_68px.png',
          alt: 'Universität Bern Logo',
          width: '107',
          target: '_blank',
        },
        // ITHACA
        {
          id: 'ern-ithaca',
          link: URLS.ERN_ITHACA,
          linkAttr: { 'aria-label': 'ern-ithaca-link' },
          imgSrc: '/logo_blue_tiny.png',
          alt: 'ERN ITHACA Logo',
          width: '159',
          target: '_blank',
        },
      ],
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
