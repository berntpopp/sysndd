// app/src/types/clinvarSignificance.ts
/**
 * Canonical ClinVar clinical-significance vocabulary — the SINGLE source of
 * truth for the client.
 *
 * ClinVar `clinical_significance` is a controlled vocabulary. Matching it with
 * `includes()` or a regex means every new or unanticipated term is silently
 * misfiled into whichever branch its substrings happen to hit — which is
 * exactly how `"Conflicting classifications of pathogenicity"` was counted and
 * drawn as Pathogenic (`.includes('pathogenic')` is true, because `pathogenic`
 * is a substring of *pathogenic*ity). See GitHub issue #607.
 *
 * Therefore: exact string equality against an explicit table, after ONE
 * normalization step. A term that cannot be resolved becomes `'unknown'` and is
 * logged — never guessed, and never able to land in an ACMG tier.
 *
 * This table is mirrored by `normalize_clinvar_classification()` in
 * `api/functions/external-proxy-gnomad.R`. Both are driven in test by
 * `api/tests/testthat/fixtures/clinvar-significance-vocabulary.json`, and both
 * suites assert their table matches that fixture in BOTH directions — so add a
 * new term to the fixture first, then to both tables.
 */

/**
 * Canonical classification buckets.
 *
 * - the five ACMG tiers
 * - `conflicting` — submitters disagree; NOT an ACMG tier and NOT pathogenic
 * - `other`       — a recognised ClinVar term that is not a pathogenicity tier
 *                   (drug response, risk factor, not provided, ...)
 * - `unknown`     — not resolvable; logged, never guessed
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
 * @param raw - Raw significance value of any type.
 * @returns The normalized key, or `''` for anything that is not a non-empty string.
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
 * ClinVar aggregates across submissions: it joins classification terms with
 * `/`, then appends non-classification assertions after `;` or `|` — e.g. the
 * live record VCV000013310, `Pathogenic/Likely pathogenic/Pathogenic, low
 * penetrance/Established risk allele; risk factor`. Matching only whole strings
 * would send every such value to `unknown` and UNDERCOUNT real pathogenic
 * variants, so `resolveAggregate()` tokenizes on those documented delimiters and
 * exact-matches each token here.
 *
 * Tokenizing a documented grammar is not substring matching: every token must be
 * a known term, or the whole value is `unknown`.
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
  conflicting: -1, // handled separately — conflicting wins outright
  other: 0,
  benign: 1,
  likely_benign: 2,
  vus: 3,
  likely_pathogenic: 4,
  pathogenic: 5,
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
 * Keeps the first `;`/`|` segment (the pathogenicity assertion; later segments
 * are secondary assertions such as `risk factor`), splits it on `/`, and
 * exact-matches every token. Any unresolvable token fails the whole value — a
 * partial match must never be allowed to promote an aggregate into an ACMG tier.
 *
 * @param key - Already-normalized significance key.
 * @returns The combined class, or `null` when the value is not resolvable.
 */
function resolveAggregate(key: string): ClinVarSignificanceClass | null {
  if (!key) return null;

  const primarySegment = key.split(/[;|]/)[0].trim();
  if (!primarySegment) return null;

  const tokens = primarySegment.split('/').map((token) => token.trim());
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
 * @param raw - Raw significance string from the gnomAD/ClinVar payload.
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
        'classified as "unknown". If it is a real ClinVar term, add it to ' +
        'api/tests/testthat/fixtures/clinvar-significance-vocabulary.json and to both ' +
        'production tables (app/src/types/clinvarSignificance.ts and ' +
        'api/functions/external-proxy-gnomad.R).'
    );
  }

  return 'unknown';
}
