// composables/useText.js

/**
 * Composable for text and label constants used across the application
 *
 * Provides centralized collection of various text labels and constants used in Vue components.
 * These constants primarily consist of text representations for various statuses and categories,
 * enhancing readability and maintainability of the codebase.
 *
 * @returns {Object} Object containing all text label mappings
 */
export default function useText() {
  return {
    /**
     * Text labels for NDD (Neurodevelopmental Disorder) status.
     */
    ndd_icon_text: {
      No: 'NOT associated with NDD',
      Yes: 'associated with NDD',
    },
    /**
     * Hover text for different types of publication references.
     */
    publication_hover_text: {
      additional_references: 'Original Article ',
      gene_review: 'GeneReview Article',
    },
    /**
     * Text labels for different modifiers.
     */
    modifier_text: {
      1: 'present',
      2: 'uncertain',
      3: 'variable',
      4: 'rare',
      5: 'absent',
    },
    /**
     * Short text labels for different inheritance types.
     */
    inheritance_short_text: {
      'Autosomal dominant inheritance': 'AD',
      'Autosomal recessive inheritance': 'AR',
      'X-linked other inheritance': 'Xo',
      'X-linked recessive inheritance': 'XR',
      'X-linked dominant inheritance': 'XD',
      'Mitochondrial inheritance': 'Mit',
      'Somatic mutation': 'Som',
    },
    /**
     * Overview text labels for different inheritance categories.
     */
    inheritance_overview_text: {
      'Autosomal dominant': 'AD',
      'Autosomal recessive': 'AR',
      'X-linked': 'X',
      Other: 'M/S',
    },
    /**
     * Mapping of inheritance categories to detailed inheritance types.
     */
    inheritance_link: {
      'Autosomal dominant': ['Autosomal dominant inheritance'],
      'Autosomal recessive': ['Autosomal recessive inheritance'],
      'X-linked': ['X-linked other inheritance', 'X-linked recessive inheritance', 'X-linked dominant inheritance'],
      Other: ['Mitochondrial inheritance', 'Somatic mutation'],
    },
    /**
     * Text for empty table states based on a boolean condition.
     */
    empty_table_text: {
      false: 'Apply for a new batch of entities.',
      true: 'Nothing to review.',
    },
    /**
     * Text labels indicating the age of data and the priority for review.
     */
    data_age_text: {
      0: 'new entry, no priority for new review',
      3: 'relatively new entry, no priority for new review',
      6: 'semi old entry, medium priority for new review',
      9: 'old entry, high priority for new review',
      12: 'very old entry, highest priority for new review',
      15: 'very old entry, highest priority for new review',
    },
  };
}
