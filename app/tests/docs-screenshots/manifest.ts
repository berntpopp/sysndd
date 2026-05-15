export type DocsScreenshotAction =
  | { type: 'click'; selector: string }
  | { type: 'fill'; selector: string; value: string; sensitive?: boolean }
  | { type: 'press'; key: string }
  | { type: 'hover'; selector: string }
  | { type: 'waitFor'; selector: string }
  | { type: 'callHelper'; name: string; args?: Record<string, unknown> };

export type DocsScreenshotAnnotation = {
  selector: string;
  mode: 'box' | 'dot' | 'callout';
  label?: string;
  number?: number;
};

export type DocsScreenshot = {
  slug: string;
  output: string;
  docRefs: string[];
  route?: string;
  url?: string;
  baseURL?: 'app' | 'api' | string;
  viewport: { width: number; height: number };
  authRole?: 'admin' | 'curator' | 'reviewer' | 'user';
  setup?: string;
  actions?: DocsScreenshotAction[];
  waitFor?: string;
  locator?: string;
  fullPage?: boolean;
  clip?: { x: number; y: number; width: number; height: number };
  maskSelectors?: string[];
  annotations?: DocsScreenshotAnnotation[];
};

export const docsScreenshots: DocsScreenshot[] = [
  {
    slug: 'home',
    output: 'documentation/static/img/generated/home.png',
    docRefs: ['documentation/02-web-tool.qmd#landing-page'],
    route: '/',
    viewport: { width: 1440, height: 900 },
    waitFor: 'main',
    fullPage: true,
  },
  {
    slug: 'entities-table',
    output: 'documentation/static/img/generated/entities-table.png',
    docRefs: ['documentation/02-web-tool.qmd#entities-table'],
    route: '/Entities',
    viewport: { width: 1440, height: 900 },
    waitFor: 'table',
    fullPage: true,
  },
  {
    slug: 'genes-table',
    output: 'documentation/static/img/generated/genes-table.png',
    docRefs: ['documentation/02-web-tool.qmd#genes-table'],
    route: '/Genes',
    viewport: { width: 1440, height: 900 },
    waitFor: 'table',
    fullPage: true,
  },
  {
    slug: 'gene-detail-chd8',
    output: 'documentation/static/img/generated/gene-detail-chd8.png',
    docRefs: ['documentation/02-web-tool.qmd#gene-page'],
    route: '/Genes/CHD8',
    viewport: { width: 1440, height: 900 },
    setup: 'geneDetailPage',
    waitFor: 'main',
    fullPage: true,
  },
  {
    slug: 'entity-detail-123',
    output: 'documentation/static/img/generated/entity-detail-123.png',
    docRefs: ['documentation/02-web-tool.qmd#entity-page'],
    route: '/Entities/123',
    viewport: { width: 1440, height: 900 },
    waitFor: 'main',
    fullPage: true,
  },
  {
    slug: 'curation-comparisons-overview',
    output: 'documentation/static/img/generated/curation-comparisons-overview.png',
    docRefs: ['documentation/02-web-tool.qmd#compare-curations'],
    route: '/CurationComparisons',
    viewport: { width: 1440, height: 900 },
    waitFor: 'main',
    fullPage: true,
  },
  {
    slug: 'publications-ndd',
    output: 'documentation/static/img/generated/publications-ndd.png',
    docRefs: ['documentation/02-web-tool.qmd#ndd-publications'],
    route: '/PublicationsNDD',
    viewport: { width: 1440, height: 900 },
    waitFor: 'main',
    fullPage: true,
  },
  {
    slug: 'functional-clusters',
    output: 'documentation/static/img/generated/functional-clusters.png',
    docRefs: ['documentation/02-web-tool.qmd#functional-clusters'],
    route: '/GeneNetworks',
    viewport: { width: 1440, height: 900 },
    waitFor: 'main',
    fullPage: true,
  },
  {
    slug: 'login-page',
    output: 'documentation/static/img/generated/login-page.png',
    docRefs: ['documentation/02-web-tool.qmd#login-page', 'documentation/06-re-review-instructions.qmd#login'],
    route: '/Login',
    viewport: { width: 1280, height: 900 },
    waitFor: 'form',
    fullPage: true,
  },
  {
    slug: 'reviewer-review-page',
    output: 'documentation/static/img/generated/reviewer-review-page.png',
    docRefs: ['documentation/06-re-review-instructions.qmd#review-page'],
    route: '/Review',
    viewport: { width: 1440, height: 900 },
    authRole: 'reviewer',
    setup: 'reviewerReviewPage',
    waitFor: 'main',
    fullPage: true,
  },
  {
    slug: 'reviewer-modify-review-modal',
    output: 'documentation/static/img/generated/reviewer-modify-review-modal.png',
    docRefs: ['documentation/06-re-review-instructions.qmd#new-review-edit'],
    route: '/Review',
    viewport: { width: 1440, height: 900 },
    authRole: 'reviewer',
    setup: 'reviewerReviewPage',
    actions: [{ type: 'callHelper', name: 'openFirstReviewEditModal' }],
    waitFor: 'main',
    fullPage: false,
    locator: '.modal.show',
  },
  {
    slug: 'api-swagger-overview',
    output: 'documentation/static/img/generated/api-swagger-overview.png',
    docRefs: ['documentation/03-api.qmd#endpoints'],
    baseURL: 'app',
    url: '/API',
    viewport: { width: 1440, height: 900 },
    setup: 'swaggerOverview',
    waitFor: '.swagger-ui',
    fullPage: true,
  },
  {
    slug: 'api-swagger-auth',
    output: 'documentation/static/img/generated/api-swagger-auth.png',
    docRefs: ['documentation/03-api.qmd#authentication-and-authorization'],
    baseURL: 'app',
    url: '/API',
    viewport: { width: 1440, height: 900 },
    setup: 'swaggerAuthScreen',
    waitFor: '.swagger-ui',
    fullPage: true,
  },
];
