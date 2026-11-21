import { mount } from '@vue/test-utils';
import { describe, expect, it } from 'vitest';
import DiseaseBadge from './DiseaseBadge.vue';
import InheritanceBadge from './InheritanceBadge.vue';
import geneBadgeSource from './GeneBadge.vue?raw';

const global = { directives: { bTooltip: {} }, stubs: { BLink: { template: '<a><slot /></a>' } } };

describe('InheritanceBadge', () => {
  it.each([
    ['Autosomal dominant inheritance', 'AD'],
    ['X-linked recessive inheritance', 'XLR'],
    ['X-linked other inheritance', 'XL'],
    ['Autosomal dominant inheritance; Autosomal recessive inheritance', 'AD/AR'],
    ['Autosomal dominant inheritance; Somatic mutation', 'AD/Som'],
  ])('shows %s as %s (S-31: one short-code table)', (fullName, code) => {
    const wrapper = mount(InheritanceBadge, { props: { fullName }, global });
    expect(wrapper.get('.inheritance-badge__abbrev').text()).toBe(code);
  });
});

describe('DiseaseBadge', () => {
  const name = 'Methylmalonic aciduria and homocystinuria, cblC type';

  it('keeps the full name in the DOM so the visible text is the accessible name', () => {
    const wrapper = mount(DiseaseBadge, {
      props: { name, maxLength: 35, linkTo: '/Ontology/OMIM:277400' },
      global,
    });
    const badge = wrapper.get('.disease-badge');
    // axe label-content-name-mismatch: an aria-label that differs from the (truncated)
    // visible text, on a span that is not itself the link (CUR-13 / S-26 / PUB-21)
    expect(badge.attributes('aria-label')).toBeUndefined();
    expect(badge.attributes('role')).toBeUndefined();
    expect(wrapper.get('.disease-badge__name').text()).toBe(name);
    // The visual truncation is CSS, capped at the requested length.
    expect(wrapper.get('.disease-badge__name').attributes('style')).toContain('max-width: 35ch');
  });
});

describe('GeneBadge contrast', () => {
  const srgb = (hex: string) =>
    [0, 2, 4]
      .map((i) => parseInt(hex.slice(1 + i, 3 + i), 16) / 255)
      .map((c) => (c <= 0.03928 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4));
  const luminance = (hex: string) => {
    const [r, g, b] = srgb(hex);
    return 0.2126 * r + 0.7152 * g + 0.0722 * b;
  };

  it('keeps white text >= 4.5:1 on every gradient stop (PUB-19 / S-25 / CUR-32)', () => {
    const gradient = geneBadgeSource.match(
      /\.gene-badge \{[^}]*background: linear-gradient\(([^)]*)\)/
    );
    expect(gradient).not.toBeNull();
    const stops = gradient![1].match(/#[0-9a-f]{6}/gi) ?? [];
    expect(stops.length).toBeGreaterThan(0);
    for (const stop of stops) {
      expect(1.05 / (luminance(stop) + 0.05)).toBeGreaterThanOrEqual(4.5);
    }
  });
});
