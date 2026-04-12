// useAsyncJob.spec.ts
/**
 * Tests for useAsyncJob composable (Phase C.C10).
 *
 * Pattern: Vue-lifecycle composable with polling + MSW network mocks
 * ------------------------------------------------------------------
 * useAsyncJob owns reactive state, VueUse `useIntervalFn` polling, and an
 * `onUnmounted` cleanup hook, so every test runs the composable inside a
 * `withSetup` mini-app. HTTP calls (`axios.get`) are intercepted by MSW's
 * node server (see `vitest.setup.ts` + `test-utils/mocks/handlers.ts`).
 *
 * The composable polls on a fixed interval via `setInterval`. To make the
 * lifecycle assertions deterministic, each test enters fake-timer mode with
 * `vi.useFakeTimers({ toFake: ['setInterval', 'clearInterval'] })` — NOT the
 * full `vi.useFakeTimers()` kit — so the microtask queue (axios / MSW / Vue
 * reactivity) still runs on real promises. Advancing `setInterval` is enough
 * to drive the poll.
 *
 * Coverage contract (plan §3 Phase C.C10):
 *   1. submit → poll → complete   (happy path)
 *   2. submit → poll → blocked    (Phase 76 ontology safeguard — the current
 *                                  composable does NOT treat `"blocked"` as
 *                                  terminal; this test pins that observable
 *                                  behavior so E4/E5 knows what they're
 *                                  changing)
 *   3. submit → poll → error      (network/5xx path)
 *
 * All job-route mocks come from the Phase B1 handler table (no new handlers).
 * Status transitions within a single test use `server.use(...)` overrides
 * (plumber scalar-array shape preserved: `status: ['x']`, `job_id: ['y']`,
 * see `CLAUDE.md` "R/Plumber returns JSON scalars as arrays").
 */

import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { http, HttpResponse } from 'msw';
import { flushPromises } from '@vue/test-utils';
import axios from 'axios';

import { withSetup } from '@/test-utils';
import { server } from '@/test-utils/mocks/server';
import useAsyncJob from './useAsyncJob';

// ---------------------------------------------------------------------------
// Shared fixtures
// ---------------------------------------------------------------------------

/**
 * The Phase B1 `hgnc_update/submit` handler returns `job_id: [string]` — an
 * array-wrapped scalar — so callers of `useAsyncJob.startJob` must `unwrap`
 * before forwarding. We keep the unwrapped value here so the test reflects
 * what a real view (ManageAnnotations.vue) would pass.
 */
const HAPPY_JOB_ID = 'hgnc-update-2025-07-01';

/**
 * The composable accepts a `statusEndpoint(jobId)` callback so callers own
 * URL construction. In tests we use a bare `/api/jobs/:job_id/status` path —
 * MSW matches path-only, and axios in jsdom routes the request through the
 * XHR interceptor.
 */
const statusEndpoint = (jobId: string) => `/api/jobs/${jobId}/status`;

/**
 * Short polling interval so a single `advanceTimersByTimeAsync` tick drives
 * exactly one poll. The `timerInterval` is pushed far enough out that the
 * elapsed-time counter never fires inside a test — we aren't exercising it.
 */
const TEST_POLL_MS = 50;
const TEST_TIMER_MS = 10_000;

async function advanceOnePoll(): Promise<void> {
  // Advance the setInterval tick, then flush any promise chains the axios
  // handler resolves with. flushPromises() is required because MSW + axios
  // resolve via real microtasks even when setInterval is faked.
  await vi.advanceTimersByTimeAsync(TEST_POLL_MS);
  await flushPromises();
}

// ---------------------------------------------------------------------------
// Test suite
// ---------------------------------------------------------------------------

