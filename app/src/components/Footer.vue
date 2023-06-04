<template>
  <div class="footer">
    <b-navbar
      toggleable="sm"
      type="light"
      variant="light"
      class="py-0 bg-footer"
    >
      <b-navbar-toggle target="footer-collapse" />
      <b-collapse
        id="footer-collapse"
        is-nav
      >
        <b-navbar-nav
          justified
          class="flex-grow-1"
        >
          <FooterNavItem
            v-for="(item, index) in footerItems"
            :key="index"
            :item="item"
          />
        </b-navbar-nav>
      </b-collapse>
    </b-navbar>
  </div>
</template>

<script>
import FooterNavItem from '@/components/small/FooterNavItem.vue';

export default {
  name: 'Footer',
  components: {
    FooterNavItem,
  },
  data() {
    return {
      link: {
        license: { 'aria-label': 'license-link' },
        github: { 'aria-label': 'github-link' },
        api: { 'aria-label': 'api-link' },
        dfg: { 'aria-label': 'dfg-link' },
        unibe: { 'aria-label': 'unibe-link' },
        'ern-ithaca': { 'aria-label': 'ern-ithaca-link' },
      },
      footerItems: [
        // cc license
        {
          link: 'http://creativecommons.org/licenses/by/4.0/',
          linkAttr: { 'aria-label': 'license-link' },
          imgSrc: '/licensebuttons.netlby4.0_88x31.png',
          alt: 'Creative Commons License',
          width: '96.52',
          target: '_blank',
        },
        // GitHub
        {
          link: '/API',
          linkAttr: { 'aria-label': 'github-link' },
          imgSrc: '/GitHub-Mark-64px_white.png',
          alt: 'GitHub Logo',
          width: '34',
          target: '_blank',
        },
        // OpenAPI
        {
          link: '/API',
          linkAttr: { 'aria-label': 'api-link' },
          imgSrc: '/swagger.png',
          alt: 'OpenAPI Logo',
          width: '34',
          target: '_self',
        },
        // DFG
        {
          link: 'https://www.dfg.de/',
          linkAttr: { 'aria-label': 'dfg-link' },
          imgSrc: '/dfg_logo_foerderung/dfg_logo_schriftzug_blau_foerderung_4c.png',
          alt: 'DFG gefördert Logo',
          width: '120',
          target: '_blank',
        },
        // UniBe
        {
          link: 'https://www.unibe.ch/',
          linkAttr: { 'aria-label': 'unibe-link' },
          imgSrc: '/ub_16pt_rgb_quer_2018_68px.png',
          alt: 'Universität Bern Logo',
          width: '107',
          target: '_blank',
        },
        // UniBe
        {
          link: 'https://ern-ithaca.eu/',
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

<!-- Add "scoped" attribute to limit CSS to this component only -->
<style scoped>
.bg-footer {
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
