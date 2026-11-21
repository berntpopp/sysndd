import { describe, expect, it } from 'vitest';
import { CLUSTER_COLORS, getClusterTextColor } from '../clusterColors';

function luminance(hex: string): number {
  const [r, g, b] = [1, 3, 5].map((i) => {
    const c = parseInt(hex.slice(i, i + 2), 16) / 255;
    return c <= 0.03928 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4;
  });
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

function contrast(a: string, b: string): number {
  const [hi, lo] = [luminance(a), luminance(b)].sort((x, y) => y - x);
  return (hi + 0.05) / (lo + 0.05);
}

describe('getClusterTextColor', () => {
  it('gives every cluster badge text at least 4.5:1 against its background', () => {
    CLUSTER_COLORS.forEach((_bg, i) => {
      const bg = CLUSTER_COLORS[i];
      expect(contrast(getClusterTextColor(i), bg)).toBeGreaterThanOrEqual(4.5);
    });
  });

  it('uses dark text on the orange cluster 1 badge (white was 2.5:1)', () => {
    expect(getClusterTextColor(1)).toBe('#000000');
    expect(getClusterTextColor('1.2')).toBe('#000000');
  });
});
