<!-- views/analyses/PubtatorNDD.vue -->
<template>
  <div class="container-fluid bg-gradient">
    <BContainer fluid>
      <BRow class="justify-content-md-center py-2">
        <BCol md="12">
          <!-- Header documentation -->
          <h6 class="mb-3 text-start">
            Exploring gene-literature connections from
            <mark v-b-tooltip.hover title="NCBI's biomedical text mining service">PubTator</mark>
            for neurodevelopmental disorders.
            <BBadge id="popover-badge-help-pubtator" pill href="#" variant="info">
              <i class="bi bi-question-circle-fill" />
            </BBadge>
            <BPopover target="popover-badge-help-pubtator" variant="info" triggers="focus">
              <template #title>About PubTator Analysis</template>
              <p>
                <strong>PubTator</strong> is NCBI's text mining system that identifies biomedical
                concepts (genes, diseases, chemicals) in scientific literature.
              </p>
              <p>
                This analysis searches for NDD-related publications and tracks which genes are
                mentioned. Use it to:
              </p>
              <ul class="mb-0">
                <li><strong>Table:</strong> Browse cached publications with gene annotations</li>
                <li>
                  <strong>Genes:</strong> Find genes for curation (prioritized by coverage gap)
                </li>
                <li><strong>Stats:</strong> View publication distribution and gene counts</li>
              </ul>
            </BPopover>
          </h6>

          <BCard no-body>
            <!-- Tabs in the Card Header -->
            <BCardHeader header-tag="nav">
              <BNav card-header tabs>
                <!-- Table tab -->
                <BNavItem :to="{ name: 'PubtatorNDDTable' }" exact exact-active-class="active">
                  Table
                </BNavItem>

                <!-- Genes tab with literature-only count badge -->
                <BNavItem :to="{ name: 'PubtatorNDDGenes' }" exact exact-active-class="active">
                  Genes
                  <BBadge v-if="novelGeneCount > 0" variant="info" pill class="ms-1">
                    {{ novelGeneCount }} literature only
                  </BBadge>
                </BNavItem>

                <!-- Stats tab -->
                <BNavItem :to="{ name: 'PubtatorNDDStats' }" exact exact-active-class="active">
                  Stats
                </BNavItem>
              </BNav>
            </BCardHeader>

            <!-- Child route content rendered here -->
            <BCardBody>
              <router-view @novel-count="handleNovelCount" />
            </BCardBody>
          </BCard>
        </BCol>
      </BRow>
    </BContainer>
  </div>
</template>

<script setup lang="ts">
import { ref } from 'vue';

// Reactive state for novel gene count
const novelGeneCount = ref<number>(0);

/**
 * Handle novel-count event from child component (PubtatorNDDGenes)
 * @param count - Number of novel genes (not in SysNDD)
 */
const handleNovelCount = (count: number) => {
  novelGeneCount.value = count;
};
</script>

<style scoped>
/* Optional styling for background gradient, spacing, etc. */
.bg-gradient {
  background: linear-gradient(120deg, #f8f9fa 0%, #fafbfc 100%);
}

mark {
  display: inline-block;
  line-height: 0em;
  padding-bottom: 0.5em;
  font-weight: bold;
  background-color: #eaadba;
}
</style>
