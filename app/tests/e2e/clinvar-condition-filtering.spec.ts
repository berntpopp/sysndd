import { test, expect } from './fixtures/auth';

const MOCK_CLINVAR_VARIANTS = {
  source: 'gnomad_clinvar',
  gene_symbol: 'CHD8',
  gene_id: 'ENSG00000100888',
  variants: [
    {
      variant_id: '14-21385614-C-T',
      clinvar_variation_id: '1001',
      pos: 21385614,
      hgvsc: 'c.100A>G',
      hgvsp: 'p.Lys34Glu',
      major_consequence: 'missense_variant',
      clinical_significance: 'Pathogenic',
      review_status: 'reviewed by expert panel',
      gold_stars: 3,
      in_gnomad: true,
      conditions: ['Neurodevelopmental syndrome', 'Autism spectrum disorder'],
    },
    {
      variant_id: '14-21385700-G-A',
      clinvar_variation_id: '1002',
      pos: 21385700,
      hgvsc: 'c.200G>A',
      hgvsp: 'p.Arg67Gln',
      major_consequence: 'missense_variant',
      clinical_significance: 'Pathogenic',
      review_status: 'criteria provided, single submitter',
      gold_stars: 1,
      in_gnomad: true,
      conditions: ['Neurodevelopmental syndrome'],
    },
    {
      variant_id: '14-21385800-T-C',
      clinvar_variation_id: '1003',
      pos: 21385800,
      hgvsc: 'c.300T>C',
      hgvsp: 'p.Leu100Pro',
      major_consequence: 'missense_variant',
      clinical_significance: 'Likely pathogenic',
      review_status: 'criteria provided, single submitter',
      gold_stars: 1,
      in_gnomad: true,
      conditions: ['Overgrowth syndrome'],
    },
    {
      variant_id: '14-21385900-A-C',
      clinvar_variation_id: '1004',
      pos: 21385900,
      hgvsc: 'c.400A>C',
      hgvsp: 'p.Thr134Pro',
      major_consequence: 'missense_variant',
      clinical_significance: 'Pathogenic',
      review_status: 'criteria provided, single submitter',
      gold_stars: 1,
      in_gnomad: true,
      conditions: ['Condition Delta'],
    },
    {
      variant_id: '14-21386000-C-G',
      clinvar_variation_id: '1005',
      pos: 21386000,
      hgvsc: 'c.500C>G',
      hgvsp: 'p.Pro167Arg',
      major_consequence: 'missense_variant',
      clinical_significance: 'Pathogenic',
      review_status: 'criteria provided, single submitter',
      gold_stars: 1,
      in_gnomad: true,
      conditions: ['Condition Epsilon'],
    },
    {
      variant_id: '14-21386100-G-T',
      clinvar_variation_id: '1006',
      pos: 21386100,
      hgvsc: 'c.600G>T',
      hgvsp: 'p.Gly200Val',
      major_consequence: 'missense_variant',
      clinical_significance: 'Pathogenic',
      review_status: 'criteria provided, single submitter',
      gold_stars: 1,
      in_gnomad: true,
      conditions: ['Condition Zeta'],
    },
    {
      variant_id: '14-21386200-T-A',
      clinvar_variation_id: '1007',
      pos: 21386200,
      hgvsc: 'c.700T>A',
      hgvsp: 'p.Tyr234Asn',
      major_consequence: 'missense_variant',
      clinical_significance: 'Pathogenic',
      review_status: 'criteria provided, single submitter',
      gold_stars: 1,
      in_gnomad: true,
      conditions: ['Condition Eta'],
    },
  ],
};

test.describe('ClinVar Condition Filtering & Visual Design', () => {
  test.beforeEach(async ({ page }) => {
    // Intercept ClinVar variants endpoint to provide rich multi-condition fixture
    await page.route('**/api/external/gnomad/variants/CHD8*', async (route) => {
      await route.fulfill({
        status: 200,
        contentType: 'application/json',
        body: JSON.stringify(MOCK_CLINVAR_VARIANTS),
      });
    });
  });

  test('renders condition filter row with count badges and handles "only" and "all" toggling', async ({
    page,
  }) => {
    await page.setViewportSize({ width: 1440, height: 900 });
    await page.goto('/Genes/CHD8');

    // Wait for the Genomic Visualizations section header
    const vizTitle = page.getByRole('heading', { name: /Genomic Visualizations/i });
    await expect(vizTitle).toBeVisible({ timeout: 25_000 });

    // Ensure the Protein View tab is active and lollipop controls condition row is visible
    const conditionRow = page.locator('.condition-filter-row');
    await expect(conditionRow).toBeVisible({ timeout: 20_000 });

    // Verify condition label and icon
    await expect(conditionRow.locator('.condition-prefix')).toContainText('Condition:');

    // Top conditions should be visible (initial limit: 5)
    // 1. Neurodevelopmental syndrome (count: 2)
    const nddChip = conditionRow.locator('.filter-chip--condition', {
      hasText: 'Neurodevelopmental syndrome',
    });
    await expect(nddChip).toBeVisible();
    await expect(nddChip.locator('.filter-count')).toHaveText('2');

    // 2. Autism spectrum disorder (count: 1)
    const asdChip = conditionRow.locator('.filter-chip--condition', {
      hasText: 'Autism spectrum disorder',
    });
    await expect(asdChip).toBeVisible();
    await expect(asdChip.locator('.filter-count')).toHaveText('1');

    // Check progressive disclosure: with 7 conditions, +2 more button should exist
    const moreBtn = conditionRow.locator('.toggle-all-conditions-btn');
    await expect(moreBtn).toBeVisible();
    await expect(moreBtn).toContainText('+2 more');

    // Click "+2 more" to expand all conditions
    await moreBtn.click();
    await expect(moreBtn).toHaveText('less');
    const allChips = conditionRow.locator('.filter-chip--condition');
    await expect(allChips).toHaveCount(7);

    // Now "Overgrowth syndrome" is visible among the expanded chips
    const overgrowthChip = conditionRow.locator('.filter-chip--condition', {
      hasText: 'Overgrowth syndrome',
    });
    await expect(overgrowthChip).toBeVisible();

    // Click "less" to collapse back to top 5
    await moreBtn.click();
    await expect(moreBtn).toContainText('+2 more');
    await expect(conditionRow.locator('.filter-chip--condition')).toHaveCount(5);

    // Test "only" button: Isolate "Autism spectrum disorder"
    const asdGroup = conditionRow.locator('.filter-group', {
      hasText: 'Autism spectrum disorder',
    });
    await asdGroup.locator('.only-btn').click();

    // "Autism spectrum disorder" chip must remain visible and active
    await expect(asdChip).not.toHaveClass(/filter-chip--hidden/);
    await expect(asdChip).toHaveAttribute('aria-pressed', 'true');

    // Other chips should now be dimmed (.filter-chip--hidden)
    await expect(nddChip).toHaveClass(/filter-chip--hidden/);
    await expect(nddChip).toHaveAttribute('aria-pressed', 'false');

    // Test "all" button: Reset all condition filters
    await conditionRow.locator('.all-btn').click();
    await expect(nddChip).not.toHaveClass(/filter-chip--hidden/);
    await expect(nddChip).toHaveAttribute('aria-pressed', 'true');
    await expect(asdChip).not.toHaveClass(/filter-chip--hidden/);

    // Capture visual screenshot of the lollipop controls with condition filters
    const controlsPanel = page.locator('.protein-lollipop-plot');
    await controlsPanel.screenshot({
      path: 'tests/e2e/.playwright-output/clinvar-condition-filtering-controls.png',
    });
  });
});
