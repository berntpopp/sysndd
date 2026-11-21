import { createHash } from 'node:crypto';
import type { Page, Route } from '@playwright/test';
import type { DocsScreenshot, DocsScreenshotAction } from './manifest';

type SetupContext = {
  page: Page;
  entry: DocsScreenshot;
};

type SetupHelper = (context: SetupContext) => Promise<void>;

const docsFunctionalClusters = [
  {
    cluster: 1,
    cluster_size: 4,
    hash_filter: 'docs-functional-cluster-1',
    identifiers: [
      { hgnc_id: 'HGNC:20153', symbol: 'CHD8', STRING_id: '9606.ENSP00000370225' },
      { hgnc_id: 'HGNC:6289', symbol: 'KMT2A', STRING_id: '9606.ENSP00000361824' },
      { hgnc_id: 'HGNC:1388', symbol: 'CREBBP', STRING_id: '9606.ENSP00000262367' },
      { hgnc_id: 'HGNC:15502', symbol: 'SETD5', STRING_id: '9606.ENSP00000371129' },
    ],
    term_enrichment: [
      {
        category: 'Process',
        number_of_genes: 4,
        fdr: '1.2e-05',
        term: 'GO:0006355',
        description: 'regulation of DNA-templated transcription',
      },
      {
        category: 'Component',
        number_of_genes: 3,
        fdr: '3.8e-04',
        term: 'GO:0000785',
        description: 'chromatin',
      },
      {
        category: 'HPO',
        number_of_genes: 3,
        fdr: '8.7e-04',
        term: 'HP:0001263',
        description: 'Global developmental delay',
      },
    ],
  },
  {
    cluster: 2,
    cluster_size: 3,
    hash_filter: 'docs-functional-cluster-2',
    identifiers: [
      { hgnc_id: 'HGNC:11411', symbol: 'SYNGAP1', STRING_id: '9606.ENSP00000403636' },
      { hgnc_id: 'HGNC:9490', symbol: 'PTEN', STRING_id: '9606.ENSP00000361021' },
      { hgnc_id: 'HGNC:11633', symbol: 'TSC2', STRING_id: '9606.ENSP00000219476' },
    ],
    term_enrichment: [
      {
        category: 'KEGG',
        number_of_genes: 3,
        fdr: '2.4e-04',
        term: 'hsa04150',
        description: 'mTOR signaling pathway',
      },
      {
        category: 'Process',
        number_of_genes: 3,
        fdr: '7.1e-04',
        term: 'GO:0050804',
        description: 'modulation of synaptic transmission',
      },
    ],
  },
];

const docsClusterCategories = [
  { value: 'Process', text: 'Biological process', link: 'https://www.ebi.ac.uk/QuickGO/term/' },
  { value: 'Component', text: 'Cellular component', link: 'https://www.ebi.ac.uk/QuickGO/term/' },
  { value: 'HPO', text: 'Human phenotype', link: 'https://hpo.jax.org/app/browse/term/' },
  { value: 'KEGG', text: 'KEGG pathway', link: 'https://www.genome.jp/dbget-bin/www_bget?' },
];

const docsPhenotypeClusters = [
  {
    cluster: '1',
    cluster_size: 2,
    hash_filter: 'docs-phenotype-cluster-1',
    identifiers: [
      { entity_id: 123, hgnc_id: 'HGNC:20153', symbol: 'CHD8' },
      { entity_id: 124, hgnc_id: 'HGNC:11411', symbol: 'SYNGAP1' },
    ],
    quali_inp_var: [
      { variable: 'Global developmental delay', 'p.value': 0.0006, 'v.test': 3.5 },
      { variable: 'Autism', 'p.value': 0.004, 'v.test': 2.8 },
    ],
    quali_sup_var: [
      { variable: 'Autosomal dominant inheritance', 'p.value': 0.003, 'v.test': 2.9 },
    ],
    quanti_sup_var: [
      { variable: 'extraneurological_system_count', 'p.value': 0.012, 'v.test': 2.4 },
    ],
  },
  {
    cluster: '2',
    cluster_size: 2,
    hash_filter: 'docs-phenotype-cluster-2',
    identifiers: [
      { entity_id: 125, hgnc_id: 'HGNC:9490', symbol: 'PTEN' },
      { entity_id: 126, hgnc_id: 'HGNC:6289', symbol: 'KMT2A' },
    ],
    quali_inp_var: [
      { variable: 'Macrocephaly', 'p.value': 0.001, 'v.test': 3.2 },
      { variable: 'Seizure', 'p.value': 0.018, 'v.test': 2.1 },
    ],
    quali_sup_var: [{ variable: 'Autosomal dominant inheritance', 'p.value': 0.01, 'v.test': 2.3 }],
    quanti_sup_var: [{ variable: 'gene_entity_count', 'p.value': 0.02, 'v.test': 2.0 }],
  },
];

const phenotypeTerms = ['Global developmental delay', 'Autism', 'Macrocephaly', 'Seizure'];

