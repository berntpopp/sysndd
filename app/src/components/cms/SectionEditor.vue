<template>
  <BCard class="section-editor mb-3" :class="{ 'border-primary': isExpanded }">
    <template #header>
      <div class="d-flex align-items-center gap-2">
        <!-- Drag handle -->
        <span class="drag-handle text-muted" title="Drag to reorder">
          <i class="bi bi-grip-vertical" />
        </span>

        <!-- Section icon preview -->
        <i :class="section.icon" class="fs-5" />

        <!-- Section title (editable inline when expanded) -->
        <div class="flex-grow-1">
          <strong v-if="!isExpanded">{{ section.title || 'Untitled Section' }}</strong>
          <BFormInput
            v-else
            v-model="localSection.title"
            size="sm"
            placeholder="Section title"
            @update:model-value="emitUpdate"
          />
        </div>

        <!-- Actions -->
        <div class="d-flex gap-1">
          <BButton
            size="sm"
            :variant="isExpanded ? 'primary' : 'outline-secondary'"
            @click="isExpanded = !isExpanded"
          >
            <i :class="isExpanded ? 'bi bi-chevron-up' : 'bi bi-chevron-down'" />
          </BButton>
          <BButton
            size="sm"
            variant="outline-danger"
            title="Delete section"
            @click="$emit('delete')"
          >
            <i class="bi bi-trash" />
          </BButton>
        </div>
      </div>
    </template>

    <BCollapse v-model="isExpanded">
      <BCardBody>
        <!-- Icon selector -->
        <BFormGroup label="Icon" label-cols="2" class="mb-3">
          <BFormSelect
            v-model="localSection.icon"
            :options="iconOptions"
            size="sm"
            @update:model-value="emitUpdate"
          />
        </BFormGroup>

        <!-- Side-by-side editor and preview -->
        <BRow>
          <BCol md="6">
            <label class="form-label fw-semibold">Content (Markdown)</label>
            <MarkdownEditor
              v-model="localSection.content"
              :rows="12"
              min-height="250px"
              max-height="400px"
              @update:model-value="emitUpdate"
              @blur="$emit('blur')"
            />
          </BCol>
          <BCol md="6">
            <label class="form-label fw-semibold">Preview</label>
            <MarkdownPreview
              :content="localSection.content"
              min-height="250px"
              max-height="400px"
            />
          </BCol>
        </BRow>
      </BCardBody>
    </BCollapse>
  </BCard>
</template>

<script setup lang="ts">
import { ref, watch, computed } from 'vue';
import type { AboutSection } from '@/types';
import { SECTION_ICONS } from '@/types/cms';
import MarkdownEditor from './MarkdownEditor.vue';
import MarkdownPreview from './MarkdownPreview.vue';

const props = defineProps<{
  section: AboutSection;
  expanded?: boolean;
}>();

const emit = defineEmits<{
  'update': [section: AboutSection];
  'delete': [];
  'blur': [];
}>();

const isExpanded = ref(props.expanded ?? false);
const localSection = ref<AboutSection>({ ...props.section });

// Sync with prop changes
watch(() => props.section, (newVal) => {
  localSection.value = { ...newVal };
}, { deep: true });

function emitUpdate() {
  emit('update', { ...localSection.value });
}

// Icon options for dropdown
const iconOptions = computed(() =>
  SECTION_ICONS.map(icon => ({
    value: icon,
    text: icon.replace('bi-', '').replace(/-/g, ' '),
  }))
);
</script>

<style scoped>
.drag-handle {
  cursor: grab;
  padding: 0.25rem;
}

.drag-handle:active {
  cursor: grabbing;
}

.section-editor.ghost {
  opacity: 0.5;
  background: var(--bs-primary-bg-subtle);
}
</style>
