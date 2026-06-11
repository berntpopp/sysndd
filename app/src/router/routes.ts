// src/router/routes.ts

import type { RouteRecordRaw, RouteLocationNormalized } from 'vue-router';
import {
  createAuthGuard,
  lazyRouteComponent,
  nddScoreComponents,
  adminViews,
} from './guards';

// Most admin views are simple Administrator-guarded, sitemap-ignored routes
// that differ only by name. Generating them keeps routes.ts DRY (and under the
// file-size ratchet) while preserving the exact per-route shape tests assert.
const simpleAdminRoute = (name: string): RouteRecordRaw => ({
  path: `/${name}`,
  name,
  component: lazyRouteComponent(adminViews, `../views/admin/${name}.vue`),
  meta: { sitemap: { ignoreRoute: true } },
  beforeEnter: createAuthGuard(['Administrator']),
});

export const routes: RouteRecordRaw[] = [
  {
    path: '/',
    name: 'Home',
    component: () => import('@/views/HomeView.vue'),
    meta: {
      sitemap: {
        priority: 1.0,
        changefreq: 'monthly',
      },
    },
  },
  {
    path: '/Entities',
    name: 'Entities',
    component: () => import('@/views/tables/EntitiesTable.vue'),
    props: (route) => ({
      sort: route.query.sort || undefined,
      filter: route.query.filter || undefined,
      fields: route.query.fields || undefined,
      pageAfter: route.query.page_after || undefined,
      pageSize: route.query.page_size || undefined,
      fspec: route.query.fspec || undefined,
    }),
    meta: {
      sitemap: {
        priority: 0.9,
        changefreq: 'monthly',
      },
    },
  },
  {
    path: '/Genes',
    name: 'Genes',
    component: () => import('@/views/tables/GenesTable.vue'),
    props: (route) => ({
      sort: route.query.sort || undefined,
      filter: route.query.filter || undefined,
      fields: route.query.fields || undefined,
      pageAfter: route.query.page_after || undefined,
      pageSize: route.query.page_size || undefined,
      fspec: route.query.fspec || undefined,
    }),
    meta: {
      sitemap: {
        priority: 0.9,
        changefreq: 'monthly',
      },
    },
  },
  {
    path: '/Phenotypes',
    name: 'Phenotypes',
    component: () => import('@/views/tables/PhenotypesTable.vue'),
    props: (route) => ({
      sort: route.query.sort || undefined,
      filter: route.query.filter || undefined,
      fields: route.query.fields || undefined,
      pageAfter: route.query.page_after || undefined,
      pageSize: route.query.page_size || undefined,
      fspec: route.query.fspec || undefined,
    }),
    meta: {
      sitemap: {
        priority: 0.9,
        changefreq: 'monthly',
      },
    },
  },
  {
    path: '/CurationComparisons',
    component: () => import('@/views/analyses/CurationComparisons.vue'),
    children: [
      {
        path: '',
        component: () => import('@/components/analyses/AnalysesCurationUpset.vue'),
        name: 'CurationComparisons',
      },
      {
        path: 'Similarity',
        name: 'CurationComparisonsSimilarity',
        component: () => import('@/components/analyses/AnalysesCurationMatrixPlot.vue'),
      },
      {
        path: 'Table',
        name: 'CurationComparisonsTable',
        component: () => import('@/components/analyses/AnalysesCurationComparisonsTable.vue'),
      },
    ],
    meta: {
      sitemap: {
        priority: 0.8,
        changefreq: 'monthly',
      },
    },
  },
  {
    path: '/PhenotypeCorrelations',
    component: () => import('@/views/analyses/PhenotypeCorrelations.vue'),
    children: [
      {
        path: '',
        component: () => import('@/components/analyses/AnalysesPhenotypeCorrelogram.vue'),
        name: 'PhenotypeCorrelations',
      },
      {
        path: 'PhenotypeCounts',
        component: () => import('@/components/analyses/AnalysesPhenotypeCounts.vue'),
      },
      {
        path: 'PhenotypeClusters',
        component: () => import('@/components/analyses/AnalysesPhenotypeClusters.vue'),
      },
    ],
    meta: {
      sitemap: {
        priority: 0.7,
        changefreq: 'monthly',
      },
    },
  },
  // ─────────────────────────────────────────────────────────────────────────────
  // UNIFIED ANALYSIS VIEW (Combines Phenotype Clusters, Gene Networks, Correlation)
  // ─────────────────────────────────────────────────────────────────────────────
  {
    path: '/Analysis',
    name: 'Analysis',
    component: () => import('@/views/AnalysisView.vue'),
    meta: {
      sitemap: {
        priority: 0.8,
        changefreq: 'monthly',
      },
    },
  },
  // ─────────────────────────────────────────────────────────────────────────────
  // NEW ROUTE FOR PHENO-FUNC CORRELATION
  // ─────────────────────────────────────────────────────────────────────────────
  {
    path: '/PhenotypeFunctionalCorrelation',
    name: 'PhenotypeFunctionalCorrelation',
    component: () => import('@/views/analyses/PhenotypeFunctionalCorrelation.vue'),
    meta: {
      sitemap: {
        priority: 0.8,
        changefreq: 'monthly',
      },
    },
  },
  // ─────────────────────────────────────────────────────────────────────────────
  {
    path: '/VariantCorrelations',
    component: () => import('@/views/analyses/VariantCorrelations.vue'),
    children: [
      {
        path: '',
        component: () => import('@/components/analyses/AnalysesVariantCorrelogram.vue'),
        name: 'VariantCorrelations',
      },
      {
        path: 'VariantCounts',
        component: () => import('@/components/analyses/AnalysesVariantCounts.vue'),
      },
    ],
    meta: {
      sitemap: {
        priority: 0.7,
        changefreq: 'monthly',
      },
    },
  },
  {
    path: '/EntriesOverTime',
    name: 'EntriesOverTime',
    component: () => import('@/views/analyses/EntriesOverTime.vue'),
    meta: {
      sitemap: {
        priority: 0.7,
        changefreq: 'monthly',
      },
    },
  },
  {
    path: '/PublicationsNDD',
    component: () => import('@/views/analyses/PublicationsNDD.vue'),
    children: [
      // 1) The "All" publications table from DB
      {
        path: '',
        name: 'PublicationsNDDTable',
        component: () => import('@/components/analyses/PublicationsNDDTable.vue'),
        props: (route) => ({
          sortInput: route.query.sort || '+publication_id',
          filterInput: route.query.filter || null,
          fieldsInput: route.query.fields || null,
          pageAfterInput: route.query.page_after || '0',
          pageSizeInput: Number(route.query.page_size) || 10,
        }),
      },
      // 2) The time plot
      {
        path: 'TimePlot',
        name: 'PublicationsNDDTimePlot',
        component: () => import('@/components/analyses/PublicationsNDDTimePlot.vue'),
      },
      // 3) The stats bar plot
      {
        path: 'Stats',
        name: 'PublicationsNDDStats',
        component: () => import('@/components/analyses/PublicationsNDDStats.vue'),
      },
    ],
    meta: {
      sitemap: {
        priority: 0.7,
        changefreq: 'monthly',
      },
    },
  },
  {
    path: '/PubtatorNDD',
    component: () => import('@/views/analyses/PubtatorNDD.vue'),
    // Example children: your table, genes, stats, etc. Expand as needed:
    children: [
      {
        path: '',
        name: 'PubtatorNDDTable',
        component: () => import('@/components/analyses/PubtatorNDDTable.vue'),
      },
      {
        path: 'PubtatorNDDGenes',
        name: 'PubtatorNDDGenes',
        component: () => import('@/components/analyses/PubtatorNDDGenes.vue'),
      },
      {
        path: 'Stats',
        name: 'PubtatorNDDStats',
        component: () => import('@/components/analyses/PubtatorNDDStats.vue'),
      },
    ],
    meta: {
      sitemap: { priority: 0.7, changefreq: 'monthly' },
    },
  },
  {
    path: '/GeneNetworks',
    name: 'GeneNetworks',
    component: () => import('@/views/analyses/GeneNetworks.vue'),
    meta: {
      sitemap: {
        priority: 0.7,
        changefreq: 'monthly',
      },
    },
  },
  {
    path: '/NDDScore',
    component: () => import('@/views/nddscore/NDDScore.vue'),
    children: [
      {
        path: '',
        name: 'NDDScore',
        component: lazyRouteComponent(
          nddScoreComponents,
          '../components/nddscore/NddScoreGeneTable.vue'
        ),
      },
      {
        path: 'ModelCard',
        name: 'NDDScoreModelCard',
        component: lazyRouteComponent(
          nddScoreComponents,
          '../components/nddscore/NddScoreModelCard.vue'
        ),
      },
      {
        path: 'Gene/:hgncIdOrSymbol',
        name: 'NDDScoreGeneDetail',
        component: lazyRouteComponent(
          nddScoreComponents,
          '../components/nddscore/NddScoreGeneDetail.vue'
        ),
        props: true,
      },
    ],
    meta: {
      sitemap: {
        priority: 0.7,
        changefreq: 'monthly',
      },
    },
  },
  {
    path: '/Panels/:category_input?/:inheritance_input?',
    name: 'Panels',
    component: () => import('@/views/tables/PanelsTable.vue'),
    meta: { sitemap: { ignoreRoute: true } },
    beforeEnter: (to: RouteLocationNormalized) => {
      const categoryInput = Array.isArray(to.params.category_input)
        ? to.params.category_input[0]
        : to.params.category_input;
      const inheritanceInput = Array.isArray(to.params.inheritance_input)
        ? to.params.inheritance_input[0]
        : to.params.inheritance_input;

      if (
        ['All', 'Limited', 'Definitive', 'Moderate', 'Refuted'].includes(categoryInput as string) &&
        ['All', 'Autosomal dominant', 'Other', 'Autosomal recessive', 'X-linked'].includes(
          inheritanceInput as string
        )
      ) {
        return true;
      }
      return { path: '/Panels/All/All' };
    },
  },
  {
    path: '/About',
    name: 'About',
    component: () => import('@/views/help/AboutView.vue'),
    meta: {
      sitemap: {
        priority: 0.5,
        changefreq: 'yearly',
      },
    },
  },
  {
    path: '/Documentation',
    name: 'Documentation',
    component: () => import('@/views/help/DocumentationView.vue'),
    meta: {
      sitemap: {
        priority: 0.5,
        changefreq: 'yearly',
      },
    },
  },
  {
    path: '/mcp',
    name: 'McpInfo',
    component: () => import('@/views/help/McpInfoView.vue'),
    meta: {
      sitemap: {
        priority: 0.5,
        changefreq: 'yearly',
      },
    },
  },
  {
    path: '/Login',
    name: 'Login',
    component: () => import('@/views/LoginView.vue'),
    meta: {
      sitemap: {
        priority: 0.5,
        changefreq: 'yearly',
      },
    },
  },
  {
    path: '/Register',
    name: 'Register',
    component: () => import('@/views/RegisterView.vue'),
    meta: {
      sitemap: {
        priority: 0.5,
        changefreq: 'yearly',
      },
    },
  },
  {
    path: '/User',
    name: 'User',
    component: () => import('@/views/UserView.vue'),
    meta: { sitemap: { ignoreRoute: true } },
    beforeEnter: createAuthGuard(['Administrator', 'Curator', 'Reviewer']),
  },
  {
    path: '/PasswordReset/:request_jwt?',
    name: 'PasswordReset',
    component: () => import('@/views/PasswordResetView.vue'),
    meta: { sitemap: { ignoreRoute: true } },
  },
  {
    path: '/Review',
    name: 'Review',
    component: () => import('@/views/review/Review.vue'),
    meta: { sitemap: { ignoreRoute: true } },
    beforeEnter: createAuthGuard(['Administrator', 'Curator', 'Reviewer']),
  },
  {
    path: '/ReviewInstructions',
    name: 'ReviewInstructions',
    component: () => import('@/views/review/ReviewInstructions.vue'),
    meta: { sitemap: { ignoreRoute: true } },
    beforeEnter: createAuthGuard(['Administrator', 'Curator', 'Reviewer']),
  },
  {
    path: '/CreateEntity',
    name: 'CreateEntity',
    component: () => import('@/views/curate/CreateEntity.vue'),
    meta: { sitemap: { ignoreRoute: true } },
    beforeEnter: createAuthGuard(['Administrator', 'Curator']),
  },
  {
    path: '/ModifyEntity',
    name: 'ModifyEntity',
    component: () => import('@/views/curate/ModifyEntity.vue'),
    meta: { sitemap: { ignoreRoute: true } },
    beforeEnter: createAuthGuard(['Administrator', 'Curator']),
  },
  {
    path: '/ApproveReview',
    name: 'ApproveReview',
    component: () => import('@/views/curate/ApproveReview.vue'),
    meta: { sitemap: { ignoreRoute: true } },
    beforeEnter: createAuthGuard(['Administrator', 'Curator']),
  },
  {
    path: '/ApproveStatus',
    name: 'ApproveStatus',
    component: () => import('@/views/curate/ApproveStatus.vue'),
    meta: { sitemap: { ignoreRoute: true } },
    beforeEnter: createAuthGuard(['Administrator', 'Curator']),
  },
  {
    path: '/ApproveUser',
    name: 'ApproveUser',
    component: () => import('@/views/curate/ApproveUser.vue'),
    meta: { sitemap: { ignoreRoute: true } },
    beforeEnter: createAuthGuard(['Administrator', 'Curator']),
  },
  {
    path: '/ManageReReview',
    name: 'ManageReReview',
    component: () => import('@/views/curate/ManageReReview.vue'),
    meta: { sitemap: { ignoreRoute: true } },
    beforeEnter: createAuthGuard(['Administrator', 'Curator']),
  },
  ...['ManageUser', 'ManageAnnotations', 'ManageOntology', 'ManageAbout'].map(simpleAdminRoute),
  {
    path: '/ViewLogs',
    name: 'ViewLogs',
    component: () => import('@/views/admin/ViewLogs.vue'),
    props: (route) => ({
      sort: route.query.sort || undefined,
      filter: route.query.filter || undefined,
      fields: route.query.fields || undefined,
      pageAfter: route.query.page_after || undefined,
      pageSize: route.query.page_size ? parseInt(route.query.page_size as string, 10) : undefined,
      fspec: route.query.fspec || undefined,
    }),
    meta: { sitemap: { ignoreRoute: true } },
    beforeEnter: createAuthGuard(['Administrator']),
  },
  ...[
    'AdminStatistics',
    'ManageBackups',
    'ManagePubtator',
    'ManageLLM',
    'ManageNDDScore',
    'ManageMetadata',
  ].map(simpleAdminRoute),
  {
    path: '/Entities/:entity_id',
    name: 'Entity',
    component: () => import('@/views/pages/EntityView.vue'),
    meta: { sitemap: { ignoreRoute: true } },
  },
  {
    path: '/Genes/:symbol',
    name: 'Gene',
    component: () => import('@/views/pages/GeneView.vue'),
    meta: { sitemap: { ignoreRoute: true } },
  },
  {
    path: '/Ontology/:disease_term',
    name: 'Ontology',
    component: () => import('@/views/pages/OntologyView.vue'),
    meta: { sitemap: { ignoreRoute: true } },
  },
  {
    path: '/Search/:search_term',
    name: 'Search',
    component: () => import('@/views/pages/SearchView.vue'),
    meta: { sitemap: { ignoreRoute: true } },
  },
  {
    path: '/:pathMatch(.*)*',
    name: 'NotFound',
    component: () => import('@/views/PageNotFoundView.vue'),
  },
  {
    path: '/API',
    name: 'API',
    component: () => import('@/views/ApiView.vue'),
    meta: {
      sitemap: {
        priority: 0.8,
        changefreq: 'monthly',
      },
    },
  },
];

// Module augmentation for route meta types
declare module 'vue-router' {
  interface RouteMeta {
    sitemap?: {
      priority?: number;
      changefreq?: 'always' | 'hourly' | 'daily' | 'weekly' | 'monthly' | 'yearly' | 'never';
      ignoreRoute?: boolean;
    };
    requiresAuth?: boolean;
  }
}
