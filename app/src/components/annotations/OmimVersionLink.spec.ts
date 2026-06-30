import { describe, it, expect } from 'vitest';
import { mount } from '@vue/test-utils';
import OmimVersionLink from './OmimVersionLink.vue';

function mountWith(version: unknown) {
  return mount(OmimVersionLink, { props: { version } });
}

describe('OmimVersionLink', () => {
  it('links a versioned OMIM id to the suffix-stripped entry, keeping the full id as label', () => {
    const wrapper = mountWith('OMIM:301058_1');
    const link = wrapper.get('a');
    expect(link.attributes('href')).toBe('https://www.omim.org/entry/301058');
    expect(link.attributes('target')).toBe('_blank');
    expect(link.attributes('rel')).toBe('noopener noreferrer');
    // Full version id (incl. _1) stays visible so curators can tell versions apart.
    expect(link.text()).toBe('OMIM:301058_1');
  });

  it('links a bare OMIM id with no version suffix', () => {
    const wrapper = mountWith('OMIM:169500');
    const link = wrapper.get('a');
    expect(link.attributes('href')).toBe('https://www.omim.org/entry/169500');
    expect(link.text()).toBe('OMIM:169500');
  });

  it('degrades a non-OMIM / unrecognised prefix to plain text (no link)', () => {
    const wrapper = mountWith('UMLS:C1234567');
    expect(wrapper.find('a').exists()).toBe(false);
    expect(wrapper.text()).toBe('UMLS:C1234567');
  });

  it('renders a dash for an empty/nullish version', () => {
    expect(mountWith('').text()).toBe('—');
    expect(mountWith(null).text()).toBe('—');
    expect(mountWith(undefined).text()).toBe('—');
  });
});
