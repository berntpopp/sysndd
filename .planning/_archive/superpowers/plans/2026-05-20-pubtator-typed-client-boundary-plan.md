# PubTator Typed Client Boundary Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the missing safety-net specs, then migrate `PubtatorNDDGenes.vue` off raw Axios and `VITE_API_URL` URL construction onto typed publication clients.

**Architecture:** Keep public routes and visible Vue behavior stable. Add tests before production changes, strengthen the existing publication typed-client contract, then replace only the PubTator component request boundary. Keep `TablesPhenotypes.vue` and backend endpoint splitting as later phases after their new specs pass.

**Tech Stack:** Vue 3, TypeScript, Vitest, MSW, Vue Test Utils, Pinia, R/testthat, Plumber endpoint source parsing, SysNDD `make code-quality-audit`.

---

## Execution Rules

- Work in `/home/bernt-popp/development/sysndd` on a normal branch. Do not create git worktrees.
- Do not rerun the old top-10 checklist; it is complete via PR #355 and PR #359.
- Do not split `admin_endpoints.R` or `publication_endpoints.R` in this PR.
- Do not change public API routes, frontend behavior, or typed API-client boundaries.
- Do not revert unrelated user changes.
- Update `scripts/code-quality-file-size-baseline.tsv` downward only, and only if a touched production file shrinks below its current baseline.
- Follow TDD for each implementation slice: write/strengthen tests, run them against unchanged behavior where applicable, make the smallest cohesive production change, rerun the tests.
- Commit each cohesive slice separately.

## File Map

- Create: `app/src/components/analyses/PubtatorNDDGenes.spec.ts`
  - Component safety net for PubTator gene list loading, filters, pagination, expanded publication loading, emitted novel count, and export behavior.
- Create: `app/src/components/tables/TablesPhenotypes.spec.ts`
  - Component safety net for typed phenotype option/entity loading, selected phenotype behavior, URL-derived filter state, empty selection, and XLSX export.
- Create: `api/tests/testthat/test-endpoint-admin.R`
  - Endpoint route/auth/validation safety net for admin routes before any future split.
- Create: `api/tests/testthat/test-endpoint-publication.R`
  - Endpoint route/auth/validation safety net for publication and PubTator routes before any future split.
- Modify: `app/src/api/publication.spec.ts`
  - Strengthen parameter and Blob-helper coverage for `listPubtatorGenes()` and `listPubtatorTable()`.
- Modify if needed: `app/src/api/publication.ts`
  - Keep helper signatures typed; only add or adjust types if the new tests expose a missing contract.
- Modify: `app/src/components/analyses/PubtatorNDDGenes.vue`
  - Remove Axios injection and `VITE_API_URL` request construction; use `listPubtatorGenes()` and `listPubtatorTable()`.
- Modify if shrunk: `scripts/code-quality-file-size-baseline.tsv`
  - Lower `app/src/components/analyses/PubtatorNDDGenes.vue` only if the file’s line count decreases below its current baseline.

## Task 1: PubTator Component Safety Net

**Files:**
- Create: `app/src/components/analyses/PubtatorNDDGenes.spec.ts`
- Read only: `app/src/components/analyses/PubtatorNDDGenes.vue`
- Read only: `app/src/test-utils/mocks/server.ts`

- [ ] **Step 1: Add the focused component spec**

Create `app/src/components/analyses/PubtatorNDDGenes.spec.ts` with this structure. Keep the data small and assert behavior through rendered output, emitted events, MSW-observed query params, and mocked export/toast calls.

