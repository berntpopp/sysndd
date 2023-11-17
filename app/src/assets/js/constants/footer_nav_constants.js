// footer_nav_constants.js

// Importing URLs from a constants file to avoid hardcoding them in this component
import URLS from '@/assets/js/constants/url_constants';

/**
 * @fileoverview This file defines constants for the footer navigation,
 * including navigation items with their respective links, attributes,
 * and other relevant properties.
 */

export default {
  /**
   * Navigation items to be displayed in the footer.
   * @type {Object[]}
   * @property {string} id - The unique identifier for the navigation item.
   * @property {string} link - The URL to which the navigation item points.
   * @property {Object} linkAttr - Additional attributes for the link element, such as aria-label.
   * @property {string} [imgSrc] - Optional. The source path for the navigation item's image.
   * @property {string} [altText] - Optional. Alt text for the navigation item's image.
   * @property {number} [width] - Optional. Width of the navigation item's image.
   * @property {string} [target] - Optional. Specifies where to open the linked document.
   */
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
      imgSrc: '/ITHACA_new_combined_logo_tiny.png',
      alt: 'ERN ITHACA Logo',
      width: '120',
      target: '_blank',
    },
  ],
  // add the rest of your constants here
};
