<template>
  <div class="container-fluid">
    <BContainer fluid>
      <!-- Header -->
      <BRow class="justify-content-md-center py-3">
        <BCol col md="11" lg="10">
          <div class="d-flex justify-content-between align-items-center mb-3">
            <div>
              <h3 class="mb-1">
                <i class="bi bi-file-earmark-text me-2" />
                Manage About Page
              </h3>
              <p class="text-muted mb-0">
                Edit the About page content using markdown. Changes are saved as drafts until published.
              </p>
            </div>

            <!-- Status indicator -->
            <div class="text-end">
              <BBadge :variant="isDraft ? 'warning' : 'success'" class="me-2">
                {{ isDraft ? 'Draft' : 'Published' }}
              </BBadge>
              <span v-if="currentVersion" class="text-muted small">
                v{{ currentVersion }}
              </span>
            </div>
          </div>

          <!-- Action buttons -->
          <div class="d-flex gap-2 mb-4">
            <BButton
              variant="outline-secondary"
              :disabled="isSaving || isPublishing"
              @click="handleSaveDraft"
            >
              <BSpinner v-if="isSaving" small class="me-1" />
              <i v-else class="bi bi-save me-1" />
              Save Draft
            </BButton>
            <BButton
              variant="primary"
              :disabled="isSaving || isPublishing || sections.length === 0"
              @click="handlePublish"
            >
              <BSpinner v-if="isPublishing" small class="me-1" />
              <i v-else class="bi bi-send me-1" />
              Publish
            </BButton>

            <!-- Last saved indicator -->
            <div v-if="lastSavedAt" class="ms-auto text-muted small align-self-center">
              <i class="bi bi-clock-history me-1" />
              Last saved: {{ formatTime(lastSavedAt) }}
            </div>
          </div>

          <!-- Error alert -->
          <BAlert v-if="error" variant="danger" dismissible @dismissed="error = null">
            {{ error }}
          </BAlert>

          <!-- Loading state -->
          <div v-if="isLoading" class="text-center py-5">
            <BSpinner label="Loading..." />
            <p class="mt-2 text-muted">Loading content...</p>
          </div>

          <!-- Section editor list -->
          <template v-else>
            <SectionList
              v-if="sections.length > 0"
              :sections="sections"
              @update:sections="sections = $event"
              @section-blur="handleAutosave"
            />

            <BCard v-else class="text-center py-5 bg-light">
              <p class="text-muted mb-3">No sections yet. Add your first section to get started.</p>
              <BButton variant="primary" @click="addInitialSection">
                <i class="bi bi-plus-lg me-1" />
                Add First Section
              </BButton>
            </BCard>
          </template>
        </BCol>
      </BRow>

      <!-- Publish confirmation modal -->
      <BModal
        v-model="showPublishModal"
        title="Publish Content"
        ok-title="Publish"
        ok-variant="primary"
        @ok="confirmPublish"
      >
        <p>Are you sure you want to publish these changes?</p>
        <p class="text-muted small mb-0">
          This will make the current content visible to all users on the About page.
          {{ sections.length }} section(s) will be updated.
        </p>
      </BModal>
    </BContainer>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted, onBeforeUnmount } from 'vue';
import { useCmsContent } from '@/composables';
import SectionList from '@/components/cms/SectionList.vue';

// CMS content composable
const {
  sections,
  isLoading,
  isSaving,
  isPublishing,
  error,
  lastSavedAt,
  currentVersion,
  isDraft,
  loadDraft,
  saveDraft,
  publish,
  addSection,
} = useCmsContent();

const showPublishModal = ref(false);

// Load content on mount
onMounted(async () => {
  await loadDraft();
});

// Autosave on navigate away
onBeforeUnmount(async () => {
  if (sections.value.length > 0) {
    await saveDraft();
  }
});

// Format time for display
function formatTime(date: Date | null): string {
  if (!date) return '';
  return date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
}

// Handle save draft button
async function handleSaveDraft() {
  const success = await saveDraft();
  if (success) {
    // Could show toast notification here
  }
}

// Handle autosave on blur
async function handleAutosave() {
  if (sections.value.length > 0) {
    await saveDraft();
  }
}

// Handle publish button - show confirmation modal
function handlePublish() {
  showPublishModal.value = true;
}

// Confirm publish from modal
async function confirmPublish() {
  showPublishModal.value = false;
  const success = await publish();
  if (success) {
    // Could show success toast
  }
}

// Add first section with default content
function addInitialSection() {
  addSection({
    section_id: 'section-' + Date.now(),
    title: 'New Section',
    icon: 'bi-info-circle',
    content: '# Welcome\n\nStart editing your content here...',
  });
}
</script>

<style scoped>
/* Minimal custom styling - rely on Bootstrap */
</style>
