<template>
  <div class="section-list">
    <draggable
      v-model="localSections"
      item-key="section_id"
      handle=".drag-handle"
      animation="200"
      ghost-class="ghost"
      @change="onOrderChange"
    >
      <template #item="{ element, index }">
        <SectionEditor
          :section="element"
          :expanded="expandedIndex === index"
          @update="(updated) => updateSection(index, updated)"
          @delete="deleteSection(index)"
          @blur="$emit('section-blur')"
        />
      </template>
    </draggable>

    <!-- Add section button -->
    <div class="text-center mt-3">
      <BButton variant="outline-primary" @click="addSection">
        <i class="bi bi-plus-lg me-1" />
        Add Section
      </BButton>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, watch } from 'vue';
import draggable from 'vuedraggable';
import type { AboutSection } from '@/types';
import SectionEditor from './SectionEditor.vue';

const props = defineProps<{
  sections: AboutSection[];
}>();

const emit = defineEmits<{
  'update:sections': [sections: AboutSection[]];
  'section-blur': [];
}>();

const localSections = ref<AboutSection[]>([...props.sections]);
const expandedIndex = ref<number | null>(null);

// Sync with parent
watch(
  () => props.sections,
  (newVal) => {
    localSections.value = [...newVal];
  },
  { deep: true }
);

function emitUpdate() {
  // Recalculate sort_order
  const updated = localSections.value.map((s, i) => ({
    ...s,
    sort_order: i,
  }));
  emit('update:sections', updated);
}

function onOrderChange() {
  emitUpdate();
}

function updateSection(index: number, updated: AboutSection) {
  localSections.value[index] = updated;
  emitUpdate();
}

function deleteSection(index: number) {
  localSections.value.splice(index, 1);
  emitUpdate();
}

function addSection() {
  const newId = `section-${Date.now()}`;
  const newSection: AboutSection = {
    section_id: newId,
    title: 'New Section',
    icon: 'bi-info-circle',
    content: '',
    sort_order: localSections.value.length,
  };
  localSections.value.push(newSection);
  expandedIndex.value = localSections.value.length - 1;
  emitUpdate();
}
</script>

<style scoped>
.ghost {
  opacity: 0.5;
  background: var(--bs-primary-bg-subtle);
  border-color: var(--bs-primary) !important;
}
</style>
