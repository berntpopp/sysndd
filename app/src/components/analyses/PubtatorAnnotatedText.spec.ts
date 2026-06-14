import { mount } from '@vue/test-utils';
import { describe, expect, it } from 'vitest';
import PubtatorAnnotatedText from './PubtatorAnnotatedText.vue';

const TEXT = '@GENE_2904 @GENE_GRIN2B @@@GRIN2B@@@ is linked to <m>NDD</m>.';

describe('PubtatorAnnotatedText', () => {
  it('renders entity-classed segments and the legend by default', () => {
    const wrapper = mount(PubtatorAnnotatedText, { props: { text: TEXT } });

    expect(wrapper.find('.annotated-text').exists()).toBe(true);
    // Gene entity highlighted.
    const gene = wrapper.find('.pubtator-gene');
    expect(gene.exists()).toBe(true);
    expect(gene.text()).toBe('GRIN2B');
    // Search-match highlighted.
    expect(wrapper.find('.pubtator-match').text()).toBe('NDD');
    // Legend present.
    expect(wrapper.find('.pubtator-legend').exists()).toBe(true);
    // Label present by default.
    expect(wrapper.text()).toContain('Annotated Text:');
  });

  it('hides the legend and label when disabled', () => {
    const wrapper = mount(PubtatorAnnotatedText, {
      props: { text: TEXT, showLegend: false, showLabel: false },
    });
    expect(wrapper.find('.pubtator-legend').exists()).toBe(false);
    expect(wrapper.text()).not.toContain('Annotated Text:');
    // Content still renders.
    expect(wrapper.find('.pubtator-gene').exists()).toBe(true);
  });

  it('renders nothing when text is empty', () => {
    const wrapper = mount(PubtatorAnnotatedText, { props: { text: '' } });
    expect(wrapper.find('.annotated-text-section').exists()).toBe(false);
  });

  it('applies the optional section class', () => {
    const wrapper = mount(PubtatorAnnotatedText, { props: { text: TEXT, sectionClass: 'mt-3' } });
    expect(wrapper.find('.annotated-text-section').classes()).toContain('mt-3');
  });
});
