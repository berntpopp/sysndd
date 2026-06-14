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

  it('exposes the database version block when present (issue #22)', async () => {
    const expected: ApiVersion = {
      version: '0.20.18',
      commit: 'abcdef1',
      title: 'SysNDD API',
      description: 'desc',
      database: {
        version: '1.0.0',
        commit: '7532ab5',
        description: 'release note',
        updated_at: '2026-06-11 10:00:00',
        available: true,
      },
    };
    server.use(http.get('/api/version', () => HttpResponse.json(expected)));

    const result = await getVersion();
    expect(result.database?.version).toBe('1.0.0');
    expect(result.database?.commit).toBe('7532ab5');
    expect(result.database?.available).toBe(true);
  });

  it('tolerates a missing database block (older API)', async () => {
    server.use(
      http.get('/api/version', () =>
        HttpResponse.json({
          version: '0.11.14',
          commit: 'abcdef1',
          title: 'SysNDD API',
          description: 'desc',
        })
      )
    );

    const result = await getVersion();
    expect(result.database).toBeUndefined();
  });

  it('unwraps Plumber 1-element-array scalars (real /api/version shape)', async () => {
    // The live endpoint (@serializer json, no unboxedJSON) wraps every scalar
    // in a 1-element array. getVersion() must unwrap so the UI shows "0.22.0"
    // and the commit-badge guard (`!== 'unknown'`) works.
    server.use(
      http.get('/api/version', () =>
        HttpResponse.json({
          version: ['0.23.0'],
          commit: ['unknown'],
          title: ['SysNDD API'],
          description: ['desc'],
          database: {
            version: ['1.0.0'],
            commit: ['unknown'],
            description: ['Initial tracked SysNDD database version (issue #22).'],
            updated_at: ['2026-06-11 16:23:27'],
            available: [true],
          },
        })
      )
    );

    const result = await getVersion();
    expect(result.version).toBe('0.23.0');
    expect(result.commit).toBe('unknown');
    expect(result.title).toBe('SysNDD API');
    expect(result.database?.version).toBe('1.0.0');
    expect(result.database?.commit).toBe('unknown');
    expect(result.database?.available).toBe(true);
  });

  it('throws AxiosError on 500', async () => {
    server.use(
      http.get('/api/version', () => HttpResponse.json({ error: 'boom' }, { status: 500 }))
    );
    await expect(getVersion()).rejects.toThrow();
  });
});
