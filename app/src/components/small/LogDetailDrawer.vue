<!-- components/small/LogDetailDrawer.vue -->
<template>
  <BModal
    :model-value="modelValue"
    size="lg"
    centered
    scrollable
    @update:model-value="$emit('update:modelValue', $event)"
    @shown="handleShown"
    @keydown="handleKeydown"
  >
    <template #header>
      <div class="d-flex justify-content-between align-items-center w-100">
        <h5 class="mb-0">
          <i class="bi bi-journal-text me-2" />
          Log Entry #{{ log?.id }}
          <BBadge v-if="log" :variant="getStatusVariant(log.status)" class="ms-2">
            {{ log.status }}
          </BBadge>
          <BBadge v-if="log" :variant="getMethodVariant(log.request_method)" class="ms-1">
            {{ log.request_method }}
          </BBadge>
        </h5>
        <div>
          <BButton
            v-b-tooltip.hover
            size="sm"
            variant="outline-secondary"
            class="me-2"
            title="Copy JSON to clipboard"
            @click="copyToClipboard"
          >
            <i :class="copied ? 'bi bi-check' : 'bi bi-clipboard'" />
            {{ copied ? 'Copied!' : 'Copy' }}
          </BButton>
        </div>
      </div>
    </template>

    <div v-if="log" class="log-detail-content">
      <!-- Summary Cards Row -->
      <div class="row g-2 mb-4">
        <div class="col-md-3">
          <div class="card bg-light h-100">
            <div class="card-body py-2 px-3">
              <div class="text-muted small">Timestamp</div>
              <div class="fw-semibold small">{{ formatTimestamp(log.timestamp) }}</div>
            </div>
          </div>
        </div>
        <div class="col-md-3">
          <div class="card bg-light h-100">
            <div class="card-body py-2 px-3">
              <div class="text-muted small">Duration</div>
              <div class="fw-semibold">
                <span :class="getDurationClass(log.duration)">{{ log.duration }}ms</span>
              </div>
            </div>
          </div>
        </div>
        <div class="col-md-3">
          <div class="card bg-light h-100">
            <div class="card-body py-2 px-3">
              <div class="text-muted small">IP Address</div>
              <div class="fw-semibold font-monospace small">{{ log.address }}</div>
            </div>
          </div>
        </div>
        <div class="col-md-3">
          <div class="card bg-light h-100">
            <div class="card-body py-2 px-3">
              <div class="text-muted small">Host</div>
              <div class="fw-semibold small">{{ log.host }}</div>
            </div>
          </div>
        </div>
      </div>

      <!-- Request details section -->
      <div class="mb-4">
        <h6 class="text-muted border-bottom pb-2 mb-3">
          <i class="bi bi-send me-2" />Request Details
        </h6>
        <dl class="row mb-0">
          <dt class="col-sm-2 text-muted">Path</dt>
          <dd class="col-sm-10 font-monospace bg-light p-2 rounded">{{ log.path }}</dd>

          <dt class="col-sm-2 text-muted">Query</dt>
          <dd class="col-sm-10">
            <code v-if="log.query" class="d-block bg-light p-2 rounded text-break">{{
              log.query
            }}</code>
            <span v-else class="text-muted fst-italic">(none)</span>
          </dd>

          <dt class="col-sm-2 text-muted">POST Body</dt>
          <dd class="col-sm-10">
            <pre v-if="log.post" class="bg-light p-2 rounded small mb-0 text-break">{{
              formatJson(log.post)
            }}</pre>
            <span v-else class="text-muted fst-italic">(none)</span>
          </dd>
        </dl>
      </div>

      <!-- Client info section -->
      <div class="mb-4">
        <h6 class="text-muted border-bottom pb-2 mb-3">
          <i class="bi bi-pc-display me-2" />Client Information
        </h6>
        <dl class="row mb-0">
          <dt class="col-sm-2 text-muted">User Agent</dt>
          <dd class="col-sm-10 small text-break">{{ log.agent }}</dd>

          <dt class="col-sm-2 text-muted">Handler</dt>
          <dd class="col-sm-10 font-monospace small">{{ log.file }}</dd>
        </dl>
      </div>

      <!-- Full JSON section (collapsible) -->
      <div class="mb-3">
        <h6
          class="text-muted border-bottom pb-2 mb-3 d-flex align-items-center"
          style="cursor: pointer"
          @click="showJson = !showJson"
        >
          <i class="bi bi-code-slash me-2" />
          Raw JSON
          <i :class="showJson ? 'bi bi-chevron-up' : 'bi bi-chevron-down'" class="ms-auto" />
        </h6>
        <BCollapse v-model="showJson">
          <pre
            class="bg-dark text-light p-3 rounded small"
            style="max-height: 250px; overflow-y: auto"
            >{{ JSON.stringify(log, null, 2) }}</pre
          >
        </BCollapse>
      </div>
    </div>

    <template #footer>
      <div class="d-flex justify-content-between align-items-center w-100">
        <div>
          <BButton
            size="sm"
            variant="outline-secondary"
            :disabled="!canNavigatePrev"
            @click="$emit('navigate-prev')"
          >
            <i class="bi bi-chevron-left" /> Previous
          </BButton>
          <BButton
            size="sm"
            variant="outline-secondary"
            class="ms-2"
            :disabled="!canNavigateNext"
            @click="$emit('navigate-next')"
          >
            Next <i class="bi bi-chevron-right" />
          </BButton>
        </div>
        <div class="text-muted small">
          <i class="bi bi-keyboard me-1" />
          Arrow keys to navigate
        </div>
        <BButton variant="secondary" @click="close"> Close </BButton>
      </div>
    </template>
  </BModal>
