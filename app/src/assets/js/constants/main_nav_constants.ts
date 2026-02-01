// main_nav_constants.ts

/**
 * Constants for main navigation elements.
 */

/** Navigation menu item with optional path or action */
export interface NavMenuItem {
  /** Display text for the menu item */
  text: string;
  /** Navigation path (for route links) */
  path?: string;
  /** Action method name (for function calls) */
  action?: string;
  /** Bootstrap icons to display */
  icons?: string[];
  /** Component to render alongside the item */
  component?: string;
}

/** Dropdown menu configuration */
export interface NavDropdown {
  /** Unique identifier for the dropdown */
  id: string;
  /** Title displayed in the navbar */
  title: string;
  /** Required permissions to view this dropdown */
  required: string[];
  /** Dropdown alignment */
  align: 'left' | 'right';
  /** Menu items in the dropdown */
  items: NavMenuItem[];
}

/**
 * Main navigation configuration
 */
const MAIN_NAV = {
  /**
   * Left-aligned dropdown menus (public sections)
   */
  DROPDOWN_ITEMS_LEFT: [
    {
      id: 'tables_dropdown',
      title: 'Tables',
      required: [''],
      align: 'left',
      items: [
        { text: 'Entities', path: '/Entities' },
        { text: 'Genes', path: '/Genes' },
        { text: 'Phenotypes', path: '/Phenotypes' },
        { text: 'Panels', path: '/Panels' },
      ],
    },
    {
      id: 'analyses_dropdown',
      title: 'Analyses',
      required: [''],
      align: 'left',
      items: [
        { text: 'Compare curations', path: '/CurationComparisons' },
        { text: 'Correlate phenotypes', path: '/PhenotypeCorrelations' },
        { text: 'Correlate variants', path: '/VariantCorrelations' },
        { text: 'Entries over time', path: '/EntriesOverTime' },
        { text: 'NDD Publications', path: '/PublicationsNDD' },
        { text: 'PubTator Analysis', path: '/PubtatorNDD' },
        { text: 'Functional clusters', path: '/GeneNetworks' },
        { text: 'Pheno-Func Correlation', path: '/PhenotypeFunctionalCorrelation' },
      ],
    },
    {
      id: 'help_dropdown',
      title: 'Help',
      required: [''],
      align: 'left',
      items: [
        { text: 'About', path: '/About' },
        { text: 'Docs and FAQ', path: '/Documentation' },
      ],
    },
  ] satisfies NavDropdown[],

  /**
   * Right-aligned dropdown menus (role-based sections)
   */
  DROPDOWN_ITEMS_RIGHT: [
    {
      id: 'administration_dropdown',
      title: 'Administration',
      required: ['admin'],
      align: 'right',
      items: [
        { text: 'Manage user', path: '/ManageUser', icons: ['gear', 'person-circle'] },
        { text: 'Manage annotations', path: '/ManageAnnotations', icons: ['gear', 'table'] },
        { text: 'Manage ontology', path: '/ManageOntology', icons: ['gear', 'list-nested'] },
        { text: 'Manage about', path: '/ManageAbout', icons: ['gear', 'question-circle-fill'] },
        {
          text: 'Admin statistics',
          path: '/AdminStatistics',
          icons: ['bar-chart-line', 'clipboard-check'],
        },
        { text: 'View logs', path: '/ViewLogs', icons: ['eye', 'clipboard-plus'] },
        { text: 'Manage backups', path: '/ManageBackups', icons: ['gear', 'database'] },
        { text: 'Manage PubTator', path: '/ManagePubtator', icons: ['gear', 'journal-medical'] },
      ],
    },
    {
      id: 'curation_dropdown',
      title: 'Curation',
      required: ['curate'],
      align: 'right',
      items: [
        { text: 'Create entity', path: '/CreateEntity', icons: ['plus-square', 'link'] },
        { text: 'Modify entity', path: '/ModifyEntity', icons: ['pen', 'link'] },
        { text: 'Approve review', path: '/ApproveReview', icons: ['check', 'clipboard-plus'] },
        { text: 'Approve status', path: '/ApproveStatus', icons: ['check', 'stoplights'] },
        { text: 'Approve user', path: '/ApproveUser', icons: ['check', 'person-circle'] },
        { text: 'Manage re-review', path: '/ManageReReview', icons: ['gear', 'clipboard-check'] },
      ],
    },
    {
      id: 'review_dropdown',
      title: 'Review',
      required: ['review'],
      align: 'right',
      items: [
        { text: 'Instructions', path: '/ReviewInstructions', icons: ['check', 'book-fill'] },
        { text: 'Re-Review', path: '/Review', icons: ['pen', 'clipboard-plus'] },
      ],
    },
    {
      id: 'user_dropdown',
      title: 'User',
      required: ['view'],
      align: 'right',
      items: [
        { text: 'View profile', path: '/User', icons: ['person-circle'] },
        {
          text: 'Token',
          action: 'refreshWithJWT',
          icons: ['arrow-repeat'],
          component: 'LogoutCountdownBadge',
        },
        { text: 'Sign out', action: 'doUserLogOut', icons: ['x-circle'] },
      ],
    },
  ] satisfies NavDropdown[],
} as const;

export default MAIN_NAV;

/** Type for accessing main navigation configuration */
export type MainNavConfig = typeof MAIN_NAV;
