<template>
  <div
    ref="previewRef"
    class="markdown-preview p-3 border rounded bg-white"
    :style="{ minHeight: minHeight, maxHeight: maxHeight, overflowY: 'auto' }"
  >
    <div v-if="isRendering" class="text-center text-muted py-4">
      <BSpinner small class="me-2" />
      Rendering...
    </div>
    <div v-else-if="renderedHtml" v-dompurify-html="renderedHtml" class="markdown-content" />
    <div v-else class="text-muted fst-italic py-4 text-center">
      Preview will appear here as you type...
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, watch, onMounted } from 'vue';
import { useMarkdownRenderer } from '@/composables';

const props = withDefaults(
  defineProps<{
    content: string;
    minHeight?: string;
    maxHeight?: string;
  }>(),
  {
    minHeight: '300px',
    maxHeight: '500px',
  }
);

const previewRef = ref<HTMLElement | null>(null);
const { rawMarkdown, renderedHtml, isRendering, renderImmediate } = useMarkdownRenderer();

// Sync content with renderer
watch(
  () => props.content,
  (newVal) => {
    rawMarkdown.value = newVal;
  },
  { immediate: true }
);

// Initial render without debounce
onMounted(() => {
  if (props.content) {
    renderImmediate(props.content);
  }
});
</script>

<style scoped>
.markdown-preview {
  word-wrap: break-word;
}

.markdown-content :deep(h1) {
  font-size: 1.5rem;
  border-bottom: 1px solid #dee2e6;
  padding-bottom: 0.3rem;
  margin-bottom: 1rem;
}

.markdown-content :deep(h2) {
  font-size: 1.3rem;
  margin-top: 1.5rem;
  margin-bottom: 0.75rem;
}

.markdown-content :deep(h3) {
  font-size: 1.1rem;
  margin-top: 1.25rem;
  margin-bottom: 0.5rem;
}

.markdown-content :deep(p) {
  margin-bottom: 0.75rem;
}

.markdown-content :deep(ul),
.markdown-content :deep(ol) {
  padding-left: 1.5rem;
  margin-bottom: 0.75rem;
}

.markdown-content :deep(blockquote) {
  border-left: 4px solid var(--bs-primary);
  padding-left: 1rem;
  margin-left: 0;
  color: var(--bs-secondary);
}

.markdown-content :deep(code) {
  background: #f4f4f4;
  padding: 0.125rem 0.25rem;
  border-radius: 0.25rem;
  font-size: 0.875em;
}

.markdown-content :deep(pre) {
  background: #f4f4f4;
  padding: 1rem;
  border-radius: 0.375rem;
  overflow-x: auto;
}

.markdown-content :deep(a) {
  color: var(--bs-primary);
}

.markdown-content :deep(hr) {
  margin: 1.5rem 0;
}

.markdown-content :deep(table) {
  width: 100%;
  margin-bottom: 1rem;
  border-collapse: collapse;
}

.markdown-content :deep(th),
.markdown-content :deep(td) {
  border: 1px solid #dee2e6;
  padding: 0.5rem;
}

.markdown-content :deep(th) {
  background: #f8f9fa;
}
</style>
