# Cluster Validation Card Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an inline "Cluster validation" card to the functional and phenotype cluster analysis pages that surfaces the already-served partition metrics (weighted modularity / data-driven k + mean silhouette) and per-cluster bootstrap-Jaccard stability, plus the DB release label.

**Architecture:** One shared, algorithm-aware presentational component (`ClusterValidationCard.vue`) fed by a pure, unit-tested helper module (`clusterValidation.ts`). Both host views (`AnalyseGeneClusters.vue`, `AnalysesPhenotypeClusters.vue`) already fetch the response; they capture `meta.snapshot` + the raw cluster rows and pass them to the card. No API/DB change.

**Tech Stack:** Vue 3 + TypeScript, BootstrapVueNext, Vitest + `@vue/test-utils`, Vite. Repo card idiom: `app/src/components/nddscore/NddScoreModelCard.vue` (BEM classes, `scalar*` unwrap helpers, design tokens, WCAG-annotated contrast).

## Global Constraints

- Frontend-only. No changes under `api/`, `db/`, or endpoints. The data is already in the payload.
- Scalar fields arrive as Plumber scalar-arrays (e.g. `[0.8525]`, `["leiden"]`); every value read from `validation`/cluster rows/`db_release` MUST be unwrapped before use.
- Stability bands are the Hennig bands from `api/functions/analysis-cluster-validation.R`: `>=0.85` highly stable, `>=0.75` stable, `0.60–0.75` doubtful, `0.50–0.60` weak, `<0.50` dissolved; missing/`NA` → `na`.
- Never color-only: every stability signal shows a text band label + numeric value alongside color (WCAG). Follow `documentation/10-visual-design-guide.md` + the `sysndd-visual-design` skill; reuse design tokens (`--neutral-*`, `--medical-*`, `--radius-*`, `--font-family-mono`) as `NddScoreModelCard.vue` does.
- No new axios calls in views/components; the card is props-only (no fetch). Types live in `app/src/api/analysis.ts`.
- Node/toolchain per `app/.nvmrc`. Gates: `cd app && npm run type-check`, `npm run lint-app` (repo target: `make lint-app`), `npm run test:unit`.
- Keep files focused; `ClusterValidationCard.vue` stays a single-responsibility presentational component. Do not enlarge the two host views beyond the small capture + mount edits.

---

### Task 1: API types for the validation surface

**Files:**
- Modify: `app/src/api/analysis.ts` (add `ClusterValidation`; extend `AnalysisSnapshotMeta`, `FunctionalCluster`, `PhenotypeCluster`)
- Test: `app/src/api/analysis.spec.ts` (must still pass; no new runtime test — this is a types-only change verified by `type-check`)

**Interfaces:**
- Produces: `ClusterValidation` interface; `AnalysisSnapshotMeta.validation?`, `.validation_hash?`, `.db_release?`; optional per-cluster fields on `FunctionalCluster`/`PhenotypeCluster`. Consumed by Tasks 2–4.

- [ ] **Step 1: Add the `ClusterValidation` interface** (insert after `AnalysisSnapshotMeta`, before `ClusteringMeta`, around line 103)

```ts
/**
 * Partition-level cluster-validation metrics persisted on the snapshot manifest
 * (#457–459). The functional (Leiden) and phenotype (MCA/HCPC) presets populate
 * different subsets; all fields are optional. Values arrive as Plumber
 * scalar-arrays, so read them through the unwrap helpers in
 * `components/analyses/clusterValidation.ts`.
 */
export interface ClusterValidation {
  validation_schema_version?: string | string[];
  algorithm?: string | string[];
  // functional (leiden)
  weighted?: boolean | boolean[];
  modularity?: number | number[];
  modularity_scope?: string | string[];
  resolution_parameter?: number | number[];
  n_iterations?: number | number[];
  n_clusters?: number | number[];
  n_dropped_below_min_size?: number | number[];
  // phenotype (mca_hcpc)
  k?: number | number[];
  k_selection_metric?: string | string[];
  mean_silhouette?: number | number[];
  silhouette_status?: string | string[];
  n_entities_assigned?: number | number[];
  n_entities_dropped?: number | number[];
  // shared
  partition_scope?: string | string[];
  resampling_scheme?: string | string[];
  subsample_fraction?: number | number[];
  n_resamples?: number | number[];
  n_resamples_effective?: number | number[];
  [key: string]: unknown;
}
```

- [ ] **Step 2: Extend `AnalysisSnapshotMeta`** — add three fields before its closing brace (currently ends at line 103)

```ts
export interface AnalysisSnapshotMeta {
  snapshot_id?: number;
  analysis_type?: string;
  parameter_hash?: string;
  schema_version?: string;
  data_class?: string;
  generated_at?: string;
  stale_after?: string;
  source_data_version?: string;
  // Cluster-validation surface (#457–459). `validation` is an empty array/object
  // for snapshots built before validation existed; the card hides itself then.
  validation?: ClusterValidation | unknown[];
  validation_hash?: string | string[];
  db_release?: { version?: string | string[]; commit?: string | string[] };
}
```

