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
    quanti_sup_var: [{ variable: 'phenotype_non_id_count', 'p.value': 0.012, 'v.test': 2.4 }],
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
};

export const setupHelpers: Record<string, SetupHelper> = {
  async tablePage({ page }) {
    await waitForTable(page);
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
      .locator('.app-navbar__account')
      .getByText(/pw_admin|admin/i)
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

  async openHelperBadge({ page }) {
    await page.getByRole('button', { name: /feedback and help/i }).click();
    await page.locator('.dropdown-menu.show').filter({ hasText: 'Cite' }).waitFor({
      state: 'visible',
      timeout: 10_000,
    });
    await page.waitForTimeout(500);
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
    await page.getByRole('heading', { name: /SysNDD API/i }).waitFor({ timeout: 30_000 });
    await page.getByText(/\/api\/admin\/openapi\.json/i).waitFor({ timeout: 30_000 });
    await page
      .getByRole('button', { name: /authorize/i })
      .first()
      .waitFor({ timeout: 30_000 });
  },

  async swaggerAuthScreen({ page }) {
    await page.waitForSelector('#swagger-ui', { timeout: 30_000 });
    await page.waitForSelector('.swagger-ui', { timeout: 30_000 }).catch(() => undefined);
    const authorizeButton = page.getByRole('button', { name: /authorize/i }).first();
    if (await authorizeButton.isVisible().catch(() => false)) {
      await authorizeButton.click();
      await page
        .waitForSelector('.modal-ux, .dialog-ux, .modal.show', { timeout: 10_000 })
        .catch(() => undefined);
    }
  },
};

export const actionHelpers: Record<
  string,
  (page: Page, args?: Record<string, unknown>) => Promise<void>
> = {
  async openFirstReviewEditModal(page) {
    const editButton = page.getByRole('button', { name: /edit review for/i }).first();
    await editButton.waitFor({ timeout: 20_000 });
    await editButton.click();
    await page.waitForSelector('.modal.show', { timeout: 10_000 });
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
    entry.baseURL === 'api' ? (process.env.PLAYWRIGHT_API_BASE_URL ?? 'http://localhost') : baseURL;
  const path = entry.url ?? entry.route ?? '/';
  return new URL(path, rawBase).toString();
}
