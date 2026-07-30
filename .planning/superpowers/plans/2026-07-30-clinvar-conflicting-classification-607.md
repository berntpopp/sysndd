# ClinVar Conflicting Classification Fix — Implementation Plan (#607)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace four divergent substring-matching ClinVar significance normalizers with one table-driven vocabulary shared by the TypeScript client and the R API, and give `Conflicting classifications of pathogenicity` its own first-class category everywhere it is counted or drawn.

**Architecture:** A new `app/src/types/clinvarSignificance.ts` owns the canonical vocabulary and the exact-match lookup. `protein.ts`, `alphafold.ts`, and `GeneClinVarCard.vue` become thin adapters over it. `api/functions/external-proxy-gnomad.R` is rewritten as an exact-match table over the identical vocabulary and promotes `conflicting` to a primary class. A single JSON fixture under `api/tests/testthat/fixtures/` drives both test suites, so client and server cannot drift.

**Tech Stack:** Vue 3 + TypeScript + Vitest (`app/`), R/Plumber + testthat (`api/`), D3 for the plots.

## Global Constraints

- **No substring or regex matching on `clinical_significance`.** Exact string equality against the lookup table, after one normalization step (`_`→space, trim, lowercase, collapse whitespace). This is the entire point of the change.
- **Aggregate values are resolved by ClinVar's documented delimiter grammar, then exact-matched per token** — whole string → first `;`/`|` segment → `/`-separated tokens, every token must resolve. This is not substring guessing, and it is what keeps a real aggregate like `Pathogenic/Likely pathogenic/Pathogenic, low penetrance/Established risk allele; risk factor` from being undercounted.
- **Unrecognised terms map to an explicit unknown bucket and are logged. Never guessed, and never able to land in an ACMG tier.**
- **Both plots keep their existing P/LP-only default.** Conflicting and Other default to **hidden** on the lollipop and the gene-structure plot, and **visible** on the 3D variant panel (which shows everything today). Do not turn other categories on.
- **Adding a term means editing the fixture first.** Bidirectional completeness tests assert each production table's key set equals the fixture's, exactly.
- `Pathogenic/Likely pathogenic` → **pathogenic** on both sides. `Benign/Likely benign` → **likely_benign** on both sides. (Most severe of the pair.)
- The Conflicting colour is `#6f42c1` — the existing `$purple` token in `app/src/assets/scss/_variables.scss`. Do not introduce a new one-off palette value (`documentation/10-visual-design-guide.md`).
- Namespace `dplyr::` verbs explicitly in R; use `base::get` if you ever need `get()` (the `config` package masks it).
- Every touched file stays under the 600-line soft ceiling (`AGENTS.md`).
- This path is read-only external-provider display. It must not touch curated SysNDD data.

## Amendments from the adversarial review

One round, Codex `gpt-5.6-terra` high, verdict BLOCK — `.planning/reviews/2026-07-30-607-spec-codex-review.md`.
Task 1 above already carries the P0 fix (aggregate grammar) and the bidirectional completeness test.
These deltas apply to the later tasks and **override** anything below that contradicts them:

- **Task 2** additionally exports `pathogenicitySeverityRank(cls: PathogenicityClass): number` from
  `protein.ts`, derived from `PATHOGENICITY_SEVERITY`. `composables/d3-lollipop/lollipop-render.ts:250`
  holds a **second** exhaustive `Record<PathogenicityClass, number>` stacking order — delete it and
  call the shared helper, or `vue-tsc` fails and the two orderings drift again.
- **Task 5** — the lollipop's current default is **P/LP only** (`ProteinDomainLollipopPlot.vue:109-114`),
  not all-on. Initialize `conflicting: false` and `other: false`. The plan text below saying "this
  surface shows every category by default" is wrong; ignore it.
- **Task 6** additionally widens the *second* `PathogenicityFilterKey` union, the one exported from
  `GeneStructurePlotControls.vue:171`, and fixes
  `components/gene/gene-structure-plot/gene-structure-tooltip.ts:133`, which `.slice(0, 5)`s a
  breakdown that now has seven possible classes — render every non-zero class instead.
- **Task 7** additionally adds `conflicting` to the `filter-change` **watcher** at
  `VariantPanel.vue:284-295`. Without it the Conf chip toggles the list but never re-emits, so 3D
  markers silently desync from the filter.
- **Task 8** declares `conflicting?: number` (**optional**) on both `ClinVarClassificationCounts` and
  `ClinVarCounts`. Required would break the existing five-count mocks in
  `composables/__tests__/useGeneClinVarCounts.spec.ts:35` and `GeneClinVarCard.spec.ts:5`. The
  `{ ...empty, ...props.counts }` spread is what zero-fills it.
- **Task 4** mirrors the Task 1 aggregate grammar in R (`clinvar_significance_tokens` +
  `.clinvar_resolve_aggregate()`) and adds the bidirectional completeness assertion over
  `names(clinvar_significance_table)`.

---

### Task 1: Shared vocabulary module + cross-language fixture

**Files:**
- Create: `api/tests/testthat/fixtures/clinvar-significance-vocabulary.json`
- Create: `app/src/types/clinvarSignificance.ts`
- Test: `app/src/types/clinvarSignificance.spec.ts`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `type ClinVarSignificanceClass = 'pathogenic' | 'likely_pathogenic' | 'vus' | 'likely_benign' | 'benign' | 'conflicting' | 'other' | 'unknown'`
  - `normalizeClinVarSignificanceKey(raw: unknown): string`
  - `normalizeClinVarSignificance(raw: unknown): ClinVarSignificanceClass`
  - `CLINVAR_SIGNIFICANCE_TABLE: Readonly<Record<string, ClinVarSignificanceClass>>`
  - `resetUnknownSignificanceLog(): void` (test seam for the once-per-term warning)

- [ ] **Step 1: Write the shared fixture**

`api/tests/testthat/fixtures/clinvar-significance-vocabulary.json` — the single source both suites assert against. It lives under `api/tests/` because that directory is copied into the API container, while host-run vitest reaches it from a full checkout.

```json
{
  "description": "Canonical ClinVar clinical_significance vocabulary shared by app/src/types/clinvarSignificance.ts and api/functions/external-proxy-gnomad.R. See GitHub issue #607.",
  "terms": [
    { "raw": "Pathogenic", "class": "pathogenic" },
    { "raw": "Pathogenic/Likely pathogenic", "class": "pathogenic" },
    { "raw": "Pathogenic, low penetrance", "class": "pathogenic" },
    { "raw": "Likely pathogenic", "class": "likely_pathogenic" },
    { "raw": "Likely pathogenic, low penetrance", "class": "likely_pathogenic" },
    { "raw": "Uncertain significance", "class": "vus" },
    { "raw": "Likely benign", "class": "likely_benign" },
    { "raw": "Benign/Likely benign", "class": "likely_benign" },
    { "raw": "Benign", "class": "benign" },
    { "raw": "Conflicting classifications of pathogenicity", "class": "conflicting" },
    { "raw": "Conflicting interpretations of pathogenicity", "class": "conflicting" },
    { "raw": "not provided", "class": "other" },
    { "raw": "no classification provided", "class": "other" },
    { "raw": "no classifications from unflagged records", "class": "other" },
    { "raw": "no classification for the single variant", "class": "other" },
    { "raw": "drug response", "class": "other" },
    { "raw": "risk factor", "class": "other" },
    { "raw": "association", "class": "other" },
    { "raw": "association not found", "class": "other" },
    { "raw": "protective", "class": "other" },
    { "raw": "Affects", "class": "other" },
    { "raw": "confers sensitivity", "class": "other" },
    { "raw": "established risk allele", "class": "other" },
    { "raw": "likely risk allele", "class": "other" },
    { "raw": "uncertain risk allele", "class": "other" },
    { "raw": "other", "class": "other" }
  ],
  "normalization_variants": [
    { "raw": "Uncertain_significance", "class": "vus" },
    { "raw": "Likely_pathogenic", "class": "likely_pathogenic" },
    { "raw": "Pathogenic/Likely_pathogenic", "class": "pathogenic" },
    { "raw": "Benign/Likely_benign", "class": "likely_benign" },
    { "raw": "  PATHOGENIC  ", "class": "pathogenic" },
    { "raw": "conflicting   classifications  of pathogenicity", "class": "conflicting" }
  ],
  "aggregate_terms": [
    { "raw": "Pathogenic|risk factor", "class": "pathogenic" },
    { "raw": "Pathogenic; risk factor", "class": "pathogenic" },
    { "raw": "Pathogenic/Established risk allele", "class": "pathogenic" },
    { "raw": "Pathogenic/Likely pathogenic/Pathogenic, low penetrance/Established risk allele; risk factor", "class": "pathogenic" },
    { "raw": "Likely pathogenic/Likely risk allele", "class": "likely_pathogenic" },
    { "raw": "Uncertain significance/Uncertain risk allele", "class": "vus" },
    { "raw": "Benign/Likely benign|other", "class": "likely_benign" },
    { "raw": "Conflicting classifications of pathogenicity; risk factor", "class": "conflicting" },
    { "raw": "Established risk allele; drug response", "class": "other" }
  ],
  "unknown_terms": [
    "Totally new ClinVar term 2027",
    "pathogenicity",
    "Pathogenic/Totally new ClinVar term 2027",
    ""
  ]
}
```

