// global-components.js
// Vue 3 async component exports using defineAsyncComponent
// Components are registered on the Vue 3 app instance in main.js

import { defineAsyncComponent } from 'vue';

const globalComponents = {
  TablesEntities: defineAsyncComponent(() => import(/* webpackChunkName: "TableComponentsEntities" */ '@/components/tables/TablesEntities.vue')),
  TablesGenes: defineAsyncComponent(() => import(/* webpackChunkName: "TableComponentsGenes" */ '@/components/tables/TablesGenes.vue')),
  TablesPhenotypes: defineAsyncComponent(() => import(/* webpackChunkName: "TableComponentsPhenotypes" */ '@/components/tables/TablesPhenotypes.vue')),
  TablesLogs: defineAsyncComponent(() => import(/* webpackChunkName: "TableComponentsLogs" */ '@/components/tables/TablesLogs.vue')),
  AnalyseGeneClusters: defineAsyncComponent(() => import(/* webpackChunkName: "AnalysesComponentsClusters" */ '@/components/analyses/AnalyseGeneClusters.vue')),
  AnalysesPhenotypeClusters: defineAsyncComponent(() => import(/* webpackChunkName: "AnalysesPhenotypeClusters" */ '@/components/analyses/AnalysesPhenotypeClusters.vue')),
  AnalysesCurationComparisonsTable: defineAsyncComponent(() => import(/* webpackChunkName: "AnalysesComponentsCuration" */ '@/components/analyses/AnalysesCurationComparisonsTable.vue')),
  AnalysesCurationMatrixPlot: defineAsyncComponent(() => import(/* webpackChunkName: "AnalysesComponentsCuration" */ '@/components/analyses/AnalysesCurationMatrixPlot.vue')),
  AnalysesCurationUpset: defineAsyncComponent(() => import(/* webpackChunkName: "AnalysesComponentsCuration" */ '@/components/analyses/AnalysesCurationUpset.vue')),
  AnalysesPhenotypeCorrelogram: defineAsyncComponent(() => import(/* webpackChunkName: "AnalysesComponentsPhenotype" */ '@/components/analyses/AnalysesPhenotypeCorrelogram.vue')),
  AnalysesPhenotypeCounts: defineAsyncComponent(() => import(/* webpackChunkName: "AnalysesComponentsPhenotype" */ '@/components/analyses/AnalysesPhenotypeCounts.vue')),
  AnalysesTimePlot: defineAsyncComponent(() => import(/* webpackChunkName: "AnalysesComponentsTime" */ '@/components/analyses/AnalysesTimePlot.vue')),
  HelperBadge: defineAsyncComponent(() => import(/* webpackChunkName: "Small" */ '@/components/HelperBadge.vue')),
  Navbar: defineAsyncComponent(() => import(/* webpackChunkName: "Navigation" */ '@/components/Navbar.vue')),
  Footer: defineAsyncComponent(() => import(/* webpackChunkName: "Navigation" */ '@/components/Footer.vue')),
  SearchBar: defineAsyncComponent(() => import(/* webpackChunkName: "Small" */ '@/components/small/SearchBar.vue')),
  Banner: defineAsyncComponent(() => import(/* webpackChunkName: "Small" */ '@/components/small/Banner.vue')),
  LogoutCountdownBadge: defineAsyncComponent(() => import(/* webpackChunkName: "Small" */ '@/components/small/LogoutCountdownBadge.vue')),
  IconPairDropdownMenu: defineAsyncComponent(() => import(/* webpackChunkName: "Small" */ '@/components/small/IconPairDropdownMenu.vue')),
};

export default globalComponents;
