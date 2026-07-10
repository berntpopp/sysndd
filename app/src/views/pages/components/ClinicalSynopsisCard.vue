<!-- app/src/views/pages/components/ClinicalSynopsisCard.vue -->
<!--
  "Clinical Synopsis" detail-page card. Extracted from EntityView.vue (#346).
  The parent keeps ownership of the useEntityReview composable and the
  clipboard copy implementation (copySynopsis/copyButtonLabel); this
  component only renders the synopsis text/loading/error state from a single
  `model` prop and reports the copy-button click via a `copy` emit.
-->
<template>
  <BRow class="entity-clinical-grid">
    <BCol cols="12" class="mb-2">
      <SectionCard
        :loading="model.loading"
        :empty="false"
        :error="model.error"
        title="Clinical Synopsis"
        min-height="18rem"
      >
        <template #header>
          <div class="clinical-card-header" data-testid="clinical-synopsis-header">
            <span>Clinical Synopsis</span>
            <span class="clinical-card-actions">
              <span v-if="model.reviewDate" class="clinical-panel-meta">
                Last reviewed {{ model.reviewDate }}
              </span>
              <BButton
                data-testid="copy-synopsis-button"
                size="sm"
                variant="outline-primary"
                class="copy-synopsis-button"
                :disabled="!model.synopsisText"
                @click="onCopyClick"
              >
                <i class="bi bi-clipboard" aria-hidden="true" />
                {{ model.copyButtonLabel }}
              </BButton>
            </span>
          </div>
        </template>
        <section
          class="clinical-synopsis-panel"
          data-testid="clinical-synopsis-panel"
          aria-label="Clinical Synopsis"
        >
          <p class="clinical-synopsis-text" data-testid="clinical-synopsis-text">
            <span v-if="model.synopsisText">{{ model.synopsisText }}</span>
            <span v-else class="entity-empty-state">No clinical synopsis available.</span>
          </p>
        </section>
      </SectionCard>
    </BCol>
  </BRow>
</template>

<script setup lang="ts">
import { BRow, BCol, BButton } from 'bootstrap-vue-next';
import SectionCard from '@/components/ui/SectionCard.vue';

export interface ClinicalSynopsisModel {
  loading: boolean;
  error: string | null;
  reviewDate: string;
  synopsisText: string;
  copyButtonLabel: string;
}

defineProps<{ model: ClinicalSynopsisModel }>();
const emit = defineEmits<{ (event: 'copy'): void }>();

function onCopyClick(): void {
  emit('copy');
}
</script>

<style scoped>
.entity-clinical-grid {
  padding-top: 0.15rem;
}
.clinical-card-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 0.75rem;
  padding-left: 0.25rem;
  color: var(--neutral-700, #374151);
  font-size: 0.875rem;
  font-weight: var(--font-weight-semibold, 600);
  line-height: 1.2;
}
.clinical-card-actions {
  display: inline-flex;
  align-items: center;
  gap: 0.5rem;
  min-width: 0;
}
.clinical-synopsis-panel {
  padding: 0.75rem;
}
.clinical-panel-meta {
  color: var(--neutral-600, #667085);
  font-size: 0.76rem;
  font-weight: 650;
}
.copy-synopsis-button {
  display: inline-flex;
  align-items: center;
  gap: 0.25rem;
  min-height: 1.45rem;
  padding: 0.08rem 0.4rem;
  border-color: var(--medical-blue-700, #0d47a1);
  color: var(--medical-blue-700, #0d47a1);
  font-size: 0.72rem;
  line-height: 1;
  white-space: nowrap;
}
.copy-synopsis-button:hover,
.copy-synopsis-button:focus {
  border-color: var(--medical-blue-700, #0d47a1);
  background-color: var(--medical-blue-700, #0d47a1);
  color: #fff;
}
.clinical-synopsis-text {
  width: 100%;
  margin: 0;
  color: var(--neutral-900, #111827);
  font-size: 0.95rem;
  line-height: 1.55;
  text-align: left;
}
.entity-empty-state {
  color: var(--neutral-600, #667085);
  font-size: 0.84rem;
  font-weight: 650;
}
@media (max-width: 575.98px) {
  .clinical-synopsis-panel {
    padding: 0.65rem;
  }
  .clinical-card-header {
    align-items: flex-start;
    flex-direction: column;
    gap: 0.15rem;
  }
  .clinical-card-actions {
    align-items: flex-start;
    flex-direction: column;
    gap: 0.25rem;
  }
  .copy-synopsis-button {
    justify-content: center;
  }
  .clinical-synopsis-text {
    font-size: 0.92rem;
  }
}
</style>
