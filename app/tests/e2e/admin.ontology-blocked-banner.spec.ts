// app/tests/e2e/admin.ontology-blocked-banner.spec.ts
//
// Covers two behaviors introduced by #470:
//
//   1. Persistent "Ontology Update Blocked" banner on /ManageAnnotations.
//      The banner is driven by the on-mount call to
//      /api/admin/ontology/dictionary-status (in loadOntologyStatus()).
//      It appears WITHOUT clicking "Update Ontology" first, provided the DB
//      contains a completed omim_update job whose result_json.status is
//      "blocked" AND the pending CSV exists inside the API container (≤48 h).
//
//      Prerequisite: run `bash app/tests/e2e/fixtures/seed-blocked-ontology.sh`
//      after `make playwright-stack` to insert the SQL row and copy the CSV.
//
//   2. OMIM-pending hint in the rename-disease autocomplete.
//      When a curator opens the "Rename disease" workflow on an entity and
//      types a 6-digit OMIM ID that returns no search results, the
//      OMIM_PENDING_HINT string from useEntityAutocomplete.ts appears in the
//      autocomplete no-results popup (teleported to body by AutocompleteInput).
//
//      Prerequisite: entity 123 (CHD8) must be seeded — run
//      `make _playwright-seed-docs-data`.  The test skips cleanly without it.

import { test, expect } from './fixtures/auth';

// ─── Helpers ────────────────────────────────────────────────────────────────

const SEEDED_ENTITY_ID = 123;
const SEEDED_ENTITY_SYMBOL = 'CHD8';

/**
 * Returns true when entity 123 (CHD8) exists in the Playwright DB.
 * The /api/entity/ listing endpoint is public; no auth header is needed.
 * Mirrors the same helper in entity.modify.spec.ts.
 */
async function seededEntityPresent(
  request: {
    get: (
      url: string,
      opts?: unknown,
    ) => Promise<{ ok(): boolean; json(): Promise<unknown> }>;
  },
): Promise<boolean> {
  try {
    const res = await request.get('/api/entity/', {
      params: {
        filter: `equals(entity_id,${SEEDED_ENTITY_ID})`,
        fields: 'entity_id',
        page_size: '1',
        compact: 'true',
      },
    });
    if (!res.ok()) return false;
    const body = (await res.json()) as { data?: unknown[] };
    return Array.isArray(body?.data) && body.data.length > 0;
  } catch {
    return false;
  }
}

// ─── Tests ──────────────────────────────────────────────────────────────────

