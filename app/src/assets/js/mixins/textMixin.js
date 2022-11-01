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
      empty_table_text: {
        false: 'Apply for a new batch of entities.',
        true: 'Nothing to review.',
      },
    };
  },
};
