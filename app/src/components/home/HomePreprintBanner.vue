<template>
  <aside
    v-if="visible"
    class="preprint-banner"
    aria-label="SysNDD preprint announcement"
    data-testid="preprint-banner"
  >
    <span class="sysndd-chip sysndd-chip--blue preprint-banner__chip">Preprint</span>

    <p class="preprint-banner__body">
      <a
        class="preprint-banner__title"
        :href="publication.url"
        target="_blank"
        rel="noopener noreferrer"
        data-testid="preprint-banner-link"
      >
        <!-- One wrapper so the icon stays inline with the wrapped title: on small
             screens a global touch-target rule makes links inline-flex. -->
        <span>
          {{ publication.title }}
          <i class="bi bi-box-arrow-up-right preprint-banner__external" aria-hidden="true" />
          <span class="visually-hidden">(opens {{ publication.server }} in a new tab)</span>
        </span>
      </a>
      <span class="preprint-banner__meta">
        {{ publication.authorsShort }} · {{ publication.server }} {{ publication.year }} ·
        <span class="preprint-banner__doi">doi:{{ publication.doi }}</span>
      </span>
    </p>

    <div class="preprint-banner__actions">
      <button
        type="button"
        class="preprint-banner__copy"
        data-testid="preprint-banner-copy"
        @click="copyCitation"
      >
        <i :class="copyIcon" aria-hidden="true" />
        <span aria-live="polite">{{ copyLabel }}</span>
      </button>
      <button
        type="button"
        class="preprint-banner__dismiss"
        aria-label="Dismiss preprint announcement"
        data-testid="preprint-banner-dismiss"
        @click="dismiss"
      >
        <i class="bi bi-x-lg" aria-hidden="true" />
      </button>
    </div>
  </aside>
</template>

<script setup lang="ts">
import { computed, onBeforeUnmount, ref } from 'vue';
import {
  SYSNDD_PREPRINT,
  PREPRINT_BANNER_STORAGE_KEY,
  formatPreprintCitation,
} from '@/constants/publication';

type CopyState = 'idle' | 'copied' | 'failed';

const COPY_FEEDBACK_MS = 2500;

const publication = SYSNDD_PREPRINT;

// Storage can be unavailable (private mode, blocked site data); the banner then
// simply stays visible and a dismissal lasts for the current page only.
function readDismissedDoi(): string | null {
  try {
    return window.localStorage.getItem(PREPRINT_BANNER_STORAGE_KEY);
  } catch {
    return null;
  }
}

const visible = ref(readDismissedDoi() !== publication.doi);
const copyState = ref<CopyState>('idle');
let copyTimer: ReturnType<typeof setTimeout> | undefined;

const copyLabel = computed(
  () => ({ idle: 'Copy citation', copied: 'Copied', failed: 'Copy failed' })[copyState.value]
);
const copyIcon = computed(
  () =>
    ({
      idle: 'bi bi-clipboard',
      copied: 'bi bi-check-lg',
      failed: 'bi bi-exclamation-circle',
    })[copyState.value]
);

async function copyCitation() {
  try {
    await navigator.clipboard.writeText(formatPreprintCitation(publication));
    copyState.value = 'copied';
  } catch {
    copyState.value = 'failed';
  }
  clearTimeout(copyTimer);
  copyTimer = setTimeout(() => {
    copyState.value = 'idle';
  }, COPY_FEEDBACK_MS);
}

function dismiss() {
  visible.value = false;
  try {
    window.localStorage.setItem(PREPRINT_BANNER_STORAGE_KEY, publication.doi);
  } catch {
    // Dismissal still applies for this page view.
  }
}

onBeforeUnmount(() => clearTimeout(copyTimer));
</script>

