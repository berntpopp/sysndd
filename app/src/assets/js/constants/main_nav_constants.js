/**
 * @fileoverview Constants for main navigation elements.
 */

export default {
  // An array of dropdown menus items to be displayed in the navbar.
  // Each item has an id, title, items for the dropdown with text and path.
  // Additionally includes conditional properties for the user, admin, curate, and review permissions.
  DROPDOWN_ITEMS_LEFT: [
    /**
     * Represents a dropdown item in the main navigation.
     * @type {Object}
     * @property {string} id - Unique identifier for the dropdown item.
     * @property {string} title - Title of the dropdown to be displayed.
     * @property {Array} required - Array of strings indicating required permissions to view this dropdown.
     * @property {string} align - Alignment of the dropdown, typically 'left' or 'right'.
     * @property {Array} items - Array of objects representing individual menu items in the dropdown.
     * Each menu item object contains:
     * @property {string} items.text - Display text for the menu item.
     * @property {string} items.path - Navigation path associated with the menu item.
     */
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
        // ─────────────────────────────────────────────────────────────────
        // NEW CORRELATE VARIANTS ITEM
        // ─────────────────────────────────────────────────────────────────
        { text: 'Correlate variants', path: '/VariantCorrelations' },
        // ─────────────────────────────────────────────────────────────────
        { text: 'Entries over time', path: '/EntriesOverTime' },
        { text: 'NDD Publications', path: '/PublicationsNDD' },
        { text: 'Functional clusters', path: '/GeneNetworks' },
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
  ],
  DROPDOWN_ITEMS_RIGHT: [
    /**
     * Represents a dropdown item in the main navigation on the right side.
     * @type {Object}
     * @property {string} id - Unique identifier for the dropdown item.
     * @property {string} title - Title of the dropdown to be displayed.
     * @property {Array} required - Array of strings indicating required permissions to view this dropdown.
     * @property {string} align - Alignment of the dropdown, typically 'left' or 'right'.
     * @property {Array} items - Array of objects representing individual menu items in the dropdown.
     * Each menu item object contains:
     * @property {string} items.text - Display text for the menu item.
     * @property {string} items.path - Navigation path associated with the menu item.
     */
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
        { text: 'Admin statistics', path: '/AdminStatistics', icons: ['bar-chart-line', 'clipboard-check'] },
        { text: 'View logs', path: '/ViewLogs', icons: ['eye', 'clipboard-plus'] },
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
          text: 'Token', action: 'refreshWithJWT', icons: ['arrow-repeat'], component: 'LogoutCountdownBadge',
        },
        { text: 'Sign out', action: 'doUserLogOut', icons: ['x-circle'] },
      ],
    },
  ],
  // add the rest of your constants here
};
