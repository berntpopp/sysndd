// ManageAnnotations.spec.ts
/**
 * Phase C unit C5 — functional spec for `views/admin/ManageAnnotations.vue`
 * (plan: .plans/v11.0/phase-c.md §3 Phase C.C5, Appendix C locked).
 *
 * ## Scope
 *
 * This spec is written against the **unchanged** 2,159-LoC
 * `ManageAnnotations.vue` as a Tier-B safety net for Phase E4
 * (`rewrite-manage-annotations`).  It exercises two functional paths
 * through the view's async-job machinery and plants one locked `it.todo`
 * that hands off the force-apply write contract to E4.
 *
 * ### 1. Happy path — HGNC update poll-to-complete
 *
 * Click "Update HGNC Data" → the view POSTs `/api/jobs/hgnc_update/submit`
 * (B1 handler default), `useAsyncJob.startJob()` begins polling
 * `GET /api/jobs/:job_id/status` on a 3-second interval.  A per-test
 * `server.use(...)` override stages three sequential status responses via
 * a closure counter: `queued → running → completed`.  The spec advances
 * fake timers through each poll, then overrides `GET /api/jobs/history`
 * to include the completed HGNC job and calls `fetchJobHistory` implicitly
 * via the view's own `completed` watcher.  Final assertion: the job row is
 * rendered in the history table.
 *
 * ### 2. Error path — Phase 76 ontology-update blocked
 *
 * Click "Update Ontology Annotations" → the view PUTs
 * `/api/admin/update_ontology_async` (not in B1 — stubbed per-test).
 * Polling transitions `queued → running → completed` via the same closure
 * counter.  The terminal response carries `result: { status: ["blocked"] }`
 * (Phase 76 lowercase shape — CLAUDE.md §Ontology Update Safeguard).  The
 * view's `ontologyJob` completed watcher does a follow-up GET on the
 * status endpoint, unwraps `result.status`, populates `ontologyBlocked`,
 * and renders the blocked alert with the critical-entities table and
 * the Force Apply affordance.
 *
 * **There is no job-cancel endpoint in the current API** — we do NOT
 * mock or assert cancellation (.plans/v11.0/phase-c.md §3 Phase C.C5).
 *
 * ### 3. Locked handshake for Phase E4
 *
 * One `it.todo` plants the force-apply contract: Phase E4 unpins it after
 * rewriting the view with `useAsyncJob` + `useTableData`.  The exact
 * string is locked in Appendix C of the phase-c plan.
 *
 * ## Notes for reviewers
 *
 * - VITE_API_URL is `undefined` in vitest (no .env.test) — we stub it to
 *   `''` via `vi.stubEnv` so `${import.meta.env.VITE_API_URL}/api/...`
 *   resolves to `/api/...` which MSW intercepts.  Without this stub the
 *   fetch URL becomes `undefined/api/...` and MSW's
 *   `onUnhandledRequest: 'error'` (vitest.setup.ts §60) throws.
 * - `useIntervalFn` (VueUse) drives the polling loop.  Fake timers
 *   (`vi.useFakeTimers`) plus `vi.advanceTimersByTimeAsync(3000)` walks
 *   through each poll cycle.  `flushPromises()` drains the micro-task
 *   queue so each `axios.get` → MSW → reactive update completes before
 *   the next advance.
 * - `server.use(...)` per-test overrides stage the sequential status
 *   responses (queued → running → completed) via a closure-captured
 *   counter — no new handlers are added to the B1 table.
 * - `bootstrap-vue-next`'s `useToast` needs the plugin installed or a
 *   mock; we mock the whole `@/composables` namespace like the existing
 *   `ModifyEntity.a11y.spec.ts` does.
 * - Endpoints fired on mount that are **not** in the B1 table
 *   (annotation_dates, pubtator stats, publication stats, deprecated
 *   entities, comparisons metadata) are handled via per-test
 *   `server.use(...)` empty-shell overrides so MSW's unhandled-request
 *   error doesn't fire.  These are NOT new handlers — they are transient
 *   test-local overrides required because ManageAnnotations' `onMounted`
 *   calls them.  Phase E4 will dedupe these into `useTableData` and this
 *   preamble will shrink.
 * - `R/Plumber returns JSON scalars as arrays` (CLAUDE.md): every status
 *   and result field in the stubs is emitted as `[value]`, matching the
 *   real plumber serialisation the view's `unwrapValue()` helper expects.
 */

