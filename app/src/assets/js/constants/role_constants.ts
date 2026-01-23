// role_constants.ts

/**
 * Constants related to user roles and their permissions within the application.
 */

import type { UserRole, NavigationSection } from '@/types';

/**
 * Role configuration with navigation permissions
 */
const ROLES = {
  /**
   * All allowed roles in the application (ordered by privilege)
   * @description Each string in the array represents a unique role within the application:
   * - 'Administrator': Users with the highest level of access and control over the application.
   * - 'Curator': Users responsible for managing and organizing data.
   * - 'Reviewer': Users who review data for accuracy and completeness.
   * - 'Viewer': Users who have read-only access to the data.
   */
  ALLOWED_ROLES: ['Administrator', 'Curator', 'Reviewer', 'Viewer'] as const satisfies readonly UserRole[],

  /**
   * Navigation permissions for each role
   * @description An array of arrays, where each sub-array lists the navigation
   * permissions available to each role. The order of roles in 'ALLOWED_ROLES'
   * corresponds to the order of sub-arrays here. Each sub-array contains strings
   * representing the sections of the application that the role is allowed to access.
   * This setup helps in configuring UI components based on the user's role.
   *
   * Index corresponds to ALLOWED_ROLES order:
   * - [0] Administrator: ['Admin', 'Curate', 'Review', 'View']
   * - [1] Curator: ['Curate', 'Review', 'View']
   * - [2] Reviewer: ['Review', 'View']
   * - [3] Viewer: ['View']
   */
  ALLOWENCE_NAVIGATION: [
    ['Admin', 'Curate', 'Review', 'View'],
    ['Curate', 'Review', 'View'],
    ['Review', 'View'],
    ['View'],
  ] as const satisfies readonly (readonly NavigationSection[])[],
} as const;

export default ROLES;

/** Type for accessing role configuration */
export type RoleConfig = typeof ROLES;
