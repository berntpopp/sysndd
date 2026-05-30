// app/src/api/llm_admin.spec.ts
//
// Vitest + MSW spec for the typed llm-admin helpers (W3.11).

import { describe, it, expect } from 'vitest';
import { http, HttpResponse } from 'msw';

import {
  getLlmConfig,
  updateLlmModel,
  getLlmCacheStats,
  getLlmCacheSummaries,
  clearLlmCache,
  regenerateLlm,
  getLlmLogs,
  validateLlmCacheEntry,
  getLlmPrompts,
  updateLlmPrompt,
  type LlmConfig,
  type LlmCacheStats,
  type PaginatedCacheSummaries,
  type ClearLlmCacheResponse,
  type RegenerateLlmResponse,
  type PaginatedLogs,
  type ValidateCacheResponse,
  type LlmPromptTemplateMap,
} from './llm_admin';
import { isApiError } from './client';
import { server } from '@/test-utils/mocks/server';

describe('api/llm — getLlmConfig', () => {
  it('returns the LLM config envelope on 200', async () => {
    const ok: LlmConfig = {
      gemini_configured: true,
      current_model: 'gemini-2.5-flash',
      source: 'default',
      default_model: 'gemini-3.5-flash',
      valid: true,
      operator_allowed: false,
      warning: null,
      available_models: [
        {
          model_id: 'gemini-2.5-flash',
          display_name: 'Gemini 2.5 Flash',
          description: '...',
          rpm_limit: 2000,
          rpd_limit: null,
          recommended_for: 'Cost-effective',
        },
      ],
      rate_limit: { capacity: 60 },
    };
    server.use(http.get('/api/llm/config', () => HttpResponse.json(ok)));

    const result = await getLlmConfig();
    expect(result.gemini_configured).toBe(true);
  });
});

describe('api/llm — updateLlmModel', () => {
  it('forwards model as a query param', async () => {
    let observedQuery: URLSearchParams | null = null;
    server.use(
      http.put('/api/llm/config', ({ request }) => {
        observedQuery = new URL(request.url).searchParams;
        return HttpResponse.json({
          success: true,
          message: 'Model changed',
          model: 'gemini-3.1-pro-preview',
        });
      })
    );

    await updateLlmModel({ model: 'gemini-3.1-pro-preview' });
    expect((observedQuery as unknown as URLSearchParams).get('model')).toBe(
      'gemini-3.1-pro-preview'
    );
  });

  it('throws AxiosError on 400 (invalid model)', async () => {
    server.use(
      http.put('/api/llm/config', () =>
        HttpResponse.json({ error: 'INVALID_MODEL' }, { status: 400 })
      )
    );

    let caught: unknown;
    try {
      await updateLlmModel({ model: 'made-up' });
    } catch (err) {
      caught = err;
    }
    expect(isApiError(caught)).toBe(true);
    if (isApiError(caught)) {
      expect(caught.response?.status).toBe(400);
    }
  });
});

describe('api/llm — getLlmCacheStats', () => {
  it('returns the stats envelope on 200', async () => {
    const ok: LlmCacheStats = {
      total_entries: 42,
      by_status: { validated: 30, rejected: 5, pending: 7 },
      by_type: { functional: 20, phenotype: 22 },
      last_generation: '2026-04-25T00:00:00Z',
      total_tokens_input: 1000,
      total_tokens_output: 2000,
      estimated_cost_usd: 0.15,
    };
    server.use(http.get('/api/llm/cache/stats', () => HttpResponse.json(ok)));

    const result = await getLlmCacheStats();
    expect(result.total_entries).toBe(42);
  });
});

describe('api/llm — getLlmCacheSummaries', () => {
  it('forwards filter and pagination params', async () => {
    let observedQuery: URLSearchParams | null = null;
    const ok: PaginatedCacheSummaries = {
      data: [],
      total: 0,
      page: 1,
      per_page: 20,
    };
    server.use(
      http.get('/api/llm/cache/summaries', ({ request }) => {
        observedQuery = new URL(request.url).searchParams;
        return HttpResponse.json(ok);
      })
    );

    await getLlmCacheSummaries({
      cluster_type: 'phenotype',
      validation_status: 'validated',
      page: 2,
    });
    const q = observedQuery as unknown as URLSearchParams;
    expect(q.get('cluster_type')).toBe('phenotype');
    expect(q.get('validation_status')).toBe('validated');
    expect(q.get('page')).toBe('2');
  });
});