import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';
import { mount, flushPromises, type VueWrapper } from '@vue/test-utils';
import { createPinia } from 'pinia';
import { createRouter, createWebHistory } from 'vue-router';
import { http, HttpResponse } from 'msw';

import { server } from '@/test-utils/mocks/server';
import ManageAnnotations from './ManageAnnotations.vue';

// ---------------------------------------------------------------------------
// Composable mocks — bootstrap-vue-next's useToast requires the plugin, which
// we don't install in isolated view tests.  See ModifyEntity.a11y.spec.ts for
// the precedent pattern.
// ---------------------------------------------------------------------------
vi.mock('@/composables/useToast', () => ({
  default: () => ({
    makeToast: vi.fn(),
  }),
}));

// ---------------------------------------------------------------------------
// onMounted auxiliary-endpoint shell stubs
//
// ManageAnnotations.onMounted fires several axios.get calls that are not in
// the B1 handler table.  They are wrapped in try/catch in the view, so the
// happy-path functional assertions don't depend on their shapes — but
// vitest.setup.ts uses `onUnhandledRequest: 'error'` which fails the test
// if any un-mocked URL is hit.  We install transient shell handlers here
// (per-test via server.use in installAuxHandlers) rather than adding them
// to the shared B1 table.
// ---------------------------------------------------------------------------
function installAuxHandlers() {
  server.use(
    http.get('/api/admin/annotation_dates', () =>
      HttpResponse.json({
        omim_update: [null],
        hgnc_update: [null],
        mondo_update: [null],
        disease_ontology_update: [null],
      })
    ),
    http.get('/api/admin/deprecated_entities', () =>
      HttpResponse.json({
        deprecated_count: [0],
        affected_entity_count: [0],
        affected_entities: [],
        mim2gene_date: [null],
        message: [null],
      })
    ),
    http.get('/api/publication/pubtator/genes', () =>
      HttpResponse.json({ data: [], meta: [{ totalItems: 0 }] })
    ),
    http.get('/api/publication/pubtator/table', () =>
      HttpResponse.json({ data: [], meta: [{ totalItems: 0 }] })
    ),
    http.get('/api/publication/stats', () =>
      HttpResponse.json({
        total: [null],
        oldest_update: [null],
        outdated_count: [null],
        filtered_count: [null],
      })
    ),
    http.get('/api/comparisons/metadata', () =>
      HttpResponse.json({
        last_full_refresh: [null],
        last_refresh_status: ['never'],
        last_refresh_error: [null],
        sources_count: [0],
        rows_imported: [0],
      })
    )
  );
}

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

/**
 * Build a tiny in-memory router so `useRoute()` inside the view resolves.
 * The view reads `route.query` to bootstrap URL state; an empty query is fine.
 */
function buildTestRouter() {
  return createRouter({
    history: createWebHistory(),
    routes: [
      { path: '/', name: 'Home', component: { template: '<div>Home</div>' } },
      {
        path: '/admin/manage-annotations',
        name: 'ManageAnnotations',
        component: { template: '<div>Manage</div>' },
      },
      // Referenced via router-link in the view
      {
        path: '/analyses/pubtator',
        name: 'PubtatorNDDStats',
        component: { template: '<div />' },
      },
      {
        path: '/admin/manage-pubtator',
        name: 'ManagePubtator',
        component: { template: '<div />' },
      },
      {
        path: '/entity/:entity_id',
        name: 'Entity',
        component: { template: '<div />' },
      },
      {
        path: '/gene/:symbol',
        name: 'Gene',
        component: { template: '<div />' },
      },
    ],
  });
}

/**
 * Common stub set for bootstrap-vue-next components used by the view.
 * We keep slots transparent so child content (rows, labels, headings)
 * stays in the rendered HTML for our `text()` assertions.
 */
