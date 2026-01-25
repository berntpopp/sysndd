<!-- views/admin/ManageAbout.vue -->
<template>
  <div class="container-fluid">
    <BContainer fluid>
      <BRow class="justify-content-md-center py-2">
        <BCol md="12" lg="11">
          <BCard
            header-tag="header"
            body-class="p-3"
            header-class="p-2"
            border-variant="dark"
          >
            <template #header>
              <BRow>
                <BCol>
                  <h5 class="mb-1 text-start">
                    <strong>Manage About Page</strong>
                    <BBadge :variant="isDraft ? 'warning' : 'success'" class="ms-2">
                      {{ isDraft ? 'Draft' : 'Published' }}
                    </BBadge>
                    <BBadge v-if="currentVersion" variant="secondary" class="ms-2">
                      v{{ currentVersion }}
                    </BBadge>
                    <BBadge variant="info" class="ms-2">
                      {{ sections.length }} section{{ sections.length !== 1 ? 's' : '' }}
                    </BBadge>
                  </h5>
                </BCol>
                <BCol class="text-end">
                  <BButton
                    v-b-tooltip.hover
                    size="sm"
                    variant="outline-secondary"
                    class="me-1"
                    title="Save as draft"
                    :disabled="isSaving || isPublishing || sections.length === 0"
                    @click="handleSaveDraft"
                  >
                    <BSpinner v-if="isSaving" small />
                    <i v-else class="bi bi-save" />
                    Save Draft
                  </BButton>
                  <BButton
                    v-b-tooltip.hover
                    size="sm"
                    variant="success"
                    class="me-1"
                    title="Publish content"
                    :disabled="isSaving || isPublishing || sections.length === 0"
                    @click="handlePublish"
                  >
                    <BSpinner v-if="isPublishing" small />
                    <i v-else class="bi bi-globe" />
                    Publish
                  </BButton>
                  <BButton
                    v-b-tooltip.hover
                    size="sm"
                    variant="outline-primary"
                    title="View live About page"
                    :href="'/About'"
                    target="_blank"
                  >
                    <i class="bi bi-eye" />
                  </BButton>
                </BCol>
              </BRow>
            </template>

            <!-- Status Messages -->
            <BAlert v-if="error" variant="danger" dismissible class="mb-3" @dismissed="error = null">
              <i class="bi bi-exclamation-triangle me-2" />
              {{ error }}
            </BAlert>

            <BAlert v-if="successMessage" variant="success" dismissible class="mb-3" @dismissed="successMessage = null">
              <i class="bi bi-check-circle me-2" />
              {{ successMessage }}
            </BAlert>

            <BAlert v-if="!apiAvailable" variant="info" class="mb-3">
              <i class="bi bi-info-circle me-2" />
              <strong>CMS API not available.</strong>
              The About page content management API is not configured. Showing default sections for preview.
              Once the API is set up, you can edit and publish content.
            </BAlert>

            <!-- Loading State -->
            <div v-if="isLoading" class="text-center py-5">
              <BSpinner variant="primary" />
              <p class="mt-2 text-muted">Loading content...</p>
            </div>

            <!-- Main Content -->
            <template v-else>
              <!-- Last saved indicator -->
              <div v-if="lastSavedAt" class="text-muted small mb-3">
                <i class="bi bi-clock-history me-1" />
                Last saved: {{ formatTime(lastSavedAt) }}
              </div>

              <!-- Section List -->
              <template v-if="sections.length > 0">
                <SectionList
                  :sections="sections"
                  @update:sections="handleSectionsUpdate"
                  @section-blur="handleAutosave"
                />
              </template>

              <!-- Empty State -->
              <div v-else class="text-center py-5">
                <i class="bi bi-file-earmark-plus display-4 text-muted mb-3 d-block" />
                <p class="text-muted mb-3">No sections yet. Add your first section to get started.</p>
                <BButton variant="primary" @click="addInitialSection">
                  <i class="bi bi-plus-lg me-1" />
                  Add First Section
                </BButton>
              </div>
            </template>
          </BCard>

          <!-- Help Card -->
          <BCard class="mt-3" body-class="p-2" border-variant="light">
            <div class="d-flex align-items-center">
              <i class="bi bi-lightbulb text-warning me-2" />
              <span class="text-muted small">
                <strong>Tips:</strong> Use markdown for formatting. Drag sections to reorder. Changes auto-save as drafts.
              </span>
            </div>
          </BCard>
        </BCol>
      </BRow>

      <!-- Publish Confirmation Modal -->
      <BModal
        v-model="showPublishModal"
        title="Publish Content"
        ok-title="Publish"
        ok-variant="success"
        @ok="confirmPublish"
      >
        <p>Are you sure you want to publish these changes?</p>
        <p class="text-muted small mb-0">
          This will update the public About page with {{ sections.length }} section{{ sections.length !== 1 ? 's' : '' }}.
        </p>
      </BModal>
    </BContainer>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted, onBeforeUnmount } from 'vue';
import { useCmsContent } from '@/composables';
import type { AboutSection } from '@/types';
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
  apiAvailable,
  loadDraft,
  saveDraft,
  publish,
  addSection,
} = useCmsContent();

const showPublishModal = ref(false);
const successMessage = ref<string | null>(null);

