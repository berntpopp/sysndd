// app/src/api/health.spec.ts
//
// Vitest + MSW spec for the typed health helpers (W3.8).

import { describe, it, expect } from 'vitest';
import { http, HttpResponse } from 'msw';

import {
  getHealth,
  getReadiness,
  getPerformance,
  type HealthStatus,
  type ReadinessStatus,
  type PerformanceMetrics,
} from './health';
import { isApiError } from './client';
import { server } from '@/test-utils/mocks/server';

describe('api/health — getHealth', () => {
  it('returns the liveness envelope on 200', async () => {
    const expected: HealthStatus = {
      status: 'healthy',
      timestamp: '2026-04-25T00:00:00Z',
      version: '0.11.14',
    };
    server.use(http.get('/api/health', () => HttpResponse.json(expected)));

    const result = await getHealth();
    expect(result).toEqual(expected);
  });

  it('throws AxiosError on 500', async () => {
    server.use(
      http.get('/api/health', () => HttpResponse.json({ error: 'boom' }, { status: 500 }))
    );
    await expect(getHealth()).rejects.toThrow();
  });
});

describe('api/health — getReadiness', () => {
  it('returns the readiness envelope on 200', async () => {
    const ok: ReadinessStatus = {
      status: 'healthy',
      database: 'connected',
      migrations: {
        pending: 0,
        applied: 12,
        startup: { fast_path: true, lock_acquired: true },
      },
      pool: { max_size: 5, active: 1, idle: 4, total: 5 },
      timestamp: '2026-04-25T00:00:00Z',
    };
    server.use(http.get('/api/health/ready', () => HttpResponse.json(ok)));

    const result = await getReadiness();
    expect(result.status).toBe('healthy');
    expect(result.database).toBe('connected');
  });

  it('throws AxiosError with status 503 when not ready', async () => {
    const unhealthy: ReadinessStatus = {
      status: 'unhealthy',
      reason: 'database_unavailable',
      database: 'disconnected',
      migrations: {
        pending: null,
        applied: null,
        startup: { fast_path: null, lock_acquired: null },
      },
      pool: { max_size: 5 },
      timestamp: '2026-04-25T00:00:00Z',
    };
    server.use(http.get('/api/health/ready', () => HttpResponse.json(unhealthy, { status: 503 })));

    let caught: unknown;
    try {
      await getReadiness();
    } catch (err) {
      caught = err;
    }
    expect(isApiError(caught)).toBe(true);
    if (isApiError(caught)) {
      expect(caught.response?.status).toBe(503);
    }
  });
});

describe('api/health — getPerformance', () => {
  it('returns the performance metrics envelope on 200', async () => {
    const metrics: PerformanceMetrics = {
      workers: { configured: 2, connections: 2, dispatcher_active: true },
      cache: { file_count: 0, total_size_mb: 0 },
      cache_versions: {},
      environment: { cache_version: '1', r_version: '4.4' },
      timestamp: '2026-04-25T00:00:00Z',
    };
    server.use(http.get('/api/health/performance', () => HttpResponse.json(metrics)));

    const result = await getPerformance();
    expect(result.workers.configured).toBe(2);
    expect(result.environment.cache_version).toBe('1');
  });
});
