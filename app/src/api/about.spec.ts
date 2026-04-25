// app/src/api/about.spec.ts
//
// Vitest + MSW spec for the typed about helpers (W3.1).
// Covers happy-path and non-2xx throw behaviour for each helper.

import { describe, it, expect } from 'vitest';
import { http, HttpResponse } from 'msw';

import {
  getAboutDraft,
  saveAboutDraft,
  publishAbout,
  getPublishedAbout,
  type AboutSection,
  type AboutMutationResponse,
} from './about';
import { isApiError } from './client';
import { server } from '@/test-utils/mocks/server';

const sampleSections: AboutSection[] = [
  { title: 'Welcome', body: 'About SysNDD' },
  { title: 'Methods', body: 'A short methodological note.' },
];

describe('api/about — getAboutDraft', () => {
  it('returns the draft sections array on 200', async () => {
    server.use(
      http.get('/api/about/draft', () => HttpResponse.json(sampleSections)),
    );
    const sections = await getAboutDraft();
    expect(sections).toEqual(sampleSections);
  });

  it('throws AxiosError on 403 (caller is not an Administrator)', async () => {
    server.use(
      http.get('/api/about/draft', () =>
        HttpResponse.json({ error: 'forbidden' }, { status: 403 }),
      ),
    );
    let caught: unknown;
    try {
      await getAboutDraft();
    } catch (err) {
      caught = err;
    }
    expect(isApiError(caught)).toBe(true);
    if (isApiError(caught)) {
      expect(caught.response?.status).toBe(403);
    }
  });
});

describe('api/about — saveAboutDraft', () => {
  it('PUTs the sections array and returns the mutation envelope', async () => {
    let receivedBody: unknown = null;
    server.use(
      http.put('/api/about/draft', async ({ request }) => {
        receivedBody = await request.json();
        const ok: AboutMutationResponse = { message: 'Draft saved successfully' };
        return HttpResponse.json(ok);
      }),
    );

    const result = await saveAboutDraft(sampleSections);
    expect(receivedBody).toEqual({ sections: sampleSections });
    expect(result.message).toBe('Draft saved successfully');
  });

  it('throws AxiosError on 400 (empty sections)', async () => {
    server.use(
      http.put('/api/about/draft', () =>
        HttpResponse.json({ error: 'Sections array cannot be empty' }, { status: 400 }),
      ),
    );
    await expect(saveAboutDraft([])).rejects.toThrow();
  });
});

describe('api/about — publishAbout', () => {
  it('POSTs the sections and returns the new version', async () => {
    let receivedBody: unknown = null;
    server.use(
      http.post('/api/about/publish', async ({ request }) => {
        receivedBody = await request.json();
        const ok: AboutMutationResponse = {
          message: 'Content published successfully',
          version: 7,
        };
        return HttpResponse.json(ok);
      }),
    );

    const result = await publishAbout(sampleSections);
    expect(receivedBody).toEqual({ sections: sampleSections });
    expect(result.version).toBe(7);
    expect(result.message).toBe('Content published successfully');
  });

  it('throws AxiosError on 500', async () => {
    server.use(
      http.post('/api/about/publish', () =>
        HttpResponse.json({ error: 'boom' }, { status: 500 }),
      ),
    );
    await expect(publishAbout(sampleSections)).rejects.toThrow();
  });
});

describe('api/about — getPublishedAbout', () => {
  it('returns the latest published sections on 200', async () => {
    server.use(
      http.get('/api/about/published', () => HttpResponse.json(sampleSections)),
    );
    const sections = await getPublishedAbout();
    expect(sections).toEqual(sampleSections);
  });

  it('returns an empty array when no content has been published', async () => {
    server.use(
      http.get('/api/about/published', () => HttpResponse.json([])),
    );
    const sections = await getPublishedAbout();
    expect(sections).toEqual([]);
  });

  it('throws AxiosError on 500', async () => {
    server.use(
      http.get('/api/about/published', () =>
        HttpResponse.json({ error: 'boom' }, { status: 500 }),
      ),
    );
    await expect(getPublishedAbout()).rejects.toThrow();
  });
});
