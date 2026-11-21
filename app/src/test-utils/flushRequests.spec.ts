// app/src/test-utils/flushRequests.spec.ts
import { describe, expect, it } from 'vitest';
import { delay, http, HttpResponse } from 'msw';
import { server } from './mocks/server';
import { flushRequests } from './flushRequests';

describe('flushRequests', () => {
  it('waits for a slow mocked response and the request it triggers', async () => {
    const seen: string[] = [];
    server.use(
      http.get('http://localhost/api/flush-probe/first', async () => {
        await delay(60);
        return HttpResponse.json({ next: 'second' });
      }),
      http.get('http://localhost/api/flush-probe/second', async () => {
        await delay(60);
        return HttpResponse.json({ ok: true });
      })
    );

    void fetch('http://localhost/api/flush-probe/first')
      .then((r) => r.json())
      .then((body: { next: string }) => {
        seen.push('first');
        return fetch(`http://localhost/api/flush-probe/${body.next}`);
      })
      .then(() => seen.push('second'));

    await flushRequests();

    expect(seen).toEqual(['first', 'second']);
  });
});
