/* eslint-disable import/prefer-default-export */
// src/router/routes.js

// TODO: remove redundance in localStorage setting/reading

export const routes = [
  {
    path: '/',
    name: 'Home',
    component: () => import(/* webpackChunkName: "Home", webpackPrefetch: 1 */ '@/views/Home.vue'),
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
    component: () => import(/* webpackChunkName: "Tables" */ '@/views/tables/Entities.vue'),
    props: (route) => ({
      sort: route.query.sort,
      filter: route.query.filter,
      fields: route.query.fields,
      pageAfter: route.query.page_after,
      pageSize: route.query.page_size,
      fspec: route.query.fspec,
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
    component: () => import(/* webpackChunkName: "Tables" */ '@/views/tables/Genes.vue'),
    props: (route) => ({
      sort: route.query.sort,
      filter: route.query.filter,
      fields: route.query.fields,
      pageAfter: route.query.page_after,
      pageSize: route.query.page_size,
      fspec: route.query.fspec,
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
    component: () => import(/* webpackChunkName: "Tables" */ '@/views/tables/Phenotypes.vue'),
    props: (route) => ({
      sort: route.query.sort,
      filter: route.query.filter,
      fields: route.query.fields,
      pageAfter: route.query.page_after,
      pageSize: route.query.page_size,
      fspec: route.query.fspec,
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
    component: () => import(/* webpackChunkName: "Analyses" */ '@/views/analyses/CurationComparisons.vue'),
    children: [
      {
        path: '',
        component: () => import(
          /* webpackChunkName: "AnalysesComponentsCuration" */ '@/components/analyses/AnalysesCurationUpset.vue'
        ),
        name: 'CurationComparisons',
      },
      {
        path: 'Similarity',
        component: () => import(
          /* webpackChunkName: "AnalysesCurationMatrixPlot" */ '@/components/analyses/AnalysesCurationMatrixPlot.vue'
        ),
      },
      {
        path: 'Table',
        component: () => import(
          /* webpackChunkName: "AnalysesCurationComparisonsTable" */ '@/components/analyses/AnalysesCurationComparisonsTable.vue'
        ),
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
    component: () => import(/* webpackChunkName: "Analyses" */ '@/views/analyses/PhenotypeCorrelations.vue'),
    children: [
      {
        path: '',
        component: () => import(
          /* webpackChunkName: "AnalysesPhenotypeCorrelogram" */ '@/components/analyses/AnalysesPhenotypeCorrelogram.vue'
        ),
        name: 'PhenotypeCorrelations',
      },
      {
        path: 'PhenotypeCounts',
        component: () => import(
          /* webpackChunkName: "AnalysesPhenotypeCounts" */ '@/components/analyses/AnalysesPhenotypeCounts.vue'
        ),
      },
      {
        path: 'PhenotypeClusters',
        component: () => import(
          /* webpackChunkName: "AnalysesPhenotypeClusters" */ '@/components/analyses/AnalysesPhenotypeClusters.vue'
        ),
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
  // NEW ROUTE FOR PHENO-FUNC CORRELATION
  // ─────────────────────────────────────────────────────────────────────────────
  {
    path: '/PhenotypeFunctionalCorrelation',
    name: 'PhenotypeFunctionalCorrelation',
    component: () => import(/* webpackChunkName: "Analyses" */ '@/views/analyses/PhenotypeFunctionalCorrelation.vue'),
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
    component: () => import(/* webpackChunkName: "AnalysesVariants" */ '@/views/analyses/VariantCorrelations.vue'),
    children: [
      {
        path: '',
        component: () => import(
          /* webpackChunkName: "AnalysesVariantCorrelogram" */ '@/components/analyses/AnalysesVariantCorrelogram.vue'
        ),
        name: 'VariantCorrelations',
      },
      {
        path: 'VariantCounts',
        component: () => import(
          /* webpackChunkName: "AnalysesVariantCounts" */ '@/components/analyses/AnalysesVariantCounts.vue'
        ),
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
    component: () => import(/* webpackChunkName: "Analyses" */ '@/views/analyses/EntriesOverTime.vue'),
    meta: {
      sitemap: {
        priority: 0.7,
        changefreq: 'monthly',
      },
    },
  },
  {
    path: '/PublicationsNDD',
    component: () => import(/* webpackChunkName: "Analyses" */ '@/views/analyses/PublicationsNDD.vue'),
    children: [
      // 1) The "All" publications table from DB
      {
        path: '',
        name: 'PublicationsNDDTable',
        component: () => import(
          /* webpackChunkName: "PublicationsNDDTable" */ '@/components/analyses/PublicationsNDDTable.vue'
        ),
      },
      // 2) The time plot
      {
        path: 'TimePlot',
        name: 'PublicationsNDDTimePlot',
        component: () => import(
          /* webpackChunkName: "PublicationsNDDTimePlot" */ '@/components/analyses/PublicationsNDDTimePlot.vue'
        ),
      },
      // 3) The stats bar plot
      {
        path: 'Stats',
        name: 'PublicationsNDDStats',
        component: () => import(
          /* webpackChunkName: "PublicationsNDDStats" */ '@/components/analyses/PublicationsNDDStats.vue'
        ),
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
    component: () => import('@/views/analyses/PubtatorNDD.vue' /* webpackChunkName: "Analyses" */),
    // Example children: your table, genes, stats, etc. Expand as needed:
    children: [
      {
        path: '',
        name: 'PubtatorNDDTable',
        component: () => import('@/components/analyses/PubtatorNDDTable.vue' /* webpackChunkName: "PubtatorNDDTable" */),
      },
      {
        path: 'PubtatorNDDGenes',
        name: 'PubtatorNDDGenes',
        component: () => import('@/components/analyses/PubtatorNDDGenes.vue' /* webpackChunkName: "PubtatorNDDGenes" */),
      },
    ],
    meta: {
      sitemap: { priority: 0.7, changefreq: 'monthly' },
    },
  },
  {
    path: '/GeneNetworks',
    name: 'GeneNetworks',
    component: () => import(/* webpackChunkName: "Analyses" */ '@/views/analyses/GeneNetworks.vue'),
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
    component: () => import(/* webpackChunkName: "Tables" */ '@/views/tables/Panels.vue'),
    meta: { sitemap: { ignoreRoute: true } },
    beforeEnter: (to, from, next) => {
      if (
        ['All', 'Limited', 'Definitive', 'Moderate', 'Refuted'].includes(
          to.params.category_input,
        )
        && [
          'All',
          'Autosomal dominant',
          'Other',
          'Autosomal recessive',
          'X-linked',
        ].includes(to.params.inheritance_input)
      ) {
        next(); // everything good, proceed
      } else {
        next({ path: '/Panels/All/All' }); // redirect to a known setup
      }
    },
  },
  {
    path: '/About',
    name: 'About',
    component: () => import(/* webpackChunkName: "About" */ '@/views/help/About.vue'),
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
    component: () => import(/* webpackChunkName: "Documentation" */ '@/views/help/Documentation.vue'),
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
    component: () => import(/* webpackChunkName: "User" */ '@/views/Login.vue'),
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
    component: () => import(/* webpackChunkName: "User" */ '@/views/Register.vue'),
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
    component: () => import(/* webpackChunkName: "User" */ '@/views/User.vue'),
    meta: { sitemap: { ignoreRoute: true } },
    beforeEnter: (to, from, next) => {
      const allowed_roles = ['Administrator', 'Curator', 'Reviewer'];
      let expires = 0;
      let timestamp = 0;
      let user_role = 'Viewer';

      if (localStorage.token) {
        expires = JSON.parse(localStorage.user).exp;
        user_role = JSON.parse(localStorage.user).user_role;
        timestamp = Math.floor(new Date().getTime() / 1000);
      }

      if (!localStorage.user || timestamp > expires || !allowed_roles.includes(user_role[0])) {
        next({ name: 'Login' });
      } else next();
    },
  },
  {
    path: '/PasswordReset/:request_jwt?',
    name: 'PasswordReset',
    component: () => import(/* webpackChunkName: "User" */ '@/views/PasswordReset.vue'),
    meta: { sitemap: { ignoreRoute: true } },
  },
  {
    path: '/Review',
    name: 'Review',
    component: () => import(/* webpackChunkName: "DataEntry" */ '@/views/review/Review.vue'),
    meta: { sitemap: { ignoreRoute: true } },
    beforeEnter: (to, from, next) => {
      const allowed_roles = ['Administrator', 'Curator', 'Reviewer'];
      let expires = 0;
      let timestamp = 0;
      let user_role = 'Viewer';

      if (localStorage.token) {
        expires = JSON.parse(localStorage.user).exp;
        user_role = JSON.parse(localStorage.user).user_role;
        timestamp = Math.floor(new Date().getTime() / 1000);
      }

      if (!localStorage.user || timestamp > expires || !allowed_roles.includes(user_role[0])) {
        next({ name: 'Login' });
      } else next();
    },
  },
  {
    path: '/ReviewInstructions',
    name: 'ReviewInstructions',
    component: () => import(/* webpackChunkName: "DataEntry" */ '@/views/review/Instructions.vue'),
    meta: { sitemap: { ignoreRoute: true } },
    beforeEnter: (to, from, next) => {
      const allowed_roles = ['Administrator', 'Curator', 'Reviewer'];
      let expires = 0;
      let timestamp = 0;
      let user_role = 'Viewer';

      if (localStorage.token) {
        expires = JSON.parse(localStorage.user).exp;
        user_role = JSON.parse(localStorage.user).user_role;
        timestamp = Math.floor(new Date().getTime() / 1000);
      }

      if (!localStorage.user || timestamp > expires || !allowed_roles.includes(user_role[0])) {
        next({ name: 'Login' });
      } else next();
    },
  },
  {
    path: '/CreateEntity',
    name: 'CreateEntity',
    component: () => import(/* webpackChunkName: "DataEntry" */ '@/views/curate/CreateEntity.vue'),
    meta: { sitemap: { ignoreRoute: true } },
    beforeEnter: (to, from, next) => {
      const allowed_roles = ['Administrator', 'Curator'];
      let expires = 0;
      let timestamp = 0;
      let user_role = 'Viewer';

      if (localStorage.token) {
        expires = JSON.parse(localStorage.user).exp;
        user_role = JSON.parse(localStorage.user).user_role;
        timestamp = Math.floor(new Date().getTime() / 1000);
      }

      if (!localStorage.user || timestamp > expires || !allowed_roles.includes(user_role[0])) {
        next({ name: 'Login' });
      } else next();
    },
  },
  {
    path: '/ModifyEntity',
    name: 'ModifyEntity',
    component: () => import(/* webpackChunkName: "DataEntry" */ '@/views/curate/ModifyEntity.vue'),
    meta: { sitemap: { ignoreRoute: true } },
    beforeEnter: (to, from, next) => {
      const allowed_roles = ['Administrator', 'Curator'];
      let expires = 0;
      let timestamp = 0;
      let user_role = 'Viewer';

      if (localStorage.token) {
        expires = JSON.parse(localStorage.user).exp;
        user_role = JSON.parse(localStorage.user).user_role;
        timestamp = Math.floor(new Date().getTime() / 1000);
      }

      if (!localStorage.user || timestamp > expires || !allowed_roles.includes(user_role[0])) {
        next({ name: 'Login' });
      } else next();
    },
  },
  {
    path: '/ApproveReview',
    name: 'ApproveReview',
    component: () => import(/* webpackChunkName: "DataEntry" */ '@/views/curate/ApproveReview.vue'),
    meta: { sitemap: { ignoreRoute: true } },
    beforeEnter: (to, from, next) => {
      const allowed_roles = ['Administrator', 'Curator'];
      let expires = 0;
      let timestamp = 0;
      let user_role = 'Viewer';

      if (localStorage.token) {
        expires = JSON.parse(localStorage.user).exp;
        user_role = JSON.parse(localStorage.user).user_role;
        timestamp = Math.floor(new Date().getTime() / 1000);
      }

      if (!localStorage.user || timestamp > expires || !allowed_roles.includes(user_role[0])) {
        next({ name: 'Login' });
      } else next();
    },
  },
  {
    path: '/ApproveStatus',
    name: 'ApproveStatus',
    component: () => import(/* webpackChunkName: "DataEntry" */ '@/views/curate/ApproveStatus.vue'),
    meta: { sitemap: { ignoreRoute: true } },
    beforeEnter: (to, from, next) => {
      const allowed_roles = ['Administrator', 'Curator'];
      let expires = 0;
      let timestamp = 0;
      let user_role = 'Viewer';

      if (localStorage.token) {
        expires = JSON.parse(localStorage.user).exp;
        user_role = JSON.parse(localStorage.user).user_role;
        timestamp = Math.floor(new Date().getTime() / 1000);
      }

      if (!localStorage.user || timestamp > expires || !allowed_roles.includes(user_role[0])) {
        next({ name: 'Login' });
      } else next();
    },
  },
  {
    path: '/ApproveUser',
    name: 'ApproveUser',
    component: () => import(/* webpackChunkName: "DataEntry" */ '@/views/curate/ApproveUser.vue'),
    meta: { sitemap: { ignoreRoute: true } },
    beforeEnter: (to, from, next) => {
      const allowed_roles = ['Administrator', 'Curator'];
      let expires = 0;
      let timestamp = 0;
      let user_role = 'Viewer';

      if (localStorage.token) {
        expires = JSON.parse(localStorage.user).exp;
        user_role = JSON.parse(localStorage.user).user_role;
        timestamp = Math.floor(new Date().getTime() / 1000);
      }

      if (!localStorage.user || timestamp > expires || !allowed_roles.includes(user_role[0])) {
        next({ name: 'Login' });
      } else next();
    },
  },
  {
    path: '/ManageReReview',
    name: 'ManageReReview',
    component: () => import(/* webpackChunkName: "DataEntry" */ '@/views/curate/ManageReReview.vue'),
    meta: { sitemap: { ignoreRoute: true } },
    beforeEnter: (to, from, next) => {
      const allowed_roles = ['Administrator', 'Curator'];
      let expires = 0;
      let timestamp = 0;
      let user_role = 'Viewer';

      if (localStorage.token) {
        expires = JSON.parse(localStorage.user).exp;
        user_role = JSON.parse(localStorage.user).user_role;
        timestamp = Math.floor(new Date().getTime() / 1000);
      }

      if (!localStorage.user || timestamp > expires || !allowed_roles.includes(user_role[0])) {
        next({ name: 'Login' });
      } else next();
    },
  },
  {
    path: '/ManageUser',
    name: 'ManageUser',
    component: () => import(/* webpackChunkName: "Administration" */ '@/views/admin/ManageUser.vue'),
    meta: { sitemap: { ignoreRoute: true } },
    beforeEnter: (to, from, next) => {
      const allowed_roles = ['Administrator'];
      let expires = 0;
      let timestamp = 0;
      let user_role = 'Viewer';

      if (localStorage.token) {
        expires = JSON.parse(localStorage.user).exp;
        user_role = JSON.parse(localStorage.user).user_role;
        timestamp = Math.floor(new Date().getTime() / 1000);
      }

      if (!localStorage.user || timestamp > expires || !allowed_roles.includes(user_role[0])) {
        next({ name: 'Login' });
      } else next();
    },
  },
  {
    path: '/ManageAnnotations',
    name: 'ManageAnnotations',
    component: () => import(/* webpackChunkName: "Administration" */ '@/views/admin/ManageAnnotations.vue'),
    meta: { sitemap: { ignoreRoute: true } },
    beforeEnter: (to, from, next) => {
      const allowed_roles = ['Administrator'];
      let expires = 0;
      let timestamp = 0;
      let user_role = 'Viewer';

      if (localStorage.token) {
        expires = JSON.parse(localStorage.user).exp;
        user_role = JSON.parse(localStorage.user).user_role;
        timestamp = Math.floor(new Date().getTime() / 1000);
      }

      if (!localStorage.user || timestamp > expires || !allowed_roles.includes(user_role[0])) {
        next({ name: 'Login' });
      } else next();
    },
  },
  {
    path: '/ManageOntology',
    name: 'ManageOntology',
    component: () => import(/* webpackChunkName: "Administration" */ '@/views/admin/ManageOntology.vue'),
    meta: { sitemap: { ignoreRoute: true } },
    beforeEnter: (to, from, next) => {
      const allowed_roles = ['Administrator'];
      let expires = 0;
      let timestamp = 0;
      let user_role = 'Viewer';

      if (localStorage.token) {
        expires = JSON.parse(localStorage.user).exp;
        user_role = JSON.parse(localStorage.user).user_role;
        timestamp = Math.floor(new Date().getTime() / 1000);
      }

      if (!localStorage.user || timestamp > expires || !allowed_roles.includes(user_role[0])) {
        next({ name: 'Login' });
      } else next();
    },
  },
  {
    path: '/ManageAbout',
    name: 'ManageAbout',
    component: () => import(/* webpackChunkName: "Administration" */ '@/views/admin/ManageAbout.vue'),
    meta: { sitemap: { ignoreRoute: true } },
    beforeEnter: (to, from, next) => {
      const allowed_roles = ['Administrator'];
      let expires = 0;
      let timestamp = 0;
      let user_role = 'Viewer';

      if (localStorage.token) {
        expires = JSON.parse(localStorage.user).exp;
        user_role = JSON.parse(localStorage.user).user_role;
        timestamp = Math.floor(new Date().getTime() / 1000);
      }

      if (!localStorage.user || timestamp > expires || !allowed_roles.includes(user_role[0])) {
        next({ name: 'Login' });
      } else next();
    },
  },
  {
    path: '/ViewLogs',
    name: 'ViewLogs',
    component: () => import(/* webpackChunkName: "Administration" */ '@/views/admin/ViewLogs.vue'),
    meta: { sitemap: { ignoreRoute: true } },
    beforeEnter: (to, from, next) => {
      const allowed_roles = ['Administrator'];
      let expires = 0;
      let timestamp = 0;
      let user_role = 'Viewer';

      if (localStorage.token) {
        expires = JSON.parse(localStorage.user).exp;
        user_role = JSON.parse(localStorage.user).user_role;
        timestamp = Math.floor(new Date().getTime() / 1000);
      }

      if (!localStorage.user || timestamp > expires || !allowed_roles.includes(user_role[0])) {
        next({ name: 'Login' });
      } else {
        next();
      }
    },
  },
  {
    path: '/AdminStatistics',
    name: 'AdminStatistics',
    component: () => import(/* webpackChunkName: "Administration" */ '@/views/admin/AdminStatistics.vue'),
    meta: { sitemap: { ignoreRoute: true } },
    beforeEnter: (to, from, next) => {
      const allowed_roles = ['Administrator'];
      let expires = 0;
      let timestamp = 0;
      let user_role = 'Viewer';

      if (localStorage.token) {
        expires = JSON.parse(localStorage.user).exp;
        user_role = JSON.parse(localStorage.user).user_role;
        timestamp = Math.floor(new Date().getTime() / 1000);
      }

      if (!localStorage.user || timestamp > expires || !allowed_roles.includes(user_role[0])) {
        next({ name: 'Login' });
      } else {
        next();
      }
    },
  },
  {
    path: '/Entities/:entity_id',
    name: 'Entity',
    component: () => import(/* webpackChunkName: "Pages" */ '@/views/pages/Entity.vue'),
    meta: { sitemap: { ignoreRoute: true } },
  },
  {
    path: '/Genes/:symbol',
    name: 'Gene',
    component: () => import(/* webpackChunkName: "Pages" */ '@/views/pages/Gene.vue'),
    meta: { sitemap: { ignoreRoute: true } },
  },
  {
    path: '/Ontology/:disease_term',
    name: 'Ontology',
    component: () => import(/* webpackChunkName: "Pages" */ '@/views/pages/Ontology.vue'),
    meta: { sitemap: { ignoreRoute: true } },
  },
  {
    path: '/Search/:search_term',
    name: 'Search',
    component: () => import(/* webpackChunkName: "Pages" */ '@/views/pages/Search.vue'),
    meta: { sitemap: { ignoreRoute: true } },
  },
  {
    path: '*',
    component: () => import(/* webpackChunkName: "Pages" */ '@/views/PageNotFound.vue'),
  },
  {
    path: '/API',
    name: 'API',
    component: () => import(/* webpackChunkName: "API" */ '@/views/API.vue'),
    meta: {
      sitemap: {
        priority: 0.8,
        changefreq: 'monthly',
      },
    },
  },
];