```ts
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { flushPromises, mount } from '@vue/test-utils';
import { createPinia, setActivePinia } from 'pinia';
import { createRouter, createMemoryHistory } from 'vue-router';
import { http, HttpResponse } from 'msw';

import '@/plugins/axios';
import axios from '@/plugins/axios';
import PubtatorNDDGenes from './PubtatorNDDGenes.vue';
import { server } from '@/test-utils/mocks/server';

const makeToastSpy = vi.fn();
const exportToExcelSpy = vi.fn().mockResolvedValue(undefined);

vi.mock('@/composables/useExcelExport', async () => {
  const { ref } = await import('vue');
  return {
    useExcelExport: () => ({
      isExporting: ref(false),
      exportToExcel: exportToExcelSpy,
    }),
  };
});

vi.mock('@/composables', async () => {
  const actual = await vi.importActual<typeof import('@/composables')>('@/composables');
  const { ref, computed } = await import('vue');
  return {
    ...actual,
    useToast: () => ({ makeToast: makeToastSpy }),
    useTableData: (opts: { pageSizeInput: number; sortInput: string; pageAfterInput: string }) => ({
      items: ref([]),
      totalRows: ref(0),
      perPage: ref(opts.pageSizeInput),
      currentPage: ref(1),
      sortBy: ref([]),
      sort: ref(opts.sortInput),
      loading: ref(false),
      isBusy: ref(false),
      downloading: ref(false),
      currentItemID: ref(Number(opts.pageAfterInput) || 0),
      prevItemID: ref(null),
      nextItemID: ref(null),
      lastItemID: ref(null),
      filter_string: ref(''),
      pageOptions: ref([10, 25, 50]),
      removeFiltersButtonTitle: computed(() => 'Remove filters'),
      removeFiltersButtonVariant: computed(() => 'outline-secondary'),
    }),
  };
});

function makeRouter() {
  return createRouter({
    history: createMemoryHistory(),
    routes: [{ path: '/', component: { template: '<div />' } }],
  });
}

async function mountSubject(props = {}) {
  setActivePinia(createPinia());
  const router = makeRouter();
  await router.push('/analyses/pubtator-genes');
  await router.isReady();

  const wrapper = mount(PubtatorNDDGenes, {
    props,
    global: {
      plugins: [router],
      provide: { axios },
      directives: { 'b-tooltip': {} },
      stubs: {
        AnalysisPanel: { template: '<section><h2>{{ title }}</h2><p>{{ description }}</p><slot name="actions" /><slot /></section>', props: ['title', 'description'] },
        InlineHelpBadge: { template: '<button />' },
        BPopover: { template: '<div><slot name="title" /><slot /></div>' },
        BSpinner: { template: '<div data-testid="spinner" />' },
        BRow: { template: '<div><slot /></div>' },
        BCol: { template: '<div><slot /></div>' },
        BContainer: { template: '<div><slot /></div>' },
        BInputGroup: { template: '<label><slot /></label>' },
        BFormSelect: { template: '<select @change="$emit(`change`)"><slot /></select>' },
        TableSearchInput: { template: '<input aria-label="table-search" @input="$emit(`input`, $event.target.value)" />' },
        TablePaginationControls: {
          template: '<nav><button data-testid="next-page" @click="$emit(`page-change`, 2)">next</button><button data-testid="per-page" @click="$emit(`per-page-change`, 25)">25</button></nav>',
        },
        TableDownloadLinkCopyButtons: { template: '<div />' },
        GeneBadge: { template: '<a :href="linkTo">{{ symbol }}</a>', props: ['symbol', 'linkTo'] },
        BBadge: { template: '<span><slot /></span>' },
        BButton: { template: '<button :disabled="disabled" @click="$emit(`click`)"><slot /></button>', props: ['disabled'] },
        BFormInput: { template: '<input />' },
        BTable: {
          props: ['items'],
          emits: ['update:sort-by'],
          data: () => ({ expandedGene: null }),
          template: '<table><tbody><template v-for="item in items" :key="item.gene_symbol"><tr><td>{{ item.gene_symbol }}</td><td>{{ item.gene_name }}</td><td>{{ item.publication_count }}</td><td>{{ item.oldest_pub_date }}</td><td>{{ item.is_novel === 1 ? `Literature Only` : `Curated` }}</td><td>{{ item.pmids }}</td><td><slot name="cell(actions)" :item="item" :expansion-showing="expandedGene === item.gene_symbol" :toggle-expansion="() => { expandedGene = expandedGene === item.gene_symbol ? null : item.gene_symbol }" /></td></tr><tr v-if="expandedGene === item.gene_symbol"><td colspan="7"><slot name="row-expansion" :item="item" /></td></tr></template></tbody></table>',
        },
      },
    },
  });
  await flushPromises();
  return wrapper;
}

beforeEach(() => {
  makeToastSpy.mockClear();
  exportToExcelSpy.mockClear();
  vi.stubEnv('VITE_API_URL', '');
  vi.stubEnv('VITE_URL', 'https://sysndd.test');
});

afterEach(() => {
  vi.unstubAllEnvs();
});
```

Add behavior tests after the harness:

```ts
describe('PubtatorNDDGenes', () => {
  it('loads gene rows with cursor params and emits the novel count', async () => {
    let observed: URLSearchParams | null = null;
    server.use(
      http.get('/api/publication/pubtator/genes', ({ request }) => {
        observed = new URL(request.url).searchParams;
        return HttpResponse.json({
          meta: [{ totalItems: 2, totalPages: 1, currentPage: 1, currentItemID: 0, fspec: [] }],
          data: [
            { gene_symbol: 'MECP2', gene_name: 'methyl CpG binding protein 2', publication_count: 4, oldest_pub_date: '2001-01-01', is_novel: 1, pmids: '123,456' },
            { gene_symbol: 'SCN2A', gene_name: 'sodium channel', publication_count: 9, oldest_pub_date: '1999-01-01', is_novel: 0, pmids: '789' },
          ],
        });
      })
    );

    const wrapper = await mountSubject();

    expect(wrapper.text()).toContain('MECP2');
    expect(wrapper.text()).toContain('Literature Only');
    expect(wrapper.emitted('novel-count')?.at(-1)).toEqual([1]);
    expect((observed as URLSearchParams).get('sort')).toBe('-is_novel,oldest_pub_date');
    expect((observed as URLSearchParams).get('page_size')).toBe('10');
  });

  it('loads expanded publication details through the PubTator table endpoint', async () => {
    let observed: URLSearchParams | null = null;
    server.use(
      http.get('/api/publication/pubtator/genes', () =>
        HttpResponse.json({
          meta: [{ totalItems: 1, totalPages: 1, currentPage: 1, currentItemID: 0, fspec: [] }],
          data: [{ gene_symbol: 'MECP2', gene_name: 'methyl CpG binding protein 2', publication_count: 2, oldest_pub_date: '2001-01-01', is_novel: 1, pmids: '123,456' }],
        })
      ),
      http.get('/api/publication/pubtator/table', ({ request }) => {
        observed = new URL(request.url).searchParams;
        return HttpResponse.json({
          data: [{ search_id: 1, pmid: 123, title: 'MECP2 paper', journal: 'Journal', date: '2001-01-01', score: 8, gene_symbols: 'MECP2', text_hl: 'MECP2 is linked to NDD.' }],
        });
      })
    );

    const wrapper = await mountSubject();
    await wrapper.findAll('button').find((button) => button.text().includes('Show'))!.trigger('click');
    await flushPromises();

    expect((observed as URLSearchParams).get('filter')).toBe('any(pmid,123,456)');
    expect((observed as URLSearchParams).get('page_size')).toBe('2');
    expect(wrapper.text()).toContain('MECP2 paper');
  });

  it('exports visible rows with stable headers and toast behavior', async () => {
    server.use(
      http.get('/api/publication/pubtator/genes', () =>
        HttpResponse.json({
          meta: [{ totalItems: 1, totalPages: 1, currentPage: 1, currentItemID: 0, fspec: [] }],
          data: [{ gene_symbol: 'MECP2', gene_name: 'methyl CpG binding protein 2', publication_count: 2, oldest_pub_date: '2001-01-01', is_novel: 1, pmids: '123,456' }],
        })
      )
    );

    const wrapper = await mountSubject();
    await wrapper.findAll('button').find((button) => button.text().includes('Export'))!.trigger('click');
    await flushPromises();

    expect(exportToExcelSpy).toHaveBeenCalledWith(
      [{ gene_symbol: 'MECP2', gene_name: 'methyl CpG binding protein 2', publication_count: 2, oldest_pub_date: '2001-01-01', source: 'Literature Only', pmids: '123,456' }],
      expect.objectContaining({
        sheetName: 'Gene Prioritization',
        headers: expect.objectContaining({ gene_symbol: 'Gene Symbol', pmids: 'PMIDs' }),
      })
    );
    expect(makeToastSpy).toHaveBeenCalledWith('Excel file downloaded', 'Success', 'success');
  });
});
```

