// app/tests/e2e/entity.modify.spec.ts
import { test, expect } from './fixtures/auth';

// Field set useEntityInfo.loadEntity() requests from GET /api/entity/. Every
// entry is a column ndd_entity_view exposes. The Modify Entity 500 regression
// (commit a586078a) added is_active/replaced_by/details here — columns the view
// does NOT expose — so select_tibble_fields() 500'd on every entity selection.
const MODIFY_ENTITY_FIELDS = [
  'entity_id',
  'symbol',
  'hgnc_id',
  'disease_ontology_name',
  'disease_ontology_id_version',
  'hpo_mode_of_inheritance_term',
  'hpo_mode_of_inheritance_term_name',
  'category',
  'ndd_phenotype',
  'ndd_phenotype_word',
].join(',');

const REGRESSED_FIELDS = `${MODIFY_ENTITY_FIELDS},is_active,replaced_by,details`;

// The select-entity and contract tests need a known entity in the DB. The
// vanilla `make playwright-stack` boots an empty DB; entity data is present only
// when the docs-screenshot fixture is seeded (`make _playwright-seed-docs-data`,
// which inserts entity 123 / CHD8). These tests skip cleanly when it is absent
// so they never false-fail on an empty stack, and run as the real end-to-end
// regression guard when data is present. The always-on CI guard is the vitest
// unit test src/views/curate/composables/useEntityInfo.spec.ts.
const SEEDED_ENTITY_ID = 123;
const SEEDED_ENTITY_SYMBOL = 'CHD8';

async function seededEntityPresent(
  request: { get: (url: string, opts?: unknown) => Promise<{ ok(): boolean; json(): Promise<any> }> },
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
    const body = await res.json();
    return Array.isArray(body?.data) && body.data.length > 0;
  } catch {
    return false;
  }
}

test.describe('curate: Modify Entity', () => {
  test('curator can open the Modify Entity page', async ({ loggedInAs }) => {
    const page = await loggedInAs('curator');
    await page.goto('/ModifyEntity');

    await expect(
      page.getByRole('heading', { name: 'Modify Entity', exact: true }),
    ).toBeVisible({ timeout: 15_000 });
    await expect(page.locator('#entity-select')).toBeVisible();
  });

  test('selecting an entity loads it without a 500 (Modify Entity regression)', async ({
    loggedInAs,
  }) => {
    const page = await loggedInAs('curator');

    test.skip(
      !(await seededEntityPresent(page.request)),
      `requires seeded entity ${SEEDED_ENTITY_ID} (${SEEDED_ENTITY_SYMBOL}); run \`make _playwright-seed-docs-data\``,
    );

    // Capture any 5xx from the entity API — the bug surfaced as a 500 on the
    // entity-detail load right after selection.
    const serverErrors: string[] = [];
    page.on('response', (r) => {
      if (r.url().includes('/api/entity') && r.status() >= 500) {
        serverErrors.push(`${r.status()} ${r.url()}`);
      }
    });

    await page.goto('/ModifyEntity');

    const input = page.locator('#entity-select');
    await input.click();
    await input.fill('CHD8');

    // The autocomplete option (role=option, labelled by gene symbol) appears.
    const option = page.getByRole('option', { name: /CHD8/i }).first();
    await expect(option).toBeVisible({ timeout: 15_000 });
    await option.click();

    // Current Selection populates: the entity header renders the selected gene.
    // Before the fix this stayed empty ("No entity selected") behind a 500 toast.
    await expect(page.getByText('Selected entity 123')).toBeVisible({ timeout: 15_000 });
    await expect(page.getByText('CHD8').first()).toBeVisible();

    expect(
      serverErrors,
      `entity API returned 5xx during selection: ${serverErrors.join(', ')}`,
    ).toHaveLength(0);
  });

  test('entity-list endpoint serves the Modify Entity field set (contract)', async ({
    request,
  }) => {
    test.skip(
      !(await seededEntityPresent(request)),
      `requires seeded entity ${SEEDED_ENTITY_ID} (${SEEDED_ENTITY_SYMBOL}); run \`make _playwright-seed-docs-data\``,
    );

    // The trimmed field set the app now sends must be accepted by the real
    // ndd_entity_view (migration 025) — this guards against re-introducing a
    // view-absent column into ENTITY_MUTATION_FIELDS.
    const ok = await request.get('/api/entity/', {
      params: {
        filter: 'equals(entity_id,123)',
        fields: MODIFY_ENTITY_FIELDS,
        page_size: '1',
        compact: 'true',
      },
    });
    expect(ok.status(), await ok.text()).toBe(200);
    const body = await ok.json();
    expect(Array.isArray(body.data)).toBeTruthy();
    expect(body.data[0]?.entity_id).toBe(123);

    // Documents WHY the fields were trimmed AND that mounted sub-routers now
    // inherit the RFC 9457 error handler: requesting is_active/replaced_by/
    // details (absent from the view) is a client error -> 400 problem+json,
    // not the old opaque 500.
    const regressed = await request.get('/api/entity/', {
      params: {
        filter: 'equals(entity_id,123)',
        fields: REGRESSED_FIELDS,
        page_size: '1',
        compact: 'true',
      },
    });
    expect(regressed.status(), await regressed.text()).toBe(400);
    expect(regressed.headers()['content-type']).toContain('problem+json');
    const problem = await regressed.json();
    expect(problem.status).toBe(400);
    expect(typeof problem.detail).toBe('string');
  });
});
