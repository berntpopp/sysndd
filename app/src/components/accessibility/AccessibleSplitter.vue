<template>
  <Splitpanes
    ref="splitpanes"
    class="accessible-splitter"
    :horizontal="orientation === 'horizontal'"
    :keyboard-step="0"
    @keydown.capture="handleSeparatorKeydown"
    @ready="syncSeparator"
    @resized="handleResized"
  >
    <Pane :size="size" :min-size="min" :max-size="max">
      <slot name="first" />
    </Pane>
    <Pane :size="100 - size" :min-size="100 - max" :max-size="100 - min">
      <slot name="second" />
    </Pane>
  </Splitpanes>
</template>

<script setup lang="ts">
import { nextTick, onMounted, ref, watch } from 'vue';
import { Pane, Splitpanes } from 'splitpanes';
import 'splitpanes/dist/splitpanes.css';

interface SplitpaneSize {
  size: number;
}

interface SplitpanesEvent {
  panes: SplitpaneSize[];
}

const props = defineProps<{
  size: number;
  min: number;
  max: number;
  orientation: 'horizontal' | 'vertical';
  label: string;
}>();

const emit = defineEmits<{
  'update:size': [size: number];
}>();

const splitpanes = ref<InstanceType<typeof Splitpanes> | null>(null);

function clampedSize(value: number): number {
  return Math.min(props.max, Math.max(props.min, value));
}

function separatorElement(): HTMLElement | null {
  const root = splitpanes.value?.$el as HTMLElement | undefined;
  return root?.querySelector<HTMLElement>('.splitpanes__splitter') ?? null;
}

function syncSeparator(): void {
  const separator = separatorElement();
  if (!separator) return;

  separator.setAttribute('role', 'separator');
  separator.setAttribute('tabindex', '0');
  separator.setAttribute('aria-label', props.label);
  separator.setAttribute('aria-orientation', props.orientation);
  separator.setAttribute('aria-valuemin', String(props.min));
  separator.setAttribute('aria-valuemax', String(props.max));
  separator.setAttribute('aria-valuenow', String(clampedSize(props.size)));
}

function updateSize(value: number): void {
  emit('update:size', clampedSize(value));
}

function handleSeparatorKeydown(event: KeyboardEvent): void {
  if (!(event.target as HTMLElement | null)?.classList.contains('splitpanes__splitter')) {
    return;
  }

  const decreaseKey = props.orientation === 'vertical' ? 'ArrowLeft' : 'ArrowUp';
  const increaseKey = props.orientation === 'vertical' ? 'ArrowRight' : 'ArrowDown';
  let nextSize: number | null = null;

  if (event.key === decreaseKey) nextSize = props.size - 2;
  if (event.key === increaseKey) nextSize = props.size + 2;
  if (event.key === 'Home') nextSize = props.min;
  if (event.key === 'End') nextSize = props.max;

  if (nextSize === null) return;

  event.preventDefault();
  updateSize(nextSize);
}

function handleResized({ panes }: SplitpanesEvent): void {
  const firstPaneSize = panes[0]?.size;
  if (typeof firstPaneSize === 'number') {
    updateSize(firstPaneSize);
  }
}

onMounted(async () => {
  await nextTick();
  syncSeparator();
});

watch(
  () => [props.size, props.min, props.max, props.orientation, props.label],
  async () => {
    await nextTick();
    syncSeparator();
  }
);

</script>

<style scoped>
:deep(.splitpanes__splitter[role='separator']:focus-visible) {
  outline: 3px solid var(--medical-blue-700, #0d47a1);
  outline-offset: -3px;
}
</style>