- [ ] **Step 3: Add optional per-cluster stability fields** to `FunctionalCluster` (they coexist with the existing index signature; explicit for discoverability)

```ts
export interface FunctionalCluster {
  cluster: string | number;
  hash_filter: string;
  identifiers?: unknown;
  term_enrichment?: unknown;
  // Per-cluster stability joined in by the snapshot builder (scalar-or-array).
  cluster_size?: number | number[];
  jaccard_mean?: number | number[];
  jaccard_n_resamples?: number | number[];
  [key: string]: unknown;
}
```

- [ ] **Step 4: Add optional per-cluster stability fields** to `PhenotypeCluster`

```ts
export interface PhenotypeCluster {
  cluster: string | number;
  identifiers: Array<{ entity_id: number; hgnc_id: string; symbol: string }>;
  cluster_size?: number | number[];
  jaccard_mean?: number | number[];
  jaccard_n_resamples?: number | number[];
  silhouette_mean?: number | number[];
  [key: string]: unknown;
}
```

- [ ] **Step 5: Verify types compile and existing API tests pass**

Run: `cd app && npm run type-check && npx vitest run src/api/analysis.spec.ts`
Expected: type-check clean; `analysis.spec.ts` PASS (unchanged behavior).

- [ ] **Step 6: Commit**

```bash
git add app/src/api/analysis.ts
git commit -m "feat(app): type the cluster-validation snapshot surface (validation, validation_hash, db_release, per-cluster stability)"
```

---

### Task 2: `clusterValidation.ts` pure helpers (TDD)

**Files:**
- Create: `app/src/components/analyses/clusterValidation.ts`
- Test: `app/src/components/analyses/clusterValidation.spec.ts`

**Interfaces:**
- Consumes: `ClusterValidation`, `AnalysisSnapshotMeta` from `@/api/analysis` (Task 1).
- Produces: `toScalar`, `toScalarNumber`, `toScalarString`, `jaccardBand`, `summarizeValidation`, `perClusterStability`, `hasValidation`, and types `ClusterAnalysisType`, `StabilityBand`, `StabilityBandKey`, `ValidationMetric`, `ClusterStabilityRow`. Consumed by Task 3.

- [ ] **Step 1: Write the failing spec** — `app/src/components/analyses/clusterValidation.spec.ts`

```ts
import { describe, it, expect } from 'vitest';
import {
  toScalarNumber,
  toScalarString,
  jaccardBand,
  summarizeValidation,
  perClusterStability,
  hasValidation,
} from './clusterValidation';

describe('scalar unwrapping', () => {
  it('unwraps Plumber scalar-arrays and passes through plain scalars', () => {
    expect(toScalarNumber([0.8525])).toBe(0.8525);
    expect(toScalarNumber(3)).toBe(3);
    expect(toScalarNumber(['x'])).toBeNull();
    expect(toScalarNumber(undefined)).toBeNull();
    expect(toScalarString(['leiden'])).toBe('leiden');
    expect(toScalarString('mca_hcpc')).toBe('mca_hcpc');
    expect(toScalarString([])).toBeNull();
  });
});

describe('jaccardBand — Hennig thresholds', () => {
  it('classifies at each boundary', () => {
    expect(jaccardBand(0.9).key).toBe('highly_stable');
    expect(jaccardBand(0.85).key).toBe('highly_stable');
    expect(jaccardBand(0.8).key).toBe('stable');
    expect(jaccardBand(0.75).key).toBe('stable');
    expect(jaccardBand(0.7).key).toBe('doubtful');
    expect(jaccardBand(0.6).key).toBe('doubtful');
    expect(jaccardBand(0.55).key).toBe('weak');
    expect(jaccardBand(0.5).key).toBe('weak');
    expect(jaccardBand(0.41).key).toBe('dissolved');
    expect(jaccardBand(null).key).toBe('na');
    expect(jaccardBand(Number.NaN).key).toBe('na');
  });
  it('gives every band a human label', () => {
    expect(jaccardBand(0.85).label).toBe('highly stable');
    expect(jaccardBand(0.41).label).toBe('dissolved');
    expect(jaccardBand(null).label).toBe('n/a');
  });
});

describe('summarizeValidation', () => {
  it('functional headline uses weighted modularity', () => {
    const rows = summarizeValidation('functional_clusters', {
      algorithm: ['leiden'],
      modularity: [0.5355],
      n_clusters: [9],
      n_dropped_below_min_size: [7],
      n_resamples_effective: [100],
    });
    const byLabel = Object.fromEntries(rows.map((r) => [r.label, r.value]));
    expect(byLabel['Modularity']).toBe('0.536');
    expect(byLabel['Clusters']).toBe('9');
    expect(byLabel['Dropped (< min size)']).toBe('7');
    expect(byLabel['Resamples']).toBe('100');
  });
  it('phenotype headline uses mean silhouette + data-driven k', () => {
    const rows = summarizeValidation('phenotype_clusters', {
      algorithm: ['mca_hcpc'],
      mean_silhouette: [0.1944],
      silhouette_status: ['ok'],
      k: [3],
      n_entities_dropped: [0],
      n_resamples_effective: [100],
    });
    const byLabel = Object.fromEntries(rows.map((r) => [r.label, r.value]));
    expect(byLabel['Mean silhouette']).toBe('0.194');
    expect(byLabel['Clusters (k)']).toBe('3');
    expect(byLabel['Dropped entities']).toBe('0');
  });
  it('returns [] when validation is absent', () => {
    expect(summarizeValidation('functional_clusters', null)).toEqual([]);
  });
});

describe('perClusterStability', () => {
  it('maps + sorts by size desc and bands each cluster', () => {
    const rows = perClusterStability([
      { cluster: ['1'], cluster_size: [206], jaccard_mean: [0.686], jaccard_n_resamples: [100] },
      { cluster: ['2'], cluster_size: [1420], jaccard_mean: [0.705], jaccard_n_resamples: [100] },
      { cluster: ['3'], cluster_size: [306], jaccard_mean: [0.456], jaccard_n_resamples: [100], silhouette_mean: [0.362] },
    ]);
    expect(rows.map((r) => r.id)).toEqual(['2', '3', '1']); // size desc
    expect(rows[0].band.key).toBe('doubtful');
    expect(rows[1].band.key).toBe('dissolved');
    expect(rows[1].silhouette).toBe(0.362);
  });
  it('is empty for a non-array input', () => {
    expect(perClusterStability(undefined)).toEqual([]);
  });
});

describe('hasValidation', () => {
  it('is false for empty/absent validation and true for a populated block', () => {
    expect(hasValidation(null)).toBe(false);
    expect(hasValidation([] as unknown as never)).toBe(false);
    expect(hasValidation({} as never)).toBe(false);
    expect(hasValidation({ algorithm: ['leiden'], modularity: [0.5] })).toBe(true);
  });
});
```

