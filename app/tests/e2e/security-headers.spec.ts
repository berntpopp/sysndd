// app/tests/e2e/security-headers.spec.ts
//
// Asserts the response-header shape on the SPA root and on a representative
// API response. The CSP/HSTS policy is captured in the ADR
// .planning/decisions/2026-04-25-csp-hsts-policy.md; this spec is the
// regression net for that policy.
//
// HSTS is intentionally one-way (preload + includeSubDomains; max-age 2y).
// The presence assertions below are the policy's enforcement gate — if a
// future change loosens HSTS, this spec must red-line it before merge.
import { test, expect } from '@playwright/test';

test.describe('security: response headers', () => {
  test('home page has the required security headers', async ({ request }) => {
    const res = await request.get('/');
    expect(res.status()).toBeLessThan(500);
    const headers = res.headers();

    // HSTS — preload+includeSubDomains policy is locked (one-way door)
    expect(headers['strict-transport-security']).toMatch(/max-age=\d+/);
    expect(headers['strict-transport-security']).toMatch(/includeSubDomains/i);
    expect(headers['strict-transport-security']).toMatch(/preload/i);

    // CSP — must declare default-src and restrict framing; must NOT contain
    // 'unsafe-inline' for script-src (replaced by sha256 hashes per the ADR).
    // 'unsafe-eval' is intentionally retained for vendor JS (NGL Web Workers,
    // Vue runtime template compiler, markdown-it) — see security-headers.conf
    // and the ADR for the rationale. If a future change drops 'unsafe-eval'
    // this assertion can be tightened to forbid it.
    const csp = headers['content-security-policy'] ?? '';
    expect(csp, 'CSP must declare default-src').toMatch(/default-src/);
    expect(csp, 'CSP must allow self-hosted app fonts').toMatch(/font-src[^;]*'self'/);
    expect(csp, 'CSP must restrict frame-ancestors or X-Frame-Options must be DENY').toMatch(
      /frame-ancestors|frame-src/
    );
    // script-src must not allow ad-hoc inline scripts; only hashed inline blocks.
    const scriptSrcMatch = csp.match(/script-src ([^;]+);/);
    expect(scriptSrcMatch, 'CSP must declare script-src').not.toBeNull();
    const scriptSrc = scriptSrcMatch?.[1] ?? '';
    expect(scriptSrc, "script-src must not allow 'unsafe-inline'").not.toMatch(/'unsafe-inline'/);
    // At least one sha256 hash is expected (the JSON-LD inline block in index.html)
    expect(scriptSrc, 'script-src must carry at least one sha256 hash').toMatch(/'sha256-/);

    // Other headers — exact presence, not exact value
    expect(headers['x-content-type-options']).toBe('nosniff');
    expect(headers['referrer-policy']).toBeDefined();
    // Either X-Frame-Options OR a CSP frame-ancestors directive must be present
    const xfo = headers['x-frame-options'];
    if (!xfo) {
      expect(csp, 'CSP must contain frame-ancestors when X-Frame-Options is absent').toMatch(
        /frame-ancestors/
      );
    } else {
      expect(xfo).toMatch(/DENY|SAMEORIGIN/i);
    }
  });

  test('an API response carries baseline headers when present', async ({ request }) => {
    // /api/health/ responds whether the caller is authenticated or not (401
    // for the unauthenticated case). Either way, the response is a real
    // request through traefik to the API container — the perfect target for
    // observing the headers traefik applies (or doesn't).
    const res = await request.get('/api/health/');
    expect([200, 401]).toContain(res.status());
    const headers = res.headers();

    // API responses are proxied through traefik. Today, traefik does not add
    // HSTS or X-Content-Type-Options to API responses; the SPA-side nginx
    // is the source of truth for those. If a future change adds HSTS to the
    // API path, the assertion below ensures it stays well-formed.
    if (headers['strict-transport-security']) {
      expect(headers['strict-transport-security']).toMatch(/max-age=\d+/);
    }
    if (headers['x-content-type-options']) {
      expect(headers['x-content-type-options']).toBe('nosniff');
    }
  });
});
