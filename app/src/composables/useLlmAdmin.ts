// app/src/composables/useLlmAdmin.ts
// Composable for LLM Administration API calls.
//
// v11.0 closeout F2a: the `token: string` parameter has been dropped from
// every exported method. The `apiClient` request interceptor
// (`@/api/client`) reads `useAuth().token.value` on every outbound call and
// injects the `Authorization: Bearer <token>` header. Call sites are
// therefore no longer responsible for sourcing the token from localStorage
// and passing it through — they just call `fetchConfig()` / `fetchPrompts()`
// / etc. directly. See `.plans/v11.0/closeout.md` §3 F2a.

import { ref, type Ref } from 'vue';
import { apiClient } from '@/api/client';
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

const API_BASE = `${import.meta.env.VITE_API_URL}/api/llm`;

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
      const data = await apiClient.get<LlmConfig>(`${API_BASE}/config`, {
        withCredentials: true,
      });
      // Unwrap Plumber's array-wrapped scalar values
      config.value = unwrapPlumberValue(data);
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
      const data = await apiClient.put<ModelUpdateResponse>(`${API_BASE}/config`, null, {
        params: { model },
        withCredentials: true,
      });
      if (config.value) {
        config.value.current_model = model;
      }
      return data;
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
      const data = await apiClient.get<PromptTemplates>(`${API_BASE}/prompts`, {
        withCredentials: true,
      });
      prompts.value = data;
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
      const data = await apiClient.put<PromptUpdateResponse>(
        `${API_BASE}/prompts/${type}`,
        { template, version, description },
        { withCredentials: true }
      );
      return data;
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
      const data = await apiClient.get<CacheStats>(`${API_BASE}/cache/stats`, {
        withCredentials: true,
      });
      cacheStats.value = data;
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
    return apiClient.get<PaginatedCacheSummaries>(`${API_BASE}/cache/summaries`, {
      params,
      withCredentials: true,
    });
  }

  async function clearCache(
    clusterType: ClusterType | 'all'
  ): Promise<CacheClearResponse> {
    return apiClient.delete<CacheClearResponse>(`${API_BASE}/cache`, {
      params: { cluster_type: clusterType },
      withCredentials: true,
    });
  }

  async function updateValidationStatus(
    cacheId: number,
    action: 'validate' | 'reject'
  ): Promise<ValidationUpdateResponse> {
    return apiClient.post<ValidationUpdateResponse>(
      `${API_BASE}/cache/${cacheId}/validate`,
      null,
      {
        params: { action },
        withCredentials: true,
      }
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Regeneration Actions
  // ─────────────────────────────────────────────────────────────────────────────

  async function triggerRegeneration(
    clusterType: ClusterType | 'all',
    force = false
  ): Promise<RegenerationJobResponse> {
    return apiClient.post<RegenerationJobResponse>(`${API_BASE}/regenerate`, null, {
      params: { cluster_type: clusterType, force },
      withCredentials: true,
    });
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
    return apiClient.get<PaginatedLogs>(`${API_BASE}/logs`, {
      params,
      withCredentials: true,
    });
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