- [ ] **Step 2: Run the spec to verify it fails**

Run: `cd app && npx vitest run src/components/analyses/clusterValidation.spec.ts`
Expected: FAIL — `Cannot find module './clusterValidation'`.

- [ ] **Step 3: Implement `app/src/components/analyses/clusterValidation.ts`**

```ts
// app/src/components/analyses/clusterValidation.ts
//
// Pure helpers for ClusterValidationCard: unwrap Plumber scalar-arrays, classify
// bootstrap-Jaccard stability into Hennig bands, and shape the partition summary +
// per-cluster stability rows. No Vue imports — unit-tested in isolation.

import type { ClusterValidation } from '@/api/analysis';

export type ClusterAnalysisType = 'functional_clusters' | 'phenotype_clusters';

export type StabilityBandKey =
  | 'highly_stable'
  | 'stable'
  | 'doubtful'
  | 'weak'
  | 'dissolved'
  | 'na';

export interface StabilityBand {
  key: StabilityBandKey;
  label: string;
}

export interface ValidationMetric {
  label: string;
  value: string;
  hint?: string;
}

export interface ClusterStabilityRow {
  id: string;
  size: number | null;
  jaccard: number | null;
  jaccardN: number | null;
  silhouette: number | null;
  band: StabilityBand;
}

export function toScalar(value: unknown): unknown {
  return Array.isArray(value) ? value[0] : value;
}

export function toScalarNumber(value: unknown): number | null {
  const v = toScalar(value);
  if (v == null || v === '') return null;
  const n = typeof v === 'number' ? v : Number(v);
  return Number.isFinite(n) ? n : null;
}

export function toScalarString(value: unknown): string | null {
  const v = toScalar(value);
  if (v == null) return null;
  const s = typeof v === 'string' ? v : String(v);
  return s.length > 0 ? s : null;
}

// Hennig clusterboot bands (api/functions/analysis-cluster-validation.R).
export function jaccardBand(value: number | null): StabilityBand {
  if (value == null || Number.isNaN(value)) return { key: 'na', label: 'n/a' };
  if (value >= 0.85) return { key: 'highly_stable', label: 'highly stable' };
  if (value >= 0.75) return { key: 'stable', label: 'stable' };
  if (value >= 0.6) return { key: 'doubtful', label: 'doubtful' };
  if (value >= 0.5) return { key: 'weak', label: 'weak' };
  return { key: 'dissolved', label: 'dissolved' };
}

function fmtDecimal(value: number | null, digits = 3): string {
  return value == null ? 'n/a' : value.toFixed(digits);
}

function fmtInt(value: number | null): string {
  return value == null ? 'n/a' : String(Math.trunc(value));
}

export function hasValidation(validation: ClusterValidation | unknown[] | null | undefined): boolean {
  if (!validation || Array.isArray(validation)) return false;
  return toScalarString((validation as ClusterValidation).algorithm) != null;
}

export function summarizeValidation(
  analysisType: ClusterAnalysisType,
  validation: ClusterValidation | unknown[] | null | undefined,
): ValidationMetric[] {
  if (!hasValidation(validation)) return [];
  const v = validation as ClusterValidation;
  const algorithm = toScalarString(v.algorithm);
  const resamples = { label: 'Resamples', value: fmtInt(toScalarNumber(v.n_resamples_effective)) };

  if (analysisType === 'phenotype_clusters' || algorithm === 'mca_hcpc') {
    const status = toScalarString(v.silhouette_status);
    return [
      { label: 'Mean silhouette', value: fmtDecimal(toScalarNumber(v.mean_silhouette)), hint: status ?? undefined },
      { label: 'Clusters (k)', value: fmtInt(toScalarNumber(v.k)), hint: 'data-driven' },
      { label: 'Dropped entities', value: fmtInt(toScalarNumber(v.n_entities_dropped)) },
      resamples,
    ];
  }
  return [
    { label: 'Modularity', value: fmtDecimal(toScalarNumber(v.modularity)), hint: 'weighted, full partition' },
    { label: 'Clusters', value: fmtInt(toScalarNumber(v.n_clusters)) },
    { label: 'Dropped (< min size)', value: fmtInt(toScalarNumber(v.n_dropped_below_min_size)) },
    resamples,
  ];
}

interface RawClusterRow {
  cluster?: unknown;
  cluster_size?: unknown;
  jaccard_mean?: unknown;
  jaccard_n_resamples?: unknown;
  silhouette_mean?: unknown;
  [key: string]: unknown;
}

export function perClusterStability(
  clusters: RawClusterRow[] | null | undefined,
): ClusterStabilityRow[] {
  if (!Array.isArray(clusters)) return [];
  return clusters
    .map((c) => {
      const jaccard = toScalarNumber(c.jaccard_mean);
      return {
        id: toScalarString(c.cluster) ?? '?',
        size: toScalarNumber(c.cluster_size),
        jaccard,
        jaccardN: toScalarNumber(c.jaccard_n_resamples),
        silhouette: toScalarNumber(c.silhouette_mean),
        band: jaccardBand(jaccard),
      };
    })
    .sort((a, b) => (b.size ?? 0) - (a.size ?? 0));
}
```

