// app/src/composables/useLlmAdmin.ts
// Composable for LLM Administration API calls

import { ref, type Ref } from 'vue';
import axios from 'axios';
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
  fetchConfig: (token: string) => Promise<void>;
  updateModel: (token: string, model: string) => Promise<ModelUpdateResponse>;

  // Prompt actions
  fetchPrompts: (token: string) => Promise<void>;
  updatePrompt: (
    token: string,
    type: PromptType,
    template: string,
    version: string,
    description?: string
  ) => Promise<PromptUpdateResponse>;

  // Cache actions
  fetchCacheStats: (token: string) => Promise<void>;
  fetchCachedSummaries: (
    token: string,
    params?: {
      cluster_type?: ClusterType;
      validation_status?: ValidationStatus;
      page?: number;
      per_page?: number;
    }
  ) => Promise<PaginatedCacheSummaries>;
  clearCache: (token: string, clusterType: ClusterType | 'all') => Promise<CacheClearResponse>;
  updateValidationStatus: (
    token: string,
    cacheId: number,
    action: 'validate' | 'reject'
  ) => Promise<ValidationUpdateResponse>;

  // Regeneration actions
  triggerRegeneration: (
    token: string,
    clusterType: ClusterType | 'all',
    force?: boolean
  ) => Promise<RegenerationJobResponse>;

  // Log actions
  fetchLogs: (
    token: string,
    params?: {
      cluster_type?: ClusterType;
      status?: LogStatus;
      from_date?: string;
      to_date?: string;
      page?: number;
      per_page?: number;
    }
  ) => Promise<PaginatedLogs>;
}

export function useLlmAdmin(): UseLlmAdminReturn {
  // Reactive state
  const config = ref<LlmConfig | null>(null);
  const prompts = ref<PromptTemplates | null>(null);
  const cacheStats = ref<CacheStats | null>(null);
  const loading = ref(false);
  const error = ref<string | null>(null);

  // Helper for auth headers
  const authHeaders = (token: string) => ({
    Authorization: `Bearer ${token}`,
  });

  // ─────────────────────────────────────────────────────────────────────────────
  // Config Actions
  // ─────────────────────────────────────────────────────────────────────────────

  async function fetchConfig(token: string): Promise<void> {
    loading.value = true;
    error.value = null;
    try {
      const response = await axios.get<LlmConfig>(`${API_BASE}/config`, {
        headers: authHeaders(token),
      });
      // Unwrap Plumber's array-wrapped scalar values
      config.value = unwrapPlumberValue(response.data);
    } catch (e) {
      error.value = e instanceof Error ? e.message : 'Failed to fetch config';
      throw e;
    } finally {
      loading.value = false;
    }
  }

  async function updateModel(token: string, model: string): Promise<ModelUpdateResponse> {
    loading.value = true;
    error.value = null;
    try {
      const response = await axios.put<ModelUpdateResponse>(`${API_BASE}/config`, null, {
        headers: authHeaders(token),
        params: { model },
      });
      if (config.value) {
        config.value.current_model = model;
      }
      return response.data;
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

  async function fetchPrompts(token: string): Promise<void> {
    loading.value = true;
    error.value = null;
    try {
      const response = await axios.get<PromptTemplates>(`${API_BASE}/prompts`, {
        headers: authHeaders(token),
      });
      prompts.value = response.data;
    } catch (e) {
      error.value = e instanceof Error ? e.message : 'Failed to fetch prompts';
      throw e;
    } finally {
      loading.value = false;
    }
  }

  async function updatePrompt(
    token: string,
    type: PromptType,
    template: string,
    version: string,
    description?: string
  ): Promise<PromptUpdateResponse> {
    loading.value = true;
    error.value = null;
    try {
      const response = await axios.put<PromptUpdateResponse>(
        `${API_BASE}/prompts/${type}`,
        { template, version, description },
        { headers: authHeaders(token) }
      );
      return response.data;
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

  async function fetchCacheStats(token: string): Promise<void> {
    loading.value = true;
    error.value = null;
    try {
      const response = await axios.get<CacheStats>(`${API_BASE}/cache/stats`, {
        headers: authHeaders(token),
      });
      cacheStats.value = response.data;
    } catch (e) {
      error.value = e instanceof Error ? e.message : 'Failed to fetch cache stats';
      throw e;
    } finally {
      loading.value = false;
    }
  }

  async function fetchCachedSummaries(
    token: string,
    params: {
      cluster_type?: ClusterType;
      validation_status?: ValidationStatus;
      page?: number;
      per_page?: number;
    } = {}
  ): Promise<PaginatedCacheSummaries> {
    const response = await axios.get<PaginatedCacheSummaries>(`${API_BASE}/cache/summaries`, {
      headers: authHeaders(token),
      params,
    });
    return response.data;
  }

  async function clearCache(
    token: string,
    clusterType: ClusterType | 'all'
  ): Promise<CacheClearResponse> {
    const response = await axios.delete<CacheClearResponse>(`${API_BASE}/cache`, {
      headers: authHeaders(token),
      params: { cluster_type: clusterType },
    });
    return response.data;
  }

  async function updateValidationStatus(
    token: string,
    cacheId: number,
    action: 'validate' | 'reject'
  ): Promise<ValidationUpdateResponse> {
    const response = await axios.post<ValidationUpdateResponse>(
      `${API_BASE}/cache/${cacheId}/validate`,
      null,
      {
        headers: authHeaders(token),
        params: { action },
      }
    );
    return response.data;
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Regeneration Actions
  // ─────────────────────────────────────────────────────────────────────────────

  async function triggerRegeneration(
    token: string,
    clusterType: ClusterType | 'all',
    force = false
  ): Promise<RegenerationJobResponse> {
    const response = await axios.post<RegenerationJobResponse>(`${API_BASE}/regenerate`, null, {
      headers: authHeaders(token),
      params: { cluster_type: clusterType, force },
    });
    return response.data;
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Log Actions
  // ─────────────────────────────────────────────────────────────────────────────

  async function fetchLogs(
    token: string,
    params: {
      cluster_type?: ClusterType;
      status?: LogStatus;
      from_date?: string;
      to_date?: string;
      page?: number;
      per_page?: number;
    } = {}
  ): Promise<PaginatedLogs> {
    const response = await axios.get<PaginatedLogs>(`${API_BASE}/logs`, {
      headers: authHeaders(token),
      params,
    });
    return response.data;
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