const bvnStubs = {
  BContainer: { template: '<div><slot /></div>' },
  BRow: { template: '<div><slot /></div>' },
  BCol: { template: '<div><slot /></div>' },
  BCard: {
    template: '<div><slot name="header" /><slot /></div>',
  },
  BAlert: {
    props: ['show', 'variant'],
    template:
      '<div role="alert" :data-variant="variant" class="b-alert-stub"><slot /></div>',
  },
  BButton: {
    props: ['disabled', 'variant'],
    emits: ['click'],
    template:
      '<button :disabled="disabled" :data-variant="variant" @click="$emit(\'click\', $event)"><slot /></button>',
  },
  BButtonGroup: { template: '<div><slot /></div>' },
  BSpinner: { template: '<span class="spinner" />' },
  BProgress: { template: '<div class="progress"><slot /></div>' },
  BFormSelect: {
    props: ['modelValue', 'disabled'],
    template: '<select :disabled="disabled"><slot /></select>',
  },
  BFormSelectOption: {
    props: ['value'],
    template: '<option :value="value"><slot /></option>',
  },
  BTable: {
    props: ['items', 'fields'],
    template: `
      <table class="b-table-stub">
        <thead>
          <tr>
            <th v-for="f in fields" :key="f.key">{{ f.label }}</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="(item, idx) in items" :key="idx" class="b-table-row">
            <td v-for="f in fields" :key="f.key">{{ item[f.key] }}</td>
          </tr>
        </tbody>
      </table>
    `,
  },
  // Non-bootstrap view children we don't need to exercise
  GenericTable: {
    props: ['items', 'fields', 'isBusy'],
    template: `
      <table class="generic-table-stub">
        <tbody>
          <tr v-for="(item, idx) in items" :key="idx" class="generic-table-row">
            <td class="cell-operation">{{ item.operation }}</td>
            <td class="cell-status">{{ item.status }}</td>
            <td class="cell-job-id">{{ item.job_id }}</td>
          </tr>
        </tbody>
      </table>
    `,
  },
  TableSearchInput: { template: '<input class="search-stub" />' },
  TableDownloadLinkCopyButtons: { template: '<div />' },
  TablePaginationControls: { template: '<div />' },
};

async function mountView(): Promise<VueWrapper> {
  const router = buildTestRouter();
  await router.push('/admin/manage-annotations');
  await router.isReady();

  const pinia = createPinia();

  const wrapper = mount(ManageAnnotations, {
    global: {
      plugins: [router, pinia],
      stubs: bvnStubs,
      // `v-b-tooltip` is registered globally by the bootstrap-vue-next plugin
      // in app code; in the isolated test mount we don't install the plugin,
      // so we register a no-op directive to silence the "Failed to resolve
      // directive: b-tooltip" warn emitted inside GenericTable's row slot.
      directives: {
        'b-tooltip': { mounted() {}, updated() {} },
      },
    },
  });

  // Let onMounted axios.get calls resolve through MSW before we assert.
  await flushPromises();

  return wrapper;
}

// ---------------------------------------------------------------------------
// Suite
// ---------------------------------------------------------------------------

