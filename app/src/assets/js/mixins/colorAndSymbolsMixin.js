// assets/js/mixins/colorAndSymbolsMixin.js

/**
 * @fileoverview Mixin for styles and symbols used across the application.
 *
 * This mixin provides a centralized definition of various styles and symbols
 * used in the Vue components, such as color codes for different statuses,
 * icons for specific conditions, and more. It helps maintain consistency
 * in the appearance of the application and reduces code redundancy.
 */

export default {
  data() {
    return {
      /**
       * Style definitions for stoplight colors based on category or numerical status.
       */
      stoplights_style: {
        1: 'success',
        2: 'primary',
        3: 'warning',
        4: 'danger',
        Definitive: 'success',
        Moderate: 'primary',
        Limited: 'warning',
        Refuted: 'danger',
      },
      /**
       * Style definitions for saved status.
       */
      saved_style: {
        0: 'secondary',
        1: 'info',
      },
      /**
       * Style definitions for review status.
       */
      review_style: {
        0: 'light',
        1: 'dark',
      },
      /**
       * Style definitions for submission status.
       */
      status_style: {
        0: 'light',
        1: 'dark',
      },
      /**
       * Style definitions for header based on a boolean condition.
       */
      header_style: {
        false: 'light',
        true: 'danger',
      },
      /**
       * Icon definitions for NDD (Neurodevelopmental Disorder) status.
       */
      ndd_icon: {
        No: 'x',
        Yes: 'check',
      },
      /**
       * Icon style definitions for NDD status.
       */
      ndd_icon_style: {
        No: 'warning',
        Yes: 'success',
      },
      /**
       * Style definitions for problematic status.
       */
      problematic_style: {
        0: 'success',
        1: 'danger',
      },
      /**
       * Symbol definitions for problematic status.
       */
      problematic_symbol: {
        0: 'check-square',
        1: 'question-square',
      },
      /**
       * Style definitions for user approval status.
       */
      user_approval_style: {
        0: 'danger',
        1: 'primary',
      },
      /**
       * Icon definitions for yes/no status.
       */
      yn_icon: {
        no: 'x',
        yes: 'check',
      },
      /**
       * Icon style definitions for yes/no status.
       */
      yn_icon_style: {
        no: 'warning',
        yes: 'success',
      },
      /**
       * Style definitions for different types of publication references.
       */
      publication_style: {
        additional_references: 'info',
        gene_review: 'primary',
      },
      /**
       * Style definitions for different modifier types.
       */
      modifier_style: {
        1: 'primary',
        2: 'warning',
        3: 'secondary',
        4: 'light',
        5: 'danger',
      },
      /**
       * Icon definitions for different user roles.
       */
      user_icon: {
        Viewer: 'person-circle',
        Reviewer: 'emoji-smile',
        Curator: 'emoji-heart-eyes',
        Administrator: 'emoji-sunglasses',
      },
      /**
       * Style definitions for different user roles.
       */
      user_style: {
        Viewer: 'secondary',
        Reviewer: 'primary',
        Curator: 'dark',
        Administrator: 'danger',
      },
      /**
       * Style definitions for data age.
       */
      data_age_style: {
        0: 'success',
        3: 'success',
        6: 'warning',
        9: 'danger',
        12: 'danger',
        15: 'danger',
      },
      /**
       * Style definitions for various categories.
       */
      category_style: {
        COMPARTMENTS: 'blue',
        Component: 'indigo',
        DISEASES: 'purple',
        Function: 'pink',
        HPO: 'red',
        InterPro: 'orange',
        KEGG: 'yellow',
        Keyword: 'green',
        NetworkNeighborAL: 'teal',
        Pfam: 'cyan',
        PMID: 'darkgoldenrod',
        Process: 'darkgreen',
        RCTM: 'darkmagenta',
        SMART: 'indianred',
        TISSUES: 'hotpink',
        WikiPathways: 'lightskyblue',
      },
    };
  },
};
