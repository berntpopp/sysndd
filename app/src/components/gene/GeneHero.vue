<template>
  <div class="gene-hero">
    <BContainer fluid class="py-4">
      <div class="d-flex flex-column gap-2">
        <!-- Gene Symbol Badge -->
        <div>
          <GeneBadge
            :symbol="symbol"
            size="lg"
            :link-to="undefined"
            :show-title="false"
          />
        </div>

        <!-- Gene Full Name -->
        <div v-if="name" class="gene-hero__name">
          {{ name }}
        </div>

        <!-- Chromosome Location -->
        <div class="gene-hero__location text-muted">
          {{ chromosomeLocationDisplay }}
        </div>
      </div>
    </BContainer>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import { BContainer } from 'bootstrap-vue-next';
import GeneBadge from '@/components/ui/GeneBadge.vue';

interface Props {
  symbol: string;
  name?: string;
  chromosomeLocation?: string;
}

const props = withDefaults(defineProps<Props>(), {
  name: undefined,
  chromosomeLocation: undefined,
});

const chromosomeLocationDisplay = computed(() => {
  if (!props.chromosomeLocation || props.chromosomeLocation === 'null') {
    return 'Location not available';
  }
  return props.chromosomeLocation;
});
</script>

<style scoped>
.gene-hero {
  background: linear-gradient(to bottom, #f8f9fa 0%, #ffffff 100%);
  border-bottom: 1px solid #e9ecef;
}

.gene-hero__name {
  font-size: 1.5rem;
  font-weight: 600;
  color: #333;
  line-height: 1.3;
}

.gene-hero__location {
  font-size: 0.9375rem;
  font-family: 'Courier New', monospace;
}

/* Responsive adjustments */
@media (max-width: 768px) {
  .gene-hero__name {
    font-size: 1.25rem;
  }

  .gene-hero__location {
    font-size: 0.875rem;
  }
}
</style>