<style scoped>
.preprint-banner {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  box-sizing: border-box;
  width: min(100%, 1480px);
  margin: 0 auto 0.75rem;
  padding: 0.4rem 0.5rem 0.4rem 0.85rem;
  border: 1px solid var(--medical-blue-100, #bbdefb);
  border-radius: var(--radius-lg, 0.5rem);
  background: var(--medical-blue-50, #e3f2fd);
  color: var(--neutral-800, #424242);
  font-size: 0.875rem;
  line-height: 1.4;
}

.preprint-banner__chip {
  flex: none;
  background-color: var(--medical-blue-700, #0d47a1);
  color: #fff;
  font-weight: var(--font-weight-semibold, 600);
  letter-spacing: 0.02em;
}

/* The chip is a label here, not a link: keep it static on hover. */
.preprint-banner__chip:hover {
  background-color: var(--medical-blue-700, #0d47a1);
  color: #fff;
}

.preprint-banner__body {
  display: flex;
  flex: 1;
  flex-wrap: wrap;
  align-items: baseline;
  gap: 0.1rem 0.75rem;
  min-width: 0;
  margin: 0;
}

.preprint-banner__title {
  color: var(--medical-blue-700, #0d47a1);
  font-weight: var(--font-weight-semibold, 600);
  text-decoration: none;
}

.preprint-banner__title:hover,
.preprint-banner__title:focus-visible {
  text-decoration: underline;
}

.preprint-banner__external {
  margin-left: 0.2rem;
  font-size: 0.75em;
}

.preprint-banner__meta {
  color: var(--neutral-700, #616161);
  font-size: 0.8125rem;
}

.preprint-banner__doi {
  font-family: var(--font-family-mono, ui-monospace, SFMono-Regular, Menlo, monospace);
  font-size: 0.95em;
  overflow-wrap: anywhere;
}

.preprint-banner__actions {
  display: flex;
  flex: none;
  align-items: center;
  gap: 0.25rem;
}

.preprint-banner__copy,
.preprint-banner__dismiss {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  gap: 0.35rem;
  min-height: 2.25rem;
  border: 1px solid transparent;
  border-radius: var(--radius-md, 0.375rem);
  background: transparent;
  color: var(--medical-blue-700, #0d47a1);
  font-size: 0.8125rem;
  font-weight: var(--font-weight-medium, 500);
  white-space: nowrap;
  cursor: pointer;
}

.preprint-banner__copy {
  padding: 0 0.65rem;
  border-color: var(--medical-blue-200, #90caf9);
  background: var(--surface-raised, #ffffff);
}

.preprint-banner__dismiss {
  min-width: 2.25rem;
  color: var(--neutral-700, #616161);
}

.preprint-banner__copy:hover,
.preprint-banner__dismiss:hover {
  border-color: var(--medical-blue-700, #0d47a1);
  color: var(--medical-blue-700, #0d47a1);
}

.preprint-banner__title:focus-visible,
.preprint-banner__copy:focus-visible,
.preprint-banner__dismiss:focus-visible {
  outline: 2px solid var(--action-focus-color, #0d47a1);
  outline-offset: 2px;
}

@media (max-width: 767.98px) {
  .preprint-banner {
    display: grid;
    grid-template-columns: minmax(0, 1fr) auto;
    align-items: start;
    gap: 0.35rem 0.5rem;
    padding: 0.6rem 0.5rem 0.5rem 0.75rem;
  }

  .preprint-banner__chip {
    grid-column: 1;
    align-self: center;
    justify-self: start;
  }

  /* Block flow keeps the external-link icon attached to the wrapped title. */
  .preprint-banner__body {
    display: block;
    grid-column: 1 / -1;
    grid-row: 2;
  }

  .preprint-banner__meta {
    display: block;
    margin-top: 0.15rem;
  }

  /* Dismiss sits top-right beside the chip; copy drops under the text. */
  .preprint-banner__actions {
    display: contents;
  }

  .preprint-banner__dismiss {
    grid-column: 2;
    grid-row: 1;
    min-width: 2.75rem;
    min-height: 2.75rem;
    margin: -0.4rem -0.25rem -0.4rem 0;
  }

  .preprint-banner__copy {
    grid-column: 1 / -1;
    grid-row: 3;
    justify-self: start;
    min-height: 2.75rem;
  }
}
</style>
