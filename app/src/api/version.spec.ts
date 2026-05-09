// app/src/api/version.spec.ts
//
// Vitest + MSW spec for the typed version helper (W3.24).

import { describe, it, expect } from 'vitest';
import { http, HttpResponse } from 'msw';

import { getVersion, type ApiVersion } from './version';
import { server } from '@/test-utils/mocks/server';

describe('api/version — getVersion', () => {
  it('returns the version envelope on 200', async () => {
    const expected: ApiVersion = {
      version: '0.11.14',
      commit: 'abcdef1',
      title: 'SysNDD API',
      description: 'Neurodevelopmental disorder gene-disease database',
    };
    server.use(http.get('/api/version', () => HttpResponse.json(expected)));

    const result = await getVersion();
    expect(result).toEqual(expected);
  });

  it('throws AxiosError on 500', async () => {
    server.use(
      http.get('/api/version', () => HttpResponse.json({ error: 'boom' }, { status: 500 }))
    );
    await expect(getVersion()).rejects.toThrow();
  });
});
