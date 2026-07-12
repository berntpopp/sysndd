// useAsyncJob — S5b request-ownership / poll-generation tests (#535).
//
// Split out of useAsyncJob.spec.ts to keep each spec under the 600-line ceiling.
// Covers poll generation + the shared-interval stopPolling guard: a stale poll
// tick from a superseded/cancelled job must not overwrite results, fail the new
// job, or fail to clear the interval.
//
// Same harness as useAsyncJob.spec.ts: fake ONLY the interval timers
// (`vi.useFakeTimers({ toFake: ['setInterval', 'clearInterval'] })`) so the
// microtask queue (axios / MSW / Vue reactivity) still runs on real promises,
// and drive the poll with `vi.advanceTimersByTimeAsync`.

import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { http, HttpResponse } from 'msw';
import { flushPromises } from '@vue/test-utils';

import { withSetup } from '@/test-utils';
import { server } from '@/test-utils/mocks/server';
import { primeAuth } from '@/test-utils/primeAuth';
import useAuth from '@/composables/useAuth';
import useAsyncJob from './useAsyncJob';

const SEEDED_TOKEN = 'test-token';
const statusEndpoint = (jobId: string) => `/api/jobs/${jobId}/status`;
const TEST_POLL_MS = 50;
const TEST_TIMER_MS = 10_000;

describe('useAsyncJob', () => {
  beforeEach(() => {
    // Fake only the interval timers; microtasks (promises / MSW / axios) stay real.
    vi.useFakeTimers({ toFake: ['setInterval', 'clearInterval'] });
    primeAuth(SEEDED_TOKEN);
  });

  afterEach(() => {
    vi.useRealTimers();
    useAuth().logout();
  });

  describe('request ownership (S5b): superseded / cancelled polls', () => {
    it('a stale poll from a superseded job does not overwrite the new job or stop its polling', async () => {
      let release!: () => void;
      const gate = new Promise<void>((r) => {
        release = r;
      });
      let entered!: () => void;
      const handlerEntered = new Promise<void>((r) => {
        entered = r;
      });
      server.use(
        http.get('/api/jobs/:job_id/status', async ({ params }) => {
          const id = String(params.job_id);
          if (id === 'j1') {
            entered();
            await gate; // hold j1's response open until the test releases it
            return HttpResponse.json({
              job_id: ['j1'],
              status: ['failed'],
              step: ['x'],
              error: ['j1 crashed'],
              progress: { current: [0], total: [0] },
            });
          }
          return HttpResponse.json({
            job_id: ['j2'],
            status: ['running'],
            step: ['go'],
            progress: { current: [1], total: [2] },
          });
        })
      );

      const [job, app] = withSetup(() =>
        useAsyncJob(statusEndpoint, { pollingInterval: TEST_POLL_MS, timerInterval: TEST_TIMER_MS })
      );

      job.startJob('j1');
      const advance = vi.advanceTimersByTimeAsync(TEST_POLL_MS); // do NOT await yet
      await handlerEntered; // j1's poll has reached the handler and is gated
      job.startJob('j2'); // supersede while j1 is in flight
      release(); // j1 now resolves (failed) — must be ignored
      await advance;
      await flushPromises();

      expect(job.jobId.value).toBe('j2');
      expect(job.status.value).not.toBe('failed'); // stale j1 did not fail j2
      expect(job.isPolling.value).toBe(true); // stale j1 did not stopPolling()

      job.stopPolling();
      app.unmount();
    });

    it('a stale poll REJECTION does not fail or stop the new job', async () => {
      let release!: () => void;
      const gate = new Promise<void>((r) => {
        release = r;
      });
      let entered!: () => void;
      const handlerEntered = new Promise<void>((r) => {
        entered = r;
      });
      server.use(
        http.get('/api/jobs/:job_id/status', async ({ params }) => {
          const id = String(params.job_id);
          if (id === 'j1') {
            entered();
            await gate;
            return HttpResponse.json({ error: 'boom' }, { status: 500 });
          }
          return HttpResponse.json({
            job_id: ['j2'],
            status: ['running'],
            step: ['go'],
            progress: { current: [0], total: [0] },
          });
        })
      );

      const [job, app] = withSetup(() =>
        useAsyncJob(statusEndpoint, { pollingInterval: TEST_POLL_MS, timerInterval: TEST_TIMER_MS })
      );

      job.startJob('j1');
      const advance = vi.advanceTimersByTimeAsync(TEST_POLL_MS);
      await handlerEntered;
      job.startJob('j2');
      release(); // j1 rejects (500) after supersede
      await advance;
      await flushPromises();

      expect(job.status.value).not.toBe('failed');
      expect(job.isPolling.value).toBe(true);

      job.stopPolling();
      app.unmount();
    });

    it('single-flights polls of the same job (no overlap while one is in flight)', async () => {
      let entered = 0;
      let release!: () => void;
      const gate = new Promise<void>((r) => {
        release = r;
      });
      server.use(
        http.get('/api/jobs/:job_id/status', async () => {
          entered += 1;
          await gate; // keep the first poll in flight across several ticks
          return HttpResponse.json({
            job_id: ['j'],
            status: ['running'],
            step: ['go'],
            progress: { current: [0], total: [0] },
          });
        })
      );

      const [job, app] = withSetup(() =>
        useAsyncJob(statusEndpoint, { pollingInterval: TEST_POLL_MS, timerInterval: TEST_TIMER_MS })
      );

      job.startJob('j');
      const advance = vi.advanceTimersByTimeAsync(TEST_POLL_MS * 4); // several ticks
      await flushPromises();
      // Only one poll may be in flight for this job generation despite 4 ticks.
      expect(entered).toBe(1);
      release();
      await advance;
      await flushPromises();

      job.stopPolling();
      app.unmount();
    });

    it('reset() invalidates an in-flight poll (its late response is ignored)', async () => {
      let release!: () => void;
      const gate = new Promise<void>((r) => {
        release = r;
      });
      let entered!: () => void;
      const handlerEntered = new Promise<void>((r) => {
        entered = r;
      });
      server.use(
        http.get('/api/jobs/:job_id/status', async () => {
          entered();
          await gate;
          return HttpResponse.json({
            job_id: ['j'],
            status: ['completed'],
            step: ['done'],
            progress: { current: [1], total: [1] },
          });
        })
      );

      const [job, app] = withSetup(() =>
        useAsyncJob(statusEndpoint, { pollingInterval: TEST_POLL_MS, timerInterval: TEST_TIMER_MS })
      );

      job.startJob('j');
      const advance = vi.advanceTimersByTimeAsync(TEST_POLL_MS);
      await handlerEntered;
      job.reset(); // invalidates the in-flight poll
      release();
      await advance;
      await flushPromises();

      expect(job.status.value).toBe('idle'); // stale 'completed' did not apply
      app.unmount();
    });
  });
});