function matrixCells(labels: string[]) {
  return labels.flatMap((x, xi) =>
    labels.map((y, yi) => ({
      x,
      x_id: `HP:DOCS${xi}`,
      y,
      y_id: `HP:DOCS${yi}`,
      value: xi === yi ? 1 : Number((0.72 - Math.abs(xi - yi) * 0.21).toFixed(2)),
    }))
  );
}

async function fulfillJson(route: Route, body: unknown, status = 200) {
  await route.fulfill({
    status,
    contentType: 'application/json',
    body: JSON.stringify(body),
  });
}

async function waitForNoSpinners(page: Page) {
  await page
    .waitForFunction(
      () =>
        document.querySelectorAll(
          '[data-testid="entities-skeleton"], [data-testid="section-card-skeleton"], .spinner-border'
        ).length === 0,
      undefined,
      { timeout: 30_000 }
    )
    .catch(() => undefined);
}

async function waitForTable(page: Page) {
  await waitForNoSpinners(page);
  await page.getByRole('table').first().waitFor({ timeout: 30_000 });
}

async function openNavbarMenu(page: Page, label: string) {
  await page.locator('.app-navbar').getByText(label, { exact: true }).click();
  await page.locator('.dropdown-menu.show').first().waitFor({ timeout: 10_000 });
}

