// global-components.js
// Vue 3 async component exports using defineAsyncComponent
// Components are registered on the Vue 3 app instance in main.js

import { defineAsyncComponent } from 'vue';

const globalComponents = {
  TablesEntities: defineAsyncComponent(() => import('@/components/tables/TablesEntities.vue')),
  TablesGenes: defineAsyncComponent(() => import('@/components/tables/TablesGenes.vue')),
  TablesPhenotypes: defineAsyncComponent(() => import('@/components/tables/TablesPhenotypes.vue')),
  TablesLogs: defineAsyncComponent(() => import('@/components/tables/TablesLogs.vue')),
  AnalyseGeneClusters: defineAsyncComponent(() => import('@/components/analyses/AnalyseGeneClusters.vue')),
  AnalysesPhenotypeClusters: defineAsyncComponent(() => import('@/components/analyses/AnalysesPhenotypeClusters.vue')),
  AnalysesCurationComparisonsTable: defineAsyncComponent(() => import('@/components/analyses/AnalysesCurationComparisonsTable.vue')),
  AnalysesCurationMatrixPlot: defineAsyncComponent(() => import('@/components/analyses/AnalysesCurationMatrixPlot.vue')),
  AnalysesCurationUpset: defineAsyncComponent(() => import('@/components/analyses/AnalysesCurationUpset.vue')),
  AnalysesPhenotypeCorrelogram: defineAsyncComponent(() => import('@/components/analyses/AnalysesPhenotypeCorrelogram.vue')),
  AnalysesPhenotypeCounts: defineAsyncComponent(() => import('@/components/analyses/AnalysesPhenotypeCounts.vue')),
  AnalysesTimePlot: defineAsyncComponent(() => import('@/components/analyses/AnalysesTimePlot.vue')),
  HelperBadge: defineAsyncComponent(() => import('@/components/HelperBadge.vue')),
  Navbar: defineAsyncComponent(() => import('@/components/Navbar.vue')),
  Footer: defineAsyncComponent(() => import('@/components/Footer.vue')),
  SearchBar: defineAsyncComponent(() => import('@/components/small/SearchBar.vue')),
  Banner: defineAsyncComponent(() => import('@/components/small/Banner.vue')),
  LogoutCountdownBadge: defineAsyncComponent(() => import('@/components/small/LogoutCountdownBadge.vue')),
  IconPairDropdownMenu: defineAsyncComponent(() => import('@/components/small/IconPairDropdownMenu.vue')),
};

export default globalComponents;