- [ ] **Step 4: Run the spec to verify it passes**

Run: `cd app && npx vitest run src/components/analyses/clusterValidation.spec.ts`
Expected: PASS (all describe blocks green).

- [ ] **Step 5: Commit**

```bash
git add app/src/components/analyses/clusterValidation.ts app/src/components/analyses/clusterValidation.spec.ts
git commit -m "feat(app): cluster-validation helper (scalar unwrap, Hennig bands, partition summary, per-cluster stability)"
```

---

### Task 3: `ClusterValidationCard.vue` (TDD)

**Files:**
- Create: `app/src/components/analyses/ClusterValidationCard.vue`
- Test: `app/src/components/analyses/ClusterValidationCard.spec.ts`

**Interfaces:**
- Consumes: helpers from `./clusterValidation` (Task 2); `AnalysisSnapshotMeta`, `FunctionalCluster`, `PhenotypeCluster` from `@/api/analysis` (Task 1).
- Produces: default-exported component `ClusterValidationCard` with props `analysisType: 'functional_clusters' | 'phenotype_clusters'`, `snapshotMeta: AnalysisSnapshotMeta | null`, `clusters: unknown[]`. Consumed by Task 4.

- [ ] **Step 1: Write the failing spec** — `app/src/components/analyses/ClusterValidationCard.spec.ts`

```ts
import { describe, it, expect } from 'vitest';
import { mount } from '@vue/test-utils';
import ClusterValidationCard from './ClusterValidationCard.vue';

const functionalMeta = {
  generated_at: '2026-07-03T06:50:00Z',
  db_release: { version: ['1.0.0'], commit: ['unknown'] },
  validation_hash: ['56a29d312f93e37c4d3ec9ed6eff975c6bab6c5fa0c0fcb90579beb62822f748'],
  validation: {
    algorithm: ['leiden'],
    modularity: [0.5355],
    n_clusters: [9],
    n_dropped_below_min_size: [7],
    n_resamples_effective: [100],
  },
};
const functionalClusters = [
  { cluster: ['1'], cluster_size: [464], jaccard_mean: [0.853], jaccard_n_resamples: [100] },
  { cluster: ['3'], cluster_size: [202], jaccard_mean: [0.41], jaccard_n_resamples: [100] },
];

describe('ClusterValidationCard', () => {
  it('renders the functional (modularity) headline + per-cluster bands with text labels', () => {
    const wrapper = mount(ClusterValidationCard, {
      props: { analysisType: 'functional_clusters', snapshotMeta: functionalMeta, clusters: functionalClusters },
    });
    const text = wrapper.text();
    expect(text).toContain('Modularity');
    expect(text).toContain('0.536');
    expect(text).toContain('1.0.0'); // db release badge
    // per-cluster band labels present as TEXT (not color-only)
    expect(text).toContain('stable');
    expect(text).toContain('dissolved');
  });

  it('renders the phenotype (silhouette + k) headline', () => {
    const wrapper = mount(ClusterValidationCard, {
      props: {
        analysisType: 'phenotype_clusters',
        snapshotMeta: {
          db_release: { version: ['1.0.0'] },
          validation: { algorithm: ['mca_hcpc'], mean_silhouette: [0.1944], k: [3], n_entities_dropped: [0], n_resamples_effective: [100] },
        },
        clusters: [{ cluster: ['2'], cluster_size: [1420], jaccard_mean: [0.705], silhouette_mean: [0.213] }],
      },
    });
    const text = wrapper.text();
    expect(text).toContain('Mean silhouette');
    expect(text).toContain('0.194');
    expect(text).toContain('Clusters (k)');
    expect(text).toContain('3');
  });

  it('renders nothing when validation is absent (old snapshot)', () => {
    const wrapper = mount(ClusterValidationCard, {
      props: {
        analysisType: 'functional_clusters',
        snapshotMeta: { db_release: { version: ['1.0.0'] }, validation: [] },
        clusters: [],
      },
    });
    expect(wrapper.find('.cluster-validation-card').exists()).toBe(false);
  });

  it('renders nothing when snapshotMeta is null', () => {
    const wrapper = mount(ClusterValidationCard, {
      props: { analysisType: 'functional_clusters', snapshotMeta: null, clusters: [] },
    });
    expect(wrapper.find('.cluster-validation-card').exists()).toBe(false);
  });
});
```