Note what the `aggregate_terms` entries pin down. `Pathogenic/Totally new ClinVar term 2027` is
`unknown`, **not** `pathogenic` — one unresolvable token poisons the whole value, which is what stops
the grammar from degenerating into "find any severe-looking token". And `pathogenicity` alone is
`unknown`, the direct regression for issue #607's substring.

- [ ] **Step 2: Write the failing test**

`app/src/types/clinvarSignificance.spec.ts`:

```ts
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';

import {
  CLINVAR_SIGNIFICANCE_TABLE,
  normalizeClinVarSignificance,
  normalizeClinVarSignificanceKey,
  resetUnknownSignificanceLog,
  type ClinVarSignificanceClass,
} from './clinvarSignificance';

interface VocabularyFixture {
  terms: Array<{ raw: string; class: ClinVarSignificanceClass }>;
  normalization_variants: Array<{ raw: string; class: ClinVarSignificanceClass }>;
  aggregate_terms: Array<{ raw: string; class: ClinVarSignificanceClass }>;
  unknown_terms: string[];
}

const fixture: VocabularyFixture = JSON.parse(
  readFileSync(
    fileURLToPath(
      new URL('../../../api/tests/testthat/fixtures/clinvar-significance-vocabulary.json', import.meta.url)
    ),
    'utf-8'
  )
);

describe('normalizeClinVarSignificance', () => {
  beforeEach(() => {
    resetUnknownSignificanceLog();
  });

  afterEach(() => {
    vi.restoreAllMocks();
  });

  it.each(fixture.terms)('maps $raw to $class', ({ raw, class: expected }) => {
    expect(normalizeClinVarSignificance(raw)).toBe(expected);
  });

  it.each(fixture.normalization_variants)(
    'normalizes $raw to $class',
    ({ raw, class: expected }) => {
      expect(normalizeClinVarSignificance(raw)).toBe(expected);
    }
  );

  it('never classifies a conflicting term as pathogenic (issue #607)', () => {
    expect(normalizeClinVarSignificance('Conflicting classifications of pathogenicity')).toBe(
      'conflicting'
    );
    expect(normalizeClinVarSignificance('Conflicting classifications of pathogenicity')).not.toBe(
      'pathogenic'
    );
  });

  it('resolves Pathogenic/Likely pathogenic to pathogenic and Benign/Likely benign to likely_benign', () => {
    expect(normalizeClinVarSignificance('Pathogenic/Likely pathogenic')).toBe('pathogenic');
    expect(normalizeClinVarSignificance('Benign/Likely benign')).toBe('likely_benign');
  });

  it.each(fixture.unknown_terms)('maps the unrecognised term %j to unknown', (raw) => {
    vi.spyOn(console, 'warn').mockImplementation(() => {});
    const result = normalizeClinVarSignificance(raw);
    expect(result).toBe('unknown');
    expect(['pathogenic', 'likely_pathogenic', 'vus', 'likely_benign', 'benign']).not.toContain(
      result
    );
  });

  it('handles null, undefined and non-string inputs without throwing', () => {
    vi.spyOn(console, 'warn').mockImplementation(() => {});
    expect(normalizeClinVarSignificance(null)).toBe('unknown');
    expect(normalizeClinVarSignificance(undefined)).toBe('unknown');
    expect(normalizeClinVarSignificance(42)).toBe('unknown');
    expect(normalizeClinVarSignificanceKey(null)).toBe('');
  });

  it('warns at most once per distinct unrecognised term', () => {
    const warn = vi.spyOn(console, 'warn').mockImplementation(() => {});
    normalizeClinVarSignificance('Brand new term');
    normalizeClinVarSignificance('Brand new term');
    normalizeClinVarSignificance('brand   NEW   term');
    normalizeClinVarSignificance('Another new term');
    expect(warn).toHaveBeenCalledTimes(2);
  });

  it.each(fixture.aggregate_terms)(
    'resolves the aggregate value $raw to $class',
    ({ raw, class: expected }) => {
      expect(normalizeClinVarSignificance(raw)).toBe(expected);
    }
  );

  it('poisons the whole aggregate when one token is unresolvable', () => {
    vi.spyOn(console, 'warn').mockImplementation(() => {});
    expect(normalizeClinVarSignificance('Pathogenic/Totally new ClinVar term 2027')).toBe('unknown');
  });

  it('keeps the production table exactly in sync with the fixture (both directions)', () => {
    const fixtureKeys = new Set(
      fixture.terms.map(({ raw }) => normalizeClinVarSignificanceKey(raw))
    );
    const tableKeys = new Set(Object.keys(CLINVAR_SIGNIFICANCE_TABLE));

    expect([...tableKeys].filter((k) => !fixtureKeys.has(k))).toEqual([]);
    expect([...fixtureKeys].filter((k) => !tableKeys.has(k))).toEqual([]);
  });
});
```

- [ ] **Step 3: Run the test and verify it fails**

Run: `cd app && npx vitest run src/types/clinvarSignificance.spec.ts`
Expected: FAIL — `Failed to resolve import "./clinvarSignificance"`.

- [ ] **Step 4: Write the module**

`app/src/types/clinvarSignificance.ts`:

```ts
// app/src/types/clinvarSignificance.ts
/**
 * Canonical ClinVar clinical-significance vocabulary — the SINGLE source of
 * truth for the client.
 *
 * ClinVar `clinical_significance` is a controlled vocabulary. Matching it with
 * `includes()` or a regex means every new or unanticipated term is silently
 * misfiled into whichever branch its substrings happen to hit — which is
 * exactly how `"Conflicting classifications of pathogenicity"` was counted as
 * Pathogenic (`.includes('pathogenic')` is true, because `pathogenic` is a
 * substring of *pathogenic*ity). See GitHub issue #607.
 *
 * Therefore: exact string equality against an explicit table, after ONE
 * normalization step. No substring matching, no regex classification. A term
 * that is not in the table becomes `'unknown'` and is logged — never guessed,
 * and never able to land in an ACMG tier.
 *
 * The table is mirrored by `normalize_clinvar_classification()` in
 * `api/functions/external-proxy-gnomad.R`. Both are driven in test by
 * `api/tests/testthat/fixtures/clinvar-significance-vocabulary.json`; keep the
 * three in sync.
 */

/**
 * Canonical classification buckets.
 *
 * - the five ACMG tiers
 * - `conflicting` — submitters disagree; NOT an ACMG tier and not pathogenic
 * - `other`       — a recognised ClinVar term that is not a pathogenicity tier
 *                   (drug response, risk factor, not provided, ...)
 * - `unknown`     — not in the table; logged, never guessed
 */
export type ClinVarSignificanceClass =
  | 'pathogenic'
  | 'likely_pathogenic'
  | 'vus'
  | 'likely_benign'
  | 'benign'
  | 'conflicting'
  | 'other'
  | 'unknown';

/**
 * Normalize a raw significance string to the table's key form:
 * underscores to spaces, trimmed, lowercased, internal whitespace collapsed.
 *
 * Returns `''` for anything that is not a non-empty string.
 */
export function normalizeClinVarSignificanceKey(raw: unknown): string {
  if (typeof raw !== 'string') return '';
  return raw.replace(/_/g, ' ').trim().toLowerCase().replace(/\s+/g, ' ');
}

/**
 * ClinVar's published germline-classification vocabulary, plus the one legacy
 * synonym ClinVar renamed in 2023 ("Conflicting interpretations of
 * pathogenicity" -> "Conflicting classifications of pathogenicity").
 *
 * Combined pairs resolve to the MORE SEVERE member, matching the server:
 * `Pathogenic/Likely pathogenic` -> pathogenic,
 * `Benign/Likely benign`         -> likely_benign.
 *
 * The three risk-allele terms map to `other` rather than an ACMG tier: they are
 * a different kind of claim, and `other` is the fail-safe destination.
 */
export const CLINVAR_SIGNIFICANCE_TABLE: Readonly<Record<string, ClinVarSignificanceClass>> =
  Object.freeze({
    pathogenic: 'pathogenic',
    'pathogenic/likely pathogenic': 'pathogenic',
    'pathogenic, low penetrance': 'pathogenic',

    'likely pathogenic': 'likely_pathogenic',
    'likely pathogenic, low penetrance': 'likely_pathogenic',

    'uncertain significance': 'vus',

    'likely benign': 'likely_benign',
    'benign/likely benign': 'likely_benign',

    benign: 'benign',

    'conflicting classifications of pathogenicity': 'conflicting',
    'conflicting interpretations of pathogenicity': 'conflicting',

    'not provided': 'other',
    'no classification provided': 'other',
    'no classifications from unflagged records': 'other',
    'no classification for the single variant': 'other',
    'drug response': 'other',
    'risk factor': 'other',
    association: 'other',
    'association not found': 'other',
    protective: 'other',
    affects: 'other',
    'confers sensitivity': 'other',
    'established risk allele': 'other',
    'likely risk allele': 'other',
    'uncertain risk allele': 'other',
    other: 'other',
  });

/**
 * Atomic classification terms, for resolving ClinVar AGGREGATE values.
 *
 * ClinVar aggregates across submissions and joins classification terms with
 * `/`, then appends non-classification assertions after `;` or `|` — e.g.
 * `Pathogenic/Likely pathogenic/Pathogenic, low penetrance/Established risk
 * allele; risk factor`. Matching only whole strings would send every such value
 * to `unknown` and UNDERCOUNT real pathogenic variants, so the aggregate ladder
 * in `normalizeClinVarSignificance` tokenizes on those documented delimiters and
 * exact-matches each token here. Tokenizing a documented grammar is not
 * substring matching: every token must be a known term, or the whole value is
 * `unknown`.
 */
const CLINVAR_SIGNIFICANCE_TOKENS: Readonly<Record<string, ClinVarSignificanceClass>> =
  Object.freeze({
    pathogenic: 'pathogenic',
    'pathogenic, low penetrance': 'pathogenic',
    'likely pathogenic': 'likely_pathogenic',
    'likely pathogenic, low penetrance': 'likely_pathogenic',
    'uncertain significance': 'vus',
    'likely benign': 'likely_benign',
    benign: 'benign',
    'conflicting classifications of pathogenicity': 'conflicting',
    'conflicting interpretations of pathogenicity': 'conflicting',
    'established risk allele': 'other',
    'likely risk allele': 'other',
    'uncertain risk allele': 'other',
    'drug response': 'other',
    'risk factor': 'other',
    association: 'other',
    protective: 'other',
    affects: 'other',
    other: 'other',
  });

/** Severity rank used to combine the tokens of an aggregate value. */
const TOKEN_SEVERITY: Record<ClinVarSignificanceClass, number> = {
  unknown: -1,
  other: 0,
  benign: 1,
  likely_benign: 2,
  vus: 3,
  likely_pathogenic: 4,
  pathogenic: 5,
  conflicting: -1, // handled separately — conflicting wins outright
};

/**
 * Distinct unrecognised keys already warned about, so a 500-variant gene page
 * emits at most one warning per term instead of 500 identical lines.
 */
const warnedUnknownKeys = new Set<string>();

/** Test seam — clears the once-per-term warning guard. */
export function resetUnknownSignificanceLog(): void {
  warnedUnknownKeys.clear();
}

/**
 * Resolve a ClinVar AGGREGATE value by its documented delimiter grammar.
 *
 * Keeps the first `;`/`|` segment (the pathogenicity assertion; the rest are
 * secondary assertions), splits it on `/`, and exact-matches every token. Any
 * unresolvable token fails the whole value — a partial match must never be
 * allowed to promote an aggregate into an ACMG tier.
 *
 * @param key Already-normalized significance key.
 * @returns The combined class, or `null` when the value is not resolvable.
 */
function resolveAggregate(key: string): ClinVarSignificanceClass | null {
  if (!key) return null;

  const primarySegment = key.split(/[;|]/)[0].trim();
  if (!primarySegment) return null;

  const tokens = primarySegment.split('/').map((token) => token.trim());
  if (tokens.length === 0) return null;

  let best: ClinVarSignificanceClass | null = null;

  for (const token of tokens) {
    const resolved = CLINVAR_SIGNIFICANCE_TOKENS[token];
    if (!resolved) return null; // one unknown token poisons the whole value
    if (resolved === 'conflicting') return 'conflicting';
    if (best === null || TOKEN_SEVERITY[resolved] > TOKEN_SEVERITY[best]) {
      best = resolved;
    }
  }

  return best;
}

/**
 * Normalize a ClinVar `clinical_significance` value to its canonical class.
 *
 * @param raw Raw significance string from the gnomAD/ClinVar payload.
 * @returns The canonical class; `'unknown'` for anything not resolvable.
 */
export function normalizeClinVarSignificance(raw: unknown): ClinVarSignificanceClass {
  const key = normalizeClinVarSignificanceKey(raw);
  const known = CLINVAR_SIGNIFICANCE_TABLE[key];
  if (known) return known;

  const aggregate = resolveAggregate(key);
  if (aggregate) return aggregate;

  if (!warnedUnknownKeys.has(key)) {
    warnedUnknownKeys.add(key);
    console.warn(
      `[clinvar] Unrecognised ClinVar clinical significance ${JSON.stringify(raw)} — ` +
        'classified as "unknown". Add it to CLINVAR_SIGNIFICANCE_TABLE ' +
        '(app/src/types/clinvarSignificance.ts) and the matching R table if it is a real term.'
    );
  }

  return 'unknown';
}
```

