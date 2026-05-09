// app/src/api/statistics.spec.ts
//
// Vitest + MSW spec for the typed statistics helpers (W3.20).

import { describe, it, expect } from 'vitest';
import { http, HttpResponse } from 'msw';

import {
  getCategoryCount,
  getNews,
  getEntitiesOverTime,
  getUpdatesStats,
  getRereviewStats,
  getUpdatedReviewsStats,
  getUpdatedStatusesStats,
  getPublicationStats,
  getContributorLeaderboard,
  getRereviewLeaderboard,
  type EntitiesOverTimeResponse,
  type UpdatesStats,
  type RereviewStats,
  type ContributorLeaderboardResponse,
  type RereviewLeaderboardResponse,
  type PublicationStatsResponse,
} from './statistics';
import { isApiError } from './client';
import { server } from '@/test-utils/mocks/server';

describe('api/statistics — getCategoryCount', () => {
  it('forwards sort/type params', async () => {
    let observedQuery: URLSearchParams | null = null;
    server.use(
      http.get('/api/statistics/category_count', ({ request }) => {
        observedQuery = new URL(request.url).searchParams;
        return HttpResponse.json([]);
      })
    );

    await getCategoryCount({ type: 'entity', sort: '-n' });
    const q = observedQuery as unknown as URLSearchParams;
    expect(q.get('type')).toBe('entity');
    expect(q.get('sort')).toBe('-n');
  });
});

describe('api/statistics — getNews', () => {
  it('forwards n param', async () => {
    let observedQuery: URLSearchParams | null = null;
    server.use(
      http.get('/api/statistics/news', ({ request }) => {
        observedQuery = new URL(request.url).searchParams;
        return HttpResponse.json([]);
      })
    );

    await getNews({ n: 10 });
    expect((observedQuery as unknown as URLSearchParams).get('n')).toBe('10');
  });
});

describe('api/statistics — getEntitiesOverTime', () => {
  it('returns the meta+data envelope on 200', async () => {
    const ok: EntitiesOverTimeResponse = { meta: {}, data: [] };
    server.use(http.get('/api/statistics/entities_over_time', () => HttpResponse.json(ok)));

    const result = await getEntitiesOverTime();
    expect(result).toHaveProperty('data');
  });
});

describe('api/statistics — getUpdatesStats', () => {
  it('forwards date range params', async () => {
    let observedQuery: URLSearchParams | null = null;
    const ok: UpdatesStats = { total_new_entities: 10, unique_genes: 5, average_per_day: 1 };
    server.use(
      http.get('/api/statistics/updates', ({ request }) => {
        observedQuery = new URL(request.url).searchParams;
        return HttpResponse.json(ok);
      })
    );

    await getUpdatesStats({ start_date: '2026-01-01', end_date: '2026-04-01' });
    const q = observedQuery as unknown as URLSearchParams;
    expect(q.get('start_date')).toBe('2026-01-01');
    expect(q.get('end_date')).toBe('2026-04-01');
  });

  it('throws AxiosError on 403 (not Administrator)', async () => {
    server.use(
      http.get('/api/statistics/updates', () =>
        HttpResponse.json({ error: 'forbidden' }, { status: 403 })
      )
    );

    let caught: unknown;
    try {
      await getUpdatesStats({ start_date: '2026-01-01', end_date: '2026-04-01' });
    } catch (err) {
      caught = err;
    }
    expect(isApiError(caught)).toBe(true);
    if (isApiError(caught)) {
      expect(caught.response?.status).toBe(403);
    }
  });
});

describe('api/statistics — getRereviewStats', () => {
  it('returns the rereview stats on 200', async () => {
    const ok: RereviewStats = {
      total_rereviews: 12,
      percentage_finished: 5,
      average_per_day: 0.4,
    };
    server.use(http.get('/api/statistics/rereview', () => HttpResponse.json(ok)));

    const result = await getRereviewStats({ start_date: '2026-01-01', end_date: '2026-04-01' });
    expect(result.total_rereviews).toBe(12);
  });
});

describe('api/statistics — getUpdatedReviewsStats / getUpdatedStatusesStats', () => {
  it('returns the updated reviews count', async () => {
    server.use(
      http.get('/api/statistics/updated_reviews', () =>
        HttpResponse.json({ total_updated_reviews: 7 })
      )
    );
    const result = await getUpdatedReviewsStats({
      start_date: '2026-01-01',
      end_date: '2026-04-01',
    });
    expect(result.total_updated_reviews).toBe(7);
  });

  it('returns the updated statuses count', async () => {
    server.use(
      http.get('/api/statistics/updated_statuses', () =>
        HttpResponse.json({ total_updated_statuses: 11 })
      )
    );
    const result = await getUpdatedStatusesStats({
      start_date: '2026-01-01',
      end_date: '2026-04-01',
    });
    expect(result.total_updated_statuses).toBe(11);
  });
});

describe('api/statistics — getPublicationStats', () => {
  it('returns the publication stats envelope', async () => {
    const ok: PublicationStatsResponse = {
      publication_type_counts: [],
      journal_counts: [],
      last_name_counts: [],
      update_date_aggregated: [],
      publication_date_aggregated: [],
      keyword_counts: [],
      time_aggregate_used: 'year',
      filter_used: '',
      min_journal_count_used: 1,
      min_lastname_count_used: 1,
      min_keyword_count_used: 1,
    };
    server.use(http.get('/api/statistics/publication_stats', () => HttpResponse.json(ok)));
    const result = await getPublicationStats({ time_aggregate: 'year' });
    expect(result.time_aggregate_used).toBe('year');
  });
});

describe('api/statistics — getContributorLeaderboard', () => {
  it('returns the leaderboard envelope', async () => {
    const ok: ContributorLeaderboardResponse = {
      data: [
        { user_id: 7, user_name: 'pw_curator', display_name: 'PW Curator', entity_count: 100 },
      ],
      meta: { top: 10, scope: 'all_time', start_date: null, end_date: null, total_contributors: 1 },
    };
    server.use(http.get('/api/statistics/contributor_leaderboard', () => HttpResponse.json(ok)));
    const result = await getContributorLeaderboard({ top: 10 });
    expect(result.data).toHaveLength(1);
  });
});

describe('api/statistics — getRereviewLeaderboard', () => {
  it('returns the rereview leaderboard envelope', async () => {
    const ok: RereviewLeaderboardResponse = {
      data: [{ user_id: 7, user_name: 'pw_reviewer', re_review_count: 50 }],
      meta: { top: 10 },
    };
    server.use(http.get('/api/statistics/rereview_leaderboard', () => HttpResponse.json(ok)));
    const result = await getRereviewLeaderboard();
    expect(result.data[0].re_review_count).toBe(50);
  });
});