export const preSetupHelpers: Record<string, SetupHelper> = {
  async analysisDataMocks({ page }) {
    await page.route('**/api/comparisons/metadata**', (route) =>
      fulfillJson(route, {
        last_full_refresh: '2026-05-15T00:00:00Z',
        last_refresh_status: 'success',
        last_refresh_error: null,
        sources_count: 8,
        rows_imported: 240,
      })
    );

    await page.route('**/api/comparisons/upset**', (route) =>
      fulfillJson(route, [
        { name: 'HGNC:20153', sets: ['SysNDD', 'gene2phenotype', 'panelapp'] },
        { name: 'HGNC:11411', sets: ['SysNDD', 'sfari'] },
        { name: 'HGNC:9490', sets: ['SysNDD', 'OMIM_NDD', 'panelapp'] },
        { name: 'HGNC:6289', sets: ['SysNDD', 'radboudumc_ID'] },
      ])
    );

    await page.route('**/api/comparisons/similarity**', (route) =>
      fulfillJson(route, matrixCells(['SysNDD', 'gene2phenotype', 'panelapp', 'sfari']))
    );

    await page.route('**/api/comparisons/browse**', (route) =>
      fulfillJson(route, {
        data: [
          {
            symbol: 'CHD8',
            hgnc_id: 'HGNC:20153',
            SysNDD: 'Definitive',
            gene2phenotype: 'Definitive',
            panelapp: 'Definitive',
            sfari: 'S',
          },
          {
            symbol: 'SYNGAP1',
            hgnc_id: 'HGNC:11411',
            SysNDD: 'Definitive',
            gene2phenotype: 'Definitive',
            panelapp: 'Limited',
            sfari: 'S',
          },
        ],
        meta: [{ total_rows: 2, execution_time: '0.01s' }],
        links: [],
      })
    );

    await page.route('**/api/phenotype/correlation**', (route) =>
      fulfillJson(route, matrixCells(phenotypeTerms))
    );

    await page.route('**/api/phenotype/count**', (route) =>
      fulfillJson(route, [
        { HPO_term: 'Global developmental delay', phenotype_id: 'HP:0001263', count: 4 },
        { HPO_term: 'Autism', phenotype_id: 'HP:0000717', count: 3 },
        { HPO_term: 'Macrocephaly', phenotype_id: 'HP:0000256', count: 2 },
        { HPO_term: 'Seizure', phenotype_id: 'HP:0001250', count: 2 },
      ])
    );

    await page.route('**/api/analysis/phenotype_clustering**', (route) =>
      fulfillJson(route, docsPhenotypeClusters)
    );

    await page.route('**/api/analysis/phenotype_cluster_summary**', (route) =>
      fulfillJson(route, { message: 'Summary not found for this documentation fixture.' }, 404)
    );

    await page.route('**/api/jobs/clustering/submit', (route) =>
      fulfillJson(
        route,
        {
          job_id: 'docs-functional-clustering',
          status: 'accepted',
          estimated_seconds: 1,
          status_url: '/api/jobs/docs-functional-clustering/status',
        },
        202
      )
    );

    await page.route('**/api/jobs/docs-functional-clustering/status', (route) =>
      fulfillJson(route, {
        job_id: 'docs-functional-clustering',
        status: 'completed',
        progress: 100,
        result: {
          categories: docsClusterCategories,
          clusters: docsFunctionalClusters,
          meta: {
            algorithm: 'leiden',
            elapsed_seconds: 0.1,
            gene_count: 7,
            cluster_count: 2,
          },
        },
      })
    );

    await page.route('**/api/analysis/functional_clustering**', (route) =>
      fulfillJson(route, {
        categories: docsClusterCategories,
        clusters: docsFunctionalClusters,
        pagination: {
          page_size: 10,
          page_after: '',
          next_cursor: null,
          total_count: 2,
          has_more: false,
        },
        meta: {
          algorithm: 'leiden',
          elapsed_seconds: 0.1,
          gene_count: 7,
          cluster_count: 2,
        },
      })
    );

    await page.route('**/api/analysis/functional_cluster_summary**', (route) =>
      fulfillJson(route, { message: 'Summary not found for this documentation fixture.' }, 404)
    );

    await page.route('**/api/analysis/network_edges**', (route) =>
      fulfillJson(route, {
        nodes: [
          { hgnc_id: 'HGNC:20153', symbol: 'CHD8', cluster: 1, degree: 3, category: 'Definitive' },
          { hgnc_id: 'HGNC:6289', symbol: 'KMT2A', cluster: 1, degree: 2, category: 'Definitive' },
          { hgnc_id: 'HGNC:1388', symbol: 'CREBBP', cluster: 1, degree: 2, category: 'Moderate' },
          { hgnc_id: 'HGNC:15502', symbol: 'SETD5', cluster: 1, degree: 1, category: 'Limited' },
          {
            hgnc_id: 'HGNC:11411',
            symbol: 'SYNGAP1',
            cluster: 2,
            degree: 2,
            category: 'Definitive',
          },
          { hgnc_id: 'HGNC:9490', symbol: 'PTEN', cluster: 2, degree: 2, category: 'Definitive' },
          { hgnc_id: 'HGNC:11633', symbol: 'TSC2', cluster: 2, degree: 1, category: 'Moderate' },
        ],
        edges: [
          { source: 'HGNC:20153', target: 'HGNC:6289', confidence: 0.82 },
          { source: 'HGNC:20153', target: 'HGNC:1388', confidence: 0.76 },
          { source: 'HGNC:6289', target: 'HGNC:15502', confidence: 0.67 },
          { source: 'HGNC:11411', target: 'HGNC:9490', confidence: 0.81 },
          { source: 'HGNC:9490', target: 'HGNC:11633', confidence: 0.78 },
        ],
        metadata: {
          node_count: 7,
          edge_count: 5,
          cluster_count: 2,
          total_edges: 5,
          edges_filtered: false,
          elapsed_seconds: 0.1,
          category_counts: { Definitive: 4, Moderate: 2, Limited: 1 },
        },
      })
    );

    await page.route('**/api/statistics/entities_over_time**', (route) =>
      fulfillJson(route, {
        meta: [{ max_cumulative_count: 8 }],
        data: [
          {
            group: 'Definitive',
            values: [
              { entry_date: '2023-01-01', cumulative_count: 2 },
              { entry_date: '2024-01-01', cumulative_count: 4 },
              { entry_date: '2025-01-01', cumulative_count: 7 },
              { entry_date: '2026-01-01', cumulative_count: 8 },
            ],
          },
          {
            group: 'Moderate',
            values: [
              { entry_date: '2023-01-01', cumulative_count: 1 },
              { entry_date: '2024-01-01', cumulative_count: 2 },
              { entry_date: '2025-01-01', cumulative_count: 3 },
              { entry_date: '2026-01-01', cumulative_count: 4 },
            ],
          },
        ],
      })
    );
  },
  // The live API had no published analysis-snapshot release on 2026-11-20, so the
  // Data releases page is rendered from one illustrative release (hashes derived
  // deterministically; not a real release).
  async dataReleaseMock({ page }) {
    const hex = (seed: string) => createHash('sha256').update(seed).digest('hex');
    const layers = [
      { analysis_type: 'functional_clusters', snapshot_id: 201, payload_hash: hex('fc-payload') },
      { analysis_type: 'phenotype_clusters', snapshot_id: 202, payload_hash: hex('pc-payload') },
      {
        analysis_type: 'phenotype_functional_correlation',
        snapshot_id: 203,
        payload_hash: hex('pfc-payload'),
      },
    ];
    const head = {
      release_id: `asr_${hex('release').slice(0, 16)}`,
      release_version: '2026.11',
      title: 'SysNDD analysis-snapshot release',
      status: 'published',
      content_digest: hex('content'),
      created_at: '2026-11-03T09:12:00Z',
      published_at: '2026-11-03T09:20:00Z',
      source_data_version: '2026-11-03',
      db_release_version: '1.0.0',
      db_release_commit: hex('commit').slice(0, 7),
      manifest_sha256: hex('manifest'),
      bundle_sha256: hex('bundle'),
      license: 'CC-BY-4.0',
      file_count: 3,
      total_bytes: 3_600_000,
      zenodo: { record_url: null, version_doi: null, concept_doi: null },
      layers,
    };
    const detail = {
      ...head,
      manifest: {
        release_id: head.release_id,
        release_version: head.release_version,
        title: head.title,
        created_at: head.created_at,
        license: head.license,
        scope_statement: 'Public derived analyses only; no curation drafts or user data.',
        generator: {
          name: 'sysndd-analysis-snapshot-release-build',
          manifest_schema_version: '1.0',
          reproducibility_schema_version: '1.2',
        },
        source: {
          source_data_version: head.source_data_version,
          db_release: { version: head.db_release_version, commit: head.db_release_commit },
          snapshots: layers.map((layer) => ({
            analysis_type: layer.analysis_type,
            snapshot_id: layer.snapshot_id,
            parameter_hash: hex(`${layer.analysis_type}-params`).slice(0, 16),
          })),
        },
        layers: layers.map((layer) => ({
          analysis_type: layer.analysis_type,
          parameter_hash: hex(`${layer.analysis_type}-params`).slice(0, 16),
          snapshot_id: layer.snapshot_id,
          input_hash: hex(`${layer.analysis_type}-input`),
          payload_hash: layer.payload_hash,
          schema_version: '1.2',
          reproducibility_hash:
            layer.analysis_type === 'phenotype_functional_correlation'
              ? null
              : hex(`${layer.analysis_type}-repro`),
          dependencies: null,
        })),
        files: layers.map((layer) => ({
          path: `${layer.analysis_type}/payload.json`,
          sha256: hex(`${layer.analysis_type}-file`),
          bytes: 1_200_000,
        })),
        content_digest: head.content_digest,
      },
    };
    await page.route(/\/api\/analysis\/releases(\?.*)?$/, (route) =>
      fulfillJson(route, { releases: [head], pagination: { limit: 20, offset: 0, count: 1 } })
    );
    await page.route(/\/api\/analysis\/releases\/(latest|asr_[^/]+)$/, (route) =>
      fulfillJson(route, detail)
    );
  },

  // The live NCBI lookup currently reports no GeneReviews chapter for any gene (its
  // E-utilities query returns zero hits), so the "Available, not linked" state is
  // shown with one real chapter: Coffin-Siris syndrome (NBK131811) for ARID1B.
  async geneReviewsAvailabilityMock({ page }) {
    await page.route('**/api/genereviews/coverage**', async (route) => {
      const response = await route.fetch();
      const body = await response.json();
      if (!route.request().url().includes('include_live=true')) {
        await fulfillJson(route, body);
        return;
      }
      for (const row of body.data ?? []) {
        if (row.symbol === 'ARID1B') {
          Object.assign(row, {
            genereview_available: true,
            available_nbk_id: 'NBK131811',
            available_url: 'https://www.ncbi.nlm.nih.gov/books/NBK131811/',
            available_title: 'Coffin-Siris Syndrome',
            needs_attention: true,
          });
        }
      }
      body.meta = { ...body.meta, needs_attention: [1] };
      await fulfillJson(route, body);
    });
  },

  // Keeps the seeded Playwright test accounts (pw_*) out of curator screenshots:
  // their rows and filter options are removed from the responses, real data stays.
  async hideTestAccounts({ page }) {
    await page.route('**/api/re_review/assignment_table**', async (route) => {
      const response = await route.fetch();
      const rows = (await response.json()) as Array<{ user_name?: string | string[] }>;
      const keep = rows.filter((row) => !/^pw_/.test(String(row.user_name ?? '')));
      await fulfillJson(route, keep);
    });
    await page.route(/\/api\/user\/(list|role_list|table)(\?.*)?$/, async (route) => {
      const response = await route.fetch();
      const text = await response.text();
      try {
        const body = JSON.parse(text);
        const strip = (items: unknown) =>
          Array.isArray(items)
            ? items.filter((item) => !/^pw_|^system$/.test(String((item as { user_name?: unknown }).user_name ?? '')))
            : items;
        await fulfillJson(route, Array.isArray(body) ? strip(body) : { ...body, data: strip(body.data) });
      } catch {
        await route.fulfill({ response, body: text });
      }
    });
  },
};

