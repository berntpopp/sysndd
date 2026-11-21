import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import * as d3 from 'd3';
import { describe, expect, it } from 'vitest';
import { addAxisTitle, countAxis, CHART_TICK_FONT_SIZE, styleAxisText } from './chartAxes';

describe('chartAxes', () => {
  it('gives count scales integer ticks only, even for small maxima', () => {
    const y = d3.scaleLinear().domain([0, 3]).range([100, 0]);
    expect(y.ticks(6)).toContain(0.5); // d3's default would print 0.5 entities
    const axis = countAxis(d3.axisLeft(y), y);
    expect(axis.tickValues()).toEqual([0, 1, 2, 3]);
    expect(axis.tickFormat()!(4200, 0)).toBe('4,200');
  });

  it('renders tick text and axis titles at a readable size', () => {
    const svg = d3.select(document.body).append('svg');
    const g = svg.append('g').call(d3.axisLeft(d3.scaleLinear().domain([0, 10])));
    styleAxisText(g);
    expect(g.attr('font-size')).toBe(String(CHART_TICK_FONT_SIZE));
    expect(CHART_TICK_FONT_SIZE).toBeGreaterThanOrEqual(11);

    addAxisTitle(svg, 'Entities', { x: -100, y: -40, rotate: true });
    const title = svg.select('text.chart-axis-title');
    expect(title.text()).toBe('Entities');
    expect(title.attr('transform')).toBe('rotate(-90)');
  });

  it.each([
    ['AnalysesTimePlot.vue', true],
    ['AnalysesPhenotypeCounts.vue', true],
    ['AnalysesVariantCounts.vue', true],
    ['PublicationsNDDStats.vue', true],
    ['PublicationsNDDTimePlot.vue', true],
    ['PubtatorNDDStats.vue', true],
    ['AnalysesPhenotypeCorrelogram.vue', false],
    ['AnalysesVariantCorrelogram.vue', false],
  ])('%s scrolls (keyboard-reachable) instead of shrinking below 1:1', (file, counts) => {
    const source = readFileSync(resolve(process.cwd(), 'src/components/analyses', file), 'utf8');
    expect(source).toMatch(/class="position-relative chart-scroll"\s+tabindex="0"\s+role="region"/);
    expect(source).toMatch(/min-width/);
    if (counts) expect(source).toContain('countAxis(d3.axisLeft(y), y)');
  });
});
