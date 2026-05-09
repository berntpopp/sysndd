// app/src/api/hash.spec.ts
//
// Vitest + MSW spec for the typed hash helpers (W3.7).

import { describe, it, expect } from 'vitest';
import { http, HttpResponse } from 'msw';

import { createHash, type HashLink } from './hash';
import { server } from '@/test-utils/mocks/server';

describe('api/hash — createHash', () => {
  it('POSTs the body and returns the hash link', async () => {
    let receivedBody: unknown = null;
    const expected: HashLink = { hash: 'abcdef123', endpoint: '/api/gene' };
    server.use(
      http.post('/api/hash/create', async ({ request }) => {
        receivedBody = await request.json();
        return HttpResponse.json(expected);
      })
    );

    const result = await createHash({
      json_data: ['HGNC:4586', 'HGNC:1100'],
      endpoint: '/api/gene',
    });

    expect(receivedBody).toEqual({
      json_data: ['HGNC:4586', 'HGNC:1100'],
      endpoint: '/api/gene',
    });
    expect(result.hash).toBe('abcdef123');
  });

  it('unwraps a 1-element-array scalar wrapper from R/Plumber', async () => {
    server.use(
      http.post('/api/hash/create', () =>
        // R/Plumber 1-element-array wrapping when @serializer unboxedJSON is omitted.
        HttpResponse.json([{ hash: 'wrapped123', endpoint: '/api/gene' }])
      )
    );

    const result = await createHash({ json_data: ['x'] });
    expect(result.hash).toBe('wrapped123');
  });

  it('throws AxiosError on 400 (missing json_data)', async () => {
    server.use(
      http.post('/api/hash/create', () =>
        HttpResponse.json(
          { error: "Required 'json_data' parameter not provided." },
          { status: 400 }
        )
      )
    );
    await expect(createHash({ json_data: null })).rejects.toThrow();
  });
});