export const setupHelpers: Record<string, SetupHelper> = {
  async tablePage({ page }) {
    await waitForTable(page);
  },

  async homeOverview({ page }) {
    await page.locator('.home-stats-panel').waitFor({ timeout: 30_000 });
    await page.locator('.home-news-panel table tbody tr').first().waitFor({ timeout: 30_000 });
    await waitForNoSpinners(page);
  },

  async homeSearchSuggestions({ page }) {
    const input = page.locator('.home-search input[role="combobox"]');
    await input.click();
    await input.pressSequentially('FBXO11', { delay: 60 });
    await page.locator('[role="listbox"] [role="option"]').first().waitFor({ timeout: 30_000 });
    await page.waitForTimeout(500);
  },

  async detailPage({ page }) {
    await waitForNoSpinners(page);
    await page.locator('main table, main .card').first().waitFor({ timeout: 30_000 });
    await page.waitForLoadState('networkidle', { timeout: 20_000 }).catch(() => undefined);
    await waitForNoSpinners(page);
    await page.waitForTimeout(1_500);
  },

  async variantCounts({ page }) {
    await page.locator('#count_dataviz svg rect').first().waitFor({ timeout: 30_000 });
    await waitForNoSpinners(page);
    await page.waitForTimeout(1_000);
  },

  async mcpPage({ page }) {
    await page.getByRole('heading', { name: 'How to connect' }).waitFor({ timeout: 30_000 });
  },

  async aboutCitationPolicy({ page }) {
    const button = page.locator('.accordion-button', { hasText: 'Citation Policy' });
    await button.click();
    await page.locator('.accordion-collapse.show', { hasText: 'Please cite' }).waitFor({ timeout: 10_000 });
    await page.waitForTimeout(800);
    await page.evaluate(() => window.scrollTo(0, 0));
  },

  async dataReleases({ page }) {
    await page.getByText('Download complete bundle').first().waitFor({ timeout: 30_000 });
    await page.locator('#technical-verification-title').waitFor({ timeout: 10_000 });
  },

  async userProfile({ page }) {
    await page.getByRole('button', { name: 'Change Password' }).waitFor({ timeout: 30_000 });
    await waitForNoSpinners(page);
    await page.waitForTimeout(800);
  },

  async curatorTable({ page }) {
    await waitForTable(page);
    await page.waitForLoadState('networkidle', { timeout: 15_000 }).catch(() => undefined);
    await page.waitForTimeout(800);
  },

  async manageReReview({ page }) {
    await page.getByRole('heading', { name: 'Submissions' }).waitFor({ timeout: 30_000 });
    await page.locator('button', { hasText: 'Return to queue' }).first().waitFor({ timeout: 30_000 });
    await page.waitForTimeout(800);
  },

  async geneReviewsLive({ page }) {
    await waitForTable(page);
    await page.locator('.form-check', { hasText: 'Check NCBI availability' }).locator('input').check();
    await page.waitForLoadState('networkidle', { timeout: 60_000 }).catch(() => undefined);
    await page.getByLabel('Filter by link status').selectOption('needs_attention');
    await page.locator('tbody tr', { hasText: 'ARID1B' }).waitFor({ timeout: 60_000 });
    await page.waitForTimeout(800);
  },

  async variationSuggestions({ page }) {
    await page.getByRole('button', { name: 'Confirm' }).first().waitFor({ timeout: 30_000 });
    await page.waitForTimeout(800);
  },

  async createEntityFresh({ page }) {
    await page.evaluate(() => {
      Object.keys(localStorage)
        .filter((key) => /create.?entity|entity.?draft|form.?draft/i.test(key))
        .forEach((key) => localStorage.removeItem(key));
    });
    await page.reload({ waitUntil: 'domcontentloaded' });
    await page.locator('#gene-select').waitFor({ timeout: 30_000 });
  },

  async modifyEntityPage({ page }) {
    await page.locator('#entity-select').waitFor({ timeout: 30_000 });
  },

  async phenotypesTable({ page }) {
    await waitForTable(page);
    await page.locator('.phenotype-select-control').waitFor({ timeout: 30_000 });
    await page.locator('.logic-toggle').waitFor({ timeout: 30_000 });
  },

  async ontologyDetail({ page }) {
    await page
      .getByText(/CHD8-related neurodevelopmental disorder/i)
      .first()
      .waitFor({ timeout: 30_000 });
    await waitForTable(page);
  },

  async openTablesMenu({ page }) {
    await openNavbarMenu(page, 'Tables');
  },

  async openAnalysesMenu({ page }) {
    await openNavbarMenu(page, 'Analyses');
  },

  async openHelpMenu({ page }) {
    await openNavbarMenu(page, 'Help');
  },

  async openUserMenu({ page }) {
    await page
      .locator('.app-navbar__account .dropdown-toggle')
      .filter({ hasText: /pw_/i })
      .last()
      .click();
    await page.locator('.dropdown-menu.show').first().waitFor({ timeout: 10_000 });
  },

  async openReviewMenu({ page }) {
    await page
      .locator('.app-navbar__account .dropdown-toggle')
      .filter({ hasText: /^Review$/ })
      .first()
      .click();
    await page.locator('.dropdown-menu.show').first().waitFor({ timeout: 10_000 });
  },

  async curationComparison({ page }) {
    await page.getByRole('heading', { name: /Curation comparisons/i }).waitFor({ timeout: 30_000 });
    await page
      .locator('svg, .upset')
      .first()
      .waitFor({ timeout: 30_000 })
      .catch(() => undefined);
    await waitForNoSpinners(page);
  },

  async curationSimilarity({ page }) {
    await page.getByRole('heading', { name: /Similarity/i }).waitFor({ timeout: 30_000 });
    await page.locator('#matrix_dataviz svg').waitFor({ timeout: 30_000 });
    await waitForNoSpinners(page);
  },

  async phenotypeCorrelogram({ page }) {
    await page.getByRole('heading', { name: /Matrix of phenotype correlations/i }).waitFor({
      timeout: 30_000,
    });
    await page.locator('#matrix_dataviz svg').waitFor({ timeout: 30_000 });
    await waitForNoSpinners(page);
  },

  async phenotypeCounts({ page }) {
    await page.getByRole('heading', { name: /Bar plot of phenotype counts/i }).waitFor({
      timeout: 30_000,
    });
    await page.locator('#count_dataviz svg').waitFor({ timeout: 30_000 });
    await waitForNoSpinners(page);
  },

  async phenotypeClusters({ page }) {
    await page
      .getByRole('heading', { name: /Entities clustered using phenotype annotation/i })
      .waitFor({ timeout: 30_000 });
    await page.locator('.cytoscape-container canvas, .cytoscape-container').first().waitFor({
      timeout: 30_000,
    });
    await waitForTable(page);
  },

  async entriesOverTime({ page }) {
    await page.getByRole('heading', { name: /Curated Counts Timeline/i }).waitFor({
      timeout: 30_000,
    });
    await page.locator('#my_dataviz svg').waitFor({ timeout: 30_000 });
    await waitForNoSpinners(page);
  },

  async functionalClusters({ page }) {
    await page.getByRole('heading', { name: /Functionally enriched gene clusters/i }).waitFor({
      timeout: 30_000,
    });
    await page.locator('.network-panel').waitFor({ timeout: 30_000 });
    await page.locator('.network-container canvas, .cytoscape-canvas').first().waitFor({
      timeout: 30_000,
    });
    await waitForTable(page);
  },

  async loginAuthError({ page }) {
    await page.locator('#login-username').fill('not_a_user');
    await page.locator('#login-password').fill('bad-password');
    await page.getByRole('button', { name: /^Login$/ }).click();
    const toast = page
      .locator('.toast, [role="alert"]')
      .filter({ hasText: /User or password wrong|Authentication failed|Redirecting to login/i })
      .first();
    await toast.waitFor({ state: 'visible', timeout: 30_000 });
    await page.waitForTimeout(500);
  },

  async passwordResetPage({ page }) {
    await page.locator('.spinner-border').waitFor({ state: 'detached', timeout: 30_000 });
    await page.getByPlaceholder('mail@your-institution.com').waitFor({ timeout: 30_000 });
    await page.locator('form').waitFor({ timeout: 30_000 });
  },

  async openMobileNavbar({ page }) {
    await page.locator('.app-navbar__toggle').click();
    await page.locator('#nav-collapse.show').waitFor({ timeout: 10_000 });
  },

  async openMobileFooter({ page }) {
    await page.locator('.app-footer__toggle').click();
    await page.locator('#footer-collapse.show').waitFor({ timeout: 10_000 });
  },

  async mobileTablePage({ page }) {
    await waitForNoSpinners(page);
    await page.locator('.mobile-record-row, [aria-label="Entities"]').first().waitFor({
      timeout: 30_000,
    });
  },

  async reviewerReviewPage({ page }) {
    await page.getByRole('heading', { name: /Re-review table/i }).waitFor({ timeout: 30_000 });
    await page
      .getByRole('button', { name: /edit review for/i })
      .first()
      .waitFor({
        timeout: 30_000,
      });
  },

  async geneDetailPage({ page }) {
    await page.getByRole('heading', { name: /CHD8/i }).first().waitFor({ timeout: 30_000 });
    await page.waitForFunction(
      () =>
        document.querySelectorAll(
          '[data-testid="entities-skeleton"], [data-testid="section-card-skeleton"], .spinner-border'
        ).length === 0,
      undefined,
      { timeout: 30_000 }
    );
    await page.getByRole('table').first().waitFor({ timeout: 30_000 });
  },

  async swaggerOverview({ page }) {
    await page.waitForSelector('#swagger-ui', { timeout: 30_000 });
    await page.waitForSelector('.swagger-ui', { timeout: 30_000 });
    await page.getByRole('heading', { name: /SysNDD API/i }).first().waitFor({ timeout: 30_000 });
    await page.getByText(/\/api\/admin\/openapi\.json/i).waitFor({ timeout: 30_000 });
    await page
      .getByRole('button', { name: /authorize/i })
      .first()
      .waitFor({ timeout: 30_000 });
  },

  async swaggerAuthScreen({ page }) {
    // Swagger loads its spec after the page: wait for the button instead of skipping it.
    const authorizeButton = page.locator('.swagger-ui button.authorize').first();
    await authorizeButton.waitFor({ timeout: 30_000 });
    await authorizeButton.click();
    await page.waitForSelector('.swagger-ui .dialog-ux', { timeout: 10_000 });
  },
};

