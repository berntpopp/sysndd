// footer_nav_constants.js

// Importing URLs from a constants file to avoid hardcoding them in this component
import URLS from '@/assets/js/constants/url_constants';

export default {
  // An array of items to be displayed in the footer.
  // Each item has an id, link, attributes for the link, image source, alt text, width, and target for the link.
  NAV_ITEMS: [
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
      link: URLS.API_LINK,
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
  // add the rest of your constants here
};
