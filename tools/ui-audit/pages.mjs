// Every route in app/src/router/routes.ts with the role that reaches it and a
// representative URL. `ready` is the selector that means "main content usable"
// (default: see run.mjs). `modal` is a selector whose click opens a dialog that
// is safe to open and dismiss with Escape (never a destructive action).
// Interactions not present on a page are recorded as skipped, not failed.

const ROWS = 'table tbody tr, .mobile-record-row'; // desktop table rows or the mobile card list

export const PAGES = [
  // --- public -------------------------------------------------------------
  { id: 'home', role: 'public', path: '/' },
  { id: 'home-first-visit', role: 'public', path: '/', firstVisit: true }, // usage-policy dialog
  { id: 'entities', role: 'public', path: '/Entities', ready: ROWS },
  { id: 'genes', role: 'public', path: '/Genes', ready: ROWS },
  { id: 'phenotypes', role: 'public', path: '/Phenotypes', ready: ROWS },
  { id: 'comparisons', role: 'public', path: '/CurationComparisons' },
  { id: 'comparisons-similarity', role: 'public', path: '/CurationComparisons/Similarity' },
  { id: 'comparisons-table', role: 'public', path: '/CurationComparisons/Table', ready: ROWS },
  { id: 'phenotype-correlations', role: 'public', path: '/PhenotypeCorrelations' },
  { id: 'phenotype-counts', role: 'public', path: '/PhenotypeCorrelations/PhenotypeCounts' },
  { id: 'phenotype-clusters', role: 'public', path: '/PhenotypeCorrelations/PhenotypeClusters' },
  { id: 'analysis', role: 'public', path: '/Analysis' },
  { id: 'phenotype-functional', role: 'public', path: '/PhenotypeFunctionalCorrelation' },
  { id: 'variant-correlations', role: 'public', path: '/VariantCorrelations' },
  { id: 'variant-counts', role: 'public', path: '/VariantCorrelations/VariantCounts' },
  { id: 'entries-over-time', role: 'public', path: '/EntriesOverTime' },
  { id: 'publications', role: 'public', path: '/PublicationsNDD', ready: ROWS },
  { id: 'publications-timeplot', role: 'public', path: '/PublicationsNDD/TimePlot' },
  { id: 'publications-stats', role: 'public', path: '/PublicationsNDD/Stats' },
  { id: 'pubtator', role: 'public', path: '/PubtatorNDD', ready: ROWS },
  { id: 'pubtator-genes', role: 'public', path: '/PubtatorNDD/PubtatorNDDGenes' },
  { id: 'pubtator-stats', role: 'public', path: '/PubtatorNDD/Stats' },
  { id: 'gene-networks', role: 'public', path: '/GeneNetworks' },
  { id: 'data-releases', role: 'public', path: '/DataReleases' },
  { id: 'nddscore', role: 'public', path: '/NDDScore' },
  { id: 'nddscore-modelcard', role: 'public', path: '/NDDScore/ModelCard' },
  { id: 'nddscore-gene', role: 'public', path: '/NDDScore/Gene/FBXO11' },
  { id: 'panels', role: 'public', path: '/Panels/All/All', ready: ROWS },
  { id: 'about', role: 'public', path: '/About' },
  { id: 'documentation', role: 'public', path: '/Documentation' },
  { id: 'mcp', role: 'public', path: '/mcp' },
  { id: 'api', role: 'public', path: '/API' },
  { id: 'login', role: 'public', path: '/Login', ready: 'form' },
  { id: 'register', role: 'public', path: '/Register', ready: 'form' },
  { id: 'password-reset', role: 'public', path: '/PasswordReset', ready: 'form' },
  { id: 'entity', role: 'public', path: '/Entities/1848' },
  { id: 'gene-fbxo11', role: 'public', path: '/Genes/FBXO11' },
  { id: 'gene-arid1b', role: 'public', path: '/Genes/ARID1B' },
  { id: 'ontology', role: 'public', path: '/Ontology/OMIM:618089' },
  { id: 'search', role: 'public', path: '/Search/FBXO11' },
  { id: 'not-found', role: 'public', path: '/this-page-does-not-exist' },
  // --- Reviewer (Administrator, Curator, Reviewer) ----------------------------
  { id: 'user', role: 'REVIEWER', path: '/User' },
  { id: 'review', role: 'REVIEWER', path: '/Review' },
  { id: 'review-instructions', role: 'REVIEWER', path: '/ReviewInstructions' },
  // --- Curator (Administrator, Curator) -------------------------------------
  { id: 'create-entity', role: 'CURATOR', path: '/CreateEntity' },
  { id: 'modify-entity', role: 'CURATOR', path: '/ModifyEntity' },
  { id: 'approve-review', role: 'CURATOR', path: '/ApproveReview' },
  { id: 'approve-status', role: 'CURATOR', path: '/ApproveStatus' },
  { id: 'approve-user', role: 'CURATOR', path: '/ApproveUser' },
  { id: 'manage-rereview', role: 'CURATOR', path: '/ManageReReview' },
  { id: 'variation-suggestions', role: 'CURATOR', path: '/curate/variation-suggestions' },
  { id: 'gene-reviews', role: 'CURATOR', path: '/GeneReviews' },
  // --- Administrator --------------------------------------------------------
  ...[
    'ManageUser', 'ManageAnnotations', 'ManageOntology', 'ManageAbout', 'ViewLogs',
    'AdminStatistics', 'ManageBackups', 'ManagePubtator', 'ManageLLM', 'ManageNDDScore',
    'ManageMetadata', 'ManageOntologyMappings', 'ManageAnalysisReleases',
  ].map((name) => ({ id: name.replace(/([a-z])([A-Z])/g, '$1-$2').toLowerCase(), role: 'ADMIN', path: `/${name}` })),
];