- [ ] **Step 5: Run the test and verify it passes**

Run: `cd app && npx vitest run src/types/clinvarSignificance.spec.ts`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add api/tests/testthat/fixtures/clinvar-significance-vocabulary.json \
        app/src/types/clinvarSignificance.ts app/src/types/clinvarSignificance.spec.ts
git commit -m "feat(app): add table-driven ClinVar significance vocabulary (#607)"
```

---

### Task 2: `protein.ts` adapter, `Conflicting` class, severity reorder

**Files:**
- Modify: `app/src/types/protein.ts` (`PathogenicityClass`, `PATHOGENICITY_COLORS`, `LollipopFilterState`, `PATHOGENICITY_SEVERITY`, `aggregateVariantsByPosition`, `normalizeClassification`)
- Test: `app/src/types/protein.spec.ts` (create)

**Interfaces:**
- Consumes: `normalizeClinVarSignificance` from Task 1.
- Produces: `PathogenicityClass` now includes `'Conflicting'`; `PATHOGENICITY_COLORS['Conflicting'] === '#6f42c1'`; `LollipopFilterState` gains `conflicting: boolean` and `other: boolean`; `normalizeClassification(raw: unknown): PathogenicityClass`.

- [ ] **Step 1: Write the failing test**

`app/src/types/protein.spec.ts`:

```ts
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { describe, expect, it, vi } from 'vitest';

import {
  PATHOGENICITY_COLORS,
  PATHOGENICITY_SEVERITY,
  aggregateVariantsByPosition,
  normalizeClassification,
  type ProcessedVariant,
} from './protein';
import type { ClinVarSignificanceClass } from './clinvarSignificance';

const fixture: {
  terms: Array<{ raw: string; class: ClinVarSignificanceClass }>;
} = JSON.parse(
  readFileSync(
    fileURLToPath(
      new URL('../../../api/tests/testthat/fixtures/clinvar-significance-vocabulary.json', import.meta.url)
    ),
    'utf-8'
  )
);

const CANONICAL_TO_DISPLAY: Record<ClinVarSignificanceClass, string> = {
  pathogenic: 'Pathogenic',
  likely_pathogenic: 'Likely pathogenic',
  vus: 'Uncertain significance',
  likely_benign: 'Likely benign',
  benign: 'Benign',
  conflicting: 'Conflicting',
  other: 'other',
  unknown: 'other',
};

function variant(overrides: Partial<ProcessedVariant>): ProcessedVariant {
  return {
    proteinPosition: 100,
    proteinHGVS: 'p.Gly530Ser',
    codingHGVS: 'c.1588G>A',
    classification: 'Pathogenic',
    goldStars: 1,
    reviewStatus: 'criteria provided',
    clinvarId: '1',
    variantId: '1-1-A-G',
    majorConsequence: 'missense_variant',
    isSpliceVariant: false,
    inGnomad: false,
    ...overrides,
  };
}

describe('normalizeClassification', () => {
  it.each(fixture.terms)('maps $raw to the display class for $class', ({ raw, class: cls }) => {
    expect(normalizeClassification(raw)).toBe(CANONICAL_TO_DISPLAY[cls]);
  });

  it('does not classify Conflicting as Pathogenic (issue #607)', () => {
    expect(normalizeClassification('Conflicting classifications of pathogenicity')).toBe(
      'Conflicting'
    );
  });

  it('maps an unrecognised term to other, never to an ACMG tier', () => {
    vi.spyOn(console, 'warn').mockImplementation(() => {});
    expect(normalizeClassification('Brand new 2027 term')).toBe('other');
  });

  it('assigns Conflicting the shared purple token', () => {
    expect(PATHOGENICITY_COLORS.Conflicting).toBe('#6f42c1');
  });
});

describe('PATHOGENICITY_SEVERITY', () => {
  it('ranks other lowest and Pathogenic highest', () => {
    expect(PATHOGENICITY_SEVERITY[0]).toBe('other');
    expect(PATHOGENICITY_SEVERITY[PATHOGENICITY_SEVERITY.length - 1]).toBe('Pathogenic');
  });

  it('ranks Conflicting above Benign and below Uncertain significance', () => {
    const idx = (cls: string) => PATHOGENICITY_SEVERITY.indexOf(cls as never);
    expect(idx('Conflicting')).toBeGreaterThan(idx('Likely benign'));
    expect(idx('Conflicting')).toBeLessThan(idx('Uncertain significance'));
  });

  it('lists every PathogenicityClass exactly once', () => {
    expect(new Set(PATHOGENICITY_SEVERITY).size).toBe(PATHOGENICITY_SEVERITY.length);
    expect(PATHOGENICITY_SEVERITY).toHaveLength(Object.keys(PATHOGENICITY_COLORS).length);
  });
});

describe('aggregateVariantsByPosition', () => {
  it('does not let an "other" variant dominate a Pathogenic position', () => {
    const result = aggregateVariantsByPosition([
      variant({ classification: 'Pathogenic' }),
      variant({ classification: 'other' }),
    ]);
    expect(result[0].dominantClass).toBe('Pathogenic');
  });

  it('reports Conflicting as dominant when it is the most severe present', () => {
    const result = aggregateVariantsByPosition([
      variant({ classification: 'Conflicting' }),
      variant({ classification: 'Benign' }),
    ]);
    expect(result[0].dominantClass).toBe('Conflicting');
    expect(result[0].countByClass.Conflicting).toBe(1);
  });
});
```

- [ ] **Step 2: Run the test and verify it fails**

Run: `cd app && npx vitest run src/types/protein.spec.ts`
Expected: FAIL — `normalizeClassification('Conflicting classifications of pathogenicity')` returns `'Pathogenic'`, and `PATHOGENICITY_COLORS.Conflicting` is `undefined`.

- [ ] **Step 3: Extend the type, colours and filter state**

In `app/src/types/protein.ts`, replace the `PathogenicityClass` union (line ~13) with:

```ts
export type PathogenicityClass =
  | 'Pathogenic'
  | 'Likely pathogenic'
  | 'Uncertain significance'
  | 'Likely benign'
  | 'Benign'
  | 'Conflicting'
  | 'other';
