export const meta = {
  name: 'sysndd-design-rating',
  description: 'Expert 1-10 design review of every public SysNDD page (parallel cluster agents)',
  phases: [{ title: 'Rate', detail: 'one agent per page cluster reviews screenshots + source + Lighthouse' }],
};

const SHOTS = '/home/bernt-popp/development/sysndd/.planning/audits/2026-06-13-frontend-audit/screenshots';
const APP = '/home/bernt-popp/development/sysndd/app/src';

const STANDARDS = `
SYSNDD DESIGN INTENT (judge against THIS, not generic web aesthetics):
SysNDD is an expert-curated neurodevelopmental-disorder gene-disease database. The product must feel like a
CLINICAL RESEARCH OPERATIONS TOOL: compact, trustworthy, table-first, quiet. AVOID marketing decoration,
oversized hero cards, expressive gradients, and decorative explanations before the data.
Public table pages + Home are the established REFERENCE ("best") surfaces; chart-heavy analysis pages are
typically the weakest. Help expert users scan, compare, and act.

DESIGN TOKENS (a mature system already exists — reward consistent use, penalize one-off values):
- Color: primary medical-blue #0d47a1/#1565c0; teal accent #00897b; status success #2e7d32 / warning #f57c00 /
  danger #c62828 / info #0277bd; neutral text #212121, secondary #757575; card border --border-subtle #d9e0ea.
  Rules: never one-hue all-blue screens; never color-alone for status (pair icon/label); no heavy dark card borders.
- Type: system sans; MONO for IDs/gene symbols/protein names; scale 12-36px; page title 18-22px semibold;
  table headers 12-14px semibold; body 14-16px; avoid negative letter-spacing in dense tables.
- Shape/density: card radius 6-8px; pill chips; dense table controls 8px gaps; form groups 12px; sections 24-32px.
- Structure rules: exactly ONE route-level <h1>; use TableShell / AnalysisShell / shell patterns; chips for
  IDs/symbols/disease/inheritance/category; no nested cards except repeated data records or true disclosure panels;
  NO horizontal overflow at 1440x900 or 390x844; icon-only controls MUST have accessible labels/tooltips.

PERFORMANCE CAVEAT: Lighthouse ran against the Vite DEV server, so a uniform Performance ~62-67 is a dev-build
artifact — DO NOT penalize design for that baseline. GeneNetworks perf is genuinely heavier (backend-gated: the
fCoSE network layout is precomputed server-side in production but runs in-browser on the dev DB) — note it but
don't over-penalize, the a11y/CLS/hierarchy were fixed.

RE-RATE CONTEXT (IMPORTANT): These screenshots are the POST-IMPROVEMENT designs after a full accessibility +
design-token pass. The per-page "lighthouse" lines below are the PRE-FIX baseline and are now RESOLVED:
accessibility is 100 on 23/25 public pages (exceptions: /About 99 = one CMS heading; /API 99 = embedded
third-party Swagger UI internals). Score accessibility as ~10 unless you can still see a concrete issue. The
fix pass added: tokenized TableShell/AnalysisShell + one route-level h1 per page; AA sysndd-chip tone classes
(no more pastel/Bootstrap-blue); labeled filter selects + icon buttons; chart legends/axis labels/units +
designed loading/empty/error states + token color scales; Home loading/empty/error states + trimmed hero;
fixed gene-detail SVG ARIA + reserved card heights. Judge the CURRENT screenshots + source on their merits.

SCORING (calibrate like a demanding senior product designer, ~145 IQ; 7=solid/professional, 8=strong,
9=excellent & distinctive, 10=reference-class. Be honest and specific; cite visible evidence from the screenshot).
Rate each dimension 1-10: hierarchy, typography, color_contrast, consistency, spacing_density, responsiveness
(use mobile screenshot if provided; if none, judge from desktop reflow cues and note it), accessibility (anchor to the
Lighthouse failing audits given), dataviz (charts/tables; N/A->score the data presentation), interaction_states
(loading/empty/error/affordance — infer from source if not visible), content_clarity.
overall = your holistic 1-10 (not a mere average; weight hierarchy, consistency, a11y, and fitness-for-purpose).
For each page give 3-6 top_findings (issue, severity high|med|low, dimension, evidence) and 3-6 improvements
(recommendation, effort S|M|L, sprint_type "foundation-shared" if it fixes many pages via a shared component/token
else "per-page", expected_impact). Foundation-shared examples: TableShell h1, shared <select> labels, td-has-header
in the table renderer, icon-button aria-labels, badge/chip contrast tokens.
`;

