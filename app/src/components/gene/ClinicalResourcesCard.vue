<template>
  <!-- Compact inline badge mode -->
  <div v-if="compact" class="compact-badges-strip">
    <span class="resources-label">Resources</span>
    <ResourceLink
      compact
      name="ClinGen"
      :url="clingenUrl"
      icon="bi-clipboard-check"
      :available="!!hgncId"
    />
    <ResourceLink compact name="SFARI" :url="sfariUrl" icon="bi-clipboard-data" :available="true" />
    <ResourceLink
      compact
      name="OMIM"
      :url="omimUrl"
      icon="bi-journal-medical"
      :available="!!omimId"
    />
    <ResourceLink
      compact
      name="gene2phenotype"
      :url="gene2phenotypeUrl"
      icon="bi-file-medical"
      :available="true"
    />
    <ResourceLink compact name="PanelApp" :url="panelappUrl" icon="bi-list-ul" :available="true" />
    <ResourceLink compact name="HGNC" :url="hgncUrl" icon="bi-book" :available="true" />
    <ResourceLink
      compact
      name="MGI (Mouse)"
      :url="mgiUrl"
      icon="bi-file-earmark-medical"
      :available="!!mgdId"
    />
    <ResourceLink
      compact
      name="RGD (Rat)"
      :url="rgdUrl"
      icon="bi-file-earmark-medical"
      :available="!!rgdId"
    />
  </div>

  <!-- Full card mode (default) -->
  <BCard v-else class="clinical-resources-card">
    <template #header>
      <h5 class="mb-0">Clinical Resources & Databases</h5>
    </template>

    <!-- Group 1: Curation -->
    <div class="resource-group">
      <h6 class="resource-group__heading">CURATION</h6>
      <BRow class="g-3">
        <BCol cols="12" md="6" lg="4">
          <ResourceLink
            name="ClinGen"
            :url="clingenUrl"
            description="Gene-disease validity"
            icon="bi-clipboard-check"
            :available="!!hgncId"
          />
        </BCol>
        <BCol cols="12" md="6" lg="4">
          <ResourceLink
            name="SFARI"
            :url="sfariUrl"
            description="Autism gene database"
            icon="bi-clipboard-data"
            :available="true"
          />
        </BCol>
      </BRow>
    </div>

    <!-- Group 2: Disease / Phenotype -->
    <div class="resource-group">
      <h6 class="resource-group__heading">DISEASE / PHENOTYPE</h6>
      <BRow class="g-3">
        <BCol cols="12" md="6" lg="4">
          <ResourceLink
            name="OMIM"
            :url="omimUrl"
            description="Mendelian inheritance"
            icon="bi-journal-medical"
            :available="!!omimId"
          />
        </BCol>
        <BCol cols="12" md="6" lg="4">
          <ResourceLink
            name="gene2phenotype"
            :url="gene2phenotypeUrl"
            description="Genotype-phenotype"
            icon="bi-file-medical"
            :available="true"
          />
        </BCol>
        <BCol cols="12" md="6" lg="4">
          <ResourceLink
            name="PanelApp"
            :url="panelappUrl"
            description="Gene panels"
            icon="bi-list-ul"
            :available="true"
          />
        </BCol>
      </BRow>
    </div>

    <!-- Group 3: Gene Information -->
    <div class="resource-group">
      <h6 class="resource-group__heading">GENE INFORMATION</h6>
      <BRow class="g-3">
        <BCol cols="12" md="6" lg="4">
          <ResourceLink
            name="HGNC"
            :url="hgncUrl"
            description="Gene nomenclature"
            icon="bi-book"
            :available="true"
          />
        </BCol>
      </BRow>
    </div>

    <!-- Group 4: Model Organisms -->
    <div class="resource-group">
      <h6 class="resource-group__heading">MODEL ORGANISMS</h6>
      <BRow class="g-3">
        <BCol cols="12" md="6" lg="4">
          <ResourceLink
            name="MGI (Mouse)"
            :url="mgiUrl"
            description="Mouse genome informatics"
            icon="bi-file-earmark-medical"
            :available="!!mgdId"
          />
        </BCol>
        <BCol cols="12" md="6" lg="4">
          <ResourceLink
            name="RGD (Rat)"
            :url="rgdUrl"
            description="Rat genome database"
            icon="bi-file-earmark-medical"
            :available="!!rgdId"
          />
        </BCol>
      </BRow>
    </div>
  </BCard>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import { BCard, BRow, BCol } from 'bootstrap-vue-next';
import ResourceLink from '@/components/gene/ResourceLink.vue';

interface Props {
  symbol: string;
  hgncId?: string;
  omimId?: string;
  mgdId?: string;
  rgdId?: string;
  compact?: boolean;
}

const props = withDefaults(defineProps<Props>(), {
  hgncId: undefined,
  omimId: undefined,
  mgdId: undefined,
  rgdId: undefined,
  compact: false,
});

// Computed URLs
const clingenUrl = computed(() => {
  const id = props.hgncId;
  return id && id !== 'null' ? `https://search.clinicalgenome.org/kb/genes/${id}` : undefined;
});

const sfariUrl = computed(() => {
  return `https://gene.sfari.org/database/human-gene/${props.symbol}`;
});

const omimUrl = computed(() => {
  const id = props.omimId;
  return id && id !== 'null' ? `https://www.omim.org/entry/${id}` : undefined;
});

const gene2phenotypeUrl = computed(() => {
  return `https://www.ebi.ac.uk/gene2phenotype/search?panel=ALL&search_term=${props.symbol}`;
});

const panelappUrl = computed(() => {
  return `https://panelapp.genomicsengland.co.uk/panels/entities/${props.symbol}`;
});

const hgncUrl = computed(() => {
  return `https://www.genenames.org/data/gene-symbol-report/#!/symbol/${props.symbol}`;
});

const mgiUrl = computed(() => {
  const id = props.mgdId;
  return id && id !== 'null' ? `http://www.informatics.jax.org/marker/${id}` : undefined;
});

const rgdUrl = computed(() => {
  const id = props.rgdId;
  return id && id !== 'null'
    ? `https://rgd.mcw.edu/rgdweb/report/gene/main.html?id=${id}`
    : undefined;
});
</script>

<style scoped>
.compact-badges-strip {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  column-gap: 0.25rem;
  row-gap: 0.1rem;
}

.resources-label {
  font-size: 0.7rem;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.3px;
  color: #868e96;
  margin-right: 0.25rem;
}

.clinical-resources-card {
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
  border: none;
}

.clinical-resources-card :deep(.card-header) {
  background-color: #f8f9fa;
  border-bottom: 1px solid #dee2e6;
}

.resource-group {
  margin-bottom: 2rem;
}

.resource-group:last-child {
  margin-bottom: 0;
}

.resource-group__heading {
  font-size: 0.75rem;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.5px;
  color: #6c757d;
  margin-bottom: 1rem;
  padding-bottom: 0.5rem;
  border-bottom: 1px solid #e9ecef;
}
</style>
