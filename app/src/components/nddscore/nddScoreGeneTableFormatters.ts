// Pure cell formatters and badge-variant helpers for the NDDScore gene
// predictions table. Extracted verbatim from NddScoreGeneTable.vue to keep the
// component a thinner shell. Behavior is unchanged — these stay model-derived
// prediction-layer presentation helpers, separate from curated SysNDD evidence.

import type { ColorVariant } from 'bootstrap-vue-next';

export function displayValue(value: unknown): string {
  if (value == null || value === '') {
    return 'NA';
  }
  return String(value);
}

export function numericValue(value: unknown): number | null {
  const numberValue = typeof value === 'number' ? value : Number(value);
  return Number.isFinite(numberValue) ? numberValue : null;
}

export function formatDecimal(value: unknown, digits: number): string {
  const numberValue = numericValue(value);
  return numberValue == null ? 'NA' : numberValue.toFixed(digits);
}

export function formatPercentile(value: unknown): string {
  const numberValue = numericValue(value);
  return numberValue == null ? 'NA' : `${numberValue.toFixed(1)}%`;
}

export function riskVariant(value: unknown): ColorVariant {
  switch (String(value).toLowerCase()) {
    case 'very high':
      return 'danger';
    case 'high':
      return 'warning';
    case 'moderate':
      return 'info';
    default:
      return 'light';
  }
}

export function confidenceVariant(value: unknown): ColorVariant {
  switch (String(value).toLowerCase()) {
    case 'high':
      return 'success';
    case 'medium':
    case 'moderate':
      return 'info';
    default:
      return 'light';
  }
}

export function isKnownGene(value: unknown): boolean {
  return value === true || value === 1 || value === '1' || value === 'true';
}

export function parseHpoPredictions(value: unknown): Array<Record<string, unknown>> {
  if (Array.isArray(value)) {
    return value.filter((entry): entry is Record<string, unknown> => Boolean(entry));
  }

  if (typeof value !== 'string' || value.length === 0) {
    return [];
  }

  try {
    const parsed = JSON.parse(value);
    return Array.isArray(parsed)
      ? parsed.filter((entry): entry is Record<string, unknown> => Boolean(entry))
      : [];
  } catch {
    return [];
  }
}

export function topHpoLabel(value: unknown, count: unknown): string {
  const predictions = parseHpoPredictions(value);
  const first = predictions[0];
  const label = first?.phenotype_name ?? first?.term_name ?? first?.phenotype_id ?? first?.hpo_id;
  const totalPredicted = numericValue(count);

  if (label) {
    return totalPredicted && totalPredicted > 1
      ? `${String(label)} +${totalPredicted - 1}`
      : String(label);
  }

  return totalPredicted ? String(totalPredicted) : 'NA';
}

export function topHpoTooltip(value: unknown): string {
  const predictions = parseHpoPredictions(value);
  if (!predictions.length) {
    return 'No predicted HPO terms available.';
  }

  return predictions
    .map((entry) => {
      const label = entry.phenotype_name ?? entry.term_name ?? entry.phenotype_id ?? entry.hpo_id;
      const probability = numericValue(entry.probability ?? entry.score);
      return probability == null
        ? String(label)
        : `${String(label)} (${formatDecimal(probability, 3)})`;
    })
    .join('; ');
}
