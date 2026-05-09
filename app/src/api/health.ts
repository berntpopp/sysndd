// app/src/api/health.ts
//
// Health-check resource helpers.
//
// Mirrors api/endpoints/health_endpoints.R (mounted at /api/health).
// Phase E.E2: filled during v11.1 Wave 1a (W3).
//
// All three endpoints are unauthenticated and lightweight. `GET /api/health`
// is the Docker HEALTHCHECK target; `GET /api/health/ready` is the K8s readiness
// probe (checks DB + migration status, returns 503 when not ready);
// `GET /api/health/performance` reports worker pool + cache stats. Used by
// Wave 0's Playwright stack-readiness check via `make playwright-stack`.

import type { AxiosRequestConfig } from 'axios';
import { apiClient } from './client';

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

/**
 * Wire shape from `GET /api/health`. Always returns 200.
 */
export interface HealthStatus {
  status: 'healthy';
  timestamp: string;
  version: string;
}

/**
 * Migration coordination state. `pending`, `applied`, etc. arrive as numbers
 * or `NA` (which serialises as JSON null).
 */
export interface MigrationStatus {
  pending: number | null;
  applied: number | null;
  startup: {
    fast_path: boolean | null;
    lock_acquired: boolean | null;
  };
  lock?: { locked: boolean | null; holder?: number | null; error?: string };
  error?: string | null;
}

/**
 * DB connection-pool snapshot from the readiness probe.
 */
export interface PoolStats {
  max_size: number;
  active?: number;
  idle?: number;
  total?: number;
  error?: string;
}

/**
 * Wire shape from `GET /api/health/ready`. The handler returns the same
 * top-level keys for both 200 (healthy) and 503 (unhealthy), but the
 * `status` field discriminates.
 */
export interface ReadinessStatus {
  status: 'healthy' | 'unhealthy';
  reason?: 'database_unavailable' | 'migration_error' | 'migrations_pending';
  database: 'connected' | 'disconnected';
  migrations: MigrationStatus;
  pool: PoolStats;
  timestamp: string;
}

/**
 * Worker-pool status returned by `GET /api/health/performance`.
 */
export interface WorkerStatus {
  configured: number;
  connections: number;
  dispatcher_active: boolean;
  error?: string;
}

/**
 * Cache statistics returned by `GET /api/health/performance`.
 */
export interface CacheStats {
  file_count: number;
  total_size_mb: number;
  oldest_cache?: string | null;
  newest_cache?: string | null;
  error?: string;
}

/**
 * Versioned-cache snapshot returned by `GET /api/health/performance`.
 */
export interface VersionedCacheStats {
  leiden_cache_files?: number;
  walktrap_cache_files?: number;
  mca_versioned_files?: number;
  cache_migration_needed?: boolean;
  error?: string;
}

/**
 * Wire shape from `GET /api/health/performance`.
 */
export interface PerformanceMetrics {
  workers: WorkerStatus;
  cache: CacheStats;
  cache_versions: VersionedCacheStats;
  environment: {
    cache_version: string;
    r_version: string;
  };
  timestamp: string;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/**
 * GET /api/health
 * Mirrors api/endpoints/health_endpoints.R:40 (handler `@get /`).
 *
 * Lightweight liveness probe — does not query the DB. Public, no auth.
 */
export async function getHealth(config?: AxiosRequestConfig): Promise<HealthStatus> {
  return apiClient.get<HealthStatus>('/api/health', config);
}

/**
 * GET /api/health/ready
 * Mirrors api/endpoints/health_endpoints.R:72 (handler `@get /ready`).
 *
 * Readiness probe — checks DB connectivity + migration status. Returns 200
 * with `status: 'healthy'` when ready; throws AxiosError with status 503
 * + `status: 'unhealthy'` body when not ready (DB down, migrations pending,
 * or migration error during startup).
 */
export async function getReadiness(config?: AxiosRequestConfig): Promise<ReadinessStatus> {
  return apiClient.get<ReadinessStatus>('/api/health/ready', config);
}

/**
 * GET /api/health/performance
 * Mirrors api/endpoints/health_endpoints.R:203 (handler `@get /performance`).
 *
 * Reports worker-pool utilisation, cache statistics, and versioned-cache
 * counts. Public, no auth.
 */
export async function getPerformance(config?: AxiosRequestConfig): Promise<PerformanceMetrics> {
  return apiClient.get<PerformanceMetrics>('/api/health/performance', config);
}
