<!-- components/small/LogDetailDrawer.vue -->
<template>
  <BOffcanvas
    :model-value="modelValue"
    placement="end"
    :title="`Log Entry #${log?.id || ''}`"
    @update:model-value="$emit('update:modelValue', $event)"
    @shown="handleShown"
    @keydown="handleKeydown"
  >
    <template #header>
      <div class="d-flex justify-content-between align-items-center w-100">
        <h5 class="mb-0">
          <i class="bi bi-journal-text me-2" />
          Log Entry #{{ log?.id }}
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
          <BButton
            size="sm"
            variant="link"
            @click="close"
          >
            <i class="bi bi-x-lg" />
          </BButton>
        </div>
      </div>
    </template>

    <div v-if="log" class="log-detail-content">
      <!-- Summary section -->
      <div class="mb-4">
        <h6 class="text-muted border-bottom pb-2 mb-3">
          <i class="bi bi-info-circle me-2" />Summary
        </h6>
        <BTable
          :items="summaryItems"
          :fields="summaryFields"
          small
          borderless
          class="mb-0"
        >
          <template #cell(value)="{ item }">
            <BBadge v-if="item.key === 'status'" :variant="getStatusVariant(item.value)">
              {{ item.value }}
            </BBadge>
            <BBadge v-else-if="item.key === 'method'" :variant="getMethodVariant(item.value)">
              {{ item.value }}
            </BBadge>
            <span v-else>{{ item.value }}</span>
          </template>
        </BTable>
      </div>

      <!-- Request details section -->
      <div class="mb-4">
        <h6 class="text-muted border-bottom pb-2 mb-3">
          <i class="bi bi-send me-2" />Request Details
        </h6>
        <dl class="row mb-0">
          <dt class="col-sm-3 text-muted">Path</dt>
          <dd class="col-sm-9 font-monospace">{{ log.path }}</dd>

          <dt class="col-sm-3 text-muted">Query</dt>
          <dd class="col-sm-9 font-monospace text-break">{{ log.query || '(none)' }}</dd>

          <dt class="col-sm-3 text-muted">POST Body</dt>
          <dd class="col-sm-9">
            <pre v-if="log.post" class="bg-light p-2 rounded small mb-0 text-break">{{ formatJson(log.post) }}</pre>
            <span v-else class="text-muted">(none)</span>
          </dd>
        </dl>
      </div>

      <!-- Client info section -->
      <div class="mb-4">
        <h6 class="text-muted border-bottom pb-2 mb-3">
          <i class="bi bi-pc-display me-2" />Client Information
        </h6>
        <dl class="row mb-0">
          <dt class="col-sm-3 text-muted">IP Address</dt>
          <dd class="col-sm-9 font-monospace">{{ log.address }}</dd>

          <dt class="col-sm-3 text-muted">Host</dt>
          <dd class="col-sm-9">{{ log.host }}</dd>

          <dt class="col-sm-3 text-muted">User Agent</dt>
          <dd class="col-sm-9 small text-break">{{ log.agent }}</dd>
        </dl>
      </div>

      <!-- Full JSON section -->
      <div class="mb-3">
        <h6 class="text-muted border-bottom pb-2 mb-3">
          <i class="bi bi-code-slash me-2" />Full JSON
        </h6>
        <pre class="bg-dark text-light p-3 rounded small" style="max-height: 300px; overflow-y: auto;">{{ JSON.stringify(log, null, 2) }}</pre>
      </div>

      <!-- Navigation hint -->
      <div class="text-center text-muted small border-top pt-2">
        <i class="bi bi-arrow-left-right me-1" />
        Use arrow keys to navigate between logs
      </div>
    </div>
  </BOffcanvas>
</template>

<script>
import { computed } from 'vue';
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

    const summaryFields = [
      { key: 'label', label: '', class: 'text-muted', thStyle: { width: '120px' } },
      { key: 'value', label: '' },
    ];

    const summaryItems = computed(() => {
      if (!props.log) return [];
      return [
        { key: 'timestamp', label: 'Timestamp', value: formatTimestamp(props.log.timestamp) },
        { key: 'method', label: 'Method', value: props.log.request_method },
        { key: 'status', label: 'Status', value: props.log.status },
        { key: 'duration', label: 'Duration', value: `${props.log.duration}ms` },
        { key: 'file', label: 'Handler', value: props.log.file },
      ];
    });

    function formatTimestamp(dateStr) {
      if (!dateStr) return '';
      return new Date(dateStr).toLocaleString('en-US', {
        year: 'numeric',
        month: 'short',
        day: 'numeric',
        hour: '2-digit',
        minute: '2-digit',
        second: '2-digit',
        timeZoneName: 'short',
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

    function copyToClipboard() {
      if (props.log) {
        copy(JSON.stringify(props.log, null, 2));
      }
    }

    function close() {
      emit('update:modelValue', false);
    }

    function handleShown() {
      // Focus the offcanvas for keyboard events
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
      }
    }

    return {
      copied,
      summaryFields,
      summaryItems,
      formatJson,
      getStatusVariant,
      getMethodVariant,
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
</style>