const SCHEMA = {
  type: 'object',
  additionalProperties: false,
  required: ['ratings'],
  properties: {
    ratings: {
      type: 'array',
      items: {
        type: 'object',
        additionalProperties: false,
        required: ['page', 'route', 'scores', 'overall', 'one_line_verdict', 'top_findings', 'improvements'],
        properties: {
          page: { type: 'string' },
          route: { type: 'string' },
          scores: {
            type: 'object',
            additionalProperties: false,
            required: ['hierarchy', 'typography', 'color_contrast', 'consistency', 'spacing_density', 'responsiveness', 'accessibility', 'dataviz', 'interaction_states', 'content_clarity'],
            properties: {
              hierarchy: { type: 'number' }, typography: { type: 'number' }, color_contrast: { type: 'number' },
              consistency: { type: 'number' }, spacing_density: { type: 'number' }, responsiveness: { type: 'number' },
              accessibility: { type: 'number' }, dataviz: { type: 'number' }, interaction_states: { type: 'number' },
              content_clarity: { type: 'number' },
            },
          },
          overall: { type: 'number' },
          one_line_verdict: { type: 'string' },
          top_findings: {
            type: 'array',
            items: {
              type: 'object', additionalProperties: false, required: ['issue', 'severity', 'dimension', 'evidence'],
              properties: { issue: { type: 'string' }, severity: { type: 'string' }, dimension: { type: 'string' }, evidence: { type: 'string' } },
            },
          },
          improvements: {
            type: 'array',
            items: {
              type: 'object', additionalProperties: false, required: ['recommendation', 'effort', 'sprint_type', 'expected_impact'],
              properties: { recommendation: { type: 'string' }, effort: { type: 'string' }, sprint_type: { type: 'string' }, expected_impact: { type: 'string' } },
            },
          },
        },
      },
    },
  },
};

