// app/src/test-utils/expectBearerHeader.ts
/**
 * MSW resolver helper for v11.0 closeout F2 worktrees.
 *
 * Assert the incoming request carries `Authorization: Bearer <expected>`.
 * Throws a clear error with the actual header value if mismatched — which
 * causes the MSW resolver to surface the failure to the test. Used inside
 * resolvers:
 *
 *   http.get('/api/x', ({ request }) => {
 *     expectBearerHeader(request, 'test-token');
 *     return HttpResponse.json({ ok: true });
 *   })
 */

export function expectBearerHeader(
  request: Request,
  expectedToken: string,
): void {
  const actual = request.headers.get('authorization');
  const expected = `Bearer ${expectedToken}`;
  if (actual !== expected) {
    throw new Error(
      `expectBearerHeader: expected "${expected}", got "${actual ?? '<missing>'}"`,
    );
  }
}
