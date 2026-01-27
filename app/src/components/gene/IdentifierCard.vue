<template>
  <BCard class="identifier-card">
    <template #header>
      <h5 class="mb-0">Identifiers</h5>
    </template>

    <!-- HGNC ID -->
    <IdentifierRow
      label="HGNC"
      :value="geneData?.hgnc_id?.[0]"
      :show-copy="true"
    />

    <!-- Entrez -->
    <IdentifierRow
      label="Entrez"
      :value="geneData?.entrez_id?.[0]"
      :external-url="entrezUrl"
      :external-label="'NCBI Gene'"
      :show-copy="true"
    />

    <!-- Ensembl -->
    <IdentifierRow
      label="Ensembl"
      :value="geneData?.ensembl_gene_id?.[0]"
      :external-url="ensemblUrl"
      :external-label="'Ensembl'"
      :show-copy="true"
    />

    <!-- UniProt -->
    <IdentifierRow
      label="UniProt"
      :value="geneData?.uniprot_ids?.[0]"
      :external-url="uniprotUrl"
      :external-label="'UniProt'"
      :show-copy="true"
    />

    <!-- UCSC -->
    <IdentifierRow
      label="UCSC"
      :value="geneData?.ucsc_id?.[0]"
      :external-url="ucscUrl"
      :external-label="'UCSC Genome Browser'"
      :show-copy="true"
    />

    <!-- CCDS -->
    <IdentifierRow
      label="CCDS"
      :value="geneData?.ccds_id?.[0]"
      :external-url="ccdsUrl"
      :external-label="'NCBI CCDS'"
      :show-copy="true"
    />

    <!-- STRING -->
    <IdentifierRow
      label="STRING"
      :value="geneData?.STRING_id?.[0]"
      :external-url="stringUrl"
      :external-label="'STRING Database'"
      :show-copy="true"
    />

    <!-- MANE Select -->
    <IdentifierRow
      label="MANE Select"
      :value="geneData?.mane_select?.[0]"
      :show-copy="true"
    />
  </BCard>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import { BCard } from 'bootstrap-vue-next';
import IdentifierRow from '@/components/gene/IdentifierRow.vue';
import type { GeneApiData } from '@/types/gene';

interface Props {
  geneData?: GeneApiData;
}

const props = withDefaults(defineProps<Props>(), {
  geneData: undefined,
});

// Computed external URLs
const entrezUrl = computed(() => {
  const id = props.geneData?.entrez_id?.[0];
  return id && id !== 'null' ? `https://www.ncbi.nlm.nih.gov/gene/${id}` : undefined;
});

const ensemblUrl = computed(() => {
  const id = props.geneData?.ensembl_gene_id?.[0];
  return id && id !== 'null' ? `https://www.ensembl.org/Homo_sapiens/Gene/Summary?g=${id}` : undefined;
});

const uniprotUrl = computed(() => {
  const id = props.geneData?.uniprot_ids?.[0];
  return id && id !== 'null' ? `https://www.uniprot.org/uniprot/${id}` : undefined;
});

const ucscUrl = computed(() => {
  const id = props.geneData?.ucsc_id?.[0];
  return id && id !== 'null' ? `https://genome-euro.ucsc.edu/cgi-bin/hgGene?hgg_gene=${id}&db=hg38` : undefined;
});

const ccdsUrl = computed(() => {
  const id = props.geneData?.ccds_id?.[0];
  return id && id !== 'null' ? `https://www.ncbi.nlm.nih.gov/CCDS/CcdsBrowse.cgi?REQUEST=CCDS&DATA=${id}` : undefined;
});

const stringUrl = computed(() => {
  const id = props.geneData?.STRING_id?.[0];
  return id && id !== 'null' ? `https://string-db.org/network/${id}` : undefined;
});
</script>

<style scoped>
.identifier-card {
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
  border: none;
}

.identifier-card :deep(.card-header) {
  background-color: #f8f9fa;
  border-bottom: 1px solid #dee2e6;
}
</style>