// page: [route, [desktop+mobile shot basenames], "lighthouse findings line", "source hints"]
const CLUSTERS = {
  'Tables + Home': [
    ['home', '/', ['home.png', 'home-mobile.png'], 'perf63 a11y99 LCP4249 | heading-order(1)', 'views/HomeView.vue, components/home/HomeStatsPanel.vue, HomeNewsPanel.vue, HomeConceptPanel.vue, components/small/AppBanner.vue'],
    ['entities', '/Entities?sort=+entity_id&page_size=10', ['entities.png', 'entities-mobile.png'], 'perf64 a11y95 | heading-order(1), select-name(3), td-has-header(1)', 'views/tables/EntitiesTable.vue, components/tables/TablesEntities.vue, components/table/TableShell.vue, components/small/TablePaginationControls.vue, TableFilterControls.vue'],
    ['genes', '/Genes?sort=+symbol&page_size=10', ['genes.png', 'genes-mobile.png'], 'perf63 a11y99 | heading-order(1), td-has-header(1)', 'views/tables/GenesTable.vue, components/tables/TablesGenes.vue, components/table/TableShell.vue'],
    ['phenotypes', '/Phenotypes?filter=all(modifier_phenotype_id,HP:0001249)', ['phenotypes.png', 'phenotypes-mobile.png'], 'perf63 a11y88 | button-name(3), color-contrast(1), heading-order(1), select-name(1), td-has-header(1)', 'views/tables/PhenotypesTable.vue, components/tables/TablesPhenotypes.vue, components/table/TableShell.vue'],
    ['panels', '/Panels/All/All', ['panels.png', 'panels-mobile.png'], 'perf64 a11y99 | heading-order(1)', 'views/tables/PanelsTable.vue, PanelsMobileRows.vue, PanelsTableControls.vue, components/table/TableShell.vue'],
  ],
  'Curation comparison analyses': [
    ['curationcomparisons', '/CurationComparisons', ['curationcomparisons.png', 'curationcomparisons-mobile.png'], 'perf64 a11y99 | heading-order(1)', 'views/analyses/CurationComparisons.vue, components/analyses/AnalysesCurationUpset.vue'],
    ['curationcomparisons-similarity', '/CurationComparisons/Similarity', ['curationcomparisons-similarity.png'], 'perf63 a11y99 | heading-order(1)', 'components/analyses/AnalysesCurationMatrixPlot.vue'],
    ['curationcomparisons-table', '/CurationComparisons/Table', ['curationcomparisons-table.png'], 'perf62 a11y95 | heading-order(1), select-name(8), td-has-header(1)', 'components/analyses/AnalysesCurationComparisonsTable.vue'],
  ],
  'Correlation analyses': [
    ['phenotypecorrelations', '/PhenotypeCorrelations', ['phenotypecorrelations.png'], 'perf63 a11y99 | heading-order(1)', 'views/analyses/PhenotypeCorrelations.vue, components/analyses/AnalysisShell.vue, AnalysesPhenotypeCorrelogram.vue'],
    ['phenotypefunctionalcorrelation', '/PhenotypeFunctionalCorrelation', ['phenotypefunctionalcorrelation.png'], 'perf66 a11y99 | heading-order(1)', 'views/analyses/PhenotypeFunctionalCorrelation.vue, components/analyses/AnalysisShell.vue'],
    ['variantcorrelations', '/VariantCorrelations', ['variantcorrelations.png'], 'perf63 a11y99 | heading-order(1)', 'views/analyses/VariantCorrelations.vue, components/analyses/AnalysisShell.vue, AnalysesVariantCorrelogram.vue'],
  ],
  'Time / Publications / Networks analyses': [
    ['entriesovertime', '/EntriesOverTime', ['entriesovertime.png'], 'perf66 a11y94 | heading-order(1), select-name(2)', 'views/analyses/EntriesOverTime.vue, components/analyses/AnalysisShell.vue, AnalysesTimePlot.vue'],
    ['publicationsndd', '/PublicationsNDD', ['publicationsndd.png'], 'perf64 a11y96 | color-contrast(10), heading-order(1), td-has-header(1)', 'views/analyses/PublicationsNDD.vue, components/analyses/AnalysisShell.vue, PublicationsNDDTable.vue'],
    ['pubtatorndd', '/PubtatorNDD', ['pubtatorndd.png'], 'perf67 a11y96 | color-contrast(29!), heading-order(1)', 'views/analyses/PubtatorNDD.vue, components/analyses/AnalysisShell.vue, PubtatorNDDTable.vue'],
    ['genenetworks', '/GeneNetworks', ['genenetworks.png'], 'perf17! a11y88 LCP4087 TBT2119 CLS0.277 | button-name(6), color-contrast(2), heading-order(1), select-name(3), td-has-header(1)', 'views/analyses/GeneNetworks.vue, components/analyses/AnalyseGeneClusters.vue, AnalysisShell.vue'],
  ],
  'NDDScore': [
    ['nddscore', '/NDDScore?sort=+rank&page_size=10', ['nddscore.png', 'nddscore-mobile.png'], 'perf63 a11y93 | color-contrast(3), heading-order(1), select-name(5), label-content-name-mismatch(4), td-has-header(1)', 'views/nddscore/NDDScore.vue, components/nddscore/NddScoreGeneTable.vue, NddScorePredictionCard.vue, components/analyses/AnalysisShell.vue'],
    ['nddscore-modelcard', '/NDDScore/ModelCard', ['nddscore-modelcard.png'], 'perf66 a11y96 | color-contrast(8), heading-order(1)', 'components/nddscore/NddScoreModelCard.vue'],
  ],
  'Help / Static / API': [
    ['about', '/About', ['about.png'], 'perf62 a11y99 LCP8754! | heading-order(1)', 'views/help/AboutView.vue, components/AppVersionInfo.vue'],
    ['documentation', '/Documentation', ['documentation.png'], 'perf66 a11y99 | heading-order(1)', 'views/help/DocumentationView.vue'],
    ['mcp', '/mcp', ['mcp.png'], 'perf67 a11y99 | heading-order(1)', 'views/help/McpInfoView.vue'],
    ['api', '/API', ['api.png'], 'perf66 a11y95 | color-contrast(5), heading-order(1)', 'views/ApiView.vue'],
  ],
  'Auth + Detail pages': [
    ['login', '/Login', ['login.png'], 'perf66 a11y99 | heading-order(1)', 'views/LoginView.vue'],
    ['register', '/Register', ['register.png'], 'perf66 a11y100 | (none) - clean', 'views/RegisterView.vue'],
    ['gene-detail', '/Genes/ARID1B', ['gene-detail.png', 'gene-detail-mobile.png'], 'perf53 a11y93 CLS0.198 | aria-prohibited-attr(636!), color-contrast(1), heading-order(1)', 'views/pages/GeneView.vue, components/gene/*Card.vue, components/ui/*Badge.vue, components/ui/SectionCard.vue'],
    ['entity-detail', '/Entities/2', ['entity-detail.png'], 'perf65 a11y99 | heading-order(1) (+5 failed network requests)', 'views/pages/EntityView.vue, components/ui/*Badge.vue, SectionCard.vue'],
  ],
};