describe('ManageAnnotations — Phase C.C5 functional spec', () => {
  beforeEach(() => {
    // VITE_API_URL is `undefined` in vitest (no .env.test).  The view builds
    // request URLs as `${import.meta.env.VITE_API_URL}/api/...` — stubbing to
    // empty string yields `/api/...` which MSW intercepts.  Without this,
    // vitest.setup.ts's `onUnhandledRequest: 'error'` fails every request.
    vi.stubEnv('VITE_API_URL', '');

    // Fake timers so we can walk the `useIntervalFn` polling loop manually.
    vi.useFakeTimers();

    installAuxHandlers();
  });

  afterEach(() => {
    vi.useRealTimers();
    vi.unstubAllEnvs();
  });

  // -------------------------------------------------------------------------
  // Happy path: HGNC update submit → poll queued → running → completed
  // -------------------------------------------------------------------------
  it('submits HGNC update and renders completed job in history table after polling', async () => {
    // Sequential poll responses via a closure counter — `server.use(...)`
    // per-test override, not a new B1 handler.  Shapes follow R/Plumber's
    // array-wrapped scalar convention (CLAUDE.md §R/Plumber returns JSON
    // scalars as arrays).
    let pollCount = 0;
    server.use(
      http.get('/api/jobs/:job_id/status', () => {
        pollCount += 1;
        if (pollCount === 1) {
          return HttpResponse.json({
            job_id: ['hgnc-update-2025-07-01'],
            status: ['queued'],
            step: ['Waiting for worker...'],
          });
        }
        if (pollCount === 2) {
          return HttpResponse.json({
            job_id: ['hgnc-update-2025-07-01'],
            status: ['running'],
            step: ['Downloading HGNC data...'],
            progress: { current: [120], total: [500] },
          });
        }
        return HttpResponse.json({
          job_id: ['hgnc-update-2025-07-01'],
          status: ['completed'],
          step: ['Done'],
          result: [{ rows_updated: 42 }],
        });
      })
    );

    // Override `/api/jobs/history` so that after the watcher refires it on
    // completion, the table renders a row for our new HGNC job.
    server.use(
      http.get('/api/jobs/history', () =>
        HttpResponse.json({
          data: [
            {
              job_id: ['hgnc-update-2025-07-01'],
              job_type: ['hgnc_update'],
              operation: ['hgnc_update'],
              status: ['completed'],
              submitted_at: ['2025-07-01 00:00:00'],
              completed_at: ['2025-07-01 00:05:12'],
              duration_seconds: [312],
              error_message: [null],
              submitted_by: ['alice_admin'],
            },
          ],
          meta: { count: [1], limit: [50] },
        })
      )
    );

    const wrapper = await mountView();

    // Click "Update HGNC Data".  Find the button by its visible label — the
    // view has several primary buttons, so we filter by text content.
    const buttons = wrapper.findAll('button');
    const hgncButton = buttons.find((b) => b.text().includes('Update HGNC Data'));
    expect(hgncButton, 'expected an "Update HGNC Data" button').toBeDefined();

    await hgncButton!.trigger('click');
    await flushPromises();

    // The submit POST has resolved; useAsyncJob.startJob() flipped status to
    // 'accepted' and resumed the 3s interval.  Walk it: each advance triggers
    // one poll cycle, flushPromises drains the MSW → axios → reactive update.
    await vi.advanceTimersByTimeAsync(3000); // poll #1 — queued
    await flushPromises();
    await vi.advanceTimersByTimeAsync(3000); // poll #2 — running
    await flushPromises();
    await vi.advanceTimersByTimeAsync(3000); // poll #3 — completed (terminal)
    await flushPromises();
    // The completed watcher calls fetchJobHistory(); let that axios round-trip
    // settle too.
    await flushPromises();

    // Sanity: the status endpoint was polled at least three times.
    expect(pollCount).toBeGreaterThanOrEqual(3);

    // Final assertion: the history table now contains the completed HGNC row.
    const rows = wrapper.findAll('.generic-table-row');
    expect(rows.length).toBeGreaterThan(0);
    const html = wrapper.html();
    expect(html).toContain('hgnc-update-2025-07-01');
    expect(html).toContain('completed');
  });

  // -------------------------------------------------------------------------
  // Error path: ontology update returns Phase 76 `status = "blocked"` shape
  // -------------------------------------------------------------------------
  it('renders the Phase 76 blocked-update alert with force-apply affordance', async () => {
    // Ontology submit is not in B1 — per-test override (test-local, not a
    // new handler in the shared table).
    server.use(
      http.put('/api/admin/update_ontology_async', () =>
        HttpResponse.json({
          message: 'Ontology update job submitted.',
          job_id: ['ontology-blocked-job-1'],
        })
      )
    );

    // User list for the "Assign to" dropdown inside the blocked alert.
    server.use(
      http.get('/api/user/list', () => HttpResponse.json([])),
      http.get('/api/jobs/history', () =>
        HttpResponse.json({ data: [], meta: { count: [0], limit: [50] } })
      )
    );

    // The same sequential-closure pattern, but the terminal response carries
    // `result.status = ["blocked"]` (Phase 76 lowercase — CLAUDE.md
    // §Ontology Update Safeguard).  Every call from poll #3 onward returns
    // the completed+blocked shape because the view's ontologyJob completed
    // watcher does a follow-up GET on the same endpoint before it reads
    // result.status.
    let pollCount = 0;
    const completedBlockedResponse = {
      job_id: ['ontology-blocked-job-1'],
      status: ['completed'],
      step: ['Blocked — manual review required'],
      result: {
        // NOTE: result is a plain object (not array-wrapped) because the
        // view's unwrapValue() passes objects through unchanged and reads
        // scalar fields per key.
        status: ['blocked'],
        blocked_job_id: ['ontology-blocked-job-1'],
        critical_count: [2],
        auto_fixable_count: [3],
        total_affected: [5],
        critical_entities: [
          {
            disease_ontology_id_version: ['OMIM:123456.2020-01-01'],
            disease_ontology_name: ['Rare Disease A'],
            hgnc_id: ['HGNC:1001'],
            hpo_mode_of_inheritance_term: ['Autosomal dominant'],
          },
          {
            disease_ontology_id_version: ['OMIM:654321.2020-01-01'],
            disease_ontology_name: ['Rare Disease B'],
            hgnc_id: ['HGNC:2002'],
            hpo_mode_of_inheritance_term: ['Autosomal recessive'],
          },
        ],
        auto_fixes: [
          {
            old_version: ['OMIM:999999.2019-01-01'],
            new_version: ['OMIM:999999.2024-01-01'],
            fix_type: ['exact_id'],
          },
        ],
      },
    };
    server.use(
      http.get('/api/jobs/:job_id/status', () => {
        pollCount += 1;
        if (pollCount === 1) {
          return HttpResponse.json({
            job_id: ['ontology-blocked-job-1'],
            status: ['queued'],
            step: ['Waiting...'],
          });
        }
        if (pollCount === 2) {
          return HttpResponse.json({
            job_id: ['ontology-blocked-job-1'],
            status: ['running'],
            step: ['Scanning ontology versions...'],
          });
        }
        return HttpResponse.json(completedBlockedResponse);
      })
    );

    const wrapper = await mountView();

    const buttons = wrapper.findAll('button');
    const ontologyButton = buttons.find((b) =>
      b.text().includes('Update Ontology Annotations')
    );
    expect(
      ontologyButton,
      'expected an "Update Ontology Annotations" button'
    ).toBeDefined();

    await ontologyButton!.trigger('click');
    await flushPromises();

    // Walk the polling loop: queued → running → completed+blocked.
    await vi.advanceTimersByTimeAsync(3000); // poll #1 — queued
    await flushPromises();
    await vi.advanceTimersByTimeAsync(3000); // poll #2 — running
    await flushPromises();
    await vi.advanceTimersByTimeAsync(3000); // poll #3 — completed (terminal)
    await flushPromises();
    // The ontologyJob completed watcher fires a follow-up axios.get and an
    // axios.get on /api/user/list for the force-apply dropdown.  Drain.
    await flushPromises();
    await flushPromises();

    // Sanity: we polled (poll #3 may also be the follow-up GET — either way
    // the counter advances at least three times).
    expect(pollCount).toBeGreaterThanOrEqual(3);

    // The blocked alert should now be rendered.
    const html = wrapper.html();
    expect(html).toContain('Ontology Update Blocked');

    // Critical-count and auto-fixable badges reflect the result payload.
    expect(html).toContain('2 critical');
    expect(html).toContain('3 auto-fixable');

    // The descriptive paragraph interpolates the critical count.
    expect(html).toContain('2 entity-referenced');

    // Critical-entities table surfaces the disease names from the payload.
    expect(html).toContain('Rare Disease A');
    expect(html).toContain('Rare Disease B');

    // The force-apply UI affordance is rendered (button label, not handler).
    // Phase E4 will unpin the it.todo below to actually assert the PUT call.
    const forceApplyButton = wrapper
      .findAll('button')
      .find((b) => b.text().includes('Force Apply'));
    expect(
      forceApplyButton,
      'expected a "Force Apply" button inside the blocked alert'
    ).toBeDefined();
  });

  // -------------------------------------------------------------------------
  // Locked handshake for Phase E4 (exact string from Appendix C)
  // -------------------------------------------------------------------------
  // Phase E4 (`rewrite-manage-annotations`) unpins this after rewriting the
  // view with `useAsyncJob` + `useTableData`.  Do NOT rename or fulfil it
  // here — it is the handshake contract for the downstream phase.
  it.todo(
    'TODO: verify the force-apply flow fires PUT /api/admin/force_apply_ontology with the correct blocked_job_id'
  );
});