describe('useAsyncJob', () => {
  beforeEach(() => {
    // Fake only the interval timers. Microtasks (promises / MSW / axios) stay
    // real so advanceTimersByTimeAsync drives the poll without deadlocking.
    vi.useFakeTimers({ toFake: ['setInterval', 'clearInterval'] });
  });

  afterEach(() => {
    vi.useRealTimers();
  });

  // -------------------------------------------------------------------------
  // Lifecycle 1 — submit → poll → complete (happy path)
  // -------------------------------------------------------------------------

  describe('submit → poll → complete', () => {
    it('transitions idle → accepted → running → completed across polls', async () => {
      // Multi-step server.use() sequence: first poll returns "running", second
      // returns "completed". Both shapes follow the plumber scalar-array
      // convention (see jobs.ts fixture for jobStatusOk).
      let pollCount = 0;
      server.use(
        http.get('/api/jobs/:job_id/status', ({ params }) => {
          pollCount += 1;
          const jobId = String(params.job_id);
          if (pollCount === 1) {
            return HttpResponse.json({
              job_id: [jobId],
              status: ['running'],
              step: ['Fetching HGNC data'],
              progress: { current: [1], total: [3] },
            });
          }
          return HttpResponse.json({
            job_id: [jobId],
            status: ['completed'],
            step: ['Done'],
            progress: { current: [3], total: [3] },
            result: [{ rows_updated: 42 }],
          });
        })
      );

      const [job, app] = withSetup(() =>
        useAsyncJob(statusEndpoint, {
          pollingInterval: TEST_POLL_MS,
          timerInterval: TEST_TIMER_MS,
        })
      );

      // Pre-submit: the composable is idle and not polling.
      expect(job.status.value).toBe('idle');
      expect(job.isPolling.value).toBe(false);
      expect(job.isLoading.value).toBe(false);

      // Submit: startJob() flips state to `accepted` and begins polling.
      job.startJob(HAPPY_JOB_ID);
      expect(job.jobId.value).toBe(HAPPY_JOB_ID);
      expect(job.status.value).toBe('accepted');
      expect(job.isLoading.value).toBe(true);
      expect(job.isPolling.value).toBe(true);
      expect(job.error.value).toBeNull();

      // First poll: "running" with 1/3 progress. Still polling.
      await advanceOnePoll();
      expect(pollCount).toBe(1);
      expect(job.status.value).toBe('running');
      expect(job.step.value).toBe('Fetching HGNC data');
      expect(job.progress.value).toEqual({ current: 1, total: 3 });
      expect(job.hasRealProgress.value).toBe(true);
      expect(job.progressPercent.value).toBe(33);
      expect(job.progressVariant.value).toBe('primary');
      expect(job.isLoading.value).toBe(true);
      expect(job.isPolling.value).toBe(true);

      // Second poll: "completed". Polling stops and variant flips to success.
      await advanceOnePoll();
      expect(pollCount).toBe(2);
      expect(job.status.value).toBe('completed');
      expect(job.step.value).toBe('Done');
      expect(job.progress.value).toEqual({ current: 3, total: 3 });
      expect(job.progressPercent.value).toBe(100);
      expect(job.progressVariant.value).toBe('success');
      expect(job.statusBadgeClass.value).toBe('bg-success');
      expect(job.isLoading.value).toBe(false);
      expect(job.isPolling.value).toBe(false);
      expect(job.error.value).toBeNull();

      // Subsequent timer ticks do nothing — polling has been paused.
      await advanceOnePoll();
      expect(pollCount).toBe(2);

      app.unmount();
    });

    it('reset() returns the composable to idle and clears polling state', async () => {
      const [job, app] = withSetup(() =>
        useAsyncJob(statusEndpoint, {
          pollingInterval: TEST_POLL_MS,
          timerInterval: TEST_TIMER_MS,
        })
      );

      job.startJob(HAPPY_JOB_ID);
      expect(job.isPolling.value).toBe(true);

      job.reset();
      expect(job.jobId.value).toBeNull();
      expect(job.status.value).toBe('idle');
      expect(job.step.value).toBe('');
      expect(job.progress.value).toEqual({ current: 0, total: 0 });
      expect(job.error.value).toBeNull();
      expect(job.isPolling.value).toBe(false);
      expect(job.isLoading.value).toBe(false);

      app.unmount();
    });
  });

  // -------------------------------------------------------------------------
  // Lifecycle 2 — submit → poll → blocked (Phase 76 ontology safeguard)
  // -------------------------------------------------------------------------

  describe('submit → poll → blocked (Phase 76 safeguard)', () => {
    it('reflects the "blocked" status returned by /api/jobs/:id/status', async () => {
      // Phase 76 introduced the `status = "blocked"` state: when the async
      // ontology update would delete categories that still have FKs, the job
      // writes a pending CSV and returns `status: ['blocked']` on its next
      // poll. See CLAUDE.md "Ontology Update Safeguard (Phase 76)" and
      // functions/job-manager.R.
      server.use(
        http.get('/api/jobs/:job_id/status', ({ params }) => {
          const jobId = String(params.job_id);
          return HttpResponse.json({
            job_id: [jobId],
            status: ['blocked'],
            step: ['Critical ontology changes detected — force-apply required'],
            progress: { current: [0], total: [0] },
          });
        })
      );

      const [job, app] = withSetup(() =>
        useAsyncJob(statusEndpoint, {
          pollingInterval: TEST_POLL_MS,
          timerInterval: TEST_TIMER_MS,
        })
      );

      job.startJob('ontology-update-blocked');
      await advanceOnePoll();

      // The composable records the blocked status on the ref. `as JobStatus`
      // in the source lets non-enum strings leak through, which is exactly
      // what the consumer (ManageAnnotations.vue) needs to render the
      // "force apply" UI.
      expect(job.status.value).toBe('blocked' as typeof job.status.value);
      expect(job.step.value).toBe(
        'Critical ontology changes detected — force-apply required'
      );

      // CURRENT BEHAVIOR PIN: "blocked" is NOT in the terminal-state branch
      // (see useAsyncJob.ts — only 'completed'/'failed' call stopPolling()).
      // Polling therefore stays active and isLoading stays false (isLoading
      // only covers 'accepted' | 'running'). Phase E4 will likely tighten
      // this; this assertion exists to flag that change when it happens.
      expect(job.isPolling.value).toBe(true);
      expect(job.isLoading.value).toBe(false);
      // No error was surfaced — "blocked" is a workflow state, not a failure.
      expect(job.error.value).toBeNull();

      // Stop the polling loop by hand to avoid the afterEach restoring real
      // timers while a setInterval is still pending.
      job.stopPolling();
      expect(job.isPolling.value).toBe(false);

      app.unmount();
    });
  });

  // -------------------------------------------------------------------------
  // Lifecycle 3 — submit → poll → error
  // -------------------------------------------------------------------------

  describe('submit → poll → error', () => {
    it('surfaces an error and stops polling on 500 from the status endpoint', async () => {
      server.use(
        http.get('/api/jobs/:job_id/status', () => {
          return HttpResponse.json(
            { error: 'Job worker crashed' },
            { status: 500 }
          );
        })
      );

      const [job, app] = withSetup(() =>
        useAsyncJob(statusEndpoint, {
          pollingInterval: TEST_POLL_MS,
          timerInterval: TEST_TIMER_MS,
        })
      );

      job.startJob('crashing-job');
      expect(job.isPolling.value).toBe(true);

      await advanceOnePoll();

      // The catch block sets status → 'failed' and error → generic message
      // (the 500 body is not reachable via axios.isAxiosError's 404 branch).
      expect(job.status.value).toBe('failed');
      expect(job.error.value).toBe('Failed to check job status');
      expect(job.progressVariant.value).toBe('danger');
      expect(job.statusBadgeClass.value).toBe('bg-danger');
      expect(job.isPolling.value).toBe(false);
      expect(job.isLoading.value).toBe(false);

      app.unmount();
    });

    it('surfaces JOB_NOT_FOUND on a 404 response and stops polling', async () => {
      // useAsyncJob has a dedicated branch for plumber's JOB_NOT_FOUND shape
      // (see `if (data?.error === 'JOB_NOT_FOUND')` in the catch block). This
      // pins that behavior — E4 / E5 rewrites will rely on it.
      server.use(
        http.get('/api/jobs/:job_id/status', () => {
          return HttpResponse.json(
            { error: 'JOB_NOT_FOUND', message: 'Job not found or expired' },
            { status: 404 }
          );
        })
      );

      const [job, app] = withSetup(() =>
        useAsyncJob(statusEndpoint, {
          pollingInterval: TEST_POLL_MS,
          timerInterval: TEST_TIMER_MS,
        })
      );

      job.startJob('missing-job');
      await advanceOnePoll();

      expect(job.status.value).toBe('failed');
      expect(job.error.value).toBe('Job not found or expired');
      expect(job.isPolling.value).toBe(false);

      app.unmount();
    });

    it('also detects JOB_NOT_FOUND delivered as a 200 body shape', async () => {
      // The non-catch branch of checkJobStatus() also looks for
      // `data.error === 'JOB_NOT_FOUND'`. Both shapes need a pinning test
      // because E4 may refactor the dispatch logic.
      server.use(
        http.get('/api/jobs/:job_id/status', () => {
          return HttpResponse.json({
            error: 'JOB_NOT_FOUND',
            message: 'gone',
          });
        })
      );

      const [job, app] = withSetup(() =>
        useAsyncJob(statusEndpoint, {
          pollingInterval: TEST_POLL_MS,
          timerInterval: TEST_TIMER_MS,
        })
      );

      job.startJob('gone-job');
      await advanceOnePoll();

      expect(job.status.value).toBe('failed');
      expect(job.error.value).toBe('Job not found');
      expect(job.isPolling.value).toBe(false);

      app.unmount();
    });
  });

  // -------------------------------------------------------------------------
  // Integration with the B1 submit handlers
  // -------------------------------------------------------------------------

  describe('integration with Phase B1 submit handlers', () => {
    it('unwraps job_id from the hgnc_update submit response and polls it', async () => {
      // Exercises the full view-facing call sequence:
      //   POST /api/jobs/hgnc_update/submit  →  { job_id: ['hgnc-update-...'] }
      //   GET  /api/jobs/<that id>/status    →  mocked completed response
      //
      // R/Plumber wraps scalars as single-element arrays, so callers must
      // `unwrap` before passing to startJob() — see CLAUDE.md "R/Plumber
      // returns JSON scalars as arrays". The view does this via
      // Array.isArray ? [0] : value. We replicate here so the spec doubles as
      // living documentation.
      server.use(
        http.get('/api/jobs/:job_id/status', ({ params }) => {
          return HttpResponse.json({
            job_id: [String(params.job_id)],
            status: ['completed'],
            step: ['Done'],
            progress: { current: [1], total: [1] },
          });
        })
      );

      const submitResponse = await axios.post(
        '/api/jobs/hgnc_update/submit',
        {},
        { headers: { authorization: 'Bearer test-token' } }
      );
      const rawJobId = submitResponse.data.job_id;
      const unwrappedJobId = Array.isArray(rawJobId) ? rawJobId[0] : rawJobId;
      expect(unwrappedJobId).toBe('hgnc-update-2025-07-01');

      const [job, app] = withSetup(() =>
        useAsyncJob(statusEndpoint, {
          pollingInterval: TEST_POLL_MS,
          timerInterval: TEST_TIMER_MS,
        })
      );

      job.startJob(unwrappedJobId);
      await advanceOnePoll();

      expect(job.status.value).toBe('completed');
      expect(job.progressPercent.value).toBe(100);
      expect(job.isPolling.value).toBe(false);

      app.unmount();
    });
  });
});
