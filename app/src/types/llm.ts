// app/src/types/llm.ts
// TypeScript interfaces for LLM Administration API

/**
 * LLM Configuration from GET /api/llm/config
 */
export interface LlmConfig {
  gemini_configured: boolean;
  current_model: string;
  available_models: GeminiModel[];
  rate_limit: RateLimitConfig;
}

export interface GeminiModel {
  model_id: string;
  display_name: string;
  description: string;
  rpm_limit: number;
  rpd_limit: number | null;
  recommended_for: string;
}

export interface RateLimitConfig {
  capacity: number;
  fill_time_s: number;
  backoff_base: number;
  max_retries: number;
}

/**
 * Prompt Template Types
 */
export type PromptType =
  | 'functional_generation'
  | 'functional_judge'
  | 'phenotype_generation'
  | 'phenotype_judge';

export interface PromptTemplate {
  template_id: number | null;
  prompt_type: PromptType;
  version: string;
  template_text: string;
  description: string | null;
}

export type PromptTemplates = Record<PromptType, PromptTemplate>;

/**
 * Cache Statistics from GET /api/llm/cache/stats
 */
export interface CacheStats {
  total_entries: number;
  by_status: {
    pending: number;
    validated: number;
    rejected: number;
  };
  by_type: {
    functional?: CacheTypeStats;
    phenotype?: CacheTypeStats;
  };
  last_generation: string | null;
  total_tokens_used: number;
  estimated_cost_usd: number;
}

export interface CacheTypeStats {
  count: number;
  validated: number;
  pending: number;
  rejected: number;
}

/**
 * Cached Summary from GET /api/llm/cache/summaries
 */
export type ValidationStatus = 'pending' | 'validated' | 'rejected';
export type ClusterType = 'functional' | 'phenotype';

export interface CachedSummary {
  cache_id: number;
  cluster_type: ClusterType;
  cluster_number: number;
  cluster_hash: string;
  model_name: string;
  prompt_version: string;
  summary_json: Record<string, unknown>;
  tags: string[] | null;
  is_current: boolean;
  validation_status: ValidationStatus;
  created_at: string;
  validated_at: string | null;
  validated_by: number | null;
}

export interface PaginatedCacheSummaries {
  data: CachedSummary[];
  total: number;
  page: number;
  per_page: number;
}

/**
 * Generation Log from GET /api/llm/logs
 */
export type LogStatus = 'success' | 'validation_failed' | 'api_error' | 'timeout';

export interface GenerationLog {
  log_id: number;
  cluster_type: ClusterType;
  cluster_number: number;
  cluster_hash: string;
  model_name: string;
  prompt_text: string;
  response_json: Record<string, unknown> | null;
  validation_errors: string | null;
  tokens_input: number | null;
  tokens_output: number | null;
  latency_ms: number | null;
  status: LogStatus;
  error_message: string | null;
  created_at: string;
}

export interface PaginatedLogs {
  data: GenerationLog[];
  total: number;
  page: number;
}

/**
 * Regeneration Job from POST /api/llm/regenerate
 */
export interface RegenerationJobResponse {
  job_id: string;
  status: string;
  cluster_type: ClusterType | 'all';
  force: boolean;
  status_url: string;
}

/**
 * Cache Clear Response from DELETE /api/llm/cache
 */
export interface CacheClearResponse {
  success: boolean;
  cleared_count: number;
  cluster_type: ClusterType | 'all';
}

/**
 * Validation Update Response from POST /api/llm/cache/:id/validate
 */
export interface ValidationUpdateResponse {
  success: boolean;
  cache_id: number;
  new_status: ValidationStatus;
}

/**
 * Model Update Response from PUT /api/llm/config
 */
export interface ModelUpdateResponse {
  success: boolean;
  current_model: string;
}

/**
 * Prompt Update Response from PUT /api/llm/prompts/:type
 */
export interface PromptUpdateResponse {
  success: boolean;
  type: PromptType;
  version: string;
  template_id: number;
}
