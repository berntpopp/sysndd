<template>
  <AuthenticatedPageShell
    title="Review instructions"
    description="Reference material for reviewing assigned SysNDD entities."
    content-class="review-instructions"
  >
    <div class="instruction-list" aria-label="Review instruction links">
      <BLink
        v-for="item in instructionLinks"
        :key="item.title"
        :href="item.href"
        target="_blank"
        rel="noopener"
        class="instruction-row"
      >
        <span class="instruction-icon" aria-hidden="true">
          <i :class="`bi ${item.icon}`" />
        </span>
        <span class="instruction-copy">
          <span class="instruction-title">{{ item.title }}</span>
          <span class="instruction-description">{{ item.description }}</span>
        </span>
        <i class="bi bi-box-arrow-up-right instruction-external" aria-hidden="true" />
      </BLink>
    </div>
  </AuthenticatedPageShell>
</template>

<script setup lang="ts">
import { useHead } from '@unhead/vue';
import AuthenticatedPageShell from '@/components/layout/AuthenticatedPageShell.vue';
import { DOCS_URLS } from '@/constants/docs';

const instructionLinks = [
  {
    title: 'Curation criteria',
    description: 'Evidence and classification rules used while reviewing entities.',
    href: DOCS_URLS.CURATION_CRITERIA,
    icon: 'bi-list-check',
  },
  {
    title: 'Re-review instructions',
    description: 'Step-by-step workflow for updating assigned entity reviews.',
    href: DOCS_URLS.RE_REVIEW_INSTRUCTIONS,
    icon: 'bi-arrow-repeat',
  },
  {
    title: 'Tutorial videos',
    description: 'Short walkthroughs for the review workflow and supporting tools.',
    href: DOCS_URLS.TUTORIAL_VIDEOS,
    icon: 'bi-play-btn',
  },
];

useHead({
  title: 'Instructions',
  meta: [
    {
      name: 'description',
      content:
        'The Instructions view contains information about the SysNDD re-review curation effort.',
    },
  ],
});
</script>

<style scoped>
.review-instructions {
  background: #fbfcfe;
}

.instruction-list {
  display: grid;
  gap: 0.65rem;
}

.instruction-row {
  display: grid;
  grid-template-columns: auto minmax(0, 1fr) auto;
  align-items: center;
  gap: 0.75rem;
  padding: 0.8rem 0.9rem;
  border: 1px solid #d9e0ea;
  border-radius: 8px;
  background: #fff;
  color: #172033;
  text-align: left;
  text-decoration: none;
  box-shadow: 0 1px 2px rgba(15, 23, 42, 0.04);
  transition:
    border-color 0.16s ease,
    box-shadow 0.16s ease,
    transform 0.16s ease;
}

.instruction-row:hover,
.instruction-row:focus {
  border-color: #9fc1f6;
  color: #0b5ed7;
  box-shadow: 0 8px 18px rgba(15, 23, 42, 0.08);
  transform: translateY(-1px);
}

.instruction-icon {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 2rem;
  height: 2rem;
  border: 1px solid #b9d5ff;
  border-radius: 999px;
  background: #eef5ff;
  color: #0d6efd;
  font-size: 1rem;
}

.instruction-copy {
  display: grid;
  gap: 0.15rem;
  min-width: 0;
}

.instruction-title {
  color: #172033;
  font-size: 0.95rem;
  font-weight: 750;
  line-height: 1.25;
}

.instruction-description {
  color: #526070;
  font-size: 0.84rem;
  line-height: 1.35;
}

.instruction-external {
  color: #64748b;
  font-size: 0.9rem;
}

@media (max-width: 575.98px) {
  .instruction-row {
    align-items: flex-start;
    padding: 0.75rem;
  }

  .instruction-description {
    font-size: 0.8rem;
  }
}
</style>
