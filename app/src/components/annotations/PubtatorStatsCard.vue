<!-- components/annotations/PubtatorStatsCard.vue -->
<template>
  <BCard
    header-tag="header"
    body-class="p-1"
    header-class="p-1"
    border-variant="dark"
    class="mb-3 text-start"
  >
    <template #header>
      <h5 class="mb-0 text-start font-weight-bold">
        Pubtator Cache Management
        <span v-if="stats.publication_count !== null" class="badge bg-info ms-2 fw-normal">
          {{ stats.publication_count?.toLocaleString() }} publications
        </span>
        <span v-if="stats.gene_count !== null" class="badge bg-info ms-2 fw-normal">
          {{ stats.gene_count?.toLocaleString() }} genes
        </span>
        <span
          v-if="stats.novel_count !== null && stats.novel_count > 0"
          class="badge bg-info ms-2 fw-normal"
        >
          {{ stats.novel_count?.toLocaleString() }} literature only
        </span>
      </h5>
    </template>

    <div class="mb-2">
      <BButton variant="outline-secondary" size="sm" :disabled="loading" @click="$emit('refresh')">
        <BSpinner v-if="loading" small type="grow" class="me-1" />
        <i v-else class="bi bi-arrow-clockwise me-1" />
        {{ loading ? 'Loading...' : 'Refresh Stats' }}
      </BButton>
      <small class="text-muted ms-2">
        Shows cached Pubtator gene-publication data for NDD literature
      </small>
    </div>

    <div v-if="stats.gene_count !== null" class="mt-2">
      <p class="text-muted small mb-2">
        The Pubtator cache contains gene-publication associations from NCBI's PubTator text-mining
        service. "Literature Only" genes are those mentioned in NDD publications but not yet curated
        in SysNDD.
      </p>
      <div class="d-flex flex-wrap gap-2">
        <router-link :to="{ name: 'PubtatorNDDStats' }" class="btn btn-sm btn-outline-primary">
          <i class="bi bi-bar-chart me-1" />
          View Pubtator Analysis
        </router-link>
        <router-link :to="{ name: 'ManagePubtator' }" class="btn btn-sm btn-outline-secondary">
          <i class="bi bi-gear me-1" />
          Manage Cache
        </router-link>
      </div>
    </div>

    <BAlert v-if="stats.gene_count === 0" variant="warning" show class="mt-2 mb-0">
      No Pubtator data cached.
      <router-link :to="{ name: 'ManagePubtator' }">Manage Cache</router-link>
      to fetch publications.
    </BAlert>
  </BCard>
</template>

<script setup lang="ts">
export interface PubtatorStats {
  publication_count: number | null;
  gene_count: number | null;
  novel_count: number | null;
}

defineProps<{
  stats: PubtatorStats;
  loading: boolean;
}>();

defineEmits<{
  (e: 'refresh'): void;
}>();
</script>
