<template>
  <BCard class="version-info border-0 bg-light" body-class="py-3">
    <h6 class="fw-bold mb-3">
      <i class="bi bi-tags me-2" aria-hidden="true" />
      Version information
    </h6>

    <BListGroup flush>
      <!-- App version (from package.json) -->
      <BListGroupItem class="bg-transparent d-flex justify-content-between align-items-center px-0">
        <span class="text-muted">
          <i class="bi bi-window me-2" aria-hidden="true" />
          Application
        </span>
        <span class="fw-semibold font-monospace">v{{ appVersion }}</span>
      </BListGroupItem>

      <!-- API version + commit (from /api/version) -->
      <BListGroupItem class="bg-transparent d-flex justify-content-between align-items-center px-0">
        <span class="text-muted">
          <i class="bi bi-hdd-network me-2" aria-hidden="true" />
          API
        </span>
        <span v-if="loading" class="text-muted small">
          <BSpinner small label="Loading version" />
        </span>
        <span v-else-if="apiVersion" class="fw-semibold font-monospace">
          v{{ apiVersion.version }}
          <BBadge
            v-if="apiVersion.commit && apiVersion.commit !== 'unknown'"
            variant="secondary"
            class="ms-2 fw-normal"
          >
            {{ apiVersion.commit }}
          </BBadge>
        </span>
        <span v-else class="text-muted small">unavailable</span>
      </BListGroupItem>

      <!-- Database version + commit (issue #22, from /api/version `database`) -->
      <BListGroupItem class="bg-transparent d-flex justify-content-between align-items-center px-0">
        <span class="text-muted">
          <i class="bi bi-database me-2" aria-hidden="true" />
          Database
        </span>
        <span v-if="loading" class="text-muted small">
          <BSpinner small label="Loading database version" />
        </span>
        <span
          v-else-if="dbVersion && dbVersion.available"
          class="fw-semibold font-monospace"
          :title="dbVersionTitle"
        >
          v{{ dbVersion.version }}
          <BBadge
            v-if="dbVersion.commit && dbVersion.commit !== 'unknown'"
            variant="secondary"
            class="ms-2 fw-normal"
          >
            {{ dbVersion.commit }}
          </BBadge>
        </span>
        <span v-else class="text-muted small">unavailable</span>
      </BListGroupItem>
    </BListGroup>
  </BCard>
</template>

<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import packageInfo from '../../package.json';
import { getVersion, type ApiVersion, type DbVersion } from '@/api/version';

const appVersion = packageInfo.version;
const loading = ref(true);
const apiVersion = ref<ApiVersion | null>(null);

const dbVersion = computed<DbVersion | null>(() => apiVersion.value?.database ?? null);

const dbVersionTitle = computed(() => {
  const db = dbVersion.value;
  if (!db) return '';
  const parts: string[] = [];
  if (db.description) parts.push(db.description);
  if (db.updated_at) parts.push(`Updated: ${db.updated_at}`);
  return parts.join(' — ');
});

onMounted(async () => {
  try {
    apiVersion.value = await getVersion({ timeout: 5000 });
  } catch (_err) {
    // Public, non-critical surface: leave apiVersion null so the template
    // shows "unavailable" rather than surfacing an error.
    apiVersion.value = null;
  } finally {
    loading.value = false;
  }
});
</script>

<style scoped>
.version-info {
  max-width: 28rem;
}
</style>
