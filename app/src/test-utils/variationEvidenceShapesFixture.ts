// app/src/test-utils/variationEvidenceShapesFixture.ts
/**
 * Loader for the cross-repo variation-evidence record-shape fixture (#612).
 *
 * The fixture lives at
 * `api/tests/testthat/fixtures/variation-evidence-record-shapes.json` because
 * that directory is copied into the API container, where the R suite runs
 * (`api/tests/` is deliberately not bind-mounted — see AGENTS.md). Host-run
 * vitest reaches it from a full checkout instead.
 *
 * Both suites drive their understood key sets from this one file and assert
 * them in both directions, so the TypeScript reader and the writer in
 * `sysndd-administration` cannot drift apart silently. Mirrors
 * `clinvarVocabularyFixture.ts`, including its `node:fs` + upward-walk
 * resolution — `import.meta.url` is not a `file:` URL under vitest's jsdom
 * environment, and a JSON `import` from outside `app/` would add a test-only
 * cross-root Vite dependency.
 */
import { existsSync, readFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';

/** One batch's record-shape contract. */
export interface EvidenceShapeFixture {
  source_key: string;
  source_type: string;
  captured_from: string;
  /** Top-level keys of `evidence_json` for this shape. */
  container_keys: string[];
  /** Every key a record of this shape may carry. */
  record_keys: string[];
  /** Keys always present on a record of this shape. */
  required_record_keys: string[];
  /** `'string'` when the shape has a `matched` list; `null` when it has none. */
  matched_item_type: 'string' | null;
  /** The exact text the MySQL JSON column holds. */
  stored_json: string;
  /** What a client receives — plumber-wrapped, captured from production. */
  wire_sample: Record<string, unknown>;
}

export interface EvidenceShapesFixture {
  shapes: Record<string, EvidenceShapeFixture>;
}

const FIXTURE_RELATIVE_PATH =
  'api/tests/testthat/fixtures/variation-evidence-record-shapes.json';

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
      'The variation-evidence shape fixture is shared with the R test suite; ' +
      'it must exist in a full checkout.'
  );
}

/** Read and parse the shared record-shape fixture. */
export function loadEvidenceShapesFixture(): EvidenceShapesFixture {
  return JSON.parse(readFileSync(resolveFixturePath(), 'utf-8')) as EvidenceShapesFixture;
}

/** The fixture's shapes, keyed by batch name (`clinvar` / `extdb2` / `synopsis`). */
export const evidenceShapes: Record<string, EvidenceShapeFixture> =
  loadEvidenceShapesFixture().shapes;
