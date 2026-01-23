// url_constants.js

/**
 * @fileoverview URL constants used throughout the application.
 */

export default {
  /**
   * Common Creative Commons license URL.
   * @type {string}
   * @description URL pointing to the Creative Commons Attribution 4.0 International License.
   * This license allows for free sharing and adaptation of the work under proper attribution.
   */
  COMMON_LICENSE: 'http://creativecommons.org/licenses/by/4.0/',

  /**
   * URL to the GitHub repository.
   * @type {string}
   * @description Link to the GitHub repository where the application's source code is hosted.
   * Useful for users who want to explore, fork, or contribute to the codebase.
   */
  GITHUB: 'https://github.com/berntpopp/sysndd/',

  /**
   * URL of the German Research Foundation (DFG).
   * @type {string}
   * @description Link to the homepage of the Deutsche Forschungsgemeinschaft (DFG),
   * a major research funding organization in Germany. This may be relevant for citing
   * funding sources or partnerships.
   */
  DFG: 'https://www.dfg.de/',

  /**
   * URL of the University of Bern.
   * @type {string}
   * @description Direct link to the official website of the University of Bern.
   * This could be used for referencing institutional affiliations or academic collaborations.
   */
  UNIBE: 'https://www.unibe.ch/',

  /**
   * URL of the European Reference Network for Rare Congenital Malformations and Intellectual Disability (ERN-ITHACA).
   * @type {string}
   * @description Link to the website of ERN-ITHACA, a network specializing in rare diseases.
   * This link may be used for informational purposes or collaborations.
   */
  ERN_ITHACA: 'https://ern-ithaca.eu/',

  /**
   * Relative link to the API endpoint.
   * @type {string}
   * @description A relative URL used to construct endpoints for API calls within the application.
   * It is combined with the base URL to make full endpoint addresses.
   */
  API_LINK: '/API',

  /**
   * Base URL for the API.
   * @type {string}
   * @description The base URL for API calls, dynamically set from the environment variables.
   * This ensures that the application can adapt to different environments (development, production, etc.).
   */
  API_URL: import.meta.env.VITE_API_URL,
  // add the rest of your constants here
};