- [ ] **Step 2: Run the new spec against unchanged production behavior**

Run:

```bash
cd app && npx vitest run src/components/analyses/PubtatorNDDGenes.spec.ts
```

Expected: PASS after any harness-only fixes. If it fails because the spec cannot mount the component, fix the spec harness. If it fails because the component uses raw Axios but still hits the same MSW routes, do not change production code yet.

- [ ] **Step 3: Commit the PubTator component safety net**

Run:

```bash
git add app/src/components/analyses/PubtatorNDDGenes.spec.ts
git commit -m "test: cover PubTator gene component behavior"
```

Expected: one test-only commit.

## Task 2: TablesPhenotypes Component Safety Net

**Files:**
- Create: `app/src/components/tables/TablesPhenotypes.spec.ts`
- Read only: `app/src/components/tables/TablesPhenotypes.vue`
- Read only: `app/src/api/phenotype.ts`

- [ ] **Step 1: Add component coverage for current typed phenotype behavior**

Create `app/src/components/tables/TablesPhenotypes.spec.ts`. Use the same Pinia/router/MSW pattern as Task 1, but keep the component’s existing typed clients intact.

Start with this harness:

```ts
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { flushPromises, mount } from '@vue/test-utils';
import { createPinia, setActivePinia } from 'pinia';
import { createRouter, createMemoryHistory } from 'vue-router';
import { http, HttpResponse } from 'msw';

import TablesPhenotypes from './TablesPhenotypes.vue';
import { server } from '@/test-utils/mocks/server';

const makeToastSpy = vi.fn();
const clickSpy = vi.fn();
const createObjectUrlSpy = vi.fn(() => 'blob:phenotype-search');

vi.mock('@/composables', async () => {
  const actual = await vi.importActual<typeof import('@/composables')>('@/composables');
  return {
    ...actual,
    useToast: () => ({ makeToast: makeToastSpy }),
    useUrlParsing: () => ({
      filterObjToStr: (filter: Record<string, { content: unknown; operator: string }>) => {
        const selected = filter.modifier_phenotype_id?.content;
        const values = Array.isArray(selected) ? selected.join(',') : '';
        const operator = filter.modifier_phenotype_id?.operator || 'all';
        return `${operator}(modifier_phenotype_id,${values})`;
      },
      filterStrToObj: (filterString: string, filter: Record<string, { content: unknown; operator: string }>) => {
        const next = { ...filter, modifier_phenotype_id: { ...filter.modifier_phenotype_id } };
        if (filterString.includes('HP:0001250')) {
          next.modifier_phenotype_id.content = ['HP:0001250'];
        }
        return next;
      },
      sortStringToVariables: () => ({ sortBy: [{ key: 'entity_id', order: 'desc' }] }),
    }),
    useColorAndSymbols: () => ({ ndd_icon_text: { Yes: 'NDD phenotype' } }),
    useText: () => ({ truncate: (value: string) => value }),
  };
});

function makeRouter() {
  return createRouter({
    history: createMemoryHistory(),
    routes: [{ path: '/', component: { template: '<div />' } }],
  });
}

async function mountSubject(props = {}) {
  setActivePinia(createPinia());
  const router = makeRouter();
  await router.push('/Tables/Phenotypes');
  await router.isReady();

  const wrapper = mount(TablesPhenotypes, {
    props,
    global: {
      plugins: [router],
      directives: { 'b-tooltip': {} },
      stubs: {
        TableShell: { template: '<section><slot name="actions" /><slot name="toolbar" /><slot name="loading" /><slot /></section>' },
        TableLoadingState: { template: '<div />' },
        TablePaginationControls: { template: '<nav />' },
        PhenotypesMobileRows: { template: '<div />' },
        EntityBadge: { template: '<a>{{ entityId }}</a>', props: ['entityId'] },
        GeneBadge: { template: '<a>{{ symbol }}</a>', props: ['symbol'] },
        DiseaseBadge: { template: '<span>{{ name }}</span>', props: ['name'] },
        InheritanceBadge: { template: '<span>{{ fullName }}</span>', props: ['fullName'] },
        CategoryIcon: { template: '<span />' },
        NddIcon: { template: '<span />' },
        BRow: { template: '<div><slot /></div>' },
        BCol: { template: '<div><slot /></div>' },
        BButton: { template: '<button @click="$emit(`click`)"><slot /></button>' },
        BSpinner: { template: '<span />' },
        BDropdown: { template: '<div><slot name="button-content" /><slot /></div>', methods: { show() {} } },
        BDropdownForm: { template: '<form><slot /></form>' },
        BDropdownDivider: { template: '<hr />' },
        BDropdownItemButton: { template: '<button @click="$emit(`click`)"><slot /></button>' },
        BDropdownText: { template: '<span><slot /></span>' },
        BFormInput: { template: '<input />' },
        BFormSelect: { template: '<select />' },
        BFormSelectOption: { template: '<option><slot /></option>' },
        BCard: { template: '<div><slot /></div>' },
        BTable: {
          props: ['items'],
          template: '<table><tbody><tr v-for="item in items" :key="item.entity_id"><td>{{ item.entity_id }}</td><td>{{ item.symbol }}</td><td>{{ item.disease_ontology_name }}</td><td>{{ item.hpo_mode_of_inheritance_term_name }}</td><td>{{ item.category }}</td><td>{{ item.ndd_phenotype_word }}</td></tr></tbody></table>',
        },
      },
    },
  });
  await flushPromises();
  await new Promise((resolve) => setTimeout(resolve, 75));
  await flushPromises();
  return wrapper;
}

interface PhenotypesVm {
  clearAllPhenotypes: () => void;
  setLogicMode: (isOr: boolean) => void;
  requestExcel: () => Promise<void>;
  filter: { modifier_phenotype_id: { content: string[]; operator: string } };
  items: unknown[];
  totalRows: number;
}

beforeEach(() => {
  makeToastSpy.mockClear();
  clickSpy.mockClear();
  createObjectUrlSpy.mockClear();
  vi.stubGlobal('URL', { ...window.URL, createObjectURL: createObjectUrlSpy });
  vi.spyOn(document, 'createElement').mockImplementation(((tagName: string) => {
    const element = document.createElementNS('http://www.w3.org/1999/xhtml', tagName) as HTMLAnchorElement;
    if (tagName === 'a') {
      element.click = clickSpy;
    }
    return element;
  }) as typeof document.createElement);
});

afterEach(() => {
  vi.restoreAllMocks();
  vi.unstubAllGlobals();
});
```

