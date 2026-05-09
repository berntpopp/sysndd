// app/src/composables/review/useReviewApprovalActions.spec.ts
/**
 * v11.0 closeout F2a spec (plan §13.2): proves the `authHeaders()` helper
 * on `useReviewApprovalActions` has been removed and every PUT/POST in the
 * file now relies on the `apiClient` request interceptor (`@/api/client`)
 * for its `Authorization: Bearer <token>` header.
 *
 * Each action accepts an `axiosClient` parameter so the view can pass its
 * `getAxios()` bridge (either the real singleton or a Vitest mock). When
 * we pass the real shared axios singleton, the F1 interceptor fires and
 * the outbound request picks up `useAuth().token.value`. That is what the
 * MSW resolver asserts via `expectBearerHeader`.
 */

import { afterEach, describe, expect, it } from 'vitest';
import { http, HttpResponse } from 'msw';
import axios from 'axios';

import '@/plugins/axios';
import '@/api/client'; // Ensure the request interceptor is installed.
import { server } from '@/test-utils/mocks/server';
import { primeAuth } from '@/test-utils/primeAuth';
import { expectBearerHeader } from '@/test-utils/expectBearerHeader';
import useAuth from '@/composables/useAuth';
import {
  approveReview,
  dismissReview,
  approveStatus,
  approveAllReviews,
} from './useReviewApprovalActions';

afterEach(() => {
  useAuth().logout();
});

describe('useReviewApprovalActions — F2a Bearer-via-interceptor', () => {
  it('approveReview PUT carries Bearer header injected by the interceptor', async () => {
    const { token } = primeAuth();
    server.use(
      http.put('*/api/review/approve/:id', ({ request, params }) => {
        expectBearerHeader(request, token);
        return HttpResponse.json({ review_id: params.id, review_approved: 1 });
      })
    );

    const response = await approveReview(axios, 101);
    expect(response.status).toBe(200);
  });

  it('dismissReview PUT carries Bearer header injected by the interceptor', async () => {
    const { token } = primeAuth('dismiss-token');
    server.use(
      http.put('*/api/review/approve/:id', ({ request }) => {
        expectBearerHeader(request, token);
        return HttpResponse.json({ ok: true });
      })
    );

    const response = await dismissReview(axios, 202);
    expect(response.status).toBe(200);
  });

  it('approveStatus PUT carries Bearer header injected by the interceptor', async () => {
    const { token } = primeAuth('status-token');
    server.use(
      http.put('*/api/status/approve/:id', ({ request }) => {
        expectBearerHeader(request, token);
        return HttpResponse.json({ ok: true });
      })
    );

    const response = await approveStatus(axios, 303);
    expect(response.status).toBe(200);
  });

  it('approveAllReviews PUT carries Bearer header injected by the interceptor', async () => {
    const { token } = primeAuth('bulk-token');
    server.use(
      http.put('*/api/review/approve/all', ({ request }) => {
        expectBearerHeader(request, token);
        return HttpResponse.json({ ok: true });
      })
    );

    const response = await approveAllReviews(axios);
    expect(response.status).toBe(200);
  });
});
