# v11.0 Closeout — Strict E7 + Coverage Reconciliation + Checkpoint #3

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans`. Each worktree executes as its own subagent and must follow `superpowers:test-driven-development` (rigid) for the §5 loop. Steps use checkbox (`- [ ]`) syntax for tracking.

**Spec reference:** `docs/superpowers/specs/2026-04-14-v11.0-closeout-design.md` (committed `f571a226`).

**Goal:** Ship v11.0 cleanly. Strict E7 closure (no direct `localStorage` token/user reads outside `useAuth.ts` + `plugins/axios.ts`); every authenticated app-session request routes through the `apiClient` interceptor; coverage ratchet reconciled with post-migration measured floor; Checkpoint #3 signed off; v11.0-exit PR merged.

**Architecture:** Three waves, seven worktrees. Wave 1 serial (F1 establishes target + guardrails). Wave 2 five worktrees parallel (F2a–F2e migrate all 24 files + document 2 enumerated exceptions). Wave 3 serial (F3 walks the exit gate + ships v11.0).

**Tech Stack:** Vue 3 Composition API + `<script setup lang="ts">` + Vite + Pinia + Vitest + `@vue/test-utils` + MSW.

**Locked decisions (spec §3.4, §7 — do not re-open):**
- **Two enumerated exceptions only.** `LoginView.signinWithJWT` (bootstrap) and `PasswordResetView.doPasswordChange` (route-token). No other inline `Authorization: Bearer` construction is allowed. Additions require plan amendment, not a PR.
- **No `authHeader()` helper on `useAuth`.** F1 explicitly rejects adding it. The migration target is `apiClient`, not a helper that hands out raw Bearer strings.
- **Pinia migration deferred to v11.1.** `useAuth.ts` stays a module-level composable. Candidate v11.1 exit criterion.
- **Per-resource `api/*.ts` fill-out deferred to v11.1.** F2 call sites go through `apiClient` directly, not through per-resource modules.

---

## 1 — Prerequisites check

Before opening this phase, confirm:

- [ ] Phase E is **done** per its own gate:
  ```bash
  git branch --list 'v11.0/phase-e/*' | wc -l              # must be 0
  git ls-remote --heads origin 'v11.0/phase-e/*' | wc -l   # must be 0
  ```
- [ ] `make ci-local` green on clean `master`.
- [ ] PRs #262, #263, #264, #265, #266 all merged (Phase E combined PRs).
- [ ] `app/src/api/client.ts` exists on `master` (E1 delivery).
- [ ] `app/src/composables/useAuth.ts` exists on `master` (E7 delivery).
- [ ] `app/tsconfig.composables-auth.json` exists (E2 delivery) — F1's useAuth updates go through the strict type-check.
- [ ] No `v11.0/closeout/*` branches exist locally or remotely.
- [ ] Coverage actuals measured and recorded: ~15% lines. This is the baseline that F1–F2 will lift; F3 pins the post-migration floor.

If any check fails, stop and escalate.

---

## 2 — Worktree manifest

All 7 worktrees branch off current `master` via `make worktree-setup NAME=closeout/<unit>`.

| # | Branch | Worktree path | Exclusive write ownership | Merge order |
|---|---|---|---|---|
| F1 | `v11.0/closeout/auth-infra` | `worktrees/closeout/auth-infra` | `app/src/composables/useAuth.ts`, `app/src/composables/useAuth.spec.ts`, `app/src/plugins/axios.ts`, `app/src/api/client.ts`, `app/src/test-utils/primeAuth.ts` (new), `app/src/test-utils/expectBearerHeader.ts` (new), `app/eslint.config.js` (or flat-config equivalent), `app/vitest.config.ts` (TODO comment only; numbers unchanged) | **Merges first** |
| F2a | `v11.0/closeout/migrate-tier-1` | `worktrees/closeout/migrate-tier-1` | 13 files + coordinated `useLlmAdmin` API change (see §3 F2a) | Parallel after F1 |
| F2b | `v11.0/closeout/migrate-tier-2` | `worktrees/closeout/migrate-tier-2` | 9 files (§3 F2b) | Parallel after F1 |
| F2c | `v11.0/closeout/migrate-review-view` | `worktrees/closeout/migrate-review-view` | `views/review/Review.vue` + spec enhancement | Parallel after F1 |
| F2d | `v11.0/closeout/migrate-manage-rereview` | `worktrees/closeout/migrate-manage-rereview` | `views/curate/ManageReReview.vue` + new spec | Parallel after F1 |
| F2e | `v11.0/closeout/document-exceptions` | `worktrees/closeout/document-exceptions` | `views/LoginView.vue`, `views/PasswordResetView.vue` + 2 new specs | Parallel after F1 |
| F3 | `v11.0/closeout/exit-pr` | `worktrees/closeout/exit-pr` | `app/vitest.config.ts` (ratchet bump), `docs/superpowers/specs/2026-04-11-v11.0-test-foundation-design.md` (amendments), v11.0-exit PR body | **Merges last** |

**Intra-phase ownership rule (§2.4 parent spec):**
- **F1 merges first** — all F2 worktrees consume F1's test-utils helpers and ESLint rule.
- **`app/src/api/client.ts`, `app/src/composables/useAuth.ts`, `app/src/plugins/axios.ts`** — F1 owns writes; F2a–F2e are read-only against these files.
- **`app/src/test-utils/primeAuth.ts`, `app/src/test-utils/expectBearerHeader.ts`** — F1 owns creation; F2 imports only.
- **F2a's `useLlmAdmin.ts` API change is an atomic unit** with consumers `ManageLLM.vue`, `LlmCacheManager.vue`, `LlmLogViewer.vue`. These four files move in the SAME PR; splitting them would break type-check mid-stack.
- **ManageReReview.vue is F2d's** — F2b does not touch it, even though it also lives under `views/curate/`.
- **F3 merges last** — dispatched only after all five F2 PRs are on `master`.

---

## 3 — Per-worktree task spec

### F1 — `auth-infra` (merges first; blocks all F2 worktrees)

- [ ] **Goal (spec §4.1):** Establish the migration target and guardrails. Make `apiClient` the single injection point for Bearer headers on authenticated app-session requests; remove `axios.defaults.headers.common.Authorization` mutations; remove the init-time `localStorage.getItem('token')` side-effect in `plugins/axios.ts`; add ESLint `no-restricted-syntax` rule; create test-utils helpers.

- [ ] **File ownership (writes):**
  - Modify: `app/src/composables/useAuth.ts` — remove three `axios.defaults.headers.common.Authorization = ...` mutations (current `master` lines **213**, **283**, **335**) and the `delete axios.defaults.headers.common.Authorization` in `logout()` (around line **297**). `useAuth` continues to own the reactive refs and `localStorage` persistence; the `apiClient` interceptor (`api/client.ts`) is now the only code that reads the token for outbound requests.
  - Modify: `app/src/plugins/axios.ts` — remove the init-time side-effect at lines **8–10** (`const token = localStorage.getItem('token'); if (token) { axios.defaults.headers.common.Authorization = ... }`). Keep the 401 interceptor's `localStorage.removeItem('token')` / `.removeItem('user')` at lines **24–25** — those writes are this file's owned responsibility per spec §2 goal 1.
  - Modify: `app/src/api/client.ts` — confirm the request interceptor reads `useAuth().token.value` (NOT `localStorage.getItem('token')`). If it currently reads localStorage, flip it to read from `useAuth()`. Verify per-request `config.headers.Authorization` overrides still merge correctly (axios behavior — defaults + per-call merge) so the §3.4 enumerated exceptions can override per-call.
  - Modify: `app/src/composables/useAuth.spec.ts` — drop assertions against `axios.defaults.headers.common` (lines **138, 211, 259, 277, 397, 452**); replace with assertions that an `apiClient.get()` call after `login()` carries the correct `Authorization` header (MSW-stubbed outbound) and carries no header after `logout()`.
  - Create: `app/src/test-utils/primeAuth.ts` — shared helper. Calls `useAuth().login(token, user)`. Returns the seeded token + user for assertions.
  - Create: `app/src/test-utils/expectBearerHeader.ts` — MSW handler helper. Given an MSW request, asserts `request.headers.get('authorization') === 'Bearer <expected>'`.
  - Modify: `app/eslint.config.js` (or the project's ESLint flat config file — identify the exact filename in Step 1) — add `no-restricted-syntax` rule from spec §8.1.
  - Modify: `app/vitest.config.ts` — add TODO comment above the `thresholds` block noting F3 will pin the closeout-reconciled floor. Numbers NOT changed in F1.

- [ ] **Acceptance:**
  - `cd app && npm run test:unit` green. `useAuth.spec.ts` covers the new interceptor-wired behavior.
  - `cd app && npm run type-check && npm run type-check:strict` green.
  - `cd app && npm run lint` green. ESLint rule fires on any regression (manually verify with a throwaway test fixture, then delete it).
  - `grep -rn "axios\.defaults\.headers\.common\.Authorization" app/src/` returns 0 matches.
  - `grep -n "localStorage\.getItem('token')" app/src/plugins/axios.ts` returns 0 matches.
  - `make ci-local` green.

- [ ] **TDD loop (§5.3 variant — F1 is infra, no it.todo):**
  ```
  1. make worktree-setup NAME=closeout/auth-infra
  2. cd worktrees/closeout/auth-infra
  3. make install-dev
  4. make doctor
  5. Identify the ESLint config filename (likely eslint.config.js for flat config,
     or .eslintrc.cjs — run: ls app/*.eslint* app/eslint.config.*).
  6. Write failing assertions in useAuth.spec.ts that expect an MSW-stubbed
     apiClient.get() to carry Authorization: Bearer <token> AFTER login() is called
     (not via axios.defaults, which we are about to remove). RED.
  7. Remove the axios.defaults mutations in useAuth.ts. RED still — apiClient
     interceptor must now be the source.
  8. Update api/client.ts interceptor to read useAuth().token.value. GREEN.
  9. Remove the init-time side-effect in plugins/axios.ts. Run useAuth.spec.ts
     — GREEN.
  10. Add test-utils/primeAuth.ts + test-utils/expectBearerHeader.ts (F2 helpers).
  11. Add ESLint no-restricted-syntax rule (spec §8.1) with overrides for
      useAuth.ts, plugins/axios.ts, test-utils/**, *.spec.ts.
  12. Add vitest.config.ts TODO comment.
  13. cd app && npm run lint && npm run type-check:strict && npm run test:unit
  14. make ci-local
  15. Open PR via superpowers:requesting-code-review.
  ```

- [ ] **Step 1: Identify the ESLint config file**

  Run:
  ```bash
  ls app/eslint.config.* app/.eslintrc.* 2>/dev/null
  ```
  Expected: exactly one file exists. Note it; all ESLint edits in this task use that path.

- [ ] **Step 2: Write failing spec — apiClient carries Authorization after login**

  Edit `app/src/composables/useAuth.spec.ts`. After the existing "stores token + user" test in the login block, add:

  ```typescript
  import { setupServer } from 'msw/node';
  import { http, HttpResponse } from 'msw';
  import { apiClient } from '@/api/client';

  const server = setupServer();
  beforeAll(() => server.listen({ onUnhandledRequest: 'error' }));
  afterEach(() => server.resetHandlers());
  afterAll(() => server.close());

  it('apiClient carries Authorization: Bearer <token> after login()', async () => {
    const auth = useAuth();
    let capturedAuth: string | null = null;
    server.use(
      http.get('*/api/ping', ({ request }) => {
        capturedAuth = request.headers.get('authorization');
        return HttpResponse.json({ ok: true });
      })
    );
    auth.login(FRESH_TOKEN, buildUserPayload({ exp: nowSec() + 3600 }));
    await apiClient.get('/api/ping');
    expect(capturedAuth).toBe(`Bearer ${FRESH_TOKEN}`);
  });

  it('apiClient carries no Authorization after logout()', async () => {
    const auth = useAuth();
    auth.login(FRESH_TOKEN, buildUserPayload({ exp: nowSec() + 3600 }));
    auth.logout();
    let capturedAuth: string | null = 'UNSET';
    server.use(
      http.get('*/api/ping', ({ request }) => {
        capturedAuth = request.headers.get('authorization');
        return HttpResponse.json({ ok: true });
      })
    );
    await apiClient.get('/api/ping');
    expect(capturedAuth).toBeNull();
  });
  ```

- [ ] **Step 3: Run spec — expect RED on the new tests**

  ```bash
  cd app && npx vitest run src/composables/useAuth.spec.ts
  ```
  Expected: The two new tests FAIL (either `apiClient` doesn't exist yet in the expected shape, or the interceptor still reads `localStorage` and passes for the wrong reason).

- [ ] **Step 4: Remove axios.defaults mutations in useAuth.ts**

  Edit `app/src/composables/useAuth.ts`. Delete these four mutations:
  - Line **213** inside `syncFromStorage()`: the `if (tokenRef.value) { axios.defaults.headers.common.Authorization = ... } else { delete axios.defaults.headers.common.Authorization }` block.
  - Line **283** inside `login()`: `axios.defaults.headers.common.Authorization = \`Bearer ${token}\`;`.
  - Line **297** inside `logout()`: `delete axios.defaults.headers.common.Authorization;`.
  - Line **335** inside `refresh()`: `axios.defaults.headers.common.Authorization = \`Bearer ${nextToken}\`;`.

  Also remove the now-unused `import axios from 'axios';` at the top if no other code in the file still uses it (grep the file first).