```

Replace `PATHOGENICITY_COLORS` (line ~58) with:

```ts
export const PATHOGENICITY_COLORS: Record<PathogenicityClass, string> = {
  Pathogenic: '#d73027',
  'Likely pathogenic': '#fc8d59',
  'Uncertain significance': '#fee08b',
  'Likely benign': '#91cf60',
  Benign: '#1a9850',
  // Submitters disagree — deliberately outside the red→green ramp.
  // #6f42c1 is the shared $purple token (app/src/assets/scss/_variables.scss).
  Conflicting: '#6f42c1',
  other: '#999999',
} as const;
```

In `LollipopFilterState` (line ~132), add the two new keys after `benign`:

```ts
  /** Show Benign variants */
  benign: boolean;
  /** Show variants where ClinVar submitters conflict */
  conflicting: boolean;
  /** Show variants whose significance is not an ACMG tier (or unrecognised) */
  other: boolean;
```

- [ ] **Step 4: Fix the severity order and the aggregation bucket**

Replace `PATHOGENICITY_SEVERITY` (line ~176):

```ts
/**
 * Pathogenicity severity order (higher index = more severe).
 * Used to pick the dominant class when aggregating a position.
 *
 * `other` is LEAST severe. It previously sat at the top, so a single
 * unrecognised variant hijacked the colour of an entire aggregated position —
 * the same "unknown term lands in a severe bucket" defect as issue #607, one
 * layer down. `Conflicting` sits just below VUS: a position holding both a
 * Pathogenic and a Conflicting still renders Pathogenic.
 */
export const PATHOGENICITY_SEVERITY: PathogenicityClass[] = [
  'other',
  'Benign',
  'Likely benign',
  'Conflicting',
  'Uncertain significance',
  'Likely pathogenic',
  'Pathogenic',
];
```

In `aggregateVariantsByPosition` (line ~207), add the bucket to the `countByClass` initializer:

```ts
    const countByClass: Record<PathogenicityClass, number> = {
      Pathogenic: 0,
      'Likely pathogenic': 0,
      'Uncertain significance': 0,
      'Likely benign': 0,
      Benign: 0,
      Conflicting: 0,
      other: 0,
    };
```

- [ ] **Step 5: Replace `normalizeClassification` with the adapter**

Replace the whole function (lines ~272-317):

```ts
/**
 * Map a raw gnomAD/ClinVar `clinical_significance` string to a
 * `PathogenicityClass` for plot colouring and filtering.
 *
 * Thin adapter over the shared table-driven vocabulary — see
 * `clinvarSignificance.ts` for why substring matching is forbidden here
 * (issue #607). Recognised non-ACMG terms and unrecognised terms both land in
 * `'other'`; the shared normalizer logs the unrecognised ones.
 *
 * @param raw - Raw clinical_significance string from the gnomAD API
 * @returns Normalized PathogenicityClass
 */
export function normalizeClassification(raw: unknown): PathogenicityClass {
  switch (normalizeClinVarSignificance(raw)) {
    case 'pathogenic':
      return 'Pathogenic';
    case 'likely_pathogenic':
      return 'Likely pathogenic';
    case 'vus':
      return 'Uncertain significance';
    case 'likely_benign':
      return 'Likely benign';
    case 'benign':
      return 'Benign';
    case 'conflicting':
      return 'Conflicting';
    default:
      return 'other';
  }
}
```

Add the import at the top of the file:

```ts
import { normalizeClinVarSignificance } from './clinvarSignificance';
```

- [ ] **Step 6: Run the tests and verify they pass**

Run: `cd app && npx vitest run src/types/protein.spec.ts && npx vue-tsc --noEmit -p tsconfig.app.json`
Expected: spec PASS. `vue-tsc` will now report errors in the consumer files that build exhaustive `Record<PathogenicityClass, …>` or `LollipopFilterState` literals — those are Tasks 5 and 6. Note them; do not fix them here.

- [ ] **Step 7: Commit**

```bash
git add app/src/types/protein.ts app/src/types/protein.spec.ts
git commit -m "fix(app): route normalizeClassification through the shared ClinVar table (#607)"
```

---

### Task 3: `alphafold.ts` adapter and the `conflicting` ACMG key

**Files:**
- Modify: `app/src/types/alphafold.ts` (`ACMG_COLORS`, `ACMG_LABELS`, `classifyClinicalSignificance`)
- Test: `app/src/types/alphafold.spec.ts` (create)

**Interfaces:**
- Consumes: `normalizeClinVarSignificance` from Task 1.
- Produces: `AcmgClassification` now includes `'conflicting'`; `classifyClinicalSignificance(raw: unknown): AcmgClassification | null` where `other`/`unknown` still yield `null`.

- [ ] **Step 1: Write the failing test**

`app/src/types/alphafold.spec.ts`:

```ts
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { describe, expect, it, vi } from 'vitest';

import { ACMG_COLORS, ACMG_LABELS, classifyClinicalSignificance } from './alphafold';
import type { ClinVarSignificanceClass } from './clinvarSignificance';

const fixture: {
  terms: Array<{ raw: string; class: ClinVarSignificanceClass }>;
} = JSON.parse(
  readFileSync(
    fileURLToPath(
      new URL('../../../api/tests/testthat/fixtures/clinvar-significance-vocabulary.json', import.meta.url)
    ),
    'utf-8'
  )
);

describe('classifyClinicalSignificance', () => {
  it.each(fixture.terms)('maps $raw to $class or null', ({ raw, class: cls }) => {
    const expected = cls === 'other' || cls === 'unknown' ? null : cls;
    expect(classifyClinicalSignificance(raw)).toBe(expected);
  });

  it('does not classify Conflicting as pathogenic (issue #607)', () => {
    expect(classifyClinicalSignificance('Conflicting classifications of pathogenicity')).toBe(
      'conflicting'
    );
  });

  it('resolves Pathogenic/Likely pathogenic to pathogenic, matching the server', () => {
    expect(classifyClinicalSignificance('Pathogenic/Likely pathogenic')).toBe('pathogenic');
    expect(classifyClinicalSignificance('Pathogenic/Likely_pathogenic')).toBe('pathogenic');
  });

  it('returns null for unrecognised terms', () => {
    vi.spyOn(console, 'warn').mockImplementation(() => {});
    expect(classifyClinicalSignificance('Brand new 2027 term')).toBeNull();
  });

  it('gives conflicting a colour and a label', () => {
    expect(ACMG_COLORS.conflicting).toBe('#6f42c1');
    expect(ACMG_LABELS.conflicting).toBe('Conflicting');
  });
});
```

- [ ] **Step 2: Run the test and verify it fails**

Run: `cd app && npx vitest run src/types/alphafold.spec.ts`
Expected: FAIL — conflicting classifies as `'pathogenic'`, `ACMG_COLORS.conflicting` is `undefined`, and `Pathogenic/Likely pathogenic` returns `'likely_pathogenic'`.

- [ ] **Step 3: Extend the palette and labels**

In `app/src/types/alphafold.ts`, replace `ACMG_COLORS` (line ~67) and `ACMG_LABELS` (line ~78):

```ts
export const ACMG_COLORS = {
  pathogenic: '#dc3545',
  likely_pathogenic: '#fd7e14',
  vus: '#ffc107',
  likely_benign: '#20c997',
  benign: '#28a745',
  // Shared $purple token — deliberately outside the pathogenicity ramp.
  conflicting: '#6f42c1',
} as const;

/**
 * ACMG pathogenicity classification text labels
 */
export const ACMG_LABELS = {
  pathogenic: 'Pathogenic',
  likely_pathogenic: 'Likely Pathogenic',
  vus: 'VUS',
  likely_benign: 'Likely Benign',
  benign: 'Benign',
  conflicting: 'Conflicting',
} as const;
```

- [ ] **Step 4: Replace `classifyClinicalSignificance` with the adapter**

Replace the doc block and function (lines ~204-239):

```ts
/**
 * Classify a ClinVar `clinical_significance` string for the 3D viewer.
 *
 * Thin adapter over the shared table-driven vocabulary — see
 * `clinvarSignificance.ts` for why substring matching is forbidden here
 * (issue #607). Recognised non-ACMG terms (`not provided`, `drug response`, …)
 * and unrecognised terms both return `null`; the caller renders those gray and
 * labels them with the raw string, which is genuinely informative.
 *
 * `Pathogenic/Likely pathogenic` resolves to `pathogenic`, matching the server
 * and the lollipop. This function previously downgraded it to
 * `likely_pathogenic`, which is why the 3D viewer and the lollipop reported
 * different P/LP splits for identical input.
 *
 * @param significance - ClinVar clinical_significance string
 * @returns ACMG classification, or null when the term is not a tier
 *
 * @example
 * classifyClinicalSignificance("Pathogenic")  // → "pathogenic"
 * classifyClinicalSignificance("Conflicting classifications of pathogenicity")  // → "conflicting"
 * classifyClinicalSignificance("not provided")  // → null
 */
