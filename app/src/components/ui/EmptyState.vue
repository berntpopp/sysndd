<template>
  <div class="empty-state">
    <slot name="icon">
      <i
        :class="`bi bi-${icon}`"
        class="empty-state-icon"
        aria-hidden="true"
      />
    </slot>
    <h3 class="empty-state-title">
      {{ title }}
    </h3>
    <p
      v-if="message"
      class="text-muted empty-state-message"
    >
      {{ message }}
    </p>
    <slot />
    <BButton
      v-if="actionLabel"
      :variant="actionVariant"
      class="mt-3"
      @click="$emit('action')"
    >
      {{ actionLabel }}
    </BButton>
  </div>
</template>

<script lang="ts">
import { defineComponent, type PropType } from 'vue';
import { BButton } from 'bootstrap-vue-next';
import type { ColorVariant } from 'bootstrap-vue-next';

export default defineComponent({
  name: 'EmptyState',
  components: {
    BButton
  },
  props: {
    icon: {
      type: String,
      default: 'search'
    },
    title: {
      type: String,
      required: true
    },
    message: {
      type: String,
      default: ''
    },
    actionLabel: {
      type: String,
      default: ''
    },
    actionVariant: {
      type: String as PropType<ColorVariant>,
      default: 'primary' as ColorVariant
    }
  },
  emits: ['action']
});
</script>

<style scoped>
.empty-state {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  text-align: center;
  padding: 3rem 1.5rem;
  max-width: 400px;
  margin: 0 auto;
}

.empty-state-icon {
  font-size: 4rem;
  color: var(--text-muted, #6c757d);
  opacity: 0.5;
  margin-bottom: 1rem;
}

.empty-state-title {
  margin-bottom: 0.5rem;
  font-size: 1.25rem;
  font-weight: 500;
}

.empty-state-message {
  margin-bottom: 0;
  font-size: 0.9375rem;
}
</style>
