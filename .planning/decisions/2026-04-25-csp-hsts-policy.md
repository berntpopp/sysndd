# ADR: CSP and HSTS Policy for SysNDD

**Date:** 2026-04-25
**Status:** Accepted
**Closes:** #299, #300

## Context

The 2026-04-23 codebase review (`.planning/reviews/2026-04-23-codebase-review.md`) flagged two unresolved security-headers governance items:

- #299: tighten CSP — drop `'unsafe-eval'`; remove or hash `'unsafe-inline'`
- #300: confirm or back down HSTS preload + includeSubDomains (already shipped, one-way door)

This ADR records the resulting policy stance.

## Decision: HSTS

We retain the directive currently shipped by `app/docker/nginx/security-headers.conf`:

```
Strict-Transport-Security: max-age=63072000; includeSubDomains; preload
```

This is a one-way door:

- Browsers cache HSTS for `max-age` (2 years).
- `includeSubDomains` prevents cookie-stripping attacks via sibling subdomains.
- `preload` requests inclusion in the [HSTS preload list](https://hstspreload.org/) shipped with browsers; once accepted, even fresh installs of the browser refuse plaintext for the apex domain.

### Operational caveats

- Adding a new subdomain that needs HTTPS is fine; adding one that does NOT serve TLS will break.
- Removing `preload` from the directive does NOT remove the domain from the preload list; that requires a manual delisting request.
- We have NOT submitted the apex domain to the preload list yet (the directive is the precondition; submission is operator action). Document the submission decision separately.

### Sub-domain inventory at policy-acceptance time

This section is a stub. The repo does not contain a definitive list of sub-domains served from the apex (`sysndd.dbmr.unibe.ch` and any related operator-managed hostnames). Before the apex domain is submitted to the HSTS preload list, the operator must enumerate every active sub-domain and confirm each serves valid TLS — `includeSubDomains` will break any plaintext sibling. This enumeration cannot be derived from the repository alone; it requires DNS / hosting inventory that lives outside the codebase.

If any non-TLS sub-domain exists (or is planned), the directive must be relaxed before submission to the preload list. The directive itself remains as-is; submission is a separate, deferred operator decision.

## Decision: CSP

The CSP directive in `app/docker/nginx/security-headers.conf` is governed by the audit script `app/scripts/audit-csp-violations.mjs` (run after `npm run build`).

### `script-src 'unsafe-inline'`

Replaced by build-time `'sha256-...'` hashes. The current build emits exactly one inline `<script>` (the Schema.org JSON-LD block in `app/index.html`); its hash is pinned in the directive. The audit script reports any drift after the next build.

Rationale: SEO crawlers expect the JSON-LD inline (so externalising it has SEO cost), and the payload is build-time-stable, so a hash is meaningful and cheap to maintain.

### `script-src 'unsafe-eval'`

Retained. The audit found 5 eval-like calls in vendor JS chunks that are runtime-reachable:

- Vue 3 runtime template compiler (`new Function("Vue", code)` emitted by `vue.esm-bundler.js`; reached via CMS-driven template rendering in `src/views/admin/ManageAbout.vue`)
- NGL viewer (`assets/ngl-*.js`) uses `new Function()` to construct Web Worker bodies for off-main-thread MD/PDB parsing
- markdown-it / DOMPurify path (`assets/useMarkdownRenderer-*.js`) emits `new Function()` in specific transforms

None are own-code. Removing `'unsafe-eval'` would break the 3D structure viewer and the admin CMS preview without alternative implementations. Replacing the offending vendors is a separate scoping decision (large surface; molecular viewer in particular has no drop-in CSP-friendly replacement). We accept the residual risk for now and revisit if a future incident calls for it.

Follow-up: a future PR can replace NGL with a CSP-friendly viewer and migrate `ManageAbout.vue`'s CMS template rendering off the runtime template compiler. Track in a new issue when scoped.

### `style-src 'unsafe-inline'`

Retained. Bootstrap-Vue-Next, NGL, and our d3 / cytoscape rendering paths emit inline `style=""` attributes that CSP cannot hash (only inline `<style>` blocks are hashable). Removing this directive would require either:

- A wholesale refactor of components emitting inline styles (high cost, low security gain — inline `style="background:red"` is not the dangerous form of inline content), or
- A nonce-based CSP regenerated per request, which the static-asset nginx layer is not set up to provide.

We accept inline-style risk and document the trade-off here.

### CSP hashing maintenance

`app/scripts/audit-csp-violations.mjs` is the source of truth for the script-src hashes. Hashes change when:

- The Vite-injected inline boot script changes (Vite minor/major upgrades, current build does not have one).
- The Schema.org JSON-LD block in `app/index.html` is edited.
- Any other inline `<script>` is added (today: don't).

Process after a relevant change:

1. `cd app && npm install ...` (apply the upgrade or edit).
2. `cd app && npm run build`.
3. `node app/scripts/audit-csp-violations.mjs --build app/dist`.
4. Update the `script-src 'sha256-...'` list in `app/docker/nginx/security-headers.conf`.
5. CI's Playwright `security-headers.spec.ts` will detect drift if a hash is forgotten (it red-lines on `'unsafe-inline'` reappearing in script-src).

The Playwright spec also serves as the contract anchor: any future loosening of script-src or removal of HSTS shape directives must red-line that spec before merge.

## Consequences

- Stronger XSS posture: an attacker injecting JS via DOM cannot run unhashed inline scripts.
- New maintenance task on Vite upgrades (process above).
- `'unsafe-eval'` and `style-src 'unsafe-inline'` remain documented acceptable trade-offs.
- HSTS directive is a one-way decision; removing or weakening it requires manual operator action (preload-list delisting + `max-age` decay window).

## Alternatives considered

- **Drop `'unsafe-eval'` immediately by replacing offending vendors.** Rejected for this PR. NGL has no drop-in CSP-friendly replacement; Vue runtime template compiler usage in CMS rendering can be replaced by precompiled templates (large refactor, separate scoping). A follow-up issue should track this.
- **Nonce-based CSP** for both script and style. Rejected: nginx-served static assets cannot rotate nonces per request without templating; switching to a Node SSR layer would be a much larger architectural change.
- **Externalising every inline script** (Vite plugin to remove inline boot script). Considered as Option B in the implementation plan; the audit found one inline script (the Schema.org JSON-LD block in `app/index.html`) so hashing was lighter weight and preserved SEO crawler expectations.

## References

- Audit script: `app/scripts/audit-csp-violations.mjs`
- nginx directive: `app/docker/nginx/security-headers.conf`
- Playwright regression spec: `app/tests/e2e/security-headers.spec.ts`
- Plan: `.planning/superpowers/plans/2026-04-25-v11.1-wave-1a-w1-security.md`
- Implementation spec: `.planning/superpowers/specs/2026-04-25-v11.1-finish-hardening-design.md` (W1)
- HSTS preload list: <https://hstspreload.org/>