export function classifyClinicalSignificance(significance: unknown): AcmgClassification | null {
  switch (normalizeClinVarSignificance(significance)) {
    case 'pathogenic':
      return 'pathogenic';
    case 'likely_pathogenic':
      return 'likely_pathogenic';
    case 'vus':
      return 'vus';
    case 'likely_benign':
      return 'likely_benign';
    case 'benign':
      return 'benign';
    case 'conflicting':
      return 'conflicting';
    default:
      return null;
  }
}
```

Add the import at the top of the file:

```ts
import { normalizeClinVarSignificance } from './clinvarSignificance';
```

- [ ] **Step 5: Run the test and verify it passes**

Run: `cd app && npx vitest run src/types/alphafold.spec.ts`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add app/src/types/alphafold.ts app/src/types/alphafold.spec.ts
git commit -m "fix(app): route classifyClinicalSignificance through the shared ClinVar table (#607)"
```

---

### Task 4: R normalizer becomes table-driven; `conflicting` becomes a primary class

**Files:**
- Modify: `api/functions/external-proxy-gnomad.R` (`clinvar_primary_classes`, `normalize_clinvar_classification`)
- Test: `api/tests/testthat/test-unit-gnomad-clinvar-summary.R`

**Interfaces:**
- Consumes: `api/tests/testthat/fixtures/clinvar-significance-vocabulary.json` from Task 1.
- Produces: `summarise_gnomad_clinvar_variants()` returns `counts$conflicting` and `class_breakdowns$conflicting`; `normalize_clinvar_classification()` returns one of the six primary keys or `other:<sanitized>`.

- [ ] **Step 1: Write the failing test**

Append to `api/tests/testthat/test-unit-gnomad-clinvar-summary.R`, and change the existing `other_classifications` assertion:

```r
describe("normalize_clinvar_classification", {
  vocabulary_path <- testthat::test_path("fixtures", "clinvar-significance-vocabulary.json")
  vocabulary <- jsonlite::fromJSON(vocabulary_path, simplifyVector = FALSE)

  it("matches the shared cross-language vocabulary fixture", {
    for (entry in c(vocabulary$terms, vocabulary$normalization_variants)) {
      expected <- switch(entry$class,
        pathogenic = "pathogenic",
        likely_pathogenic = "likely_pathogenic",
        vus = "vus",
        likely_benign = "likely_benign",
        benign = "benign",
        conflicting = "conflicting",
        NA_character_
      )

      actual <- normalize_clinvar_classification(entry$raw)

      if (is.na(expected)) {
        expect_true(
          startsWith(actual, "other:"),
          info = paste0(entry$raw, " should be an other:* key, got ", actual)
        )
      } else {
        expect_equal(actual, expected, info = entry$raw)
      }
    }
  })

  it("never routes an unrecognised term into a primary class", {
    primary_keys <- names(clinvar_primary_classes)
    for (raw in vocabulary$unknown_terms) {
      actual <- normalize_clinvar_classification(raw)
      expect_false(actual %in% primary_keys, info = paste0(raw, " -> ", actual))
      expect_true(startsWith(actual, "other:"), info = paste0(raw, " -> ", actual))
    }
  })

  it("does not classify a conflicting term as pathogenic (issue #607)", {
    expect_equal(
      normalize_clinvar_classification("Conflicting classifications of pathogenicity"),
      "conflicting"
    )
    expect_equal(
      normalize_clinvar_classification("Conflicting_interpretations_of_pathogenicity"),
      "conflicting"
    )
  })

  it("handles NULL, NA and empty input", {
    expect_equal(normalize_clinvar_classification(NULL), "other:unknown")
    expect_equal(normalize_clinvar_classification(NA), "other:unknown")
    expect_equal(normalize_clinvar_classification(""), "other:unknown")
  })
})
```

In the existing `describe("summarise_gnomad_clinvar_variants", …)` block, replace the
`"keeps unmapped classifications visible outside the five primary chips"` test with:

```r
  it("counts conflicting classifications as a primary class", {
    summary <- summarise_gnomad_clinvar_variants(clinvar_fixture)

    expect_equal(summary$counts$conflicting, 1)
    expect_equal(summary$class_breakdowns$conflicting$label, "Conflicting classifications")
    expect_equal(summary$class_breakdowns$conflicting$short_label, "CONF")
    expect_equal(summary$class_breakdowns$conflicting$count, 1)
  })

  it("keeps unmapped classifications visible outside the primary chips", {
    summary <- summarise_gnomad_clinvar_variants(clinvar_fixture)

    expect_null(summary$other_classifications$conflicting_classifications_of_pathogenicity)
    expect_equal(summary$other_classifications$not_provided, 1)
  })
```

- [ ] **Step 2: Run the test and verify it fails**

Run: `cd api && Rscript -e "testthat::test_file('tests/testthat/test-unit-gnomad-clinvar-summary.R')"`
Expected: FAIL — `summary$counts$conflicting` is `NULL`, and the fixture file / `conflicting` key do not exist yet.

- [ ] **Step 3: Add `conflicting` as a primary class**

In `api/functions/external-proxy-gnomad.R`, replace `clinvar_primary_classes` (line ~303):

```r
clinvar_primary_classes <- list(
  pathogenic = list(label = "Pathogenic", short_label = "P"),
  likely_pathogenic = list(label = "Likely pathogenic", short_label = "LP"),
  conflicting = list(label = "Conflicting classifications", short_label = "CONF"),
  vus = list(label = "VUS", short_label = "VUS"),
  likely_benign = list(label = "Likely benign", short_label = "LB"),
  benign = list(label = "Benign", short_label = "B")
)
```

- [ ] **Step 4: Replace the normalizer with the exact-match table**

Replace `normalize_clinvar_classification()` (lines ~330-370):

```r
#' Canonical ClinVar clinical-significance vocabulary
#'
#' Mirrors `CLINVAR_SIGNIFICANCE_TABLE` in `app/src/types/clinvarSignificance.ts`.
#' Both are driven in test by
#' `api/tests/testthat/fixtures/clinvar-significance-vocabulary.json`; keep the
#' three in sync.
#'
#' Keys are already normalized (underscores to spaces, lowercase, single-spaced).
#' Combined pairs resolve to the MORE SEVERE member.
clinvar_significance_table <- c(
  "pathogenic"                                   = "pathogenic",
  "pathogenic/likely pathogenic"                 = "pathogenic",
  "pathogenic, low penetrance"                   = "pathogenic",

  "likely pathogenic"                            = "likely_pathogenic",
  "likely pathogenic, low penetrance"            = "likely_pathogenic",

  "uncertain significance"                       = "vus",

  "likely benign"                                = "likely_benign",
  "benign/likely benign"                         = "likely_benign",

  "benign"                                       = "benign",

  "conflicting classifications of pathogenicity" = "conflicting",
  "conflicting interpretations of pathogenicity" = "conflicting",

  "not provided"                                 = "other:not_provided",
  "no classification provided"                   = "other:no_classification_provided",
  "no classifications from unflagged records"    = "other:no_classifications_from_unflagged_records",
  "no classification for the single variant"     = "other:no_classification_for_the_single_variant",
  "drug response"                                = "other:drug_response",
  "risk factor"                                  = "other:risk_factor",
  "association"                                  = "other:association",
  "association not found"                        = "other:association_not_found",
  "protective"                                   = "other:protective",
  "affects"                                      = "other:affects",
  "confers sensitivity"                          = "other:confers_sensitivity",
  "established risk allele"                      = "other:established_risk_allele",
  "likely risk allele"                           = "other:likely_risk_allele",
  "uncertain risk allele"                        = "other:uncertain_risk_allele",
  "other"                                        = "other:other"
)

#' Normalize ClinVar clinical significance for compact summary chips
#'
#' ClinVar `clinical_significance` is a controlled vocabulary, so it is matched
#' by EXACT string equality against `clinvar_significance_table` after one
#' normalization step. Substring matching (`grepl`) silently misfiles every new
#' or unanticipated term into whichever branch its substrings happen to hit —
#' `"Conflicting classifications of pathogenicity"` contains `"pathogenic"`,
#' which is how the client counted it as Pathogenic (issue #607). Do not
#' reintroduce a `grepl()` fallback here.
#'
#' @param significance ClinVar clinical significance string
#' @return One of the primary class keys or an `other:*` key
#' @export
normalize_clinvar_classification <- function(significance) {
  if (is.null(significance) || length(significance) == 0) {
    return("other:unknown")
  }

  significance <- significance[[1]]

  if (is.na(significance)) {
    return("other:unknown")
  }

  key <- gsub("_", " ", tolower(as.character(significance)), fixed = TRUE)
  key <- trimws(gsub("\\s+", " ", key))

  if (identical(key, "")) {
    return("other:unknown")
  }

  mapped <- clinvar_significance_table[[key]]
  if (!is.null(mapped)) {
    return(mapped)
  }

  paste0("other:", sanitize_summary_key(key))
}
```

- [ ] **Step 5: Run the tests and verify they pass**

Run: `cd api && Rscript -e "testthat::test_file('tests/testthat/test-unit-gnomad-clinvar-summary.R')"`
Expected: PASS, including the pre-existing consequence and quality-count tests.

- [ ] **Step 6: Lint and commit**

