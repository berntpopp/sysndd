// app/tests/e2e/entity.modify.spec.ts
import { test, expect } from './fixtures/auth';

test.describe('curate: entity modify', () => {
  test('curator can open the Modify Entity page and see the search scaffolding', async ({
    loggedInAs,
  }) => {
    const page = await loggedInAs('curator');

    await page.goto('/ModifyEntity');

    // Page header confirms the view loaded.
    await expect(page.getByRole('heading', { name: /Modify an existing entity/i })).toBeVisible({
      timeout: 10_000,
    });

    // The search input is the entry point for the modify flow.
    await expect(
      page
        .getByPlaceholder(/Search by ID, gene symbol, or disease name/i)
        .first(),
    ).toBeVisible();

    // Note: deep flow (search → select entity → open modify modal → save)
    // exercises an autocomplete combobox driven by the gene/disease search
    // service. Wave 0 captures the page scaffold; Wave 1b workstream W4
    // (auth/curate migration) is the natural place to add full-flow
    // coverage when ModifyEntity gets migrated to typed clients.
  });
});