- [ ] **Step 2: Run the spec to verify it fails**

Run: `cd app && npx vitest run src/components/analyses/ClusterValidationCard.spec.ts`
Expected: FAIL — cannot resolve `./ClusterValidationCard.vue`.

- [ ] **Step 3: Implement `app/src/components/analyses/ClusterValidationCard.vue`**

```vue
<template>
  <section
    v-if="visible"
    class="cluster-validation-card"
    aria-labelledby="cluster-validation-card-title"
  >
    <header class="cluster-validation-card__header">
      <div class="cluster-validation-card__title-wrap">
        <i class="bi bi-diagram-3 cluster-validation-card__icon" aria-hidden="true" />
        <div>
          <h3 id="cluster-validation-card-title" class="cluster-validation-card__title">
            Cluster validation
          </h3>
          <p class="cluster-validation-card__subtitle">{{ subtitle }}</p>
        </div>
      </div>
      <div class="cluster-validation-card__release">
        <BBadge v-if="dbVersion" variant="info">DB {{ dbVersion }}</BBadge>
        <span v-if="builtOn" class="cluster-validation-card__built">built {{ builtOn }}</span>
      </div>
    </header>

    <div class="cluster-validation-card__grid" aria-label="Partition metrics">
      <div v-for="metric in metrics" :key="metric.label" class="cluster-validation-card__metric">
        <span class="cluster-validation-card__metric-label">{{ metric.label }}</span>
        <span class="cluster-validation-card__metric-value">
          {{ metric.value }}
          <small v-if="metric.hint" class="cluster-validation-card__metric-hint">{{ metric.hint }}</small>
        </span>
      </div>
    </div>

    <div v-if="rows.length" class="cluster-validation-card__clusters" aria-label="Per-cluster stability">
      <div class="cluster-validation-card__clusters-head">
        <span>Cluster</span>
        <span>Bootstrap-Jaccard stability</span>
      </div>
      <div v-for="row in rows" :key="row.id" class="cluster-validation-card__row">
        <span class="cluster-validation-card__row-id">
          Cluster {{ row.id }}
          <small v-if="row.size != null">· {{ row.size }} {{ unitLabel }}</small>
        </span>
        <div class="cluster-validation-card__bar-wrap">
          <div class="cluster-validation-card__bar-track">
            <div
              class="cluster-validation-card__bar-fill"
              :class="`cluster-validation-card__bar-fill--${row.band.key}`"
              :style="{ width: barWidth(row.jaccard) }"
            />
          </div>
          <span class="cluster-validation-card__row-metrics">
            <span
              class="cluster-validation-card__band"
              :class="`cluster-validation-card__band--${row.band.key}`"
            >{{ row.band.label }}</span>
            <span class="cluster-validation-card__jaccard">{{ fmt(row.jaccard) }}</span>
            <span v-if="row.silhouette != null" class="cluster-validation-card__sil">
              sil {{ fmt(row.silhouette) }}
            </span>
          </span>
        </div>
      </div>
    </div>

    <footer class="cluster-validation-card__footer">
      <ul class="cluster-validation-card__legend" aria-label="Stability bands">
        <li><span class="cluster-validation-card__swatch cluster-validation-card__band--stable" />stable ≥0.75</li>
        <li><span class="cluster-validation-card__swatch cluster-validation-card__band--doubtful" />doubtful 0.60–0.75</li>
        <li><span class="cluster-validation-card__swatch cluster-validation-card__band--weak" />weak 0.50–0.60</li>
        <li><span class="cluster-validation-card__swatch cluster-validation-card__band--dissolved" />dissolved &lt;0.50</li>
      </ul>
      <p class="cluster-validation-card__method">
        <i class="bi bi-info-circle" aria-hidden="true" />
        {{ methodNote }}
        <span v-if="validationHashShort" class="cluster-validation-card__hash">· {{ validationHashShort }}</span>
      </p>
    </footer>
  </section>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import { BBadge } from 'bootstrap-vue-next';
import type { AnalysisSnapshotMeta } from '@/api/analysis';
import {
  summarizeValidation,
  perClusterStability,
  hasValidation,
  toScalarNumber,
  toScalarString,
  type ClusterAnalysisType,
} from './clusterValidation';

defineOptions({ name: 'ClusterValidationCard' });

const props = defineProps<{
  analysisType: ClusterAnalysisType;
  snapshotMeta: AnalysisSnapshotMeta | null;
  clusters: unknown[];
}>();

const validation = computed(() => props.snapshotMeta?.validation ?? null);
const visible = computed(() => hasValidation(validation.value));

const isPhenotype = computed(() => props.analysisType === 'phenotype_clusters');
const unitLabel = computed(() => (isPhenotype.value ? 'entities' : 'genes'));
const subtitle = computed(() =>
  isPhenotype.value
    ? 'Data-driven k (MCA/HCPC); per-cluster reproducibility from bootstrap subsampling.'
    : 'Weighted Leiden run to convergence; per-cluster reproducibility from bootstrap subsampling.',
);

const metrics = computed(() => summarizeValidation(props.analysisType, validation.value));
const rows = computed(() => perClusterStability(props.clusters as never));

const dbVersion = computed(() => toScalarString(props.snapshotMeta?.db_release?.version));
const builtOn = computed(() => {
  const raw = toScalarString(props.snapshotMeta?.generated_at);
  return raw ? raw.slice(0, 10) : null;
});
const validationHashShort = computed(() => {
  const h = toScalarString(props.snapshotMeta?.validation_hash);
  return h ? `validation ${h.slice(0, 8)}` : null;
});
const methodNote = computed(() =>
  'Stability = bootstrap-Jaccard over subsamples (Hennig bands). Read stable/highly-stable clusters with confidence; treat weak/dissolved clusters cautiously.',
);

function fmt(value: number | null): string {
  return value == null ? 'n/a' : value.toFixed(3);
}
function barWidth(value: number | null): string {
  const pct = value == null ? 0 : Math.max(0, Math.min(1, value)) * 100;
  return `${pct}%`;
}
</script>

<style scoped>
.cluster-validation-card {
  display: grid;
  gap: 0.875rem;
  padding: 1rem;
  margin-top: 0.75rem;
  border: 1px solid #d7dee8;
  border-radius: var(--radius-lg, 8px);
  background: #fff;
  box-shadow: 0 1px 2px rgb(15 23 42 / 6%);
}

.cluster-validation-card__header {
  display: flex;
  flex-wrap: wrap;
  align-items: flex-start;
  justify-content: space-between;
  gap: 0.75rem;
}

.cluster-validation-card__title-wrap {
  display: flex;
  align-items: flex-start;
  gap: 0.65rem;
}

.cluster-validation-card__icon {
  color: var(--medical-teal-600, #00897b);
  font-size: 1.1rem;
  line-height: 1.4;
}

.cluster-validation-card__title {
  margin: 0;
  color: var(--neutral-900, #212121);
  font-size: 1rem;
  font-weight: 700;
  line-height: 1.25;
}

.cluster-validation-card__subtitle {
  margin: 0;
  color: var(--neutral-600, #757575);
  font-size: 0.875rem;
  line-height: 1.45;
}

.cluster-validation-card__release {
  display: flex;
  flex-direction: column;
  align-items: flex-end;
  gap: 0.2rem;
}

.cluster-validation-card__built {
  color: var(--neutral-600, #757575);
  font-size: 0.75rem;
}

.cluster-validation-card__grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(9rem, 1fr));
  gap: 0.5rem;
}

.cluster-validation-card__metric {
  display: grid;
  gap: 0.15rem;
  min-width: 0;
  padding: 0.55rem 0.65rem;
  border: 1px solid #e1e7ef;
  border-radius: var(--radius-md, 6px);
  background: #fff;
}

.cluster-validation-card__metric-label {
  color: var(--neutral-700, #616161);
  font-size: 0.75rem;
  font-weight: 700;
}

.cluster-validation-card__metric-value {
  color: var(--neutral-900, #212121);
  font-family: var(--font-family-mono, ui-monospace, SFMono-Regular, Menlo, monospace);
  font-size: 1rem;
  font-weight: 700;
}

.cluster-validation-card__metric-hint {
  display: block;
  color: var(--neutral-600, #757575);
  font-family: inherit;
  font-size: 0.7rem;
  font-weight: 400;
}

.cluster-validation-card__clusters {
  display: grid;
  gap: 0.35rem;
  max-height: 22rem;
  overflow-y: auto;
}

.cluster-validation-card__clusters-head {
  display: grid;
  grid-template-columns: minmax(9rem, 1fr) 2fr;
  gap: 0.75rem;
  color: var(--neutral-700, #616161);
  font-size: 0.7rem;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.02em;
}

.cluster-validation-card__row {
  display: grid;
  grid-template-columns: minmax(9rem, 1fr) 2fr;
  align-items: center;
  gap: 0.75rem;
}

.cluster-validation-card__row-id {
  color: var(--neutral-900, #212121);
  font-size: 0.8125rem;
  font-weight: 600;
}

.cluster-validation-card__row-id small {
  color: var(--neutral-600, #757575);
  font-weight: 400;
}

.cluster-validation-card__bar-wrap {
  display: flex;
  align-items: center;
  gap: 0.6rem;
  min-width: 0;
}

.cluster-validation-card__bar-track {
  position: relative;
  flex: 1 1 auto;
  min-width: 3rem;
  height: 0.55rem;
  border-radius: 999px;
  background: #eef2f7;
  overflow: hidden;
}

.cluster-validation-card__bar-fill {
  height: 100%;
  border-radius: 999px;
}

.cluster-validation-card__row-metrics {
  display: inline-flex;
  align-items: center;
  gap: 0.4rem;
  flex: 0 0 auto;
  font-family: var(--font-family-mono, ui-monospace, SFMono-Regular, Menlo, monospace);
  font-size: 0.75rem;
}

.cluster-validation-card__band {
  padding: 0.05rem 0.4rem;
  border-radius: 999px;
  color: #fff;
  font-family: var(--font-family-base, system-ui, sans-serif);
  font-size: 0.7rem;
  font-weight: 700;
  white-space: nowrap;
}

.cluster-validation-card__jaccard {
  color: var(--neutral-900, #212121);
  font-weight: 700;
}

.cluster-validation-card__sil {
  color: var(--neutral-600, #757575);
}

/* Band colors — vivid fill + AA-contrast chip text (white on each). */
.cluster-validation-card__band--highly_stable,
.cluster-validation-card__band--stable { background: #2e7d32; }
.cluster-validation-card__band--doubtful { background: #b26a00; }
.cluster-validation-card__band--weak { background: #d84315; }
.cluster-validation-card__band--dissolved { background: #c62828; }
.cluster-validation-card__band--na { background: #757575; }

.cluster-validation-card__bar-fill--highly_stable,
.cluster-validation-card__bar-fill--stable { background: #2e7d32; }
.cluster-validation-card__bar-fill--doubtful { background: #b26a00; }
.cluster-validation-card__bar-fill--weak { background: #d84315; }
.cluster-validation-card__bar-fill--dissolved { background: #c62828; }
.cluster-validation-card__bar-fill--na { background: #9aa4b2; }

.cluster-validation-card__footer {
  display: grid;
  gap: 0.4rem;
  border-top: 1px solid #eef2f7;
  padding-top: 0.65rem;
}

.cluster-validation-card__legend {
  display: flex;
  flex-wrap: wrap;
  gap: 0.4rem 0.9rem;
  margin: 0;
  padding: 0;
  list-style: none;
  color: var(--neutral-700, #616161);
  font-size: 0.72rem;
}

.cluster-validation-card__legend li {
  display: inline-flex;
  align-items: center;
  gap: 0.3rem;
}

.cluster-validation-card__swatch {
  display: inline-block;
  width: 0.7rem;
  height: 0.7rem;
  border-radius: 3px;
}

.cluster-validation-card__method {
  margin: 0;
  color: var(--neutral-600, #757575);
  font-size: 0.72rem;
  line-height: 1.45;
}

.cluster-validation-card__hash {
  font-family: var(--font-family-mono, ui-monospace, SFMono-Regular, Menlo, monospace);
}
</style>
```