```bash
make lint-api
git add api/functions/external-proxy-gnomad.R api/tests/testthat/test-unit-gnomad-clinvar-summary.R
git commit -m "fix(api): make ClinVar significance normalization table-driven; promote conflicting (#607)"
```

---

### Task 5: Protein lollipop surface — Conflicting + Other chips

**Files:**
- Modify: `app/src/composables/d3-lollipop/lollipop-helpers.ts` (`isClassificationVisible`)
- Modify: `app/src/components/gene/proteinLollipopControls.ts` (`PathogenicityFilterKey`, `selectOnlyPathogenicity`, `selectAllPathogenicity`)
- Modify: `app/src/components/gene/ProteinDomainLollipopPlot.vue` (initial `filterState`, `legendItems`)
- Test: `app/src/components/gene/proteinLollipopControls.spec.ts`

**Interfaces:**
- Consumes: `PathogenicityClass` with `'Conflicting'` and `LollipopFilterState` with `conflicting`/`other` (Task 2).
- Produces: `PathogenicityFilterKey` gains `'conflicting' | 'other'`.

- [ ] **Step 1: Write the failing test**

Append to `app/src/components/gene/proteinLollipopControls.spec.ts`:

```ts
import { isClassificationVisible } from '@/composables/d3-lollipop/lollipop-helpers';

describe('conflicting + other pathogenicity filters (#607)', () => {
  function state(overrides: Partial<LollipopFilterState> = {}): LollipopFilterState {
    return {
      pathogenic: true,
      likelyPathogenic: true,
      vus: true,
      likelyBenign: true,
      benign: true,
      conflicting: true,
      other: true,
      effectFilters: {
        missense: true,
        frameshift: true,
        stop_gained: true,
        splice: true,
        inframe_indel: true,
        synonymous: true,
        other: true,
      },
      coloringMode: 'acmg',
      ...overrides,
    };
  }

  it('hides Conflicting variants when the conflicting filter is off', () => {
    expect(isClassificationVisible('Conflicting', state())).toBe(true);
    expect(isClassificationVisible('Conflicting', state({ conflicting: false }))).toBe(false);
  });

  it('does not hide Conflicting variants when the pathogenic filter is off', () => {
    expect(isClassificationVisible('Conflicting', state({ pathogenic: false }))).toBe(true);
  });

  it('routes "other" through its own filter key', () => {
    expect(isClassificationVisible('other', state({ other: false }))).toBe(false);
  });

  it('counts Conflicting variants under their own key', () => {
    const counts = countByClassification([
      { classification: 'Conflicting' },
      { classification: 'Conflicting' },
      { classification: 'Pathogenic' },
    ] as ProcessedVariant[]);
    expect(counts['Conflicting']).toBe(2);
    expect(counts['Pathogenic']).toBe(1);
  });

  it('selectOnly and selectAll cover conflicting and other', () => {
    const s = state();
    selectOnlyPathogenicity(s, 'conflicting');
    expect(s.conflicting).toBe(true);
    expect(s.pathogenic).toBe(false);
    expect(s.other).toBe(false);

    selectAllPathogenicity(s);
    expect(s.conflicting).toBe(true);
    expect(s.other).toBe(true);
    expect(s.benign).toBe(true);
  });
});
```

Add `import type { LollipopFilterState, ProcessedVariant } from '@/types/protein';` to the spec's imports if it is not already present.

- [ ] **Step 2: Run the test and verify it fails**

Run: `cd app && npx vitest run src/components/gene/proteinLollipopControls.spec.ts`
Expected: FAIL — `isClassificationVisible('Conflicting', …)` returns `true` unconditionally via the `default` branch, and `selectOnlyPathogenicity` does not touch the new keys.

- [ ] **Step 3: Extend `isClassificationVisible`**

In `app/src/composables/d3-lollipop/lollipop-helpers.ts`, replace the switch (line ~41):

```ts
  switch (classification) {
    case 'Pathogenic':
      return filterState.pathogenic;
    case 'Likely pathogenic':
      return filterState.likelyPathogenic;
    case 'Uncertain significance':
      return filterState.vus;
    case 'Likely benign':
      return filterState.likelyBenign;
    case 'Benign':
      return filterState.benign;
    case 'Conflicting':
      return filterState.conflicting ?? true;
    default:
      // 'other' — recognised non-ACMG terms and unrecognised terms.
      // `?? true` keeps a caller that supplies a partial filter state working.
      return filterState.other ?? true;
  }
```

- [ ] **Step 4: Extend the control helpers**

In `app/src/components/gene/proteinLollipopControls.ts`:

```ts
export type PathogenicityFilterKey =
  | 'pathogenic'
  | 'likelyPathogenic'
  | 'vus'
  | 'likelyBenign'
  | 'benign'
  | 'conflicting'
  | 'other';
```

```ts
export function selectOnlyPathogenicity(
  filterState: LollipopFilterState,
  key: PathogenicityFilterKey
): void {
  filterState.pathogenic = key === 'pathogenic';
  filterState.likelyPathogenic = key === 'likelyPathogenic';
  filterState.vus = key === 'vus';
  filterState.likelyBenign = key === 'likelyBenign';
  filterState.benign = key === 'benign';
  filterState.conflicting = key === 'conflicting';
  filterState.other = key === 'other';
}

export function selectAllPathogenicity(filterState: LollipopFilterState): void {
  filterState.pathogenic = true;
  filterState.likelyPathogenic = true;
  filterState.vus = true;
  filterState.likelyBenign = true;
  filterState.benign = true;
  filterState.conflicting = true;
  filterState.other = true;
}
```

- [ ] **Step 5: Wire the plot's state and legend**

In `app/src/components/gene/ProteinDomainLollipopPlot.vue`, add the two keys to the reactive
`filterState` initializer (the block ending at line ~123), both `true` — this surface shows every
category by default:

```ts
  benign: true,
  conflicting: true,
  other: true,
  effectFilters: {
```

Then append to the array returned by `legendItems` (line ~152), after the `benign` entry:

```ts
    {
      key: 'conflicting' as const,
      label: 'Conflicting',
      color: PATHOGENICITY_COLORS['Conflicting'],
      visible: filterState.conflicting,
      count: counts['Conflicting'] || 0,
    },
```

and, because `other` is only meaningful when present, build the list conditionally by replacing the
final `];` of that computed with:

```ts
  ];

  const otherCount = counts['other'] || 0;
  if (otherCount > 0) {
    items.push({
      key: 'other' as const,
      label: 'Other',
      color: PATHOGENICITY_COLORS['other'],
      visible: filterState.other,
      count: otherCount,
    });
  }

  return items;
});
```

changing the computed's opening from `return [` to `const items = [` so the array can be extended.

- [ ] **Step 6: Run the tests and verify they pass**

Run: `cd app && npx vitest run src/components/gene/proteinLollipopControls.spec.ts src/components/gene/ProteinLollipopControlsPanel.spec.ts`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add app/src/composables/d3-lollipop/lollipop-helpers.ts \
        app/src/components/gene/proteinLollipopControls.ts \
        app/src/components/gene/proteinLollipopControls.spec.ts \
        app/src/components/gene/ProteinDomainLollipopPlot.vue
git commit -m "feat(app): add Conflicting and Other filter chips to the protein lollipop (#607)"
```

---

### Task 6: Gene-structure plot surface

**Files:**
- Modify: `app/src/components/gene/GeneStructurePlotWithVariants.vue` (`filterState`, `filterItems`, `isVariantVisible`, `selectOnlyPathogenicity`/`selectAll` handlers)
- Test: `app/src/components/gene/geneStructureVariantPlotUtils.spec.ts`

**Interfaces:**
- Consumes: `PathogenicityClass` with `'Conflicting'` (Task 2), `PathogenicityLegendRow` (already exported by `GeneStructurePlotControls.vue`).
- Produces: nothing new for other tasks.

- [ ] **Step 1: Write the failing test**

Append to `app/src/components/gene/geneStructureVariantPlotUtils.spec.ts`:

```ts
describe('conflicting visibility (#607)', () => {
  const effectFilters = {
    missense: true,
    frameshift: true,
    stop_gained: true,
    splice: true,
    inframe_indel: true,
    synonymous: true,
    other: true,
  };

  const conflicting = {
    genomicPosition: 2000,
    classification: 'Conflicting',
    majorConsequence: 'missense_variant',
  };

  it('hides Conflicting variants when the Conflicting filter is off', () => {
    expect(
      isGeneStructureVariantVisible(conflicting, {
        pathogenicity: { Pathogenic: true, 'Likely pathogenic': true, Conflicting: false },
        effectFilters,
      })
    ).toBe(false);
  });

  it('shows Conflicting variants when the Conflicting filter is on', () => {
    expect(
      isGeneStructureVariantVisible(conflicting, {
        pathogenicity: { Pathogenic: false, Conflicting: true },
        effectFilters,
      })
    ).toBe(true);
  });

  it('aggregates Conflicting under its own classification key', () => {
    const result = aggregateVariantsByGenomicPosition(
      [conflicting, { ...conflicting, genomicPosition: 2010 }],
      100000
    );
    expect(result[0].classifications.Conflicting).toBe(2);
    expect(result[0].dominantClassification).toBe('Conflicting');
  });
});
```

- [ ] **Step 2: Run the test and verify it fails**

Run: `cd app && npx vitest run src/components/gene/geneStructureVariantPlotUtils.spec.ts`
Expected: FAIL on the first case — the `?? true` fallback makes an absent-then-false key resolve
inconsistently once `Conflicting` is passed explicitly. (If it passes because the map already
carries the key, the remaining component wiring below is still required.)

- [ ] **Step 3: Add the filter keys and chips**

In `app/src/components/gene/GeneStructurePlotWithVariants.vue`, extend the reactive `filterState`
(line ~99). Both new keys default to **`false`**, matching this surface's existing P/LP-only posture:

```ts
  vus: false,
  likelyBenign: false,
  benign: false,
  conflicting: false,
  other: false,
