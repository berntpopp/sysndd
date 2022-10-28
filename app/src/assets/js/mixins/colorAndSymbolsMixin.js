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
      ndd_icon_text: {
        No: 'NOT associated with NDD',
        Yes: 'associated with NDD',
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
    };
  },
};