Add these tests:

```ts
describe('TablesPhenotypes', () => {
  it('loads phenotype options and selected phenotype entity rows through typed endpoints', async () => {
    let listQuery: URLSearchParams | null = null;
    let browseQuery: URLSearchParams | null = null;
    server.use(
      http.get('/api/list/phenotype', ({ request }) => {
        listQuery = new URL(request.url).searchParams;
        return HttpResponse.json({
          data: [{ HPO_term: 'Intellectual disability', phenotype_id: 'HP:0001249' }],
        });
      }),
      http.get('/api/phenotype/entities/browse', ({ request }) => {
        browseQuery = new URL(request.url).searchParams;
        return HttpResponse.json({
          meta: [{ fspec: [], totalItems: 1, currentPage: 1, totalPages: 1, currentItemID: 0, executionTime: 3 }],
          data: [{ entity_id: 'E1', symbol: 'MECP2', disease_ontology_name: 'Rett syndrome', hpo_mode_of_inheritance_term_name: 'X-linked', category: 'Definitive', ndd_phenotype_word: 'Yes' }],
        });
      })
    );

    const wrapper = await mountSubject();

    expect((listQuery as URLSearchParams).get('tree')).toBe('FALSE');
    expect((browseQuery as URLSearchParams).get('sort')).toBe('entity_id');
    expect((browseQuery as URLSearchParams).get('page_size')).toBe('10');
    expect((browseQuery as URLSearchParams).get('format')).toBe('json');
    expect((browseQuery as URLSearchParams).get('filter')).toContain('HP:0001249');
    expect(wrapper.text()).toContain('MECP2');
  });

  it('does not request entity rows when no phenotype is selected', async () => {
    let browseCalls = 0;
    server.use(
      http.get('/api/list/phenotype', () => HttpResponse.json({ data: [] })),
      http.get('/api/phenotype/entities/browse', () => {
        browseCalls += 1;
        return HttpResponse.json({ meta: [{ fspec: [], totalItems: 0, currentPage: 1, totalPages: 1 }], data: [] });
      })
    );

    const wrapper = await mountSubject();
    const vm = wrapper.vm as unknown as PhenotypesVm;
    const callsAfterMount = browseCalls;
    vm.clearAllPhenotypes();
    await flushPromises();

    expect(vm.items).toEqual([]);
    expect(vm.totalRows).toBe(0);
    expect(browseCalls).toBe(callsAfterMount);
  });

  it('exports all selected phenotype rows as phenotype_search.xlsx', async () => {
    let exportQuery: URLSearchParams | null = null;
    server.use(
      http.get('/api/list/phenotype', () => HttpResponse.json({ data: [] })),
      http.get('/api/phenotype/entities/browse', ({ request }) => {
        const query = new URL(request.url).searchParams;
        if (query.get('format') === 'xlsx') {
          exportQuery = query;
          return new HttpResponse(new Uint8Array([0x50, 0x4b]), { status: 200 });
        }
        return HttpResponse.json({ meta: [{ fspec: [], totalItems: 1, currentPage: 1, totalPages: 1, currentItemID: 0 }], data: [] });
      })
    );

    const wrapper = await mountSubject();
    await (wrapper.vm as unknown as PhenotypesVm).requestExcel();
    await flushPromises();

    expect((exportQuery as URLSearchParams).get('page_after')).toBe('0');
    expect((exportQuery as URLSearchParams).get('page_size')).toBe('all');
    expect((exportQuery as URLSearchParams).get('format')).toBe('xlsx');
    expect(clickSpy).toHaveBeenCalled();
  });
});
```

- [ ] **Step 2: Run the new spec against unchanged production behavior**

Run:

```bash
cd app && npx vitest run src/components/tables/TablesPhenotypes.spec.ts
```

Expected: PASS after spec-harness fixes only. Do not edit `TablesPhenotypes.vue` in this task.

- [ ] **Step 3: Commit the TablesPhenotypes safety net**