phase('Rate');
const clusterEntries = Object.entries(CLUSTERS);
const results = await parallel(
  clusterEntries.map(([clusterName, pages]) => () => {
    const pageBlocks = pages.map(([name, route, shots, lh, src]) => {
      const shotPaths = shots.map((s) => `${SHOTS}/${s}`).join('\n      ');
      return `
- PAGE "${name}" (route ${route})
    screenshots to Read (view them; they are 1440x900 desktop${shots.length > 1 ? ' + 390x844 mobile' : ', no mobile capture'}):
      ${shotPaths}
    lighthouse: ${lh}
    source to Read under ${APP}/: ${src}`;
    }).join('\n');
    return agent(
      `You are a demanding senior product/UX designer reviewing the SysNDD web app cluster "${clusterName}".
${STANDARDS}

Review EACH of the following ${pages.length} pages. For every page you MUST:
1) Read its screenshot PNG file(s) with the Read tool and actually look at the rendered layout, hierarchy, spacing, color, chips, charts, and density.
2) Read the listed source component(s) to judge consistency, interaction/loading/empty/error states, token usage, and a11y.
3) Anchor accessibility & color_contrast scores to the given Lighthouse failing audits (e.g. heading-order, select-name, td-has-header, button-name, color-contrast(N), aria-prohibited-attr).
4) Produce honest 1-10 scores + concrete findings + concrete improvements per the scoring rubric, tagging each improvement foundation-shared vs per-page.

Pages:
${pageBlocks}

Return ONLY the structured object with one ratings[] entry per page (${pages.length} entries).`,
      { label: `rate:${clusterName}`, phase: 'Rate', schema: SCHEMA }
    );
  })
);

const all = results.filter(Boolean).flatMap((r) => r.ratings || []);
return { count: all.length, ratings: all };