- [ ] **Step 4: Run the spec to verify it passes**

Run: `cd app && npx vitest run src/components/analyses/ClusterValidationCard.spec.ts`
Expected: PASS (all four cases green).

- [ ] **Step 5: Commit**

```bash
git add app/src/components/analyses/ClusterValidationCard.vue app/src/components/analyses/ClusterValidationCard.spec.ts
git commit -m "feat(app): ClusterValidationCard — partition metrics + per-cluster stability bands"
```

---

### Task 4: Mount the card on both analysis views

**Files:**
- Modify: `app/src/components/analyses/AnalyseGeneClusters.vue` (import + register + `data()` fields + capture in load + template mount at `</Splitpanes>` → `</AnalysisPanel>`, ~line 357)
- Modify: `app/src/components/analyses/AnalysesPhenotypeClusters.vue` (import + register + `data()` fields + capture in load + template mount before `</AnalysisPanel>`, ~line 231)

**Interfaces:**
- Consumes: `ClusterValidationCard` (Task 3). Both views are Options API; add data props `snapshotMeta` + `clusterRows`, set them in the existing `getFunctionalClustering`/`getPhenotypeClustering` success path.

- [ ] **Step 1: Functional view — import + register the component**

In `app/src/components/analyses/AnalyseGeneClusters.vue`, add to the imports near `GenericTable` (line ~371):
```js
import ClusterValidationCard from '@/components/analyses/ClusterValidationCard.vue';
```
and to the `components: { … }` block (near line ~418, where `GenericTable,` is registered):
```js
    ClusterValidationCard,
```