Run:

```bash
git add app/src/components/tables/TablesPhenotypes.spec.ts
git commit -m "test: cover phenotype table component behavior"
```

Expected: one test-only commit.

## Task 3: Admin Endpoint Safety Net

**Files:**
- Create: `api/tests/testthat/test-endpoint-admin.R`
- Read only: `api/endpoints/admin_endpoints.R`
- Read only: `api/tests/testthat/test-endpoint-phenotype.R`
- Read only: `api/tests/testthat/test-endpoint-auth.R`

- [ ] **Step 1: Add structural endpoint tests**

Create `api/tests/testthat/test-endpoint-admin.R` using the existing source-parsing pattern. Start with route-surface/auth checks that do not require a live DB.

```r
library(testthat)

admin_endpoint_path <- function() {
  file.path(get_api_dir(), "endpoints", "admin_endpoints.R")
}

admin_source <- function() {
  readLines(admin_endpoint_path(), warn = FALSE)
}

admin_body_blob <- function(decorator_regex) {
  src <- admin_source()
  dec_hits <- grep(decorator_regex, src)
  if (length(dec_hits) == 0L) {
    stop("Decorator not found in admin_endpoints.R: ", decorator_regex)
  }
  dec_idx <- dec_hits[[1L]]
  next_dec <- grep("^#\\*\\s+@(get|post|put|delete)\\b", src)
  after_idx <- next_dec[next_dec > dec_idx]
  after <- if (length(after_idx) == 0L) length(src) + 1L else after_idx[[1L]]
  paste(src[dec_idx:(after - 1L)], collapse = "\n")
}

expect_admin_guard <- function(body_blob) {
  expect_match(body_blob, "require_role\\(")
  expect_match(body_blob, "Administrator")
}

test_that("admin_endpoints.R exposes ontology async and force-apply route surface", {
  with_test_db_transaction({
    src <- admin_source()
    expect_true(any(grepl("^#\\*\\s+@put\\s+update_ontology_async\\s*$", src)))
    expect_true(any(grepl("^#\\*\\s+@put\\s+force_apply_ontology\\s*$", src)))
  })
})

test_that("admin ontology mutation routes require Administrator role", {
  with_test_db_transaction({
    expect_admin_guard(admin_body_blob("^#\\*\\s+@put\\s+update_ontology_async\\s*$"))
    expect_admin_guard(admin_body_blob("^#\\*\\s+@put\\s+force_apply_ontology\\s*$"))
  })
})

test_that("force_apply_ontology validates blocked_job_id before job submission", {
  with_test_db_transaction({
    body <- admin_body_blob("^#\\*\\s+@put\\s+force_apply_ontology\\s*$")
    expect_match(body, "blocked_job_id")
    expect_match(body, "400")
    expect_match(body, "submit_async_job|create_async_job|enqueue")
  })
})
```

Add additional checks for any NDDScore import/admin routes present in the file:

```r
test_that("NDDScore admin routes keep Administrator guard and async job boundary", {
  with_test_db_transaction({
    src <- admin_source()
    nddscore_decorators <- grep("^#\\*\\s+@(post|put|get).*nddscore", src, value = TRUE, ignore.case = TRUE)
    expect_gt(length(nddscore_decorators), 0L)
    nddscore_blocks <- lapply(nddscore_decorators, function(decorator) {
      admin_body_blob(paste0("^", gsub("([\\W])", "\\\\\\1", decorator), "\\s*$"))
    })
    expect_true(any(vapply(nddscore_blocks, grepl, logical(1), pattern = "require_role\\(")))
    expect_true(any(vapply(nddscore_blocks, grepl, logical(1), pattern = "nddscore_import|submit_async_job|async")))
  })
})
```

- [ ] **Step 2: Run the endpoint spec**

Run:

```bash
cd api && Rscript -e "testthat::test_file('tests/testthat/test-endpoint-admin.R')"
```

Expected: PASS. If host R cannot load packages or connect to the configured test DB, record the exact error and run the documented container fallback if available:

```bash
docker exec sysndd-api-1 Rscript -e "testthat::test_file('/app/tests/testthat/test-endpoint-admin.R')"
```

- [ ] **Step 3: Commit the admin endpoint safety net**

Run:

```bash
git add api/tests/testthat/test-endpoint-admin.R
git commit -m "test: cover admin endpoint route surface"
```

Expected: one test-only commit.

## Task 4: Publication Endpoint Safety Net

**Files:**
- Create: `api/tests/testthat/test-endpoint-publication.R`
- Read only: `api/endpoints/publication_endpoints.R`
- Read only: `api/tests/testthat/test-endpoint-phenotype.R`
- Read only: `api/tests/testthat/test-unit-publication-endpoint-helpers.R`

- [ ] **Step 1: Add publication endpoint route/auth/validation coverage**

Create `api/tests/testthat/test-endpoint-publication.R` with structural route checks and body-slice assertions.