test.describe('admin: ontology blocked banner (#470)', () => {
  test(
    'admin sees the persistent blocked banner on ManageAnnotations load (no update click required)',
    async ({ loggedInAs }) => {
      const page = await loggedInAs('admin');
      await page.goto('/ManageAnnotations');

      // AuthenticatedPageShell renders title="Manage Annotations" as <h1>.
      await expect(
        page.getByRole('heading', { name: /Manage Annotations/i }),
      ).toBeVisible({ timeout: 10_000 });

      // The blocked-banner alert is rendered by OntologyAnnotationsCard inside a
      // <BAlert v-if="blocked"> block.  Its heading text is:
      //   <h6 class="alert-heading ...">Ontology Update Blocked <span ...>…</span></h6>
      // The on-mount dictionary-status fetch can take a few seconds; 15 s timeout.
      //
      // NOTE: this assertion requires the SQL seed row AND the pending CSV to be
      // present in the API container (see seed-blocked-ontology.sh).  Without the
      // seed the status endpoint returns blocked=false and this test will time out.
      await expect(page.getByText(/Ontology Update Blocked/i)).toBeVisible({
        timeout: 15_000,
      });

      // The "Force Apply" danger button is rendered inside the same <BAlert>.
      // Template: `{{ forceApplyJob.isLoading.value ? 'Applying...' : 'Force Apply' }}`
      // On initial render the job is idle, so the button shows "Force Apply".
      await expect(
        page.getByRole('button', { name: /Force Apply/i }),
      ).toBeVisible();
    },
  );

  test(
    'curator sees OMIM-pending hint after typing a 6-digit OMIM ID with no match in rename-disease input',
    async ({ loggedInAs }) => {
      const page = await loggedInAs('curator');

      // Skip cleanly when entity 123 is absent — the "Rename disease" button
      // stays disabled until entity_loaded is true, so we cannot open the
      // rename workflow without a pre-seeded entity.
      test.skip(
        !(await seededEntityPresent(page.request)),
        `requires seeded entity ${SEEDED_ENTITY_ID} (${SEEDED_ENTITY_SYMBOL}); ` +
          `run \`make _playwright-seed-docs-data\` then restart the spec`,
      );

      await page.goto('/ModifyEntity');

      // The page shell renders title="Modify Entity" as <h1>.
      await expect(
        page.getByRole('heading', { name: 'Modify Entity', exact: true }),
      ).toBeVisible({ timeout: 15_000 });

      // ── Step 1: select entity 123 (CHD8) ─────────────────────────────────
      // SELECTOR NOTE: #entity-select is the id of the entity typeahead in
      // EntitySearchPanel, confirmed in entity.modify.spec.ts.  If the id
      // changes, update this selector.
      const entityInput = page.locator('#entity-select');
      await entityInput.click();
      await entityInput.fill(SEEDED_ENTITY_SYMBOL);

      const option = page.getByRole('option', { name: /CHD8/i }).first();
      await expect(option).toBeVisible({ timeout: 15_000 });
      await option.click();

      // After selection the "Current Selection" panel shows "Selected entity 123".
      await expect(
        page.getByText(`Selected entity ${SEEDED_ENTITY_ID}`),
      ).toBeVisible({ timeout: 15_000 });

      // ── Step 2: open the rename-disease workflow ──────────────────────────
      // The "Rename disease" BButton has aria-label="Rename disease"
      // (ModifyEntity.vue line ~96) and is only enabled once entity_loaded is
      // true.  After clicking it, InlineEntityWorkflow is rendered with
      // workflow="rename".
      await page.getByRole('button', { name: /Rename disease/i }).click();

      // ── Step 3: wait for the disease autocomplete to appear ───────────────
      // InlineEntityWorkflow.vue: <AutocompleteInput input-id="ontology-select" ...>
      // AutocompleteInput renders <BFormInput :id="inputId" ...>, so the real
      // DOM element gets id="ontology-select".
      // SELECTOR NOTE: if input-id ever changes in InlineEntityWorkflow.vue,
      // update this locator and the comment above.
      const diseaseInput = page.locator('#ontology-select');
      await expect(diseaseInput).toBeVisible({ timeout: 5_000 });

      // ── Step 4: type a 6-digit OMIM ID that has no match ─────────────────
      // "999999" satisfies the OMIM_SHAPED regex (/^(omim:?\s*)?\d{6}$/i) and
      // returns no results from /api/search/ontology/999999 on any standard
      // Playwright DB (no disease_ontology_set rows for this ID exist).
      await diseaseInput.fill('999999');

      // ── Step 5: assert the OMIM-pending hint ─────────────────────────────
      // After the 300 ms debounce fires and the API responds with no results,
      // AutocompleteInput renders the no-results popup (teleported to body):
      //   <div class="autocomplete-no-results" ...>
      //     <small class="text-muted">{{ noResultsMessage }}</small>
      //   </div>
      // useEntityAutocomplete.ts sets noResultsMessage to OMIM_PENDING_HINT:
      //   "No matching disease found. If you recently added this OMIM ID,
      //    the disease dictionary may need an administrator refresh."
      // 15 s covers debounce (300 ms) + API round-trip.
      await expect(
        page.getByText(/may need an administrator refresh/i),
      ).toBeVisible({ timeout: 15_000 });
    },
  );
});