- [ ] **Step 2: Functional view — add reactive state** in `data()` return (near `itemsCluster: [],`, line ~466)

```js
      snapshotMeta: null,
      clusterRows: [],
```

- [ ] **Step 3: Functional view — capture meta + raw clusters** in the load success path (line ~762, where `this.itemsCluster = data.clusters;`)

```js
        this.itemsCluster = data.clusters;
        this.clusterRows = data.clusters || [];
        this.snapshotMeta = data.meta?.snapshot || null;
```

- [ ] **Step 4: Functional view — mount the card** between `</Splitpanes>` and `</AnalysisPanel>` (line ~357)

```html
    </Splitpanes>
    <ClusterValidationCard
      analysis-type="functional_clusters"
      :snapshot-meta="snapshotMeta"
      :clusters="clusterRows"
    />
  </AnalysisPanel>
```

- [ ] **Step 5: Phenotype view — import + register**

In `app/src/components/analyses/AnalysesPhenotypeClusters.vue`, add to imports (near the `getPhenotypeClustering` import, line ~246):
```js
import ClusterValidationCard from '@/components/analyses/ClusterValidationCard.vue';
```
and to the `components: { … }` registration block:
```js
    ClusterValidationCard,
```

- [ ] **Step 6: Phenotype view — add reactive state** in `data()` return (near `itemsCluster: [],`, line ~306)

