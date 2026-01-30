<template>
  <div class="markdown-editor">
    <!-- Toolbar -->
    <div class="toolbar d-flex flex-wrap gap-1 mb-2 p-2 bg-light rounded border">
      <BButton
        v-for="action in toolbarActions"
        :key="action.title"
        size="sm"
        variant="outline-secondary"
        :title="action.title"
        @click="insertFormatting(action)"
      >
        <i :class="action.icon" />
      </BButton>
      <div class="vr mx-2" />
      <BButton
        size="sm"
        variant="outline-info"
        title="Markdown Help"
        @click="showCheatsheet = !showCheatsheet"
      >
        <i class="bi bi-question-circle" />
      </BButton>
    </div>

    <!-- Cheatsheet (collapsible) -->
    <BCollapse v-model="showCheatsheet" class="mb-2">
      <MarkdownCheatsheet />
    </BCollapse>

    <!-- Textarea -->
    <BFormTextarea
      ref="textareaRef"
      v-model="localContent"
      class="markdown-textarea"
      :rows="rows"
      :style="{ minHeight: minHeight, maxHeight: maxHeight, resize: 'vertical' }"
      placeholder="Enter markdown content..."
      @blur="$emit('blur')"
      @input="onInput"
    />
  </div>
</template>

<script setup lang="ts">
import { ref, watch, type ComponentPublicInstance } from 'vue';
import type { ToolbarAction } from '@/types';
import MarkdownCheatsheet from './MarkdownCheatsheet.vue';

const props = withDefaults(
  defineProps<{
    modelValue: string;
    rows?: number;
    minHeight?: string;
    maxHeight?: string;
  }>(),
  {
    rows: 15,
    minHeight: '300px',
    maxHeight: '500px',
  }
);

const emit = defineEmits<{
  'update:modelValue': [value: string];
  blur: [];
}>();

const textareaRef = ref<ComponentPublicInstance | null>(null);
const showCheatsheet = ref(false);
const localContent = ref(props.modelValue);

// Sync with v-model
watch(
  () => props.modelValue,
  (newVal) => {
    if (newVal !== localContent.value) {
      localContent.value = newVal;
    }
  }
);

function onInput() {
  emit('update:modelValue', localContent.value);
}

// Toolbar actions per CONTEXT.md: bold, italic, link, headers, lists
const toolbarActions: ToolbarAction[] = [
  {
    icon: 'bi bi-type-bold',
    title: 'Bold (Ctrl+B)',
    prefix: '**',
    suffix: '**',
    placeholder: 'bold text',
  },
  {
    icon: 'bi bi-type-italic',
    title: 'Italic (Ctrl+I)',
    prefix: '_',
    suffix: '_',
    placeholder: 'italic text',
  },
  { icon: 'bi bi-link', title: 'Link', prefix: '[', suffix: '](url)', placeholder: 'link text' },
  { icon: 'bi bi-type-h1', title: 'Heading 1', prefix: '# ', suffix: '', placeholder: '' },
  { icon: 'bi bi-type-h2', title: 'Heading 2', prefix: '## ', suffix: '', placeholder: '' },
  { icon: 'bi bi-type-h3', title: 'Heading 3', prefix: '### ', suffix: '', placeholder: '' },
  { icon: 'bi bi-list-ul', title: 'Bullet List', prefix: '- ', suffix: '', placeholder: '' },
  { icon: 'bi bi-list-ol', title: 'Numbered List', prefix: '1. ', suffix: '', placeholder: '' },
  { icon: 'bi bi-quote', title: 'Blockquote', prefix: '> ', suffix: '', placeholder: '' },
  { icon: 'bi bi-code', title: 'Code', prefix: '`', suffix: '`', placeholder: 'code' },
];

function insertFormatting(action: ToolbarAction) {
  const textarea = (textareaRef.value?.$el || textareaRef.value) as HTMLTextAreaElement | null;
  if (!textarea) return;

  const start = textarea.selectionStart;
  const end = textarea.selectionEnd;
  const selectedText = localContent.value.substring(start, end) || action.placeholder || '';
  const replacement = `${action.prefix}${selectedText}${action.suffix}`;

  localContent.value =
    localContent.value.substring(0, start) + replacement + localContent.value.substring(end);

  emit('update:modelValue', localContent.value);

  // Restore cursor position
  const newCursorPos = start + action.prefix.length + selectedText.length;
  setTimeout(() => {
    textarea.focus();
    textarea.setSelectionRange(newCursorPos, newCursorPos);
  }, 0);
}
</script>

<style scoped>
.markdown-textarea {
  font-family: ui-monospace, SFMono-Regular, 'SF Mono', Menlo, Consolas, monospace;
  font-size: 0.9rem;
  line-height: 1.6;
  tab-size: 2;
}

.toolbar .btn {
  min-width: 32px;
}
</style>
