// role_constants.js

/**
 * @fileoverview Constants related to user roles and their permissions within the application.
 */

export default {
  /**
   * A list of all roles allowed in the application.
   * @type {string[]}
   * @description Each string in the array represents a unique role within the application.
   * These roles include:
   * - 'Administrator': Users with the highest level of access and control over the application.
   * - 'Curator': Users responsible for managing and organizing data.
   * - 'Reviewer': Users who review data for accuracy and completeness.
   * - 'Viewer': Users who have read-only access to the data.
   */
  ALLOWED_ROLES: ['Administrator', 'Curator', 'Reviewer', 'Viewer'],

  /**
   * Defines navigation permissions for each role.
   * @type {string[][]}
   * @description An array of arrays, where each sub-array lists the navigation
   * permissions available to each role. The order of roles in 'ALLOWED_ROLES'
   * corresponds to the order of sub-arrays here. Each sub-array contains strings
   * representing the sections of the application that the role is allowed to access.
   * This setup helps in configuring UI components based on the user's role.
   *
   * For example:
   * - The first sub-array ['Admin', 'Curate', 'Review', 'View'] corresponds to the
   *   'Administrator' role, indicating that users with this role can access all four sections.
   * - The last sub-array ['View'] corresponds to the 'Viewer' role, indicating that
   *   users with this role can only access the 'View' section.
   */
  ALLOWENCE_NAVIGATION: [
    ['Admin', 'Curate', 'Review', 'View'],
    ['Curate', 'Review', 'View'],
    ['Review', 'View'],
    ['View'],
  ],
};
