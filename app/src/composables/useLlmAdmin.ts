// app/src/composables/useLlmAdmin.ts
// Composable for LLM Administration API calls.
//
// HTTP transport is delegated to the typed resource helpers in
// `@/api/llm_admin` (getLlmConfig / updateLlmModel / getLlmPrompts /
// updateLlmPrompt / getLlmCacheStats / getLlmCacheSummaries / clearLlmCache /
// validateLlmCacheEntry / regenerateLlm / getLlmLogs) rather than reaching for
// raw `apiClient.get/post` URLs here. This composable owns the reactive state
// (config / prompts / cacheStats / loading / error) and exposes the
// view-facing types from `@/types/llm`.
//
// v11.0 closeout F2a: the `token: string` parameter has been dropped from
// every exported method. The `apiClient` request interceptor
// (`@/api/client`) reads `useAuth().token.value` on every outbound call and
// injects the `Authorization: Bearer <token>` header (the typed helpers run
// through the same interceptor). Call sites are therefore no longer
// responsible for sourcing the token from localStorage and passing it through
// — they just call `fetchConfig()` / `fetchPrompts()` / etc. directly. See
// `.planning/_archive/legacy-plans/v11.0/closeout.md` §3 F2a.

import { ref, type Ref } from 'vue';
import {
  getLlmConfig,
  updateLlmModel,
  getLlmPrompts,
  updateLlmPrompt,
  getLlmCacheStats,
  getLlmCacheSummaries,
  clearLlmCache,
  validateLlmCacheEntry,
  regenerateLlm,
  getLlmLogs,
} from '@/api/llm_admin';
import type {
  LlmConfig,
  PromptTemplates,
  PromptType,
  CacheStats,
  PaginatedCacheSummaries,
  PaginatedLogs,
  CacheClearResponse,
  RegenerationJobResponse,
  ValidationUpdateResponse,
  ModelUpdateResponse,
  PromptUpdateResponse,
  ClusterType,
  ValidationStatus,
  LogStatus,
} from '@/types/llm';

/**
 * Unwrap Plumber's array-wrapped scalar values.
 * R/Plumber wraps scalar values in single-element arrays (e.g., ["value"] instead of "value").
 * This function recursively unwraps them for proper TypeScript consumption.
 */
function unwrapPlumberValue<T>(value: T): T {
  if (value === null || value === undefined) {
    return value;
  }

  // If it's an array with exactly one element that is a primitive, unwrap it
  if (Array.isArray(value)) {
    if (
      value.length === 1 &&
      (typeof value[0] === 'string' ||
        typeof value[0] === 'number' ||
        typeof value[0] === 'boolean')
    ) {
      return value[0] as T;
    }
    // If array has multiple elements or contains objects, process each element
    return value.map((item) => unwrapPlumberValue(item)) as T;
  }

  // If it's an object, recursively unwrap all properties
  if (typeof value === 'object') {
    const result: Record<string, unknown> = {};
    for (const key of Object.keys(value as Record<string, unknown>)) {
      result[key] = unwrapPlumberValue((value as Record<string, unknown>)[key]);
    }
    return result as T;
  }

  return value;
}

export interface UseLlmAdminReturn {
  // State
  config: Ref<LlmConfig | null>;
  prompts: Ref<PromptTemplates | null>;
  cacheStats: Ref<CacheStats | null>;
  loading: Ref<boolean>;
  error: Ref<string | null>;

  // Config actions
  fetchConfig: () => Promise<void>;
  updateModel: (model: string) => Promise<ModelUpdateResponse>;

  // Prompt actions
  fetchPrompts: () => Promise<void>;
  updatePrompt: (
    type: PromptType,
    template: string,
    version: string,
    description?: string
  ) => Promise<PromptUpdateResponse>;

  // Cache actions
  fetchCacheStats: () => Promise<void>;
  fetchCachedSummaries: (params?: {
    cluster_type?: ClusterType;
    validation_status?: ValidationStatus;
    page?: number;
    per_page?: number;
  }) => Promise<PaginatedCacheSummaries>;
  clearCache: (clusterType: ClusterType | 'all') => Promise<CacheClearResponse>;
  updateValidationStatus: (
    cacheId: number,
    action: 'validate' | 'reject'
  ) => Promise<ValidationUpdateResponse>;

  // Regeneration actions
  triggerRegeneration: (
    clusterType: ClusterType | 'all',
    force?: boolean
  ) => Promise<RegenerationJobResponse>;

  // Log actions
  fetchLogs: (params?: {
    cluster_type?: ClusterType;
    status?: LogStatus;
    from_date?: string;
    to_date?: string;
    page?: number;
    per_page?: number;
  }) => Promise<PaginatedLogs>;
}