```

Extend `filterItems` (line ~160). Insert the Conflicting row after `benign`, and append the Other
row only when it has a count, by changing the computed's `return [ … ];` into
`const items = [ … ];` plus:

```ts
    {
      key: 'conflicting' as const,
      label: 'Conflicting',
      color: PATHOGENICITY_COLORS['Conflicting'],
      visible: filterState.conflicting,
      count: counts['Conflicting'] || 0,
    },
  ];

  const otherCount = counts['other'] || 0;
  if (otherCount > 0) {
    items.push({
      key: 'other' as const,
      label: 'Other',
      color: PATHOGENICITY_COLORS['other'],
      visible: filterState.other,
      count: otherCount,
    });
  }

  return items;
});
```

Extend `isVariantVisible` (line ~310):

```ts
function isVariantVisible(variant: GenomicVariant): boolean {
  return isGeneStructureVariantVisible(variant, {
    pathogenicity: {
      Pathogenic: filterState.pathogenic,
      'Likely pathogenic': filterState.likelyPathogenic,
      'Uncertain significance': filterState.vus,
      'Likely benign': filterState.likelyBenign,
      Benign: filterState.benign,
      Conflicting: filterState.conflicting,
      other: filterState.other,
    },
    effectFilters: filterState.effectFilters,
  });
}
```

Extend this component's local `selectOnlyPathogenicity` and `selectAllPathogenicity` handlers to set
`filterState.conflicting` and `filterState.other` the same way Task 5 does for the lollipop (search
the file for the existing five assignments and add the two new lines to each).

- [ ] **Step 4: Run the tests and verify they pass**

Run: `cd app && npx vitest run src/components/gene/geneStructureVariantPlotUtils.spec.ts src/components/gene/GeneStructurePlotControls.spec.ts`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add app/src/components/gene/GeneStructurePlotWithVariants.vue \
        app/src/components/gene/geneStructureVariantPlotUtils.spec.ts
git commit -m "feat(app): add Conflicting and Other filters to the gene structure plot (#607)"
```

---

### Task 7: 3D VariantPanel surface

**Files:**
- Modify: `app/src/components/gene/variantPanelData.ts` (`VariantFilterKey`, `classificationToFilterKey`, `countByClassification`, `filterMappableVariants`, `getHiddenClassifications`, `selectOnly`, `selectAll`)
- Modify: `app/src/components/gene/VariantPanel.vue` (`filterState` initializer, `legendItems`)
- Test: `app/src/components/gene/variantPanelData.spec.ts`

**Interfaces:**
- Consumes: `AcmgClassification` with `'conflicting'` (Task 3).
- Produces: `VariantFilterKey` gains `'conflicting'`.

- [ ] **Step 1: Write the failing test**

Append to `app/src/components/gene/variantPanelData.spec.ts`:

```ts
describe('conflicting classification (#607)', () => {
  const conflictingVariant = {
    hgvsp: 'p.Gly530Ser',
    hgvsc: 'c.1588G>A',
    variant_id: '5-141330000-C-T',
    clinical_significance: 'Conflicting classifications of pathogenicity',
    clinvar_variation_id: '2138035',
    review_status: 'criteria provided, conflicting classifications',
    gold_stars: 1,
    major_consequence: 'missense_variant',
    in_gnomad: true,
  } as unknown as ClinVarVariant;

  const fullState: VariantFilterState = {
    pathogenic: true,
    likelyPathogenic: true,
    vus: true,
    likelyBenign: true,
    benign: true,
    conflicting: true,
  };

  it('classifies VCV002138035 as conflicting, not pathogenic', () => {
    const [item] = buildMappableVariants([conflictingVariant]);
    expect(item.classification).toBe('conflicting');
    expect(item.color).toBe('#6f42c1');
    expect(item.label).toBe('Conflicting');
  });

  it('counts it under conflicting', () => {
    const counts = countByClassification(buildMappableVariants([conflictingVariant]));
    expect(counts.conflicting).toBe(1);
    expect(counts.pathogenic).toBe(0);
  });

  it('hides it when the conflicting filter is off', () => {
    const items = buildMappableVariants([conflictingVariant]);
    expect(filterMappableVariants(items, fullState, '')).toHaveLength(1);
    expect(
      filterMappableVariants(items, { ...fullState, conflicting: false }, '')
    ).toHaveLength(0);
  });

  it('reports conflicting in the hidden-classification list', () => {
    expect(getHiddenClassifications({ ...fullState, conflicting: false })).toContain('conflicting');
    expect(getHiddenClassifications(fullState)).not.toContain('conflicting');
  });

  it('selectOnly and selectAll cover conflicting', () => {
    const s = { ...fullState };
    selectOnly(s, 'conflicting');
    expect(s.conflicting).toBe(true);
    expect(s.pathogenic).toBe(false);
    selectAll(s);
    expect(s.conflicting).toBe(true);
  });
});
```

- [ ] **Step 2: Run the test and verify it fails**

Run: `cd app && npx vitest run src/components/gene/variantPanelData.spec.ts`
Expected: FAIL — `item.classification` is `'pathogenic'`.

- [ ] **Step 3: Extend `variantPanelData.ts`**

```ts
export type VariantFilterKey =
  | 'pathogenic'
  | 'likelyPathogenic'
  | 'vus'
  | 'likelyBenign'
  | 'benign'
  | 'conflicting';

export const classificationToFilterKey: Record<AcmgClassification, VariantFilterKey> = {
  pathogenic: 'pathogenic',
  likely_pathogenic: 'likelyPathogenic',
  vus: 'vus',
  likely_benign: 'likelyBenign',
  benign: 'benign',
  conflicting: 'conflicting',
};
```

In `countByClassification`, add `conflicting: 0` to the initializer. In `getHiddenClassifications`,
add `if (!filterState.conflicting) hidden.push('conflicting');`. In `selectOnly`, add
`filterState.conflicting = key === 'conflicting';`. In `selectAll`, add
`filterState.conflicting = true;`.

Replace the no-op `else` in `filterMappableVariants` (line ~120) with an explicit comment — the
behaviour is intentional, but a silent empty block reads as an oversight:

```ts
    if (item.classification) {
      const filterKey = classificationToFilterKey[item.classification];
      if (!filterState[filterKey]) return false;
    }
    // Unclassified variants (recognised non-ACMG terms such as "drug response",
    // and unrecognised terms) have no filter chip and are always listed, with
    // their raw significance string as the label. Intentional: this panel is a
    // manual pick-list, not a density plot.
```

- [ ] **Step 4: Wire the panel's state and legend**

In `app/src/components/gene/VariantPanel.vue`, add `conflicting: true` to the reactive `filterState`
initializer, and append to `legendItems` (line ~211) after the `benign` entry:

```ts
    {
      key: 'conflicting' as const,
      label: 'Conf',
      color: ACMG_COLORS.conflicting,
      visible: filterState.conflicting,
      count: counts.conflicting,
    },
```

- [ ] **Step 5: Run the tests and verify they pass**

Run: `cd app && npx vitest run src/components/gene/variantPanelData.spec.ts src/components/gene/VariantPanel.spec.ts`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add app/src/components/gene/variantPanelData.ts \
        app/src/components/gene/variantPanelData.spec.ts \
        app/src/components/gene/VariantPanel.vue
