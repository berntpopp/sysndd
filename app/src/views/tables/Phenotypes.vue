<template>
  <div class="container-fluid">
    <!-- Load Phenotypes table component element -->
    <TablesPhenotypes />
    <!-- Load Phenotypes table component element -->
  </div>
</template>


<script>
import TablesPhenotypes from "@/components/tables/TablesPhenotypes.vue";

export default {
  name: "Phenotypes",
  components: { TablesPhenotypes },
  metaInfo: {
    // if no subcomponents specify a metaInfo.title, this title will be used
    title: "Phenotypes",
    // all titles will be injected into this template
    titleTemplate:
      "%s | SysNDD - The expert curated database of gene disease relationships in neurodevelopmental disorders",
    htmlAttrs: {
      lang: "en",
    },
    meta: [
      {
        vmid: "description",
        name: "description",
        content:
          "The Phenotypes table view allows browsing NDD associated entities by pehnotype and filtering with download possibility.",
      },
    ],
  },
};
</script>


<style scoped>
</style>