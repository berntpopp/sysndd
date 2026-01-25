<template>
  <div class="container-fluid bg-light">
    <BSpinner
      v-if="loading"
      label="Loading..."
      class="d-block mx-auto my-5"
    />
    <BContainer
      v-else
      fluid
    >
      <BRow class="justify-content-md-center py-4">
        <BCol
          col
          md="10"
          lg="8"
        >
          <!-- Page Header -->
          <div class="text-center mb-4">
            <h2 class="fw-bold text-primary">
              <i class="bi bi-info-circle me-2" />
              About SysNDD
            </h2>
            <p class="text-muted">
              Learn about the SysNDD database, its creators, and how to cite our work
            </p>
          </div>

          <!-- Error state -->
          <BAlert v-if="error" variant="warning" show class="text-center">
            <i class="bi bi-exclamation-triangle me-2" />
            Unable to load content. Please try again later.
          </BAlert>

          <!-- Dynamic Accordion from CMS -->
          <BAccordion v-else-if="sections.length > 0" id="about-accordion">
            <BAccordionItem
              v-for="(section, index) in sections"
              :key="section.section_id"
              :visible="index === 0"
            >
              <template #title>
                <span class="fw-semibold">
                  <i :class="section.icon + ' me-2'" />
                  {{ section.title }}
                </span>
              </template>
              <div v-dompurify-html="renderMarkdown(section.content)" class="py-2 about-content" />
            </BAccordionItem>
          </BAccordion>

          <!-- Empty state -->
          <BAlert v-else variant="info" show class="text-center">
            <i class="bi bi-info-circle me-2" />
            No content available yet.
          </BAlert>
        </BCol>
      </BRow>
    </BContainer>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue';
import { useHead } from '@unhead/vue';
import { useCmsContent, renderMarkdown } from '@/composables';
import type { AboutSection } from '@/types';

useHead({
  title: 'About',
  meta: [
    {
      name: 'description',
      content:
        'The About view contains information about the SysNDD curation effort and website.',
    },
  ],
});

const loading = ref(true);
const error = ref<string | null>(null);
const sections = ref<AboutSection[]>([]);

const { loadPublished } = useCmsContent();

onMounted(async () => {
  try {
    sections.value = await loadPublished();
  } catch (err) {
    error.value = err instanceof Error ? err.message : 'Failed to load content';
    console.error('Failed to load About content:', err);
  } finally {
    loading.value = false;
  }
});
</script>

<style scoped>
.bg-light {
  background-color: #f8f9fa !important;
}

/* Markdown content styling */
.about-content :deep(h1),
.about-content :deep(h2),
.about-content :deep(h3),
.about-content :deep(h4),
.about-content :deep(h5),
.about-content :deep(h6) {
  margin-top: 1rem;
  margin-bottom: 0.5rem;
  font-weight: 600;
}

.about-content :deep(p) {
  margin-bottom: 0.75rem;
}

.about-content :deep(ul),
.about-content :deep(ol) {
  padding-left: 1.5rem;
  margin-bottom: 0.75rem;
}

.about-content :deep(a) {
  color: var(--bs-primary);
}

.about-content :deep(blockquote) {
  border-left: 4px solid var(--bs-primary);
  padding-left: 1rem;
  margin-left: 0;
  color: var(--bs-secondary);
}

.about-content :deep(code) {
  background: #f4f4f4;
  padding: 0.125rem 0.25rem;
  border-radius: 0.25rem;
}

.about-content :deep(pre) {
  background: #f4f4f4;
  padding: 1rem;
  border-radius: 0.375rem;
  overflow-x: auto;
}

/* Preserve timeline styling for News section if markdown generates it */
.about-content :deep(.timeline .d-flex) {
  border-left: 2px solid #dee2e6;
  padding-left: 1rem;
  margin-left: 0.5rem;
}
</style>