git commit -m "feat(app): add a Conflicting filter to the 3D variant panel (#607)"
```

---

### Task 8: ClinVar card — Conflicting chip and shared-normalizer fallback

**Files:**
- Modify: `app/src/composables/useGeneClinVarCounts.ts` (`ClinVarClassificationCounts`)
- Modify: `app/src/components/gene/GeneClinVarCard.vue` (`ClinVarCounts`, `counts` fallback, `chipMeta`, `.clinvar-chip--conf`)
- Test: `app/src/components/gene/GeneClinVarCard.spec.ts`

**Interfaces:**
- Consumes: `normalizeClinVarSignificance` (Task 1), the server's `counts.conflicting` (Task 4).
- Produces: nothing new for other tasks.

- [ ] **Step 1: Write the failing test**

Append to `app/src/components/gene/GeneClinVarCard.spec.ts`:

```ts
describe('conflicting classifications (#607)', () => {
  it('renders a CONF chip from the server counts', () => {
    const wrapper = mount(GeneClinVarCard, {
      props: {
        geneSymbol: 'PCDH12',
        loading: false,
        error: null,
        counts: {
          pathogenic: 18,
          likely_pathogenic: 13,
          vus: 261,
          likely_benign: 145,
          benign: 37,
          conflicting: 28,
        },
        totalCount: 503,
      },
    });

    expect(wrapper.text()).toContain('CONF 28');
    expect(wrapper.text()).toContain('P 18');
  });

  it('does not count conflicting variants as pathogenic in the fallback path', () => {
    const wrapper = mount(GeneClinVarCard, {
      props: {
        geneSymbol: 'PCDH12',
        loading: false,
        error: null,
        data: [
          { clinical_significance: 'Pathogenic' },
          { clinical_significance: 'Conflicting classifications of pathogenicity' },
          { clinical_significance: 'Conflicting classifications of pathogenicity' },
        ] as never,
      },
    });

    expect(wrapper.text()).toContain('P 1');
    expect(wrapper.text()).toContain('CONF 2');
    expect(wrapper.text()).not.toContain('P 3');
  });

  it('omits the CONF chip when a stale payload has no conflicting count', () => {
    const wrapper = mount(GeneClinVarCard, {
      props: {
        geneSymbol: 'CHD8',
        loading: false,
        error: null,
        counts: {
          pathogenic: 2,
          likely_pathogenic: 0,
          vus: 0,
          likely_benign: 0,
          benign: 0,
        } as never,
        totalCount: 2,
      },
    });

    expect(wrapper.text()).not.toContain('CONF');
  });
});
```

- [ ] **Step 2: Run the test and verify it fails**

Run: `cd app && npx vitest run src/components/gene/GeneClinVarCard.spec.ts`
Expected: FAIL — no `CONF` chip exists, and the fallback path reports `P 3`.

- [ ] **Step 3: Extend the types**

In `app/src/composables/useGeneClinVarCounts.ts`:

```ts
export interface ClinVarClassificationCounts {
  pathogenic: number;
  likely_pathogenic: number;
  conflicting: number;
  vus: number;
  likely_benign: number;
  benign: number;
}
```

In `app/src/components/gene/GeneClinVarCard.vue`:

```ts
export interface ClinVarCounts {
  pathogenic: number;
  likely_pathogenic: number;
  conflicting: number;
  vus: number;
  likely_benign: number;
  benign: number;
}
```

- [ ] **Step 4: Route the fallback through the shared normalizer**

Replace the body of the `counts` computed (lines ~148-190):

```ts
const counts = computed<ClinVarCounts>(() => {
  const empty: ClinVarCounts = {
    pathogenic: 0,
    likely_pathogenic: 0,
    conflicting: 0,
    vus: 0,
    likely_benign: 0,
    benign: 0,
  };

  if (props.counts) return { ...empty, ...props.counts };
  if (!props.data || props.data.length === 0) return empty;

  const result: ClinVarCounts = { ...empty };

  props.data.forEach((variant) => {
    // Table-driven, exact-match classification — never substring matching.
    // See app/src/types/clinvarSignificance.ts and issue #607.
    const cls = normalizeClinVarSignificance(variant.clinical_significance);
    if (cls === 'other' || cls === 'unknown') return;
    result[cls] += 1;
  });

  return result;
});
```

Add the import:

```ts
import { normalizeClinVarSignificance } from '@/types/clinvarSignificance';
```

Note that `{ ...empty, ...props.counts }` is what makes a stale payload without `conflicting`
degrade to `0` (and therefore be filtered out by the existing `count > 0` rule) instead of
rendering `CONF NaN`.

- [ ] **Step 5: Add the chip**

Insert into `chipMeta` between the `likely_pathogenic` and `vus` entries:

```ts
  {
    key: 'conflicting',
    label: 'Conflicting classifications',
    shortLabel: 'CONF',
    className: 'clinvar-chip--conf',
  },
```

Add the style beside the other chip rules:

```css
.clinvar-chip--conf {
  background: #6f42c1;
  color: #fff;
}
```

- [ ] **Step 6: Run the tests and verify they pass**

Run: `cd app && npx vitest run src/components/gene/GeneClinVarCard.spec.ts`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add app/src/composables/useGeneClinVarCounts.ts \
        app/src/components/gene/GeneClinVarCard.vue \
        app/src/components/gene/GeneClinVarCard.spec.ts
git commit -m "feat(app): surface conflicting ClinVar classifications on the gene card (#607)"
```

---

### Task 9: Full verification, docs, and the live visual check

**Files:**
- Modify: `AGENTS.md` (Stack-Specific Gotchas)
- Modify: `CHANGELOG.md`

- [ ] **Step 1: Run the whole frontend gate**

```bash
cd app && npm run type-check && npx vitest run && cd .. && make lint-app
```
Expected: type-check clean, all specs pass. If `vue-tsc` reports an exhaustive `Record<PathogenicityClass, …>` or `Record<AcmgClassification, …>` that no earlier task touched, add the missing member there — that is the union widening doing its job.

- [ ] **Step 2: Run the API gate**

```bash
make lint-api
cd api && Rscript -e "testthat::test_file('tests/testthat/test-unit-gnomad-clinvar-summary.R')"
```
Expected: PASS.

- [ ] **Step 3: Restart the dev stack and verify PCDH12 in a browser**

```bash
make dev
```

Open `http://localhost:8080/Genes/PCDH12` (or the dev host the stack reports) and confirm, with a
screenshot:

- ClinVar Variants card reads `P 18 | LP 13 | CONF 28 | VUS 261 | LB 145 | B 37`.
- The Protein View lollipop legend reads `Pathogenic 13 | Likely pathogenic 13 | Conflicting 28 | VUS 261 | Likely benign 145 | Benign 37` — **not** `Pathogenic 46`.
- The Conflicting chip is purple, and toggling it removes/restores exactly 28 markers.
- The gene-structure tab shows a Conflicting chip that is off by default.
- The 3D structure tab's variant panel shows a `Conf` chip.
- The browser console shows no `[clinvar] Unrecognised …` warning for PCDH12.

- [ ] **Step 4: Record the invariant in AGENTS.md**

Add to the **Stack-Specific Gotchas** list:

```markdown
- ClinVar `clinical_significance` is a controlled vocabulary and MUST be classified by exact string equality against the shared lookup table — never `includes()`/`grepl()`. `"Conflicting classifications of pathogenicity"` contains the substring `pathogenic`, which is how it was counted and drawn as **Pathogenic** across the lollipop, gene-structure plot, 3D viewer and variant panel while the server-computed ClinVar card on the same page disagreed (#607). The single client source of truth is `app/src/types/clinvarSignificance.ts` (`normalizeClinVarSignificance()`); `protein.ts::normalizeClassification()`, `alphafold.ts::classifyClinicalSignificance()` and `GeneClinVarCard.vue` are thin adapters over it, and `normalize_clinvar_classification()` in `api/functions/external-proxy-gnomad.R` mirrors the same table. All three are driven in test by one fixture, `api/tests/testthat/fixtures/clinvar-significance-vocabulary.json` — add a new term there first, then to both tables. An unrecognised term resolves to `unknown` (client) / `other:<sanitized>` (server) and is logged; it must never be able to reach an ACMG tier. `conflicting` is a first-class class on both sides: `counts$conflicting` + `class_breakdowns$conflicting` on `/api/external/gnomad/variants/<symbol>?summary=true`, and its own purple (`#6f42c1`, the `$purple` token) legend chip on all three visualizations. `PATHOGENICITY_SEVERITY` ranks `other` LOWEST — it previously ranked highest, so one unrecognised variant hijacked the dominant colour of an aggregated position.
```

- [ ] **Step 5: Add a CHANGELOG entry**

Under the current unreleased/next version heading:

```markdown
### Fixed

- ClinVar variants classified `Conflicting classifications of pathogenicity` are no longer counted and drawn as Pathogenic in the gene-page lollipop, gene-structure plot, 3D structure viewer and variant panel (#607). All four significance normalizers are replaced by one table-driven vocabulary matched by exact string equality; `Pathogenic/Likely pathogenic` now resolves identically on the client and the server; conflicting classifications get their own legend category, filter chip and ClinVar-card chip; and an unrecognised term resolves to an explicit unknown bucket instead of being guessed into an ACMG tier.
```

- [ ] **Step 6: Run the full local gate and commit**

```bash
make code-quality-audit
make pre-commit
git add AGENTS.md CHANGELOG.md
git commit -m "docs: record the ClinVar exact-match vocabulary invariant (#607)"
```

---

## Self-Review

**Spec coverage:**

| Spec section | Task |
|---|---|
| §3.1 shared vocabulary module | 1 |
| §3.2 `protein.ts` adapter | 2 |
| §3.2 `alphafold.ts` adapter | 3 |
| §3.2 `GeneClinVarCard.vue` adapter | 8 |
| §3.3 lollipop chips | 5 |
| §3.3 gene-structure chips | 6 |
| §3.3 VariantPanel chip | 7 |
| §3.3 `PATHOGENICITY_SEVERITY` reorder (defect 2.1.2) | 2 |
| §3.3 `filterMappableVariants` no-op else (defect 2.1.3) | 7 |
| §3.3 `isGeneStructureVariantVisible` `?? true` (defect 2.1.1) | 6 |
| §3.4 R table + primary `conflicting` | 4 |
| §3.5 card chip | 8 |
| §4 shared fixture + all suites | 1–8 |
| §4 live PCDH12 visual check | 9 |

**Type consistency:** `ClinVarSignificanceClass` (Task 1) is consumed by name in Tasks 2, 3 and 8.
`PathogenicityFilterKey` gains `'conflicting' | 'other'` in Task 5 and is the key type used by the
Task 6 legend rows. `VariantFilterKey` gains `'conflicting'` in Task 7 only.
`ClinVarCounts`/`ClinVarClassificationCounts` gain `conflicting` in Task 8 and match the R
`clinvar_primary_classes` key added in Task 4.

**Ordering constraint:** Tasks 2 and 3 widen unions that Tasks 5–8 depend on, so 1 → 2 → 3 must
precede 5–8. Task 4 (R) is independent of 5–8 and may run in parallel with them. Task 9 is last.
