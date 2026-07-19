// app/src/utils/safe-url.ts
//
// Guards a bound `:href` against scheme injection (#573 Slice B, Codex round-1
// review, HIGH). Vue does not sanitize `javascript:`/`data:`/etc. schemes on a
// bound `:href` — if any admin-authored or upstream string ever reaches a
// public anchor's `href` unvalidated (e.g. `zenodo.record_url`, recorded via
// `PATCH /api/admin/analysis/releases/<id>/doi` with no URL validation on the
// backend), an unauthenticated visitor gets a clickable script URL.

/**
 * Return the URL only if it parses as an http(s) URL; otherwise null.
 * Guards against javascript:/data:/etc. scheme injection in bound hrefs.
 */
export function safeHttpUrl(value: unknown): string | null {
  if (typeof value !== 'string' || value.trim() === '') return null;
  try {
    const u = new URL(value, window.location.origin);
    return u.protocol === 'http:' || u.protocol === 'https:' ? value : null;
  } catch {
    return null;
  }
}