export const actionHelpers: Record<
  string,
  (page: Page, args?: Record<string, unknown>) => Promise<void>
> = {

  async collapseSwaggerGroups(page) {
    const open = page.locator('.swagger-ui .opblock-tag-section.is-open h3.opblock-tag');
    while ((await open.count()) > 0) {
      await open.first().click();
      await page.waitForTimeout(150);
    }
    await page.evaluate(() => window.scrollTo(0, 0));
  },

  async openCriteriaBatch(page) {
    await page.locator('button', { hasText: 'Criteria batch' }).first().click();
    await page.locator('#batch-name').waitFor({ timeout: 10_000 });
    await page.locator('#batch-name').fill('Definitive entities reviewed before 2023');
    await page.locator('#batch-size').fill('20');
    await page.locator('#user-select').selectOption({ label: 'Assign later' });
    await page.locator('#date-start').fill('2020-01-01');
    await page.locator('#date-end').fill('2022-12-31');
    await page.locator('#status-filter').selectOption({ label: 'Definitive' });
    await page.mouse.click(5, 5);
    await page.waitForTimeout(500);
  },

  async openFirstRefuseModal(page, args) {
    await page.getByRole('button', { name: /Refuse re-review for/ }).first().click();
    await page.locator('#refuse-reason-input').waitFor({ timeout: 10_000 });
    await page.locator('#refuse-reason-input').fill(String(args?.reason ?? ''));
    await page.locator('.modal.show').first().waitFor({ timeout: 10_000 });
    await page.waitForTimeout(700); // let the fade-in finish
  },

  async fillFirstStatusModal(page, args) {
    await actionHelpers.openFirstStatusEditModal(page);
    if (args?.category) {
      await page.locator('#status-select').selectOption({ label: String(args.category) });
    }
    await page.locator('#status-textarea-comment').fill(String(args?.comment ?? ''));
  },

  async scrollToVariationZones(page) {
    const zones = page.locator('[data-testid="variation-provenance-zones"]');
    await zones.waitFor({ timeout: 30_000 });
    await page.locator('#vario-zone-suggested-heading').waitFor({ timeout: 30_000 });
    await zones.scrollIntoViewIfNeeded();
  },

  async enableCurationMode(page) {
    await page.locator('.form-check', { hasText: 'Curation mode' }).locator('input').check();
    await page
      .getByRole('button', { name: /Approve review\/status for/ })
      .first()
      .waitFor({ timeout: 30_000 });
    await page.waitForTimeout(500);
  },

  async createEntityCore(page, args) {
    const pick = async (selector: string, query: string, match: string) => {
      await page.locator(selector).fill(query);
      await page.locator('.autocomplete-item', { hasText: match }).first().click();
    };
    await pick('#gene-select', String(args?.gene ?? 'MAU2'), String(args?.geneMatch ?? 'HGNC:29140'));
    await pick(
      '#disease-select',
      String(args?.disease ?? 'Cornelia'),
      String(args?.diseaseMatch ?? 'OMIM:621570')
    );
    await page
      .locator('#inheritance-select')
      .selectOption({ label: String(args?.inheritance ?? 'Autosomal dominant inheritance') });
    await page.locator('.step-core-entity input[name="ndd-phenotype"][value="true"]').check({ force: true });
    await page.getByRole('button', { name: /Next: Evidence/ }).waitFor({ timeout: 10_000 });
    await page.mouse.click(5, 5);
  },

  async createEntityEvidence(page, args) {
    await actionHelpers.createEntityCore(page, args);
    await page.getByRole('button', { name: /Next: Evidence/ }).click();
    for (const pmid of (args?.pmids as string[] | undefined) ?? []) {
      await page.locator('#publications-input').fill(pmid);
      await page.keyboard.press('Enter');
      await page.locator('.wizard-content', { hasText: pmid }).waitFor({ timeout: 20_000 });
    }
    await page.locator('#synopsis-textarea').fill(String(args?.synopsis ?? ''));
    await page.locator('#synopsis-textarea').blur();
    await page.getByText('Saving...').waitFor({ state: 'hidden', timeout: 15_000 }).catch(() => undefined);
    await page.waitForTimeout(600);
  },

  async createEntityReview(page, args) {
    await actionHelpers.createEntityEvidence(page, args);
    await page.getByRole('button', { name: /Next: Phenotype/ }).click();
    await page.getByRole('button', { name: /Next: Classification/ }).click();
    await page.locator('#status-select').selectOption({ label: String(args?.status ?? 'Definitive') });
    await page.getByRole('button', { name: /Next: Review/ }).click();
    await page.getByText('Ready to submit!').waitFor({ timeout: 15_000 });
    await page.getByText('Saving...').waitFor({ state: 'hidden', timeout: 15_000 }).catch(() => undefined);
    await page.waitForTimeout(600);
  },

  async modifyEntitySelect(page, args) {
    await page.locator('#entity-select').fill(String(args?.query ?? 'ARID1B'));
    await page.locator('.autocomplete-item').first().click();
    await page.locator('.modify-entity-actions').waitFor({ timeout: 30_000 });
    await page.waitForTimeout(800);
  },

  async modifyEntityCombined(page, args) {
    await actionHelpers.modifyEntitySelect(page, args);
    await page.getByRole('button', { name: 'Modify status and review together' }).click();
    await page.locator('#combined-review-synopsis').waitFor({ timeout: 30_000 });
    // the form renders greyed out with a spinner until the current review has loaded
    await page.waitForFunction(
      () =>
        (document.querySelector('#combined-review-synopsis') as HTMLTextAreaElement | null)?.value
          .length,
      undefined,
      { timeout: 30_000 }
    );
    await page.waitForLoadState('networkidle', { timeout: 15_000 }).catch(() => undefined);
    await page.waitForTimeout(800);
  },

  async modifyEntityDeactivate(page, args) {
    await actionHelpers.modifyEntitySelect(page, args);
    await page.getByRole('button', { name: 'Deactivate entity' }).click();
    await page.locator('#deactivateSwitch').waitFor({ timeout: 10_000 });
    await page.locator('#deactivateSwitch').check();
    await page.locator('#replaceSwitch').check();
    await page.locator('#replace-entity-select').fill(String(args?.replacement ?? 'SCN2A'));
    await page.locator('.autocomplete-item').first().click();
    await page.waitForTimeout(600);
  },

  async openFirstUserReview(page) {
    await page.getByRole('button', { name: /^Review user / }).first().click();
    await page.locator('.modal.show #role-select').waitFor({ timeout: 10_000 });
    await page.locator('#role-select').selectOption({ label: 'Reviewer' });
    await page.waitForTimeout(400);
  },
  async openFirstReviewEditModal(page) {
    const editButton = page.getByRole('button', { name: /edit review for/i }).first();
    await editButton.waitFor({ timeout: 20_000 });
    await editButton.click();
    await page.waitForSelector('.modal.show', { timeout: 10_000 });
    await page.locator('#review-textarea-comment').waitFor({ timeout: 20_000 });
    await page
      .locator('.modal.show')
      .getByRole('button', { name: /Save Review/i })
      .waitFor({ timeout: 20_000 });
    await page
      .locator('.modal.show')
      .getByText(/^(Saving|Loading)\b[^.]{0,40}(\.\.\.|…)$/i)
      .first()
      .waitFor({ state: 'hidden', timeout: 20_000 });
  },

  async openFirstStatusEditModal(page) {
    const editButton = page.getByRole('button', { name: /edit status for/i }).first();
    await editButton.waitFor({ timeout: 20_000 });
    await editButton.click();
    await page.waitForSelector('.modal.show', { timeout: 10_000 });
    await page.getByRole('heading', { name: /Edit Status/i }).waitFor({ timeout: 10_000 });
    await page.locator('#status-textarea-comment').waitFor({ timeout: 20_000 });
    await page
      .locator('.modal.show')
      .getByText(/^(Saving|Loading)\b[^.]{0,40}(\.\.\.|…)$/i)
      .first()
      .waitFor({ state: 'hidden', timeout: 20_000 })
      .catch(() => undefined);
  },

  async openFirstSubmitReviewModal(page) {
    const submitButton = page.getByRole('button', { name: /submit review for/i }).first();
    await submitButton.waitFor({ timeout: 20_000 });
    // Submit stays disabled until the review is saved (#708): save it unchanged first.
    // click() below waits for this same row's button to become enabled.
    if (await submitButton.isDisabled()) {
      await actionHelpers.openFirstReviewEditModal(page);
      const modal = page.locator('.modal.show').first();
      await modal.getByRole('button', { name: /Save Review/i }).click();
      await modal.waitFor({ state: 'hidden', timeout: 20_000 });
    }
    await submitButton.click();
    await page.waitForSelector('.modal.show', { timeout: 10_000 });
    await page.getByRole('heading', { name: /Submit Review/i }).waitFor({ timeout: 10_000 });
  },

  async submitFirstReview(page) {
    await actionHelpers.openFirstSubmitReviewModal(page);
    const modal = page.locator('.modal.show').first();
    await modal.getByRole('button', { name: /^Submit Review$/ }).click();
    await modal.waitFor({ state: 'hidden', timeout: 20_000 }).catch(() => undefined);
    await page
      .getByText(/^0 entities$/)
      .first()
      .waitFor({ timeout: 30_000 });
    await page
      .getByText(/New batch|There are no records matching your request/i)
      .first()
      .waitFor({
        timeout: 30_000,
      });
  },
};

