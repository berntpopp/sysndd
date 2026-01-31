// useText.spec.ts
/**
 * Tests for useText composable
 *
 * Pattern: Stateless composable testing
 * Returns constant text mappings, no reactive state or lifecycle hooks.
 * Can be tested directly without Vue context.
 *
 * Key learning:
 * - Same pattern as useColorAndSymbols - direct testing
 * - Good for composables that provide lookup tables / constants
 */

import { describe, it, expect } from 'vitest';
import useText from './useText';

describe('useText', () => {
  describe('modifier_text', () => {
    it('maps modifier IDs to text labels', () => {
      const { modifier_text } = useText();

      expect(modifier_text[1]).toBe('present');
      expect(modifier_text[2]).toBe('uncertain');
      expect(modifier_text[3]).toBe('variable');
      expect(modifier_text[4]).toBe('rare');
      expect(modifier_text[5]).toBe('absent');
    });

    it('provides all 5 modifier text mappings', () => {
      const { modifier_text } = useText();

      expect(Object.keys(modifier_text)).toHaveLength(5);
    });
  });

  describe('inheritance_short_text', () => {
    it('abbreviates inheritance types correctly', () => {
      const { inheritance_short_text } = useText();

      expect(inheritance_short_text['Autosomal dominant inheritance']).toBe('AD');
      expect(inheritance_short_text['Autosomal recessive inheritance']).toBe('AR');
      expect(inheritance_short_text['X-linked recessive inheritance']).toBe('XR');
      expect(inheritance_short_text['X-linked dominant inheritance']).toBe('XD');
      expect(inheritance_short_text['X-linked other inheritance']).toBe('Xo');
      expect(inheritance_short_text['Mitochondrial inheritance']).toBe('Mit');
      expect(inheritance_short_text['Somatic mutation']).toBe('Som');
    });
  });

  describe('inheritance_overview_text', () => {
    it('provides overview abbreviations for inheritance categories', () => {
      const { inheritance_overview_text } = useText();

      expect(inheritance_overview_text['Autosomal dominant']).toBe('AD');
      expect(inheritance_overview_text['Autosomal recessive']).toBe('AR');
      expect(inheritance_overview_text['X-linked']).toBe('X');
      expect(inheritance_overview_text['Other']).toBe('M/S');
    });
  });

  describe('inheritance_link', () => {
    it('maps inheritance categories to detailed types', () => {
      const { inheritance_link } = useText();

      expect(inheritance_link['Autosomal dominant']).toEqual(['Autosomal dominant inheritance']);
      expect(inheritance_link['Autosomal recessive']).toEqual(['Autosomal recessive inheritance']);
      expect(inheritance_link['X-linked']).toContain('X-linked recessive inheritance');
      expect(inheritance_link['X-linked']).toContain('X-linked dominant inheritance');
      expect(inheritance_link['Other']).toContain('Mitochondrial inheritance');
      expect(inheritance_link['Other']).toContain('Somatic mutation');
    });
  });

  describe('data_age_text', () => {
    it('provides review priority text based on data age', () => {
      const { data_age_text } = useText();

      expect(data_age_text[0]).toContain('no priority');
      expect(data_age_text[3]).toContain('no priority');
      expect(data_age_text[6]).toContain('medium priority');
      expect(data_age_text[9]).toContain('high priority');
      expect(data_age_text[12]).toContain('highest priority');
    });

    it('describes entry age appropriately', () => {
      const { data_age_text } = useText();

      expect(data_age_text[0]).toContain('new entry');
      expect(data_age_text[6]).toContain('semi old');
      expect(data_age_text[12]).toContain('very old');
    });
  });

  describe('ndd_icon_text', () => {
    it('provides descriptive text for NDD status', () => {
      const { ndd_icon_text } = useText();

      expect(ndd_icon_text['Yes']).toContain('associated with NDD');
      expect(ndd_icon_text['No']).toContain('NOT associated with NDD');
    });
  });

  describe('publication_hover_text', () => {
    it('provides hover text for publication types', () => {
      const { publication_hover_text } = useText();

      expect(publication_hover_text['additional_references']).toContain('Original Article');
      expect(publication_hover_text['gene_review']).toContain('GeneReview');
    });
  });

  describe('empty_table_text', () => {
    it('provides text for empty table states', () => {
      const { empty_table_text } = useText();

      expect(empty_table_text['false']).toContain('Apply for a new batch');
      expect(empty_table_text['true']).toContain('Nothing to review');
    });
  });
});
