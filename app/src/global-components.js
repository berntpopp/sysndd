import Vue from 'vue';

const components = {
  TablesEntities: () => import(/* webpackChunkName: "TableComponentsEntities" */ '@/components/tables/TablesEntities.vue'),
  TablesGenes: () => import(/* webpackChunkName: "TableComponentsGenes" */ '@/components/tables/TablesGenes.vue'),
  TablesPhenotypes: () => import(/* webpackChunkName: "TableComponentsPhenotypes" */ '@/components/tables/TablesPhenotypes.vue'),
  AnalyseGeneClusters: () => import(/* webpackChunkName: "AnalysesComponentsClusters" */ '@/components/analyses/AnalyseGeneClusters.vue'),
  AnalysesCurationComparisonsTable: () => import(/* webpackChunkName: "AnalysesComponentsCuration" */ '@/components/analyses/AnalysesCurationComparisonsTable.vue'),
  AnalysesCurationMatrixPlot: () => import(/* webpackChunkName: "AnalysesComponentsCuration" */ '@/components/analyses/AnalysesCurationMatrixPlot.vue'),
  AnalysesCurationUpset: () => import(/* webpackChunkName: "AnalysesComponentsCuration" */ '@/components/analyses/AnalysesCurationUpset.vue'),
  AnalysesPhenotypeCorrelogram: () => import(/* webpackChunkName: "AnalysesComponentsPhenotype" */ '@/components/analyses/AnalysesPhenotypeCorrelogram.vue'),
  AnalysesPhenotypeCounts: () => import(/* webpackChunkName: "AnalysesComponentsPhenotype" */ '@/components/analyses/AnalysesPhenotypeCounts.vue'),
  AnalysesTimePlot: () => import(/* webpackChunkName: "AnalysesComponentsTime" */ '@/components/analyses/AnalysesTimePlot.vue'),
};

Object.entries(components).forEach(([name, component]) => Vue.component(name, component));