```js
      snapshotMeta: null,
      clusterRows: [],
```

- [ ] **Step 7: Phenotype view — capture meta + raw clusters** in the load path (line ~452–455)

```js
        const data = await getPhenotypeClustering();
        this.clusterRows = data.clusters || [];
        this.snapshotMeta = data.meta?.snapshot || null;
        this.itemsCluster = (data.clusters || []).map((cluster) => ({
```
(only the two new lines are added directly after `const data = …`; the existing `this.itemsCluster = …map(` line is unchanged.)

- [ ] **Step 8: Phenotype view — mount the card** just before `</AnalysisPanel>` (line ~231)

```html
    <ClusterValidationCard
      analysis-type="phenotype_clusters"
      :snapshot-meta="snapshotMeta"
      :clusters="clusterRows"
    />
  </AnalysisPanel>
```

- [ ] **Step 9: Run the full frontend gates**

Run: `cd app && npm run type-check && npx vitest run src/components/analyses/clusterValidation.spec.ts src/components/analyses/ClusterValidationCard.spec.ts src/api/analysis.spec.ts && npm run lint`
Expected: type-check clean; the three specs PASS; lint clean (0 new issues).

- [ ] **Step 10: Manual smoke against the running stack** (dev app on http://localhost:5173)

Open `http://localhost:5173/Analyses` → Functional clusters and Phenotype clusters panels. Expected: a "Cluster validation" card renders below each — functional shows Modularity 0.54 + 9 clusters with per-cluster bands (cluster 1 "stable", cluster 3 "dissolved"); phenotype shows Mean silhouette 0.194 + k=3. Confirm the card is absent if a page's snapshot has no validation (no console errors).

- [ ] **Step 11: Commit**

```bash
git add app/src/components/analyses/AnalyseGeneClusters.vue app/src/components/analyses/AnalysesPhenotypeClusters.vue
git commit -m "feat(app): surface cluster validation card on functional + phenotype analysis pages"
```

---

## Self-Review

**Spec coverage:**
- Inline card on both cluster pages → Task 4 (mount on functional + phenotype). ✓
- Partition summary + per-cluster stability with bands → Task 2 (`summarizeValidation`, `perClusterStability`, `jaccardBand`) + Task 3 (render). ✓
- Algorithm-aware headline (modularity vs silhouette+k) → `summarizeValidation` branch + card subtitle. ✓
- Bands from R doc thresholds → `jaccardBand` (0.85/0.75/0.60/0.50). ✓
- No API/DB change; types only → Task 1. ✓
- Scalar-array unwrap → `toScalar*` used everywhere. ✓
- Hide when no validation / 503 handled by page → `hasValidation` → `v-if="visible"` (Task 3) + views only pass data they already have. ✓
- Not color-only (WCAG) → band label text + numeric value always rendered; card spec asserts band label text present. ✓
- Visual tokens/idiom → mirrors `NddScoreModelCard` classes/tokens. ✓
- Testing (helper spec, card spec, type-check, lint) → Tasks 2, 3, 4 step 9. ✓

**Placeholder scan:** none — every step has concrete code/commands.

**Type consistency:** `ClusterValidation`/`AnalysisSnapshotMeta` (Task 1) are the exact types imported by Task 2/3; helper function names (`summarizeValidation`, `perClusterStability`, `jaccardBand`, `hasValidation`, `toScalarNumber`, `toScalarString`) match between Task 2 definition, its spec, and Task 3 imports; card props (`analysisType`, `snapshotMeta`, `clusters`) match Task 4 template bindings (`analysis-type`, `:snapshot-meta`, `:clusters`).