export function useLlmAdmin(): UseLlmAdminReturn {
  // Reactive state
  const config = ref<LlmConfig | null>(null);
  const prompts = ref<PromptTemplates | null>(null);
  const cacheStats = ref<CacheStats | null>(null);
  const loading = ref(false);
  const error = ref<string | null>(null);

  // ─────────────────────────────────────────────────────────────────────────────
  // Config Actions
  // ─────────────────────────────────────────────────────────────────────────────

  async function fetchConfig(): Promise<void> {
    loading.value = true;
    error.value = null;
    try {
      const data = await getLlmConfig();
      // Unwrap Plumber's array-wrapped scalar values. llm_admin.ts and
      // @/types/llm declare parallel LlmConfig shapes (identical runtime data);
      // bridge via unknown.
      config.value = unwrapPlumberValue(data as unknown as LlmConfig);
    } catch (e) {
      error.value = e instanceof Error ? e.message : 'Failed to fetch config';
      throw e;
    } finally {
      loading.value = false;
    }
  }

  async function updateModel(model: string): Promise<ModelUpdateResponse> {
    loading.value = true;
    error.value = null;
    try {
      const data = await updateLlmModel({ model });
      if (config.value) {
        config.value.current_model = model;
      }
      return data as unknown as ModelUpdateResponse;
    } catch (e) {
      error.value = e instanceof Error ? e.message : 'Failed to update model';
      throw e;
    } finally {
      loading.value = false;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Prompt Actions
  // ─────────────────────────────────────────────────────────────────────────────

  async function fetchPrompts(): Promise<void> {
    loading.value = true;
    error.value = null;
    try {
      const data = await getLlmPrompts();
      prompts.value = data as unknown as PromptTemplates;
    } catch (e) {
      error.value = e instanceof Error ? e.message : 'Failed to fetch prompts';
      throw e;
    } finally {
      loading.value = false;
    }
  }

  async function updatePrompt(
    type: PromptType,
    template: string,
    version: string,
    description?: string
  ): Promise<PromptUpdateResponse> {
    loading.value = true;
    error.value = null;
    try {
      const data = await updateLlmPrompt(type, { template, version, description });
      return data as unknown as PromptUpdateResponse;
    } catch (e) {
      error.value = e instanceof Error ? e.message : 'Failed to update prompt';
      throw e;
    } finally {
      loading.value = false;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Cache Actions
  // ─────────────────────────────────────────────────────────────────────────────

  async function fetchCacheStats(): Promise<void> {
    loading.value = true;
    error.value = null;
    try {
      const data = await getLlmCacheStats();
      cacheStats.value = data as unknown as CacheStats;
    } catch (e) {
      error.value = e instanceof Error ? e.message : 'Failed to fetch cache stats';
      throw e;
    } finally {
      loading.value = false;
    }
  }

  async function fetchCachedSummaries(
    params: {
      cluster_type?: ClusterType;
      validation_status?: ValidationStatus;
      page?: number;
      per_page?: number;
    } = {}
  ): Promise<PaginatedCacheSummaries> {
    const data = await getLlmCacheSummaries(params);
    return data as unknown as PaginatedCacheSummaries;
  }

  async function clearCache(clusterType: ClusterType | 'all'): Promise<CacheClearResponse> {
    const data = await clearLlmCache({ cluster_type: clusterType });
    return data as unknown as CacheClearResponse;
  }

  async function updateValidationStatus(
    cacheId: number,
    action: 'validate' | 'reject'
  ): Promise<ValidationUpdateResponse> {
    const data = await validateLlmCacheEntry(cacheId, { action });
    return data as unknown as ValidationUpdateResponse;
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Regeneration Actions
  // ─────────────────────────────────────────────────────────────────────────────

  async function triggerRegeneration(
    clusterType: ClusterType | 'all',
    force = false
  ): Promise<RegenerationJobResponse> {
    const data = await regenerateLlm({ cluster_type: clusterType, force });
    return data as unknown as RegenerationJobResponse;
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Log Actions
  // ─────────────────────────────────────────────────────────────────────────────

  async function fetchLogs(
    params: {
      cluster_type?: ClusterType;
      status?: LogStatus;
      from_date?: string;
      to_date?: string;
      page?: number;
      per_page?: number;
    } = {}
  ): Promise<PaginatedLogs> {
    const data = await getLlmLogs(params);
    return data as unknown as PaginatedLogs;
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Return
  // ─────────────────────────────────────────────────────────────────────────────

  return {
    // State
    config,
    prompts,
    cacheStats,
    loading,
    error,

    // Actions
    fetchConfig,
    updateModel,
    fetchPrompts,
    updatePrompt,
    fetchCacheStats,
    fetchCachedSummaries,
    clearCache,
    updateValidationStatus,
    triggerRegeneration,
    fetchLogs,
  };
}