describe('api/llm — clearLlmCache', () => {
  it('forwards cluster_type and returns the cleared envelope', async () => {
    const ok: ClearLlmCacheResponse = {
      success: true,
      message: 'Cache cleared',
      cleared_count: 12,
    };
    server.use(http.delete('/api/llm/cache', () => HttpResponse.json(ok)));
    const result = await clearLlmCache({ cluster_type: 'phenotype' });
    expect(result.cleared_count).toBe(12);
  });
});

describe('api/llm — regenerateLlm', () => {
  it('returns the 202 regenerate envelope', async () => {
    const ok: RegenerateLlmResponse = {
      job_id: 'parent-1',
      status: 'accepted',
      status_url: '/api/jobs/parent-1',
      cluster_types: ['functional'],
      results: {},
    };
    server.use(http.post('/api/llm/regenerate', () => HttpResponse.json(ok, { status: 202 })));

    const result = await regenerateLlm({ cluster_type: 'functional', force: true });
    expect(result.job_id).toBe('parent-1');
  });
});

describe('api/llm — getLlmLogs', () => {
  it('returns the paginated logs envelope on 200', async () => {
    const ok: PaginatedLogs = {
      data: [],
      total: 0,
      page: 1,
      per_page: 50,
    };
    server.use(http.get('/api/llm/logs', () => HttpResponse.json(ok)));
    const result = await getLlmLogs({ status: 'success' });
    expect(result.total).toBe(0);
  });
});

describe('api/llm — validateLlmCacheEntry', () => {
  it('URL-encodes cache_id and forwards action', async () => {
    let observedPath: string | null = null;
    let observedQuery: URLSearchParams | null = null;
    const ok: ValidateCacheResponse = {
      success: true,
      message: 'validated',
      cache_id: 42,
      validation_status: 'validated',
    };
    server.use(
      http.post('/api/llm/cache/:id/validate', ({ request }) => {
        observedPath = new URL(request.url).pathname;
        observedQuery = new URL(request.url).searchParams;
        return HttpResponse.json(ok);
      })
    );

    await validateLlmCacheEntry(42, { action: 'validate' });
    expect(observedPath).toBe('/api/llm/cache/42/validate');
    expect((observedQuery as unknown as URLSearchParams).get('action')).toBe('validate');
  });
});

describe('api/llm — getLlmPrompts', () => {
  it('returns the prompt-templates map on 200', async () => {
    const ok: LlmPromptTemplateMap = {
      functional_generation: {
        template_id: 1,
        prompt_type: 'functional_generation',
        version: '1.0',
        template_text: '...',
        description: null,
      },
    };
    server.use(http.get('/api/llm/prompts', () => HttpResponse.json(ok)));
    const result = await getLlmPrompts();
    expect(result.functional_generation?.version).toBe('1.0');
  });
});

describe('api/llm — updateLlmPrompt', () => {
  it('PUTs the body and URL-encodes the type path param', async () => {
    let receivedBody: unknown = null;
    let observedPath: string | null = null;
    server.use(
      http.put('/api/llm/prompts/:type', async ({ request }) => {
        observedPath = new URL(request.url).pathname;
        receivedBody = await request.json();
        return HttpResponse.json({
          success: true,
          message: 'OK',
          type: 'functional_generation',
          version: '1.1',
        });
      })
    );

    await updateLlmPrompt('functional_generation', {
      template: 'new template',
      version: '1.1',
      description: 'updated',
    });
    expect(observedPath).toBe('/api/llm/prompts/functional_generation');
    expect(receivedBody).toEqual({
      template: 'new template',
      version: '1.1',
      description: 'updated',
    });
  });

  it('throws AxiosError on 400 (missing template)', async () => {
    server.use(
      http.put('/api/llm/prompts/:type', () =>
        HttpResponse.json({ error: 'MISSING_TEMPLATE' }, { status: 400 })
      )
    );

    await expect(
      updateLlmPrompt('functional_generation', { template: '', version: '1.0' })
    ).rejects.toThrow();
  });
});