```r
library(testthat)

publication_endpoint_path <- function() {
  file.path(get_api_dir(), "endpoints", "publication_endpoints.R")
}

publication_source <- function() {
  readLines(publication_endpoint_path(), warn = FALSE)
}

publication_body_blob <- function(decorator_regex) {
  src <- publication_source()
  dec_hits <- grep(decorator_regex, src)
  if (length(dec_hits) == 0L) {
    stop("Decorator not found in publication_endpoints.R: ", decorator_regex)
  }
  dec_idx <- dec_hits[[1L]]
  next_dec <- grep("^#\\*\\s+@(get|post|put|delete)\\b", src)
  after_idx <- next_dec[next_dec > dec_idx]
  after <- if (length(after_idx) == 0L) length(src) + 1L else after_idx[[1L]]
  paste(src[dec_idx:(after - 1L)], collapse = "\n")
}

test_that("publication_endpoints.R exposes public read route surface", {
  with_test_db_transaction({
    src <- publication_source()
    expect_true(any(grepl("^#\\*\\s+@get\\s+/stats\\s*$", src)))
    expect_true(any(grepl("^#\\*\\s+@get\\s+<pmid>\\s*$", src)))
    expect_true(any(grepl("^#\\*\\s+@get\\s+pubtator/search\\s*$", src)))
    expect_true(any(grepl("^#\\*\\s+@get\\s+/\\s*$", src)))
    expect_true(any(grepl("^#\\*\\s+@get\\s+/pubtator/table\\s*$", src)))
    expect_true(any(grepl("^#\\*\\s+@get\\s+/pubtator/genes\\s*$", src)))
  })
})

test_that("publication public read routes do not require Administrator role", {
  with_test_db_transaction({
    public_routes <- c(
      "^#\\*\\s+@get\\s+/stats\\s*$",
      "^#\\*\\s+@get\\s+<pmid>\\s*$",
      "^#\\*\\s+@get\\s+pubtator/search\\s*$",
      "^#\\*\\s+@get\\s+/\\s*$",
      "^#\\*\\s+@get\\s+/pubtator/table\\s*$",
      "^#\\*\\s+@get\\s+/pubtator/genes\\s*$"
    )
    for (route in public_routes) {
      expect_false(grepl("require_role\\(", publication_body_blob(route)))
    }
  })
})

test_that("PubTator list routes keep cursor pagination and xlsx branches", {
  with_test_db_transaction({
    table_body <- publication_body_blob("^#\\*\\s+@get\\s+/pubtator/table\\s*$")
    genes_body <- publication_body_blob("^#\\*\\s+@get\\s+/pubtator/genes\\s*$")
    expect_match(table_body, "page_after")
    expect_match(table_body, "page_size")
    expect_match(table_body, "\"xlsx\"")
    expect_match(genes_body, "page_after")
    expect_match(genes_body, "page_size")
    expect_match(genes_body, "\"xlsx\"")
  })
})

test_that("PubTator mutation routes are present for backend auth follow-up", {
  with_test_db_transaction({
    mutation_routes <- c(
      "^#\\*\\s+@post\\s+/pubtator/backfill-genes\\s*$",
      "^#\\*\\s+@post\\s+/pubtator/update\\s*$",
      "^#\\*\\s+@post\\s+/pubtator/update/submit\\s*$",
      "^#\\*\\s+@post\\s+/pubtator/clear-cache\\s*$"
    )
    for (route in mutation_routes) {
      expect_silent(publication_body_blob(route))
    }
  })
})

test_that("PubTator cache-status and update routes validate required query input", {
  with_test_db_transaction({
    cache_body <- publication_body_blob("^#\\*\\s+@get\\s+/pubtator/cache-status\\s*$")
    update_body <- publication_body_blob("^#\\*\\s+@post\\s+/pubtator/update\\s*$")
    submit_body <- publication_body_blob("^#\\*\\s+@post\\s+/pubtator/update/submit\\s*$")
    expect_match(cache_body, "query")
    expect_match(cache_body, "400")
    expect_match(update_body, "query")
    expect_match(update_body, "400")
    expect_match(submit_body, "query")
    expect_match(submit_body, "400")
  })
})

test_that("PubTator async submit keeps duplicate-job response path", {
  with_test_db_transaction({
    submit_body <- publication_body_blob("^#\\*\\s+@post\\s+/pubtator/update/submit\\s*$")
    expect_match(submit_body, "check_duplicate_job")
    expect_match(submit_body, "409")
    expect_match(submit_body, "already running")
  })
})
```

Do not add a `require_role()` assertion for the publication mutation routes in
this safety-net PR. Current production code has no in-handler guards there, so a
guard assertion would fail before the PubTator typed-client migration. Record
the missing guards as a backend security follow-up in the PR notes instead.

- [ ] **Step 2: Run the publication endpoint spec**

Run:

```bash
cd api && Rscript -e "testthat::test_file('tests/testthat/test-endpoint-publication.R')"
```

Expected: PASS. If host R cannot load packages or connect to the configured test DB, record the exact error and run the documented container fallback if available:

```bash
docker exec sysndd-api-1 Rscript -e "testthat::test_file('/app/tests/testthat/test-endpoint-publication.R')"
```

- [ ] **Step 3: Commit the publication endpoint safety net**

Run:

```bash
git add api/tests/testthat/test-endpoint-publication.R
git commit -m "test: cover publication endpoint route surface"
```

Expected: one test-only commit.

## Task 5: Publication Client Contract Coverage

**Files:**
- Modify: `app/src/api/publication.spec.ts`
- Modify if test exposes a missing type only: `app/src/api/publication.ts`

- [ ] **Step 1: Strengthen `listPubtatorGenes` parameter coverage**

Add this test under `describe('api/publication — listPubtatorGenes', ...)`:

```ts
it('forwards cursor params and forces format=json', async () => {
  let observedQuery: URLSearchParams | null = null;
  const ok: PubtatorGenesResponse = { data: [] };
  server.use(
    http.get('/api/publication/pubtator/genes', ({ request }) => {
      observedQuery = new URL(request.url).searchParams;
      return HttpResponse.json(ok);
    })
  );

  await listPubtatorGenes({
    sort: '-is_novel,oldest_pub_date',
    filter: 'all(publication_count,5)',
    page_after: 25,
    page_size: '10',
    fields: 'gene_symbol,pmids',
  });

  expect((observedQuery as URLSearchParams).get('sort')).toBe('-is_novel,oldest_pub_date');
  expect((observedQuery as URLSearchParams).get('filter')).toBe('all(publication_count,5)');
  expect((observedQuery as URLSearchParams).get('page_after')).toBe('25');
  expect((observedQuery as URLSearchParams).get('page_size')).toBe('10');
  expect((observedQuery as URLSearchParams).get('fields')).toBe('gene_symbol,pmids');
  expect((observedQuery as URLSearchParams).get('format')).toBe('json');
});
```

