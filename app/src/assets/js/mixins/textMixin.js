// assets/js/mixins/textMixin.js

export default {
  data() {
    return {
      ndd_icon_text: {
        No: 'NOT associated with NDD',
        Yes: 'associated with NDD',
      },
      publication_hover_text: {
        additional_references: 'Original Article ',
        gene_review: 'GeneReview Article',
      },
      modifier_text: {
        1: 'present',
        2: 'uncertain',
        3: 'variable',
        4: 'rare',
        5: 'absent',
      },
      inheritance_short_text: {
        'Autosomal dominant inheritance': 'AD',
        'Autosomal recessive inheritance': 'AR',
        'X-linked other inheritance': 'Xo',
        'X-linked recessive inheritance': 'XR',
        'X-linked dominant inheritance': 'XD',
        'Mitochondrial inheritance': 'Mit',
        'Somatic mutation': 'Som',
      },
      inheritance_overview_text: {
        'Autosomal dominant': 'AD',
        'Autosomal recessive': 'AR',
        'X-linked': 'X',
        Other: 'M/S',
      },
      inheritance_link: {
        'Autosomal dominant': ['Autosomal dominant inheritance'],
        'Autosomal recessive': ['Autosomal recessive inheritance'],
        'X-linked': ['X-linked other inheritance', 'X-linked recessive inheritance', 'X-linked dominant inheritance'],
        Other: ['Mitochondrial inheritance', 'Somatic mutation'],
      },
      empty_table_text: {
        false: 'Apply for a new batch of entities.',
        true: 'Nothing to review.',
      },
      data_age_text: {
        0: 'new entry, no priority for new review',
        3: 'relatively new entry, no priority for new review',
        6: 'semi old entry, medium priority for new review',
        9: 'old entry, high priority for new review',
        12: 'very old entry, highest priority for new review',
        15: 'very old entry, highest priority for new review',
      },
    };
  },
};