</template>

<script>
import { ref } from 'vue';
import { useClipboard } from '@vueuse/core';

export default {
  name: 'LogDetailDrawer',
  props: {
    modelValue: {
      type: Boolean,
      default: false,
    },
    log: {
      type: Object,
      default: null,
    },
    canNavigatePrev: {
      type: Boolean,
      default: false,
    },
    canNavigateNext: {
      type: Boolean,
      default: false,
    },
  },
  emits: ['update:modelValue', 'navigate-prev', 'navigate-next'],
  setup(props, { emit }) {
    const { copy, copied } = useClipboard({ copiedDuring: 2000 });
    const showJson = ref(false);

    function formatTimestamp(dateStr) {
      if (!dateStr) return '';
      return new Date(dateStr).toLocaleString('en-US', {
        year: 'numeric',
        month: 'short',
        day: 'numeric',
        hour: '2-digit',
        minute: '2-digit',
        second: '2-digit',
      });
    }

    function formatJson(str) {
      if (!str) return '';
      try {
        return JSON.stringify(JSON.parse(str), null, 2);
      } catch {
        return str;
      }
    }

    function getStatusVariant(status) {
      if (status >= 200 && status < 300) return 'success';
      if (status >= 400 && status < 500) return 'warning';
      if (status >= 500) return 'danger';
      return 'secondary';
    }

    function getMethodVariant(method) {
      const variants = {
        GET: 'success',
        POST: 'primary',
        PUT: 'warning',
        DELETE: 'danger',
        OPTIONS: 'info',
      };
      return variants[method] || 'secondary';
    }

    function getDurationClass(duration) {
      if (duration < 100) return 'text-success';
      if (duration < 500) return 'text-warning';
      return 'text-danger';
    }

    function copyToClipboard() {
      if (props.log) {
        copy(JSON.stringify(props.log, null, 2));
      }
    }

    function close() {
      emit('update:modelValue', false);
    }

    function handleShown() {
      // Focus the modal for keyboard events
    }

    function handleKeydown(event) {
      if (event.key === 'ArrowLeft' || event.key === 'ArrowUp') {
        event.preventDefault();
        if (props.canNavigatePrev) {
          emit('navigate-prev');
        }
      } else if (event.key === 'ArrowRight' || event.key === 'ArrowDown') {
        event.preventDefault();
        if (props.canNavigateNext) {
          emit('navigate-next');
        }
      } else if (event.key === 'Escape') {
        close();
      }
    }

    return {
      copied,
      showJson,
      formatTimestamp,
      formatJson,
      getStatusVariant,
      getMethodVariant,
      getDurationClass,
      copyToClipboard,
      close,
      handleShown,
      handleKeydown,
    };
  },
};
</script>

<style scoped>
.log-detail-content {
  font-size: 0.9rem;
}

pre {
  white-space: pre-wrap;
  word-break: break-word;
}

dl.row dt {
  font-weight: 500;
}

dl.row dd {
  margin-bottom: 0.75rem;
}
</style>