- [ ] **Step 2: Strengthen `listPubtatorTable` parameter and signal coverage**

Add this test under `describe('api/publication — listPubtatorTable', ...)`:

```ts
it('forwards PMID filter params and accepts request config', async () => {
  let observedQuery: URLSearchParams | null = null;
  const ok: PubtatorTableResponse = { data: [{ pmid: 123 }] };
  server.use(
    http.get('/api/publication/pubtator/table', ({ request }) => {
      observedQuery = new URL(request.url).searchParams;
      return HttpResponse.json(ok);
    })
  );

  const controller = new AbortController();
  const result = await listPubtatorTable(
    {
      filter: 'any(pmid,123,456)',
      fields: 'search_id,pmid,title',
      page_size: '2',
    },
    { signal: controller.signal }
  );

  expect(result.data[0].pmid).toBe(123);
  expect((observedQuery as URLSearchParams).get('filter')).toBe('any(pmid,123,456)');
  expect((observedQuery as URLSearchParams).get('fields')).toBe('search_id,pmid,title');
  expect((observedQuery as URLSearchParams).get('page_size')).toBe('2');
  expect((observedQuery as URLSearchParams).get('format')).toBe('json');
});
```

- [ ] **Step 3: Run the publication client spec**

Run:

```bash
cd app && npx vitest run src/api/publication.spec.ts
```

Expected: PASS after test-only changes. If TypeScript rejects `signal` on the config object, update imports/types in `app/src/api/publication.ts` to preserve `AxiosRequestConfig` support and rerun this command.

- [ ] **Step 4: Commit typed-client coverage**

Run:

```bash
git add app/src/api/publication.spec.ts app/src/api/publication.ts
git commit -m "test: cover PubTator publication client params"
```

Expected: one focused commit. If `publication.ts` was unchanged, Git will ignore it.

## Task 6: Migrate PubtatorNDDGenes To Typed Clients

**Files:**
- Modify: `app/src/components/analyses/PubtatorNDDGenes.vue`
- Modify if assertions need import paths adjusted: `app/src/components/analyses/PubtatorNDDGenes.spec.ts`
- Modify downward only if shrunk: `scripts/code-quality-file-size-baseline.tsv`

- [ ] **Step 1: Remove raw Axios imports and injection**

In `app/src/components/analyses/PubtatorNDDGenes.vue`, remove:

```ts
import { ref, computed, watch, onMounted, onUnmounted, inject } from 'vue';
import type { AxiosInstance } from 'axios';
```

Replace with:

```ts
import { ref, computed, watch, onMounted, onUnmounted } from 'vue';
import { listPubtatorGenes, listPubtatorTable } from '@/api/publication';
```

Delete:

```ts
// Inject axios
const axios = inject<AxiosInstance>('axios');
```

Also remove the now-stale test harness injection from
`app/src/components/analyses/PubtatorNDDGenes.spec.ts`:

```ts
import axios from '@/plugins/axios';
```

and delete the mount option:

```ts
provide: { axios },
```

- [ ] **Step 2: Route expanded publication loading through `listPubtatorTable()`**

Replace `fetchPublicationData()` with this implementation:

```ts
const fetchPublicationData = async (geneSymbol: string, pmids: string[]) => {
  if (pmids.length === 0) return;
  if (publicationCache.value[geneSymbol]) return;

  publicationAbortControllers.get(geneSymbol)?.abort();
  const controller = new AbortController();
  publicationAbortControllers.set(geneSymbol, controller);

  loadingPublications.value[geneSymbol] = true;

  try {
    const response = await listPubtatorTable(
      {
        filter: `any(pmid,${pmids.join(',')})`,
        fields: 'search_id,pmid,doi,title,journal,date,score,gene_symbols,text_hl',
        page_size: String(pmids.length),
      },
      { signal: controller.signal }
    );
    publicationCache.value[geneSymbol] = (response.data || []) as PublicationData[];
  } catch (error) {
    if ((error as Error).name !== 'AbortError' && (error as Error).name !== 'CanceledError') {
      console.error('Failed to fetch publication data:', error);
      publicationCache.value[geneSymbol] = [];
    }
  } finally {
    publicationAbortControllers.delete(geneSymbol);
    loadingPublications.value[geneSymbol] = false;
  }
};
```

- [ ] **Step 3: Route gene loading through `listPubtatorGenes()`**

In `loadData()`, delete the Axios availability check and raw URL construction. Replace the request body with:

```ts
const loadData = async () => {
  isBusy.value = true;

  try {
    const response = await listPubtatorGenes({
      sort: sort.value,
      filter: filter_string.value,
      page_after: currentItemID.value,
      page_size: String(perPage.value),
      fields: props.fspecInput,
    });

    items.value = response.data || [];

    if (response.meta && Array.isArray(response.meta) && response.meta.length > 0) {
      const metaObj = response.meta[0] as {
        totalItems?: number;
        totalPages?: number;
        prevItemID?: number | null;
        currentItemID?: number;
        nextItemID?: number | null;
        lastItemID?: number | null;
        currentPage?: number;
        fspec?: FieldDefinition[];
      };
      totalRows.value = metaObj.totalItems || 0;
      totalPages.value = metaObj.totalPages || 1;
      prevItemID.value = metaObj.prevItemID || null;
      currentItemID.value = metaObj.currentItemID || 0;
      nextItemID.value = metaObj.nextItemID || null;
      lastItemID.value = metaObj.lastItemID || null;
      currentPage.value = metaObj.currentPage || 1;

      if (metaObj.fspec && Array.isArray(metaObj.fspec)) {
        fields.value = mergeFields(metaObj.fspec);
      }
    }

    const uiStore = useUiStore();
    uiStore.requestScrollbarUpdate();
  } catch (error) {
    makeToast(error, 'Error', 'danger');
  } finally {
    isBusy.value = false;
  }
};
```