// Default sections matching the current About page content
const defaultSections: AboutSection[] = [
  {
    section_id: 'creators',
    title: 'About SysNDD and its creators',
    icon: 'bi-people',
    content: `The SysNDD database is based on some content of its predecessor database, SysID.

The concept for a curated gene collection and database with the goal to facilitate research and diagnostics into NDDs has been conceived by Annette Schenck and Christiane Zweier.

In 2009, they established SysID with a manually curated catalog of published genes implicated in neurodevelopmental disorders (NDDs).

## Affiliations

- **Christiane Zweier:** Human Genetics at the University/University Hospital Bern, Switzerland
- **Bernt Popp:** Berlin Institute of Health (BIH) at Charite Berlin, Germany
- **Annette Schenck:** Radboud university medical center, Nijmegen, the Netherlands`,
    sort_order: 0,
  },
  {
    section_id: 'citation',
    title: 'Citation Policy',
    icon: 'bi-journal-text',
    content: `Please cite the following publication:

> Kochinke K, Zweier C, Nijhof B, et al. Systematic Phenomics Analysis Deconvolutes Genes Mutated in Intellectual Disability into Biologically Coherent Modules. Am J Hum Genet. 2016;98(1):149-64.

We are currently working on a new manuscript reporting SysNDD.`,
    sort_order: 1,
  },
  {
    section_id: 'funding',
    title: 'Support and Funding',
    icon: 'bi-cash-stack',
    content: `## Current Support

- DFG grant PO2366/2-1 to Bernt Popp
- DFG grant ZW184/6-1 to Christiane Zweier
- ITHACA ERN through Alain Verloes

## Previous Support

- European Union's FP7 GenCoDys (HEALTH-241995)
- NWO VIDI and TOP grants (917-96-346, 912-12-109)
- DFG grants ZW184/1-1 and -2`,
    sort_order: 2,
  },
  {
    section_id: 'news',
    title: 'News and Updates',
    icon: 'bi-megaphone',
    content: `**2022-05-07** - First SysNDD native data update. Deprecating SysID. SysNDD now in usable beta mode.

**2021-11-09** - Several updates to the APP, API and DB preparing it for re-review mode.

**2021-08-16** - SysNDD is currently in alpha development status.`,
    sort_order: 3,
  },
  {
    section_id: 'credits',
    title: 'Credits and acknowledgement',
    icon: 'bi-award',
    content: `We acknowledge Martijn Huynen and members of the Huynen and Schenck groups at the Radboud University Medical Center Nijmegen for building SysID.

We thank all past users for constructive feedback.

Alain Verloes and ERN ITHACA provide valuable support for data integration with Orphanet.`,
    sort_order: 4,
  },
  {
    section_id: 'disclaimer',
    title: 'Disclaimer',
    icon: 'bi-shield-exclamation',
    content: `The Department of Human Genetics makes no representation about the suitability or accuracy of this software or data for any purpose.

**Responsible for this website:** Bernt Popp (admin [at] sysndd.org)

**Responsible for this project:** Christiane Zweier (curator [at] sysndd.org)

**Address:** Universitatsklinik fur Humangenetik, Inselspital, Freiburgstrasse 15, 3010 Bern, Switzerland`,
    sort_order: 5,
  },
  {
    section_id: 'contact',
    title: 'Contact',
    icon: 'bi-envelope',
    content: `If you have technical problems using SysNDD or requests regarding the data or functionality, please contact us at:

**support [at] sysndd.org**`,
    sort_order: 6,
  },
];

// Load content on mount
onMounted(async () => {
  const loaded = await loadDraft();
  // If API not available or no sections, use defaults
  if (!loaded || sections.value.length === 0) {
    sections.value = [...defaultSections];
  }
});

// Autosave on navigate away (only if API is available)
onBeforeUnmount(async () => {
  if (apiAvailable.value && sections.value.length > 0) {
    await saveDraft();
  }
});

// Format time for display
function formatTime(date: Date | null): string {
  if (!date) return '';
  return date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
}

// Handle sections update
function handleSectionsUpdate(updated: AboutSection[]) {
  sections.value = updated;
}

// Handle save draft button
async function handleSaveDraft() {
  if (!apiAvailable.value) {
    successMessage.value = 'Preview mode - API not available for saving';
    setTimeout(() => { successMessage.value = null; }, 3000);
    return;
  }
  const success = await saveDraft();
  if (success) {
    successMessage.value = 'Draft saved successfully';
    setTimeout(() => { successMessage.value = null; }, 3000);
  }
}

// Handle autosave on blur
async function handleAutosave() {
  if (apiAvailable.value && sections.value.length > 0) {
    await saveDraft();
  }
}

// Handle publish button - show confirmation modal
function handlePublish() {
  if (!apiAvailable.value) {
    successMessage.value = 'Preview mode - API not available for publishing';
    setTimeout(() => { successMessage.value = null; }, 3000);
    return;
  }
  showPublishModal.value = true;
}

// Confirm publish from modal
async function confirmPublish() {
  showPublishModal.value = false;
  const success = await publish();
  if (success) {
    successMessage.value = 'Content published successfully!';
    setTimeout(() => { successMessage.value = null; }, 5000);
  }
}

// Add first section
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
/* Match other admin views styling */
</style>