- [ ] **Step 5: Update api/client.ts interceptor to read useAuth()**

  Open `app/src/api/client.ts`. Confirm/change the request interceptor so the token source is `useAuth().token.value` (via an import that does NOT create a module cycle — `useAuth` imports nothing from `api/client`, so the one-way dependency is safe).

  If `client.ts` currently reads `localStorage.getItem('token')` in its interceptor, replace with:
  ```typescript
  import { useAuth } from '@/composables/useAuth';
  // ...
  apiClient.interceptors.request.use((config) => {
    const auth = useAuth();
    const token = auth.token.value;
    if (token) {
      config.headers = config.headers ?? {};
      (config.headers as Record<string, string>).Authorization = `Bearer ${token}`;
    }
    return config;
  });
  ```

- [ ] **Step 6: Remove init-time side-effect in plugins/axios.ts**

  Edit `app/src/plugins/axios.ts`. Delete lines **8–10**:
  ```typescript
  const token = localStorage.getItem('token');
  if (token) {
    axios.defaults.headers.common.Authorization = `Bearer ${token}`;
  }
  ```

  Keep the 401 interceptor intact (lines 24–25 localStorage clearing stays — that is this file's legitimate owned responsibility).

- [ ] **Step 7: Run useAuth.spec.ts — expect GREEN on the new tests**

  ```bash
  cd app && npx vitest run src/composables/useAuth.spec.ts
  ```
  Expected: all tests PASS. If existing `axios.defaults` assertions fail, remove those lines (they test the behavior we deliberately deleted).

- [ ] **Step 8: Create `app/src/test-utils/primeAuth.ts`**

  ```typescript
  import { useAuth } from '@/composables/useAuth';
  import type { UserPayload } from '@/composables/useAuth';

  const DEFAULT_USER: UserPayload = {
    user_id: [1],
    user_name: ['test-admin'],
    email: ['test@sysndd.local'],
    user_role: ['Administrator'],
    user_created: ['2024-01-01'],
    abbreviation: ['TA'],
    orcid: [''],
    exp: [Math.floor(Date.now() / 1000) + 3600],
  };

  /**
   * Seed the auth composable with a session for a single test. Call in
   * `beforeEach` or inline before an authed request. `afterEach` should
   * call `useAuth().logout()` to reset.
   *
   * NOT `localStorage.setItem` — research-aligned: use the abstraction
   * seam, not the storage backend. See
   * docs/superpowers/specs/2026-04-14-v11.0-closeout-design.md §5.2.
   */
  export function primeAuth(
    token: string = 'test-token',
    user: UserPayload = DEFAULT_USER,
  ): { token: string; user: UserPayload } {
    useAuth().login(token, user);
    return { token, user };
  }
  ```

- [ ] **Step 9: Create `app/src/test-utils/expectBearerHeader.ts`**

  ```typescript
  /**
   * MSW resolver helper. Assert the incoming request carries
   * `Authorization: Bearer <expected>`. Throws a clear error with the
   * actual header value if mismatched. Used inside resolvers:
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
  ```

- [ ] **Step 10: Add ESLint `no-restricted-syntax` rule**

  Edit the ESLint config file identified in Step 1. Append the rule with per-file overrides:

  ```javascript
  // Closeout §8.1: forbid direct localStorage token/user reads outside
  // the permitted owners (useAuth.ts, plugins/axios.ts, test-utils, specs).
  const CLOSEOUT_NO_LOCAL_STORAGE_TOKEN = {
    files: ['app/src/**/*.{ts,vue}'],
    ignores: [
      'app/src/composables/useAuth.ts',
      'app/src/plugins/axios.ts',
      'app/src/test-utils/**',
      '**/*.spec.ts',
    ],
    rules: {
      'no-restricted-syntax': [
        'error',
        {
          selector:
            "MemberExpression[object.name='localStorage'][property.name=/^(token|user)$/]",
          message:
            'Direct localStorage.token / localStorage.user access is forbidden outside app/src/composables/useAuth.ts. Use useAuth() or apiClient.',
        },
        {
          selector:
            "CallExpression[callee.object.name='localStorage'][callee.property.name=/^(getItem|setItem|removeItem)$/][arguments.0.value=/^(token|user)$/]",
          message:
            "Direct localStorage.{get,set,remove}Item('token'|'user') access is forbidden outside app/src/composables/useAuth.ts. Use useAuth() or apiClient.",
        },
      ],
    },
  };
  ```

  Integrate into the flat-config `export default []` array (or, if `.eslintrc.cjs` is in use, adapt to the legacy `overrides:` schema).

- [ ] **Step 11: Verify ESLint rule fires**

  Temporarily add to any non-exempt file (e.g. `app/src/views/RegisterView.vue` at line 247):
  ```javascript
  // DELETE ME: rule-test
  if (localStorage.token) { /* test */ }
  ```
  Run `cd app && npm run lint`. Expected: FAIL with the closeout message. Delete the test line; re-run lint to confirm PASS.

- [ ] **Step 12: Add vitest.config.ts TODO comment**

  Edit `app/vitest.config.ts`. Above the `thresholds: { ... }` block, add:
  ```javascript
  // Closeout F3 pins the post-migration ratchet (§6 spec). Numbers
  // below stay at the Phase C floor until F3 measures and rebumps.
  ```

- [ ] **Step 13: Verify acceptance gates**

  ```bash
  cd app && npm run lint && npm run type-check && npm run type-check:strict && npm run test:unit
  grep -rn 'axios\.defaults\.headers\.common\.Authorization' app/src/ | wc -l   # expect 0
  grep -n "localStorage\.getItem('token')" app/src/plugins/axios.ts | wc -l       # expect 0
  make ci-local
  ```
  Expected: every command exit 0; both grep counts `0`.

- [ ] **Step 14: Commit and open PR**

  ```bash
  git add app/src/composables/useAuth.ts app/src/composables/useAuth.spec.ts \
          app/src/plugins/axios.ts app/src/api/client.ts \
          app/src/test-utils/primeAuth.ts app/src/test-utils/expectBearerHeader.ts \
          app/eslint.config.js app/vitest.config.ts
  git commit -m "v11.0/closeout: F1 auth-infra — interceptor-only Bearer + ESLint guardrail + test helpers"
  ```
  Open PR via `superpowers:requesting-code-review`.

- [ ] **Test-gate reference:** F1 modifies pre-existing `useAuth.spec.ts` to match new internal behavior (interceptor-based). Layer 2 (`verify-test-gate.sh`) must recognize this as legitimate — the rule is "no disabling tests to make the source pass"; F1's edits tighten the assertions (test now asserts outbound header, strictly stronger than `axios.defaults` assertion). If `verify-test-gate.sh` flags this, document in the PR body that this is a test-tightening change, not a relaxation. Layer 1 — no protecting Phase C test is weakened.

---

### F2a — `migrate-tier-1` (parallel, dispatches after F1 merges)

- [ ] **Goal (spec §4.2 F2a):** Migrate 13 Tier-1 files (14 usages) from inline `Authorization: Bearer ${localStorage.getItem('token')}` construction to `apiClient` calls; coordinated `useLlmAdmin` API signature change (drop the `token: string` parameter from every method; consumers stop calling `getToken()`).

- [ ] **File ownership (writes) — exact list from spec §13.2:**
  - Modify: `app/src/views/admin/AdminStatistics.vue`
  - Modify: `app/src/views/admin/ManageLLM.vue` (delete the `getToken()` helper at line 211)
  - Modify: `app/src/views/curate/ApproveStatus.vue` (delete the `authHdr` shim at line 67)
  - Modify: `app/src/views/curate/ApproveReview.vue`
  - Modify: `app/src/views/curate/CreateEntity.vue`
  - Modify: `app/src/composables/useAsyncJob.ts`
  - Modify: `app/src/composables/annotations/useAnnotationFormatters.ts`
  - Modify: `app/src/composables/review/useReviewApprovalActions.ts`
  - Modify: `app/src/composables/useCmsContent.ts`
  - Modify: `app/src/views/curate/composables/useReviewForm.ts`
  - Modify: `app/src/views/curate/composables/useStatusForm.ts`
  - Modify: `app/src/components/llm/LlmCacheManager.vue`
  - Modify: `app/src/components/llm/LlmLogViewer.vue`
  - Modify: `app/src/composables/useLlmAdmin.ts` (**API signature change:** drop `token: string` parameter from every method; the interceptor supplies the header)
  - Create new specs (11 files): the spec list is in spec §13.2 column "New spec?".
  - Enhance existing specs (3 files): add assertions that the outbound request carries `Authorization: Bearer <token>` via `expectBearerHeader`. Existing test cases must stay green.

- [ ] **Acceptance:**
  - `grep -rn "localStorage\.\(getItem\|setItem\|removeItem\)\s*(\s*['\"]\\(token\\|user\\)['\"]\s*)" app/src/views/admin/AdminStatistics.vue app/src/views/admin/ManageLLM.vue app/src/views/curate/ApproveStatus.vue app/src/views/curate/ApproveReview.vue app/src/views/curate/CreateEntity.vue app/src/composables/useAsyncJob.ts app/src/composables/annotations/useAnnotationFormatters.ts app/src/composables/review/useReviewApprovalActions.ts app/src/composables/useCmsContent.ts app/src/views/curate/composables/useReviewForm.ts app/src/views/curate/composables/useStatusForm.ts app/src/components/llm/LlmCacheManager.vue app/src/components/llm/LlmLogViewer.vue app/src/composables/useLlmAdmin.ts` returns 0.
  - `cd app && npm run lint` green (F1's ESLint rule now covers these files).
  - `cd app && npm run type-check && npm run type-check:strict` green.
  - Each new/enhanced spec passes, including the MSW Bearer-header assertion.
  - `make ci-local` green.

- [ ] **TDD loop (per-file, rigid §5.3):**
  ```
  For each file F in the tier-1 list:
    a. If a spec exists → add MSW handler with expectBearerHeader for every
       authed call. RED.
    b. If no spec exists → write a new spec exercising each authed call path.
       RED.
    c. Replace the inline Authorization construction with apiClient call. GREEN.
    d. Run cd app && npx vitest run <the-spec> — GREEN.
    e. Confirm ESLint passes for the file: cd app && npx eslint <the-file>.
  After all 14 files migrated:
    f. cd app && npm run test:unit
    g. cd app && npm run type-check:strict
    h. make ci-local
    i. Open PR.
  ```

- [ ] **Example — migrating `AdminStatistics.vue`** (template for the other files):

  **Step A — write failing spec**
  Create `app/src/views/admin/AdminStatistics.spec.ts`:
  ```typescript
  import { mount } from '@vue/test-utils';
  import { setupServer } from 'msw/node';
  import { http, HttpResponse } from 'msw';
  import AdminStatistics from '@/views/admin/AdminStatistics.vue';
  import { primeAuth } from '@/test-utils/primeAuth';
  import { expectBearerHeader } from '@/test-utils/expectBearerHeader';
  import { useAuth } from '@/composables/useAuth';

  const server = setupServer();
  beforeAll(() => server.listen({ onUnhandledRequest: 'error' }));
  afterEach(() => {
    server.resetHandlers();
    useAuth().logout();
  });
  afterAll(() => server.close());

  it('sends Bearer header to /api/admin/statistics after login', async () => {
    const { token } = primeAuth();
    server.use(
      http.get('*/api/admin/statistics', ({ request }) => {
        expectBearerHeader(request, token);
        return HttpResponse.json({ stats: [] });
      }),
    );
    mount(AdminStatistics, { global: { stubs: { 'router-link': true } } });
    // The component fetches on mount; wait for the MSW resolver to fire.
    await new Promise((r) => setTimeout(r, 0));
    // If expectBearerHeader threw, the test already failed.
  });
  ```

  **Step B — run spec, expect RED**
  ```bash
  cd app && npx vitest run src/views/admin/AdminStatistics.spec.ts
  ```
  Expected: FAIL because the component still uses raw `axios` and `axios.defaults.headers.common.Authorization` is no longer set (F1 removed it).

  **Step C — migrate the call site**
  In `app/src/views/admin/AdminStatistics.vue`, replace:
  ```javascript
  axios.get(`${URLS.API_URL}/api/admin/statistics`, {
    headers: {
      Authorization: `Bearer ${localStorage.getItem('token')}`,
    },
  })
  ```
  with:
  ```javascript
  import { apiClient } from '@/api/client';
  // ...
  apiClient.get('/api/admin/statistics')
  ```

  **Step D — run spec, expect GREEN**
  ```bash
  cd app && npx vitest run src/views/admin/AdminStatistics.spec.ts
  ```
  Expected: PASS.

  **Step E — confirm lint**
  ```bash
  cd app && npx eslint src/views/admin/AdminStatistics.vue
  ```
  Expected: no `no-restricted-syntax` violations.

- [ ] **Special handling — `useLlmAdmin.ts` + its three consumers**

  The signature change must be atomic. Order:
  1. Modify `composables/useLlmAdmin.ts` — drop `token: string` from every exported method. Remove line 131–133 (`authHeaders`). Methods delegate to `apiClient` directly.
  2. Modify `views/admin/ManageLLM.vue` — delete `getToken()` helper at lines 210–213. Update every method call from `fetchConfig(getToken())` to `fetchConfig()`.
  3. Modify `components/llm/LlmCacheManager.vue` — delete its local `getToken()` at line 238, remove its argument at call sites.
  4. Modify `components/llm/LlmLogViewer.vue` — same pattern as LlmCacheManager.
  5. Run `cd app && npm run type-check` — MUST be green at this checkpoint. If any consumer still passes a token, type-check fails and the migration is incomplete.
  6. New spec for `useLlmAdmin.spec.ts` covers `fetchConfig` + `fetchPrompts` + `fetchCacheStats` with MSW + `expectBearerHeader`.

- [ ] **Commit + PR**

  ```bash
  git add <all 14 touched files + their specs>
  git commit -m "v11.0/closeout: F2a tier-1 migration (13 files + useLlmAdmin API change)"
  ```
  Open PR via `superpowers:requesting-code-review`.

- [ ] **Test-gate reference:** Every new spec is a new `*.spec.ts` file — allowed by Layer 2. Enhanced specs (ApproveStatus, ApproveReview, useAsyncJob, useReviewForm, useStatusForm) must ADD assertions, not relax them. If `verify-test-gate.sh` flags a diff on these, document in the PR body that assertions are strictly tighter.

---

### F2b — `migrate-tier-2` (parallel)

- [ ] **Goal (spec §4.2 F2b):** Migrate 9 Tier-2 files (34 usages) including the previously-missed `ModifyEntity.vue` (3 usages).

- [ ] **File ownership (writes) — exact list from spec §13.3:**
  - Modify: `app/src/views/RegisterView.vue` — **custom `doUserLogOut` → `useAuth().logout()`**. Also remove the dot-access read at line 247 (`if (localStorage.user)`) — replace with `useAuth().isAuthenticated.value`. 5 usages total.
  - Modify: `app/src/views/admin/ManageOntology.vue`
  - Modify: `app/src/views/admin/ManageUser.vue` (9 usages — largest single file)
  - Modify: `app/src/views/admin/ManageBackups.vue`
  - Modify: `app/src/views/curate/ApproveUser.vue`
  - Modify: `app/src/views/curate/ModifyEntity.vue` (3 usages, lines 1307/1348/1416)
  - Modify: `app/src/composables/useBatchForm.ts` (8 usages)
  - Modify: `app/src/components/small/IconPairDropdownMenu.vue` — **duplicate logout logic → `useAuth().logout()`**. Remove dot-access at line 57 (`if (localStorage.user || localStorage.token)`) and both `removeItem` calls.
  - Modify: `app/src/components/tables/TablesLogs.vue`
  - New specs: 8 files (everything except RegisterView's existing spec which gets enhanced).

- [ ] **Acceptance:**
  - All 9 files compile to 0 matches against the closeout grep pattern.
  - ESLint rule green across all 9 files.
  - 8 new specs each include `expectBearerHeader` for at least one authed operation; enhanced RegisterView spec covers `doUserLogOut` → `useAuth().logout()` path and MSW `sendRegistration` flow.
  - `cd app && npm run type-check && npm run type-check:strict` green.
  - `make ci-local` green.

- [ ] **TDD loop:** same per-file pattern as F2a. Example for RegisterView:

  **Step A — write failing spec (enhanced RegisterView.spec.ts)**
  Add to the existing spec (or create if missing):
  ```typescript
  it('doUserLogOut routes through useAuth().logout() and does NOT touch localStorage directly', async () => {
    const auth = useAuth();
    primeAuth();
    const logoutSpy = vi.spyOn(auth, 'logout');
    const wrapper = mount(RegisterView, { /* ... */ });
    // trigger mounted()
    await wrapper.vm.$nextTick();
    expect(logoutSpy).toHaveBeenCalledOnce();
    expect(localStorage.getItem('token')).toBeNull();
    expect(localStorage.getItem('user')).toBeNull();
  });
  ```

  **Step B — run, expect RED**: `mounted()` still does `if (localStorage.user) { this.doUserLogOut(); }` and `doUserLogOut` calls `localStorage.removeItem` directly. Test fails because `logoutSpy` never fires through `useAuth`.

  **Step C — migrate** (`app/src/views/RegisterView.vue` lines 246–316):
  ```javascript
  import { useAuth } from '@/composables/useAuth';
  // in setup or data:
  const auth = useAuth();

  mounted() {
    if (auth.isAuthenticated.value) {
      this.doUserLogOut();
    }
    this.loading = false;
  },

  doUserLogOut() {
    auth.logout();
    this.user = null;
    this.$router.push('/');
  },
  ```

  **Step D — run spec, expect GREEN.**

- [ ] **Special handling — `ManageUser.vue` (largest file in tier)**

  9 Bearer reads at lines 1156, 1210, 1270, 1393, 1491, 1502, 1523, 1583, 1694. Migrate each in sequence, running the ManageUser spec after EVERY ONE to catch regressions early. The existing spec file exists but does NOT cover auth paths — F2b adds 9 new test cases, one per migrated call. Each new test uses `primeAuth() + expectBearerHeader` on the corresponding endpoint. This is the largest single-file spec delta in the closeout.

- [ ] **Commit + PR**

  ```bash
  git add <9 files + their specs>
  git commit -m "v11.0/closeout: F2b tier-2 migration (9 files, 34 usages incl. ModifyEntity + ManageUser + RegisterView logout via useAuth)"
  ```
  Open PR.

- [ ] **Test-gate reference:** RegisterView.spec.ts is enhanced (strictly additive assertions, plus `doUserLogOut` test). 8 new spec files are legitimate new-file additions under Layer 2.

---

### F2c — `migrate-review-view` (parallel)

- [ ] **Protecting Phase C test:** C2's `app/src/views/review/Review.spec.ts` is on `master` (from spec §8 parent). Confirm:
  ```bash
  cd app && npx vitest run src/views/review/Review.spec.ts
  ```
  Must be GREEN before the migration starts.

- [ ] **Goal (spec §4.2 F2c):** Migrate `app/src/views/review/Review.vue` (1454 LoC, 7 usages). The `mounted()` hook reads `localStorage.user` directly and `JSON.parse`s it — replace with `useAuth().user` (corrupt-payload resilience is already handled in the composable). 5 Bearer reads migrated to `apiClient`.

- [ ] **File ownership (writes):**
  - Modify: `app/src/views/review/Review.vue` at lines:
    - **1032–1033**: `if (localStorage.user) { this.user = JSON.parse(localStorage.user); }` → `const auth = useAuth(); this.user = auth.user.value;` (plus handle `null` case — existing `curator_mode` computation expects an object).
    - **1181, 1313, 1334, 1356, 1373**: 5 Bearer header reads → `apiClient` calls.
  - Modify: `app/src/views/review/Review.spec.ts` — ENHANCE only. Existing cases stay green; add new cases:
    - Mount assertion: `localStorage.getItem('user')` returns null, component still has `this.user` populated from `useAuth()`.
    - MSW Bearer assertion on each of the 5 endpoints via `expectBearerHeader`.

- [ ] **Acceptance:**
  - `grep -n "localStorage" app/src/views/review/Review.vue` returns 0 matches.
  - Existing Review.spec.ts tests still green.
  - New assertions green.
  - `make ci-local` green.

- [ ] **TDD loop:** same as F2a/F2b. Five new MSW-handlers spec cases, one per Bearer endpoint; one replace-the-mounted-hook case.

- [ ] **Commit + PR**

  ```bash
  git add app/src/views/review/Review.vue app/src/views/review/Review.spec.ts
  git commit -m "v11.0/closeout: F2c migrate Review.vue (1454 LoC) — useAuth + apiClient"
  ```

---

### F2d — `migrate-manage-rereview` (parallel)

- [ ] **Protecting Phase C test:** **NONE exists today.** F2d is the one F2 worktree that writes a genuinely new spec before migrating. This is the largest test-authoring task in the closeout.

- [ ] **Goal (spec §4.2 F2d):** Migrate `app/src/views/curate/ManageReReview.vue` (1133 LoC, 9 usages at lines 767, 789, 825, 849, 889, 931, 979, 1027, 1056) + author a new spec covering all 9 authed operations.

- [ ] **File ownership (writes):**
  - Create: `app/src/views/curate/ManageReReview.spec.ts` — new file; 9 test cases minimum, one per Bearer endpoint. Each case uses `primeAuth() + expectBearerHeader`.
  - Modify: `app/src/views/curate/ManageReReview.vue` at the 9 Bearer-construction sites → `apiClient` calls.

- [ ] **Acceptance:**
  - `grep -n "localStorage\\.getItem" app/src/views/curate/ManageReReview.vue` returns 0.
  - New spec covers all 9 operations; `npx vitest run src/views/curate/ManageReReview.spec.ts` green.
  - `make ci-local` green.
  - Manual smoke test: open a re-review in `make dev` stack, submit. Screenshot before/after for PR.

- [ ] **TDD loop (extended — new spec first):**
  ```
  1. make worktree-setup NAME=closeout/migrate-manage-rereview
  2. cd worktrees/closeout/migrate-manage-rereview
  3. make install-dev
  4. make doctor
  5. Author ManageReReview.spec.ts skeleton (9 empty test cases, one per endpoint).
     Each case: primeAuth → mount component → trigger the action → assert MSW
     handler fires expectBearerHeader. RED — source still uses raw axios + localStorage.
  6. Migrate each of the 9 call sites ONE AT A TIME. After each:
       cd app && npx vitest run src/views/curate/ManageReReview.spec.ts
       cd app && npx eslint src/views/curate/ManageReReview.vue
     Each migration turns one RED test GREEN.
  7. make dev   # start stack
  8. Manual smoke: submit a re-review action; screenshot.
  9. make ci-local
  10. Commit: "v11.0/closeout: F2d migrate ManageReReview.vue (1133 LoC) + new spec"
  11. Open PR.
  ```

- [ ] **Test-gate reference:** New spec file — Layer 2 allows it. Source migration is standard.

---

### F2e — `document-exceptions` (parallel)

- [ ] **Goal (spec §3.4 + §4.2 F2e):** Document the two enumerated exceptions by (a) adding marker comments, (b) writing specs that PROVE the exceptions don't read `localStorage`.

- [ ] **File ownership (writes):**
  - Modify: `app/src/views/LoginView.vue` at line **204** — add trailing comment: `// closeout-exception-E1: bootstrap two-step handshake; useAuth.login() requires both token+user atomically (§3.4)`.
  - Modify: `app/src/views/PasswordResetView.vue` at line **232** — add trailing comment: `// closeout-exception-E2: route-param one-shot JWT from email link; not a session token (§3.4)`.
  - Create: `app/src/views/LoginView.spec.ts` — new spec, 3 test cases: (a) outbound GET `/api/auth/signin` carries Bearer of the local `token` param; (b) `localStorage.getItem('token')` is `null` throughout the handshake; (c) `useAuth().login()` is called exactly once after BOTH token AND user are known.
  - Create: `app/src/views/PasswordResetView.spec.ts` — new spec, 3 test cases: (a) outbound POST carries Bearer of `$route.params.request_jwt`; (b) `localStorage.getItem('token')` is `null`; (c) `useAuth()` is never invoked (the route-param credential is not a session).

- [ ] **Acceptance:**
  - Both marker comments present (grep: `closeout-exception-E1` and `closeout-exception-E2` each return exactly 1 hit).
  - `LoginView.spec.ts` and `PasswordResetView.spec.ts` pass.
  - Neither file reads `localStorage.token`/`localStorage.user` (ESLint enforces).
  - `make ci-local` green.

- [ ] **Example — `LoginView.spec.ts`:**
  ```typescript
  import { mount } from '@vue/test-utils';
  import { setupServer } from 'msw/node';
  import { http, HttpResponse } from 'msw';
  import LoginView from '@/views/LoginView.vue';
  import { useAuth } from '@/composables/useAuth';

  const server = setupServer();
  beforeAll(() => server.listen({ onUnhandledRequest: 'error' }));
  afterEach(() => { server.resetHandlers(); useAuth().logout(); localStorage.clear(); });
  afterAll(() => server.close());

  it('E1 bootstrap: GET /api/auth/signin carries Bearer of the local token (not localStorage)', async () => {
    expect(localStorage.getItem('token')).toBeNull();
    let signinAuth: string | null = null;
    server.use(
      http.post('*/api/auth/authenticate', () => HttpResponse.json(['BOOTSTRAP_TOKEN'])),
      http.get('*/api/auth/signin', ({ request }) => {
        signinAuth = request.headers.get('authorization');
        expect(localStorage.getItem('token')).toBeNull(); // proves it's genuinely the local variable
        return HttpResponse.json({
          user_id: [1], user_name: ['admin'], email: ['a@b'], user_role: ['Administrator'],
          user_created: ['2024'], abbreviation: ['A'], orcid: [''], exp: [Math.floor(Date.now()/1000) + 3600],
        });
      })
    );
    const wrapper = mount(LoginView, { /* ... */ });
    await wrapper.find('form').trigger('submit');
    await new Promise(r => setTimeout(r, 0));
    expect(signinAuth).toBe('Bearer BOOTSTRAP_TOKEN');
  });

  it('E1 bootstrap: useAuth().login() called exactly once, with both token and user', async () => {
    const loginSpy = vi.spyOn(useAuth(), 'login');
    // ... same server setup ...
    // trigger form submit ...
    expect(loginSpy).toHaveBeenCalledTimes(1);
    expect(loginSpy.mock.calls[0][0]).toBe('BOOTSTRAP_TOKEN');
    expect(loginSpy.mock.calls[0][1]).toMatchObject({ user_role: ['Administrator'] });
  });
  ```

- [ ] **Example — `PasswordResetView.spec.ts`:**
  Similar pattern; assert `useAuth().login` is NEVER called (`expect(loginSpy).not.toHaveBeenCalled()`) and the outbound POST carries the route-param JWT.

- [ ] **Commit + PR**
  ```bash
  git add app/src/views/LoginView.vue app/src/views/PasswordResetView.vue \
          app/src/views/LoginView.spec.ts app/src/views/PasswordResetView.spec.ts
  git commit -m "v11.0/closeout: F2e document 2 enumerated Bearer-header exceptions + specs"
  ```

- [ ] **Test-gate reference:** Two new spec files; Layer 2 allows.

---

### F3 — `exit-pr` (merges last; only after all 5 F2 PRs merged)

- [ ] **Goal (spec §4.3, §6, §9):** Close v11.0. Pin the coverage ratchet to the post-migration measured floor; amend the parent spec §4.6 and §3 Phase E gate narrative; walk exit criteria 1–20 in the PR body; tag `v11.0` at the merge commit.

- [ ] **Prerequisites — confirm F1+F2a+F2b+F2c+F2d+F2e all merged:**
  ```bash
  git log --oneline master -20 | grep -E 'closeout: (F1|F2[abcde])'
  # expect 6 lines
  git branch --list 'v11.0/closeout/*' | wc -l
  # expect 1 (exit-pr worktree itself)
  ```

- [ ] **File ownership (writes):**
  - Modify: `app/vitest.config.ts` — replace the `thresholds: { lines: 13, functions: 9, branches: 12, statements: 13 }` numbers with the post-migration measured floor (rounded down per integer rule).
  - Modify: `docs/superpowers/specs/2026-04-11-v11.0-test-foundation-design.md` §4.6 per spec §6.1 substitution.
  - Modify: `docs/superpowers/specs/2026-04-11-v11.0-test-foundation-design.md` §3 Phase E gate narrative per spec §6.2.
  - Create: v11.0-exit PR body (GitHub PR description) — walks exit criteria 1–20 as a checklist.

- [ ] **Step 1: Measure coverage on merged master**
  ```bash
  cd app && npm run test:coverage 2>&1 | tail -20
  ```
  Record: lines / functions / branches / statements actuals. Expected range (spec §4.3 estimate): 18–22 lines, 15–19 functions, 14–18 branches, 18–22 statements. If actuals fall OUTSIDE this range (above or below), note in PR body — below means unexpected regressions, above means migrations lifted more than predicted.

- [ ] **Step 2: Pin `vitest.config.ts` ratchet**

  Edit `app/vitest.config.ts`. Replace the threshold numbers with `floor(actual) - 0` (rounded DOWN per Phase C rule — never round up). Example (illustrative — use your actuals):
  ```javascript
  thresholds: {
    lines: 19,      // measured 19.3 → rounded down
    functions: 16,  // measured 16.4 → rounded down
    branches: 15,   // measured 15.1 → rounded down
    statements: 19, // measured 19.2 → rounded down
  },
  ```
  Update the comment block above to note the F3 reconciliation:
  ```javascript
  // Closeout F3 (2026-04-14+): ratchet reconciled to post-migration measured
  // floor. Spec §4.6 amended in parallel. See
  // docs/superpowers/specs/2026-04-14-v11.0-closeout-design.md §6.
  ```

- [ ] **Step 3: Run coverage locally — expect PASS**
  ```bash
  cd app && npm run test:coverage
  ```
  Expected: exit 0. If any threshold fails, the measurement in Step 1 was inconsistent — re-measure in a clean worktree.

- [ ] **Step 4: Amend parent spec §4.6**

  Edit `docs/superpowers/specs/2026-04-11-v11.0-test-foundation-design.md`. Locate §4.6 ("Coverage threshold ratchet"). Replace per spec §6.1:

  **Find:**
  > End of Phase C → 55 / 55 / 55 / 55  (bumped in the last-merging Phase C PR)
  > End of v11.0   → unchanged at 55  (the refactor preserves coverage; the tests lifted it)

  **Replace with:**
  > End of Phase C → ratchet pinned at measured floor (13/9/12/13). The original 55 target was set against a much larger denominator before test-utils/ was excluded from coverage; post-exclusion the plan's original 45→55 bump was already stale (documented inline in `app/vitest.config.ts`).
  > End of v11.0 (post-closeout) → ratchet pinned at post-migration measured floor (actuals: {lines}/{functions}/{branches}/{statements}, rounded down per integer rule). See `docs/superpowers/specs/2026-04-14-v11.0-closeout-design.md` and `.plans/v11.0/closeout.md`.
  > v11.1 target → 30/25/25/30 (advisory). Per-resource `api/*.ts` fill-out and httpOnly-cookie migration lift the numerator; enforced in v11.2.

  Substitute `{lines}/{functions}/{branches}/{statements}` with the Step 1 actuals.

- [ ] **Step 5: Amend parent spec §3 Phase E gate narrative**

  Add a final paragraph to §3 Phase E gate:
  > **Post-closeout annotation (2026-04-14+):** Phase E merged on the narrow §8 grep pattern (5 dot-access sites outside useAuth.ts). Strict E7 closure (60+ `localStorage.getItem('token')` sites) was delivered by the v11.0 closeout (F1–F3). This is a post-mortem annotation, not a re-scope — Phase E's contract per its own §8 was honored; the closeout delivered the spec's intent in addition. See `docs/superpowers/specs/2026-04-14-v11.0-closeout-design.md`.

- [ ] **Step 6: Confirm mechanical exit gates (§9)**
  ```bash
  # Gate 1 — strict E7 grep returns 0
  violations=$(grep -rn "localStorage\.token\|localStorage\.user\|localStorage\.getItem(['\"]\(token\|user\)['\"])" app/src/ \
    --exclude-dir=test-utils \
    | grep -v 'useAuth.ts' | grep -v 'plugins/axios.ts' | grep -v '\.spec\.ts' | wc -l)
  [ "$violations" = "0" ] || { echo "FAIL: $violations violations"; exit 1; }

  # Gate 2 — ESLint green
  cd app && npm run lint

  # Gate 3 — type-check + strict
  cd app && npm run type-check && npm run type-check:strict

  # Gate 4 — coverage
  cd app && npm run test:coverage

  # Gate 5 — full CI
  cd .. && make ci-local

  # Gate 6 — flake-free streak
  gh run list --workflow ci.yml --branch master --limit 15 --json conclusion,event \
    | jq '[.[] | select(.event=="push") | .conclusion] | .[0:10] | all(.=="success")'
  ```
  If Gate 6 returns `false`, apply the parent §4.7 exit ramp: 7 consecutive green + 0 red in the preceding 7-day window.

- [ ] **Step 7: Write v11.0-exit PR body**

  Use this template (substitute actuals):

  ```markdown
  # v11.0 — Closeout Exit PR

  Closes v11.0. This PR:
  1. Pins `vitest.config.ts` coverage ratchet to post-migration measured floor.
  2. Amends parent spec §4.6 and §3 Phase E gate narrative.
  3. Opens Checkpoint #3 for sign-off on exit criteria 1–20.

  ## Checkpoint #3 — Exit Criteria Walkthrough

  | # | Criterion | Delivered by | Verification | Status |
  |---|-----------|--------------|--------------|--------|
  | 1 | Credentials-in-URL P0 fixed (POST body) | A1 | `api/endpoints/auth_endpoints.R` | ✅ |
  | 2 | Dev environment bootstrap | A7 | `make doctor` | ✅ |
  | 3 | (...etc for criteria 3–20, one per parent §1.4...) | | | |
  | 18 | Flake-free streak (10 consecutive OR 7/0-in-7-days) | post-closeout CI | `gh run list` snippet | ✅ |
  | 19 | Every new/rewritten file in v11.0 is TypeScript | F1–E7 | manual audit | ✅ |
  | 20 | Backend coverage advisory printed by `make test-api` | B3 | `make test-api` tail | ✅ |

  ## Mechanical gates (from closeout spec §9)

  - [x] `grep -rn "localStorage.\(token\|user\|getItem.token\|getItem.user\)" app/src/` outside useAuth.ts + plugins/axios.ts + test-utils + specs returns 0
  - [x] ESLint `no-restricted-syntax` rule enforced; `npm run lint` green
  - [x] `npm run type-check && npm run type-check:strict` green
  - [x] `npm run test:coverage` passes against reconciled ratchet (lines {L}, functions {F}, branches {B}, statements {S})
  - [x] `make ci-local` green on clean master
  - [x] Flake-free streak confirmed

  ## v11.1 roadmap handoff (considered-and-rejected items)

  - Pinia migration for useAuth.ts — spec §7.
  - Per-resource `api/*.ts` module fill-out — E1 deferred.
  - httpOnly cookie + refresh flow — OWASP 2026 canonical — v11.1+.

  Tag `v11.0` applied at merge commit.
  ```

- [ ] **Step 8: Commit + PR**

  ```bash
  git add app/vitest.config.ts docs/superpowers/specs/2026-04-11-v11.0-test-foundation-design.md
  git commit -m "v11.0/closeout: F3 exit PR — coverage ratchet reconciled, parent spec amended, Checkpoint #3"
  ```
  Open PR via `superpowers:requesting-code-review` with the body from Step 7.

- [ ] **Step 9: After PR merges, tag v11.0**

  ```bash
  git checkout master && git pull
  git tag -a v11.0 -m "v11.0 — Test foundation & safety rails"
  git push origin v11.0
  ```

- [ ] **Test-gate reference:** F3 touches no source code, only config + spec docs. Layer 1 & 2 vacuous. Layer 3 (human Checkpoint #3) is this PR's review.

---

## 4 — Parallel dispatch block

Merge order (§2 manifest): F1 first → F2a, F2b, F2c, F2d, F2e parallel → F3 last.

```bash
# After F1 merges on master:
make worktree-setup NAME=closeout/migrate-tier-1
make worktree-setup NAME=closeout/migrate-tier-2
make worktree-setup NAME=closeout/migrate-review-view
make worktree-setup NAME=closeout/migrate-manage-rereview
make worktree-setup NAME=closeout/document-exceptions
# Dispatch all 5 F2 agents in parallel via superpowers:dispatching-parallel-agents.

# After all 5 F2 PRs are merged on master:
make worktree-setup NAME=closeout/exit-pr
```

**Before each F2 dispatch agent starts:**
1. Confirm F1 is on `master`: `git log --oneline master -5 | grep F1`.
2. Rebase the F2 branch: `git pull --rebase origin master` inside the worktree.

**F3 gating check before dispatch:**
```bash
git log --oneline master -20 | grep -E 'closeout: (F1|F2[abcde])' | wc -l
# expect 6
```

---

## 5 — TDD loop (from spec §5.3, rigid)

Every F2 worktree follows this loop literally:

```
1. make worktree-setup NAME=closeout/<unit>
2. cd worktrees/closeout/<unit>
3. make install-dev                 # idempotent
4. make doctor                      # verify env
5. For each file in the tier's catalog:
   a. Spec exists → add Bearer + 401 assertions using MSW + expectBearerHeader. RED.
   b. Spec missing → author new spec covering authed paths. RED.
   c. Migrate the call site (inline Authorization → apiClient). GREEN.
   d. Confirm ESLint rule is clean: cd app && npx eslint <the-file>.
6. cd app && npm run test:unit
7. cd app && npm run type-check && npm run type-check:strict
8. cd app && npm run lint
9. make ci-local
10. Capture before/after screenshots for F2c + F2d (Risk 7 mitigation).
11. Open PR via superpowers:requesting-code-review.
```

**Rigid rules:**
- No PR may weaken or delete a pre-existing spec's assertions. Enhancements (additive assertions) are allowed.
- No PR may re-introduce a `localStorage.getItem('token')` or `localStorage.(token|user)` read in any non-exempt file. ESLint enforces.
- No PR may add a new `Authorization: Bearer` construction outside the 2 enumerated exception files. Advisory grep surfaces violations in PR review.
- Test-utils helpers (`primeAuth`, `expectBearerHeader`) are imported only, never modified inside F2.

---

## 6 — Test contract (from spec §5.1)

**Per authed operation migrated, the spec asserts two things:**

1. **Token present → header reaches the wire.** MSW resolver reads `request.headers.get('authorization')` via `expectBearerHeader(request, token)`. Returns 200 on match; MSW throws on mismatch (test fails).
2. **Token absent → 401 handling.** No `primeAuth()` call; MSW responds 401 to the authed endpoint; view's error handler either shows the error UI or calls `useAuth().handle401()`. `useAuth.spec.ts` already covers the `handle401` path, so view specs assert the call chain only.

**Test-utils imports (F1 provides):**
```typescript
import { primeAuth } from '@/test-utils/primeAuth';
import { expectBearerHeader } from '@/test-utils/expectBearerHeader';
```

**MSW lifecycle (per spec file):**
```typescript
const server = setupServer();
beforeAll(() => server.listen({ onUnhandledRequest: 'error' }));
afterEach(() => { server.resetHandlers(); useAuth().logout(); });
afterAll(() => server.close());
```

---

## 7 — Human checkpoint #3

**Checkpoint #3 (spec §7, parent §2.7, last of 3):**

> After F1–F3 merge, the human reviewer runs `make ci-local` on clean `master`, confirms exit criterion #18 (10-run or 7/0-in-7-days flake-free streak), and walks every exit criterion in the v11.0-exit PR body.

Checkpoint #3 passes when **all** of these hold:
1. Spec §9 gates (grep, ESLint, type-check, coverage, CI) pass.
2. Parent §1.4 exit criteria 1–20 each have a green verification in the PR body.
3. `useAuth()` is the sole reader of `localStorage.(token|user)` besides `plugins/axios.ts`.
4. Every `Authorization: Bearer` construction outside the interceptor is in one of the two enumerated exception files (`LoginView.vue:204` or `PasswordResetView.vue:232`), each with its marker comment and companion spec.
5. Flake-free streak confirmed.

**If any criterion fails, v11.0 is not shipped.** Open a reinforcing worktree (`v11.0/closeout/reinforce-<issue>`) and re-run the checkpoint.

---

## 8 — Phase gate commands (from spec §9)

Run on clean `master` after every closeout PR merges:

```bash
# Worktrees cleaned
git branch --list 'v11.0/closeout/*' | wc -l               # must be 0 after F3
git ls-remote --heads origin 'v11.0/closeout/*' | wc -l    # must be 0 after F3

# Mechanical E7 gate
violations=$(grep -rn "localStorage\.token\|localStorage\.user\|localStorage\.getItem(['\"]\(token\|user\)['\"])" app/src/ \
  --exclude-dir=test-utils \
  | grep -v 'useAuth.ts' | grep -v 'plugins/axios.ts' | grep -v '\.spec\.ts' | wc -l)
[ "$violations" = "0" ] || { echo "E7 gate FAILED: $violations violations"; exit 1; }

# ESLint guardrail
cd app && npm run lint

# Type-check
cd app && npm run type-check && npm run type-check:strict

# Coverage
cd app && npm run test:coverage

# Full CI
cd .. && make ci-local

# Flake-free streak (at least one of these two must be true)
gh run list --workflow ci.yml --branch master --limit 15 --json conclusion,event \
  | jq '[.[] | select(.event=="push") | .conclusion] | .[0:10] | all(.=="success")'
# OR the 7/0-in-7-days exit ramp (manual count per parent §4.7).

# v11.0 tag
git tag -l 'v11.0'   # expect 'v11.0' printed after F3 merge
```

If every command above exits 0, v11.0 is shipped.

---

## 9 — Rollback protocol

If a closeout PR lands on `master` and causes a production regression:

1. **F1 regression** (e.g. login completely broken) — revert F1's merge commit via `gh pr create` with a `Revert F1` body. F2/F3 branches rebase onto the reverted master.
2. **F2a/F2b/F2c/F2d/F2e regression** — revert that one PR only; other F2 PRs keep their gains. The closeout remains in a legitimate partial state because each F2 is independently valuable (each reduces the closeout grep count by N).
3. **F3 regression** — extremely unlikely (config + docs only). Revert; re-measure coverage; re-pin the ratchet.

If a migration breaks the E7 grep gate (new violations introduced), the offending PR is the one to revert.

---

## 10 — Self-review checklist (run before marking plan complete)

- [x] Every F1–F3 has File ownership, Acceptance, TDD loop, Test-gate reference sections.
- [x] Every code step shows the actual code (no "implement X" placeholders).
- [x] Every bash step has expected exit status / grep count / output pattern.
- [x] Enumerated exceptions list is complete (E1 LoginView, E2 PasswordResetView — no third).
- [x] No file appears in two worktrees' ownership sets. Catalog appendix from spec §13 is the authoritative reference.
- [x] Coverage ratchet numbers in F3 are parametric (`{L}/{F}/{B}/{S}`) — the agent measures and substitutes.
- [x] `useLlmAdmin.ts` coordinated API change is atomic with its 3 consumers.
- [x] ESLint rule has per-file override list matching spec §8.1.
- [x] v11.0 tag command is present in §8.
