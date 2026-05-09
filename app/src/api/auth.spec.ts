// app/src/api/auth.spec.ts
//
// Vitest + MSW spec for the typed auth helpers. Phase E.E1 / v11.1 follow-up:
// covers the signup() helper that complements the existing
// authenticate / signin / refresh / changePassword surface in `auth.ts`.
//
// Wire shape and validation rules mirror
// `api/endpoints/authentication_endpoints.R` (`@post signup`).

import { describe, it, expect } from 'vitest';
import { http, HttpResponse } from 'msw';

import { signup, type SignupRequest } from './auth';
import { isApiError } from './client';
import { server } from '@/test-utils/mocks/server';

const validSignupBody: SignupRequest = {
  user_name: 'pwtestuser',
  email: 'pwtestuser@example.com',
  orcid: '0000-0000-0000-000X',
  first_name: 'PW',
  family_name: 'Test',
  comment: 'Vitest spec for the typed signup helper.',
  terms_agreed: 'accepted',
};

describe('api/auth — signup', () => {
  it('resolves on 200 and forwards the JSON body to /api/auth/signup', async () => {
    let receivedBody: unknown = null;
    let receivedPath: string | null = null;
    server.use(
      http.post('/api/auth/signup', async ({ request }) => {
        receivedPath = new URL(request.url).pathname;
        receivedBody = await request.json();
        return HttpResponse.json({ ok: true });
      })
    );

    await expect(signup(validSignupBody)).resolves.toBeUndefined();
    expect(receivedPath).toBe('/api/auth/signup');
    expect(receivedBody).toEqual(validSignupBody);
  });

  it('throws AxiosError on 400 (validation error)', async () => {
    server.use(
      http.post('/api/auth/signup', () =>
        HttpResponse.json({ error: 'Invalid signup payload.' }, { status: 400 })
      )
    );

    let caught: unknown;
    try {
      await signup({ ...validSignupBody, terms_agreed: 'not_accepted' });
    } catch (err) {
      caught = err;
    }

    expect(caught).toBeDefined();
    expect(isApiError(caught)).toBe(true);
    if (isApiError(caught)) {
      expect(caught.response?.status).toBe(400);
    }
  });
});
