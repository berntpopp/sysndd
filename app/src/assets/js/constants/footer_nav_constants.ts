// footer_nav_constants.ts

/**
 * Constants for footer navigation elements.
 * Includes external links with logos for partners, licenses, and resources.
 */

// Importing URLs from a constants file to avoid hardcoding them
import URLS from '@/assets/js/constants/url_constants';

/** Footer link item configuration */
export interface FooterLink {
  /** Unique identifier for the navigation item */
  id: string;
  /** The URL to which the navigation item points */
  link: string;
  /** Additional attributes for the link element (e.g., aria-label) */
  linkAttr: Record<string, string>;
  /** Source path for the navigation item's image */
  imgSrc: string;
  /** Alt text for the navigation item's image */
  alt: string;
  /** Width of the navigation item's image (in pixels) */
  width: string;
  /** Specifies where to open the linked document */
  target: '_blank' | '_self' | '_parent' | '_top';
}

/**
 * Footer navigation configuration
 */
const FOOTER_NAV = {
  /**
   * Navigation items to be displayed in the footer.
   * Includes logos for CC license, GitHub, OpenAPI, funding organizations, and partners.
   */
  NAV_ITEMS: [
    // Creative Commons license
    {
      id: 'cc-license',
      link: URLS.COMMON_LICENSE,
      linkAttr: { 'aria-label': 'license-link' },
      imgSrc: '/licensebuttons.netlby4.0_88x31.png',
      alt: 'Creative Commons License',
      width: '96.52',
      target: '_blank',
    },
    // GitHub repository
    {
      id: 'github',
      link: URLS.GITHUB,
      linkAttr: { 'aria-label': 'github-link' },
      imgSrc: '/GitHub-Mark-64px_white.png',
      alt: 'GitHub Logo',
      width: '34',
      target: '_blank',
    },
    // OpenAPI documentation
    {
      id: 'openapi',
      link: URLS.API_LINK,
      linkAttr: { 'aria-label': 'api-link' },
      imgSrc: '/swagger.png',
      alt: 'OpenAPI Logo',
      width: '34',
      target: '_self',
    },
    // German Research Foundation (DFG)
    {
      id: 'dfg',
      link: URLS.DFG,
      linkAttr: { 'aria-label': 'dfg-link' },
      imgSrc: '/dfg_logo_foerderung/dfg_logo_schriftzug_blau_foerderung_4c.png',
      alt: 'DFG gefördert Logo',
      width: '120',
      target: '_blank',
    },
    // University of Bern
    {
      id: 'unibe',
      link: URLS.UNIBE,
      linkAttr: { 'aria-label': 'unibe-link' },
      imgSrc: '/ub_16pt_rgb_quer_2018_68px.png',
      alt: 'Universität Bern Logo',
      width: '107',
      target: '_blank',
    },
    // European Reference Network ITHACA
    {
      id: 'ern-ithaca',
      link: URLS.ERN_ITHACA,
      linkAttr: { 'aria-label': 'ern-ithaca-link' },
      imgSrc: '/ITHACA_new_combined_logo_tiny.png',
      alt: 'ERN ITHACA Logo',
      width: '120',
      target: '_blank',
    },
  ] satisfies FooterLink[],
} as const;

export default FOOTER_NAV;

/** Type for accessing footer navigation configuration */
export type FooterNavConfig = typeof FOOTER_NAV;
