// url_constants.ts

/**
 * URL constants used throughout the application.
 * Values sourced from environment variables with type safety.
 */

/**
 * Application URL configuration
 * Using 'as const' enables literal type inference
 */
const URLS = {
  /**
   * Creative Commons Attribution 4.0 International License
   * @description URL pointing to the Creative Commons Attribution 4.0 International License.
   * This license allows for free sharing and adaptation of the work under proper attribution.
   */
  COMMON_LICENSE: 'http://creativecommons.org/licenses/by/4.0/',

  /**
   * GitHub repository URL
   * @description Link to the GitHub repository where the application's source code is hosted.
   * Useful for users who want to explore, fork, or contribute to the codebase.
   */
  GITHUB: 'https://github.com/berntpopp/sysndd/',

  /**
   * German Research Foundation (DFG) URL
   * @description Link to the homepage of the Deutsche Forschungsgemeinschaft (DFG),
   * a major research funding organization in Germany. This may be relevant for citing
   * funding sources or partnerships.
   */
  DFG: 'https://www.dfg.de/',

  /**
   * University of Bern URL
   * @description Direct link to the official website of the University of Bern.
   * This could be used for referencing institutional affiliations or academic collaborations.
   */
  UNIBE: 'https://www.unibe.ch/',

  /**
   * European Reference Network for Rare Congenital Malformations
   * @description Link to the website of ERN-ITHACA, a network specializing in rare diseases.
   * This link may be used for informational purposes or collaborations.
   */
  ERN_ITHACA: 'https://ern-ithaca.eu/',

  /**
   * Relative link to the API documentation endpoint
   * @description A relative URL used to construct endpoints for API calls within the application.
   * It is combined with the base URL to make full endpoint addresses.
   */
  API_LINK: '/API',

  /**
   * Base URL for API calls (from environment)
   * @description The base URL for API calls, dynamically set from the environment variables.
   * This ensures that the application can adapt to different environments (development, production, etc.).
   */
  API_URL: import.meta.env.VITE_API_URL,
} as const;

export default URLS;

/** Type for the URLS object - enables strict typing in consumers */
export type UrlConfig = typeof URLS;
