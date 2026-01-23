// useColorAndSymbols.spec.ts
/**
 * Tests for useColorAndSymbols composable
 *
 * Pattern: Stateless composable testing
 * This composable returns constant mappings with no reactive state or lifecycle hooks.
 * Can be tested directly without Vue context or withSetup helper.
 *
 * Key learning:
 * - Stateless composables return plain objects (not refs/reactive)
 * - Test directly by calling the composable and checking returned values
 * - No cleanup needed since there's no Vue app context
 */

import { describe, it, expect } from 'vitest';
import useColorAndSymbols from './useColorAndSymbols';

describe('useColorAndSymbols', () => {
  describe('stoplights_style', () => {
    it('maps numeric category to Bootstrap variant', () => {
      const { stoplights_style } = useColorAndSymbols();

      expect(stoplights_style[1]).toBe('success');
      expect(stoplights_style[2]).toBe('primary');
      expect(stoplights_style[3]).toBe('warning');
      expect(stoplights_style[4]).toBe('danger');
    });

    it('maps string category to Bootstrap variant', () => {
      const { stoplights_style } = useColorAndSymbols();

      expect(stoplights_style['Definitive']).toBe('success');
      expect(stoplights_style['Moderate']).toBe('primary');
      expect(stoplights_style['Limited']).toBe('warning');
      expect(stoplights_style['Refuted']).toBe('danger');
      expect(stoplights_style['not applicable']).toBe('secondary');
    });
  });

  describe('saved_style', () => {
    it('maps saved status to Bootstrap variant', () => {
      const { saved_style } = useColorAndSymbols();

      expect(saved_style[0]).toBe('secondary');
      expect(saved_style[1]).toBe('info');
    });
  });

  describe('review_style', () => {
    it('maps review status to Bootstrap variant', () => {
      const { review_style } = useColorAndSymbols();

      expect(review_style[0]).toBe('light');
      expect(review_style[1]).toBe('dark');
    });
  });

  describe('ndd_icon', () => {
    it('provides correct icons for NDD status', () => {
      const { ndd_icon } = useColorAndSymbols();

      expect(ndd_icon['Yes']).toBe('check');
      expect(ndd_icon['No']).toBe('x');
    });
  });

  describe('ndd_icon_style', () => {
    it('provides correct styles for NDD icon status', () => {
      const { ndd_icon_style } = useColorAndSymbols();

      expect(ndd_icon_style['Yes']).toBe('success');
      expect(ndd_icon_style['No']).toBe('warning');
    });
  });

  describe('problematic_style', () => {
    it('maps problematic status to Bootstrap variant', () => {
      const { problematic_style } = useColorAndSymbols();

      expect(problematic_style[0]).toBe('success');
      expect(problematic_style[1]).toBe('danger');
    });
  });

  describe('problematic_symbol', () => {
    it('provides correct symbols for problematic status', () => {
      const { problematic_symbol } = useColorAndSymbols();

      expect(problematic_symbol[0]).toBe('check-square');
      expect(problematic_symbol[1]).toBe('question-square');
    });
  });

  describe('user_style', () => {
    it('maps user roles to Bootstrap variants', () => {
      const { user_style } = useColorAndSymbols();

      expect(user_style['Viewer']).toBe('secondary');
      expect(user_style['Reviewer']).toBe('primary');
      expect(user_style['Curator']).toBe('dark');
      expect(user_style['Administrator']).toBe('danger');
    });
  });

  describe('user_icon', () => {
    it('provides correct icons for user roles', () => {
      const { user_icon } = useColorAndSymbols();

      expect(user_icon['Viewer']).toBe('person-circle');
      expect(user_icon['Reviewer']).toBe('emoji-smile');
      expect(user_icon['Curator']).toBe('emoji-heart-eyes');
      expect(user_icon['Administrator']).toBe('emoji-sunglasses');
    });
  });

  describe('modifier_style', () => {
    it('maps modifier types to Bootstrap variants', () => {
      const { modifier_style } = useColorAndSymbols();

      expect(modifier_style[1]).toBe('primary');
      expect(modifier_style[2]).toBe('warning');
      expect(modifier_style[3]).toBe('secondary');
      expect(modifier_style[4]).toBe('light');
      expect(modifier_style[5]).toBe('danger');
    });
  });

  describe('data_age_style', () => {
    it('maps data age to Bootstrap variants', () => {
      const { data_age_style } = useColorAndSymbols();

      expect(data_age_style[0]).toBe('success');
      expect(data_age_style[3]).toBe('success');
      expect(data_age_style[6]).toBe('warning');
      expect(data_age_style[9]).toBe('danger');
      expect(data_age_style[12]).toBe('danger');
    });
  });

  describe('category_style', () => {
    it('provides color mappings for all categories', () => {
      const { category_style } = useColorAndSymbols();

      // Verify key categories have color mappings
      expect(category_style['HPO']).toBe('red');
      expect(category_style['KEGG']).toBe('yellow');
      expect(category_style['PMID']).toBe('darkgoldenrod');
      expect(category_style['InterPro']).toBe('orange');
      expect(category_style['WikiPathways']).toBe('lightskyblue');
    });
  });

  describe('publication_style', () => {
    it('maps publication types to Bootstrap variants', () => {
      const { publication_style } = useColorAndSymbols();

      expect(publication_style['additional_references']).toBe('info');
      expect(publication_style['gene_review']).toBe('primary');
    });
  });

  describe('yn_icon', () => {
    it('provides correct icons for yes/no status', () => {
      const { yn_icon } = useColorAndSymbols();

      expect(yn_icon['yes']).toBe('check');
      expect(yn_icon['no']).toBe('x');
    });
  });

  describe('yn_icon_style', () => {
    it('provides correct styles for yes/no icon status', () => {
      const { yn_icon_style } = useColorAndSymbols();

      expect(yn_icon_style['yes']).toBe('success');
      expect(yn_icon_style['no']).toBe('warning');
    });
  });
});
