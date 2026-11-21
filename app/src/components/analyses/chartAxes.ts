// Shared axis conventions for the D3 analysis charts: integer ticks on count
// scales, readable tick text, and axis titles. The charts keep a min-width equal
// to their viewBox width (scrolling inside the card on phones), so SVG units
// render at >= 1:1 and CHART_TICK_FONT_SIZE is the on-screen floor.
import * as d3 from 'd3';

/** Tick and axis-title text size in SVG units (d3's default is 10). */
export const CHART_TICK_FONT_SIZE = 12;

/** Integer-only, thousands-separated ticks for a count scale (no "0.5" on small counts). */
export function countAxis(
  axis: d3.Axis<d3.NumberValue>,
  scale: d3.ScaleLinear<number, number>,
  count = 6
): d3.Axis<d3.NumberValue> {
  return axis.tickValues(scale.ticks(count).filter(Number.isInteger)).tickFormat(d3.format(',d'));
}

/** Raise an axis group's tick text from d3's 10 px default. Call after `.call(axis)`. */
export function styleAxisText<E extends d3.BaseType, D, P extends d3.BaseType, PD>(
  g: d3.Selection<E, D, P, PD>
): d3.Selection<E, D, P, PD> {
  return g.attr('font-size', CHART_TICK_FONT_SIZE);
}

/** Append a centred axis title; `rotate` turns it for a vertical (y) axis. */
export function addAxisTitle<E extends d3.BaseType, D, P extends d3.BaseType, PD>(
  parent: d3.Selection<E, D, P, PD>,
  text: string,
  { x, y, rotate = false }: { x: number; y: number; rotate?: boolean }
): void {
  parent
    .append('text')
    .attr('class', 'chart-axis-title')
    .attr('x', x)
    .attr('y', y)
    .attr('transform', rotate ? 'rotate(-90)' : null)
    .attr('text-anchor', 'middle')
    .attr('font-size', CHART_TICK_FONT_SIZE)
    .attr('fill', '#495057')
    .text(text);
}
