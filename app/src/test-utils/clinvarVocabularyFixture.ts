// app/src/test-utils/clinvarVocabularyFixture.ts
/**
 * Loader for the cross-language ClinVar significance vocabulary fixture.
 *
 * The fixture lives at `api/tests/testthat/fixtures/clinvar-significance-vocabulary.json`
 * because that directory is copied into the API container, where the R suite runs
 * (`api/tests/` is deliberately not bind-mounted — see AGENTS.md). Host-run vitest
 * reaches it from a full checkout instead.
 *
 * Both suites drive their production table from this one file, and both assert
 * their table matches it in both directions, so the TypeScript and R vocabularies
 * cannot drift. See GitHub issue #607.
 */
import { existsSync, readFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';

import type { ClinVarSignificanceClass } from '@/types/clinvarSignificance';

/** One `raw ClinVar string -> expected canonical class` fixture row. */
export interface VocabularyEntry {
  raw: string;
  class: ClinVarSignificanceClass;
}

/** Shape of the shared vocabulary fixture file. */
export interface VocabularyFixture {
  /** Whole-string terms — the exact key set both production tables must carry. */
  terms: VocabularyEntry[];
  /** Case / underscore / whitespace variants of terms already in `terms`. */
  normalization_variants: VocabularyEntry[];
  /** ClinVar aggregate values resolved through the `;` / `|` / `/` grammar. */
  aggregate_terms: VocabularyEntry[];
  /** Values that must resolve to `unknown` and never to an ACMG tier. */
  unknown_terms: string[];
}

const FIXTURE_RELATIVE_PATH = 'api/tests/testthat/fixtures/clinvar-significance-vocabulary.json';

/**
 * Walk up from the current working directory until the fixture is found.
 *
 * `import.meta.url` is not a `file:` URL under vitest's jsdom environment, so the
 * path is resolved from `process.cwd()` instead — which is `app/` when the suite
 * runs the usual way, and the repo root if someone runs it from there.
 */
function resolveFixturePath(): string {
  let dir = process.cwd();

  for (let depth = 0; depth < 8; depth += 1) {
    const candidate = resolve(dir, FIXTURE_RELATIVE_PATH);
    if (existsSync(candidate)) return candidate;

    const parent = dirname(dir);
    if (parent === dir) break;
    dir = parent;
  }

  throw new Error(
    `Could not locate ${FIXTURE_RELATIVE_PATH} above ${process.cwd()}. ` +
      'The ClinVar vocabulary fixture is shared with the R test suite; it must exist in a full checkout.'
  );
}

/** Read and parse the shared vocabulary fixture. */
export function loadClinVarVocabularyFixture(): VocabularyFixture {
  return JSON.parse(readFileSync(resolveFixturePath(), 'utf-8')) as VocabularyFixture;
}
