// global-components.js

import Vue from 'vue';

const components = {
  TablesEntities: () => import(/* webpackChunkName: "TableComponentsEntities" */ '@/components/tables/TablesEntities.vue'),
  TablesGenes: () => import(/* webpackChunkName: "TableComponentsGenes" */ '@/components/tables/TablesGenes.vue'),
  TablesPhenotypes: () => import(/* webpackChunkName: "TableComponentsPhenotypes" */ '@/components/tables/TablesPhenotypes.vue'),
  TablesLogs: () => import(/* webpackChunkName: "TableComponentsLogs" */ '@/components/tables/TablesLogs.vue'),
  AnalyseGeneClusters: () => import(/* webpackChunkName: "AnalysesComponentsClusters" */ '@/components/analyses/AnalyseGeneClusters.vue'),
  AnalysesPhenotypeClusters: () => import(/* webpackChunkName: "AnalysesPhenotypeClusters" */ '@/components/analyses/AnalysesPhenotypeClusters.vue'),
  AnalysesCurationComparisonsTable: () => import(/* webpackChunkName: "AnalysesComponentsCuration" */ '@/components/analyses/AnalysesCurationComparisonsTable.vue'),
  AnalysesCurationMatrixPlot: () => import(/* webpackChunkName: "AnalysesComponentsCuration" */ '@/components/analyses/AnalysesCurationMatrixPlot.vue'),
  AnalysesCurationUpset: () => import(/* webpackChunkName: "AnalysesComponentsCuration" */ '@/components/analyses/AnalysesCurationUpset.vue'),
  AnalysesPhenotypeCorrelogram: () => import(/* webpackChunkName: "AnalysesComponentsPhenotype" */ '@/components/analyses/AnalysesPhenotypeCorrelogram.vue'),
  AnalysesPhenotypeCounts: () => import(/* webpackChunkName: "AnalysesComponentsPhenotype" */ '@/components/analyses/AnalysesPhenotypeCounts.vue'),
  AnalysesTimePlot: () => import(/* webpackChunkName: "AnalysesComponentsTime" */ '@/components/analyses/AnalysesTimePlot.vue'),
  HelperBadge: () => import(/* webpackChunkName: "Small" */ '@/components/HelperBadge.vue'),
  Navbar: () => import(/* webpackChunkName: "Navigation" */ '@/components/Navbar.vue'),
  Footer: () => import(/* webpackChunkName: "Navigation" */ '@/components/Footer.vue'),
  SearchBar: () => import(/* webpackChunkName: "Small" */ '@/components/small/SearchBar.vue'),
  Banner: () => import(/* webpackChunkName: "Small" */ '@/components/small/Banner.vue'),
  LogoutCountdownBadge: () => import(/* webpackChunkName: "Small" */ '@/components/small/LogoutCountdownBadge.vue'),
  IconPairDropdownMenu: () => import(/* webpackChunkName: "Small" */ '@/components/small/IconPairDropdownMenu.vue'),
};

Object.entries(components).forEach(([name, component]) => Vue.component(name, component));
