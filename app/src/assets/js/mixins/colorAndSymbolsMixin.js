// assets/js/mixins/colorAndSymbolsMixin.js

export default {
  data() {
    return {
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
      saved_style: {
        0: 'secondary',
        1: 'info',
      },
      review_style: {
        0: 'light',
        1: 'dark',
      },
      status_style: {
        0: 'light',
        1: 'dark',
      },
      header_style: {
        false: 'light',
        true: 'danger',
      },
      ndd_icon: {
        No: 'x',
        Yes: 'check',
      },
      ndd_icon_style: {
        No: 'warning',
        Yes: 'success',
      },
      problematic_style: {
        0: 'success',
        1: 'danger',
      },
      problematic_symbol: {
        0: 'check-square',
        1: 'question-square',
      },
      user_approval_style: {
        0: 'danger',
        1: 'primary',
      },
      yn_icon: {
        no: 'x',
        yes: 'check',
      },
      yn_icon_style: {
        no: 'warning',
        yes: 'success',
      },
      publication_style: {
        additional_references: 'info',
        gene_review: 'primary',
      },
      modifier_style: {
        1: 'primary',
        2: 'warning',
        3: 'secondary',
        4: 'light',
        5: 'danger',
      },
      user_icon: {
        Viewer: 'person-circle',
        Reviewer: 'emoji-smile',
        Curator: 'emoji-heart-eyes',
        Administrator: 'emoji-sunglasses',
      },
      user_stlye: {
        Viewer: 'secondary',
        Reviewer: 'primary',
        Curator: 'dark',
        Administrator: 'danger',
      },
      data_age_style: {
        0: 'success',
        3: 'success',
        6: 'warning',
        9: 'danger',
        12: 'danger',
        15: 'danger',
      },
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
