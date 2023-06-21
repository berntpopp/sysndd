// main_nav_constants.js

export default {
  // An array of dropdown menus items to be displayed in the navbar.
  // Each item has an id, title, items for the dropdown with text and path.
  // Additionally includes conditional properties for the user, admin, curate, and review permissions.
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
    {
      id: 'administration_dropdown',
      title: 'Administration',
      required: ['admin'],
      align: 'right',
      items: [
        { text: 'Manage user', path: '/ManageUser', icons: ['gear', 'person-circle'] },
        { text: 'Manage annotations', path: '/ManageAnnotations', icons: ['gear', 'table'] },
        { text: 'Manage about', path: '/ManageAbout', icons: ['gear', 'question-circle-fill'] },
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
