// app/tests/e2e/entity.create.spec.ts
import { test, expect } from './fixtures/auth';

test.describe('curate: entity create', () => {
  test('curator can open the Create Entity wizard and see the form scaffolding', async ({
    loggedInAs,
  }) => {
    const page = await loggedInAs('curator');

    await page.goto('/CreateEntity');

    // The wizard renders with a page header.
    await expect(page.getByRole('heading', { name: /Create New Entity/i })).toBeVisible({
      timeout: 10_000,
    });

    // Subtitle text confirms the wizard wrapper rendered (not a 404 / blank).
    await expect(
      page.getByText(/Add a new gene-disease relationship to the SysNDD database/i),
    ).toBeVisible();

    // Note: the full form-fill flow (gene typeahead → disease autocomplete →
    // inheritance select → wizard advance → submit) drives several
    // sub-components (StepCoreEntity, StepEvidence, etc.). Wave 0 captures
    // the wizard scaffold only — Wave 1b workstream W4 (auth/curate
    // migration) is the natural place to add full-flow coverage once the
    // typed clients are in place.
  });
});