- [ ] **Step 4: Run target PubTator specs**

Before running the specs, update the two request assertions in
`PubtatorNDDGenes.spec.ts` to pin the typed-client `format=json` parameter that
is introduced by this migration:

```ts
expect((observed as URLSearchParams).get('format')).toBe('json');
```

Add that assertion to the initial `/api/publication/pubtator/genes` request
test and the expanded `/api/publication/pubtator/table` request test.

Run:

```bash
cd app && npx vitest run src/components/analyses/PubtatorNDDGenes.spec.ts src/components/analyses/pubtatorGeneFilters.spec.ts src/api/publication.spec.ts
```

Expected: PASS. If the component spec observes missing params, fix the production parameter object rather than weakening the spec.

- [ ] **Step 5: Run frontend type-check**

Run:

```bash
cd app && npm run type-check
```

Expected: PASS. If `response.meta` typing is too loose, add a local typed alias in `PubtatorNDDGenes.vue` or strengthen the exported `PubtatorGenesResponse` metadata type in `app/src/api/publication.ts` with the fields used by this component.

- [ ] **Step 6: Ratchet file-size baseline downward if applicable**

Run:

```bash
wc -l app/src/components/analyses/PubtatorNDDGenes.vue
rg -n '^app/src/components/analyses/PubtatorNDDGenes.vue\\b' scripts/code-quality-file-size-baseline.tsv
```

Expected: if the current line count is lower than the baseline entry, lower only that entry in `scripts/code-quality-file-size-baseline.tsv`. If the current count is the same or higher, do not edit the baseline.

- [ ] **Step 7: Run code-quality audit**

Run:

```bash
make code-quality-audit
```

Expected: PASS.

- [ ] **Step 8: Commit the typed-client migration**

Run:

```bash
git add app/src/components/analyses/PubtatorNDDGenes.vue app/src/components/analyses/PubtatorNDDGenes.spec.ts app/src/api/publication.ts scripts/code-quality-file-size-baseline.tsv
git commit -m "refactor: route PubTator genes through typed clients"
```

Expected: one production commit. If `publication.ts`, the component spec, or the baseline did not change, Git will ignore those paths.

## Task 7: Optional Later Phase Assessment For TablesPhenotypes

**Files:**
- Inspect: `app/src/components/tables/TablesPhenotypes.vue`
- Inspect: `app/src/components/tables/TablesPhenotypes.spec.ts`
- Do not modify production in the first PR.

- [ ] **Step 1: Use the new spec to decide whether a follow-up slice is small**

Run:

```bash
wc -l app/src/components/tables/TablesPhenotypes.vue
cd app && npx vitest run src/components/tables/TablesPhenotypes.spec.ts src/components/tables/phenotypeTableFilters.spec.ts
```

Expected: tests PASS. Record whether a follow-up can be isolated to component/request coverage and extraction, such as moving phenotype dropdown option helpers or request coordination glue.

- [ ] **Step 2: Document the follow-up decision in the PR description**

Use this wording if no production slice is included:

```md
TablesPhenotypes.vue now has component safety-net coverage. Production extraction is intentionally deferred to a later PR so this PR stays focused on the PubTator typed-client boundary.

Backend follow-ups found during planning:
- `publication_endpoints.R` has two `@get <pmid>` decorators; resolve the route collision before splitting publication routes.
- PubTator mutation handlers are documented as admin endpoints but currently have no in-handler `require_role()` guard; plan a dedicated backend auth fix before further endpoint refactors.
```

Expected: no code commit for this task unless the implementation session explicitly creates PR notes.

## Final Verification

Run these commands in order before handoff:

```bash
cd app && npx vitest run src/components/analyses/PubtatorNDDGenes.spec.ts src/components/analyses/pubtatorGeneFilters.spec.ts src/components/tables/TablesPhenotypes.spec.ts src/components/tables/phenotypeTableFilters.spec.ts src/api/publication.spec.ts
cd api && Rscript -e "testthat::test_file('tests/testthat/test-endpoint-admin.R')"
cd api && Rscript -e "testthat::test_file('tests/testthat/test-endpoint-publication.R')"
cd app && npm run type-check
git diff --check
make code-quality-audit
make pre-commit
make ci-local
```

Expected outcomes:

- Targeted Vitest specs pass.
- Targeted R/testthat specs pass, or the exact host-R blocker is documented with the attempted command and fallback.
- `cd app && npm run type-check` exits 0.
- `git diff --check` exits 0.
- `make code-quality-audit` exits 0 with no raised baseline entries.
- `make pre-commit` exits 0.
- `make ci-local` exits 0 if the environment has the required local services and dependencies. If not, document the exact blocker.

## Handoff Checklist

- [ ] Safety-net specs were committed before production changes.
- [ ] `PubtatorNDDGenes.vue` no longer imports Axios, injects Axios, or constructs `VITE_API_URL` API request URLs.
- [ ] PubTator gene and publication-detail requests go through `app/src/api/publication.ts`.
- [ ] Visible table behavior, pagination/filter behavior, export headers, and toast/error behavior remain covered by tests.
- [ ] Backend endpoint files were not split in this PR.
- [ ] `TablesPhenotypes.vue` production code was not changed unless a separate approved follow-up slice was created.
- [ ] `scripts/code-quality-file-size-baseline.tsv` was lowered only if applicable and never raised.
