<!-- TableSearchInput.vue -->
<template>
  <div class="search-input-container">
    <input
      ref="inputRef"
      v-model="localValue"
      :placeholder="placeholder"
      type="search"
      class="form-control form-control-sm mb-1 border-dark search-input"
      :class="{ 'search-input-active': localValue && localValue.length > 0 }"
      @input="handleInput"
    />
    <button
      v-if="clearable && !loading && localValue && localValue.length > 0"
      type="button"
      class="search-clear-btn"
      aria-label="Clear search"
      @click="handleClear"
    >
      <i class="bi bi-x-circle-fill"></i>
    </button>
    <div v-if="loading" class="search-loading">
      <span class="spinner-border spinner-border-sm" role="status" aria-label="Loading"></span>
    </div>
  </div>
</template>

<script setup>
import { ref, watch, onBeforeUnmount } from 'vue';

// Props
const props = defineProps({
  placeholder: {
    type: String,
    default: 'Search...',
  },
  debounceTime: {
    type: Number,
    default: 500,
  },
  clearable: {
    type: Boolean,
    default: true,
  },
  loading: {
    type: Boolean,
    default: false,
  },
});

// Vue 3.4+ defineModel for two-way binding
const model = defineModel({ type: [String, null], default: null });

// Emits for additional events
const emit = defineEmits(['input', 'update', 'clear']);

// Local state
const localValue = ref(model.value ?? '');
const debounceTimer = ref(null);
const inputRef = ref(null);

// Watch for external model changes
watch(model, (newVal) => {
  const normalized = newVal ?? '';
  if (localValue.value !== normalized) {
    localValue.value = normalized;
  }
});

// Cleanup on unmount
onBeforeUnmount(() => {
  if (debounceTimer.value) {
    clearTimeout(debounceTimer.value);
  }
});

// Handle input with debounce
function handleInput() {
  // Clear existing timer
  if (debounceTimer.value) {
    clearTimeout(debounceTimer.value);
  }

  // Set new debounced emit
  debounceTimer.value = setTimeout(() => {
    // Update the model (parent v-model)
    model.value = localValue.value;
    // Emit additional events for flexibility
    emit('input', localValue.value);
    emit('update', localValue.value);
  }, props.debounceTime);
}

// Handle clear button
function handleClear() {
  // Clear any pending debounce
  if (debounceTimer.value) {
    clearTimeout(debounceTimer.value);
  }

  localValue.value = '';
  // Immediately update model (bypass debounce)
  model.value = '';
  emit('input', '');
  emit('update', '');
  emit('clear');

  // Focus back to input after clear
  if (inputRef.value) {
    inputRef.value.focus();
  }
}
</script>

<style scoped>
.search-input-container {
  position: relative;
  display: flex;
  align-items: center;
}

.search-input {
  padding-right: 2rem;
  transition: border-color 0.15s ease-in-out;
}

.search-input-active {
  border-color: var(--medical-blue-500, #1976d2);
}

.search-clear-btn {
  position: absolute;
  right: 0.5rem;
  top: 50%;
  transform: translateY(-50%);
  background: none;
  border: none;
  padding: 0.25rem;
  cursor: pointer;
  color: var(--neutral-500, #9e9e9e);
  line-height: 1;
  display: flex;
  align-items: center;
  justify-content: center;
}

.search-clear-btn:hover {
  color: var(--neutral-700, #616161);
}

.search-loading {
  position: absolute;
  right: 0.5rem;
  top: 50%;
  transform: translateY(-50%);
}
</style>