export async function runAction(page: Page, action: DocsScreenshotAction): Promise<void> {
  if (action.type === 'click') {
    await page.locator(action.selector).click();
    return;
  }
  if (action.type === 'fill') {
    await page.locator(action.selector).fill(action.value);
    return;
  }
  if (action.type === 'press') {
    await page.keyboard.press(action.key);
    return;
  }
  if (action.type === 'hover') {
    await page.locator(action.selector).hover();
    return;
  }
  if (action.type === 'waitFor') {
    await page.waitForSelector(action.selector, { timeout: 30_000 });
    return;
  }
  const helper = actionHelpers[action.name];
  if (!helper) {
    throw new Error(`Unknown docs screenshot action helper: ${action.name}`);
  }
  await helper(page, action.args);
}

export function targetUrl(entry: DocsScreenshot, baseURL: string): string {
  const rawBase =
    entry.baseURL === 'api'
      ? (process.env.PLAYWRIGHT_API_BASE_URL ?? 'http://localhost')
      : entry.baseURL === 'public'
        ? (process.env.DOCS_SCREENSHOTS_PUBLIC_BASE_URL ?? 'https://sysndd.dbmr.unibe.ch')
        : baseURL;
  const path = entry.url ?? entry.route ?? '/';
  return new URL(path, rawBase).toString();
}
