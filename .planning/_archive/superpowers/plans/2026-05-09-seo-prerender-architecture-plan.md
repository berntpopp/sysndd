# SEO Prerender Architecture Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Serve route-specific, crawlable HTML for public SysNDD pages while preserving the existing Vue/Vite SPA and nginx deployment model.

**Architecture:** Add a frontend-owned static prerender pipeline that generates SEO HTML shells, canonical metadata, JSON-LD, and sitemaps into `app/dist`. Add compact public API endpoints for SEO payloads. Keep runtime generation optional through a Compose `ops` sidecar rather than coupling it to API migrations or nginx startup.

**Tech Stack:** Vue 3, Vite, TypeScript, `@unhead/vue`, Node scripts, R/Plumber API, MySQL, Docker Compose, nginx, Vitest, testthat.

---

## File Structure

- Create `app/src/seo/seoTypes.ts`: shared TypeScript interfaces for SEO payloads and route records.
- Create `app/src/seo/seoMeta.ts`: pure metadata, canonical, JSON-LD, and summary HTML generation.
- Create `app/src/seo/sitemap.ts`: sitemap XML generation helpers.
- Create `app/src/seo/__tests__/seoMeta.spec.ts`: unit tests for metadata and escaping.
- Create `app/src/seo/__tests__/sitemap.spec.ts`: unit tests for sitemap XML.
- Create `app/scripts/generate-seo-pages.mjs`: build/prerender script that reads fixture or API payloads and writes route HTML.
- Create `app/scripts/fixtures/seo/`: deterministic fixture payloads for unit/build tests.
- Modify `app/package.json`: add `seo:generate`, `seo:generate:fixture`, and `build:seo` scripts.
- Modify `app/index.html`: replace hand-maintained static JSON-LD with placeholders used by the generator, while keeping SPA fallback valid.
- Modify `app/Dockerfile`: run SEO generation after Vite build when configured.
- Modify `docker-compose.yml`: add optional `seo-prerender` service behind profile `ops` only after build-time path is stable.
- Create `api/endpoints/seo_endpoints.R`: public SEO payload endpoints.
- Create `api/services/seo-service.R`: SQL-backed data assembly for SEO payloads.
- Create `api/tests/testthat/test-seo-endpoints.R`: API endpoint/service tests.
- Modify `documentation/08-development.qmd`, `documentation/09-deployment.qmd`, and `AGENTS.md`: document commands and operating model.

## Task 1: Add Pure SEO Metadata Generation

**Files:**
- Create: `app/src/seo/seoTypes.ts`
- Create: `app/src/seo/seoMeta.ts`
- Create: `app/src/seo/__tests__/seoMeta.spec.ts`

- [ ] **Step 1: Write failing tests**

Create `app/src/seo/__tests__/seoMeta.spec.ts` with tests that assert:

```ts
import { describe, expect, it } from 'vitest';
import { buildEntitySeo, buildGeneSeo, escapeHtml } from '../seoMeta';
import type { EntitySeoPayload, GeneSeoPayload } from '../seoTypes';

describe('seoMeta', () => {
  it('builds CHD8 gene metadata with canonical URL and escaped visible content', () => {
    const payload: GeneSeoPayload = {
      symbol: 'CHD8',
      name: 'chromodomain helicase DNA binding protein 8',
      hgncId: 'HGNC:20153',
      ensemblGeneId: 'ENSG00000100888',
      entrezId: '57680',
      omimId: '610528',
      entityCount: 2,
      diseases: ['autism', 'CHD8-related neurodevelopmental disorder with overgrowth'],
      inheritanceModes: ['Autosomal dominant'],
      classifications: [{ label: 'Definitive', count: 1 }],
      nddStatuses: [{ label: 'NDD', count: 2 }],
      pmids: ['22495309', '24998929'],
      lastModified: '2026-05-09',
    };

    const result = buildGeneSeo(payload, 'https://sysndd.dbmr.unibe.ch');

    expect(result.title).toBe('CHD8 Gene-Disease Associations in Neurodevelopmental Disorders | SysNDD');
    expect(result.description).toContain('CHD8');
    expect(result.description).toContain('2 curated gene-disease associations');
    expect(result.canonicalUrl).toBe('https://sysndd.dbmr.unibe.ch/Genes/CHD8');
    expect(result.h1).toBe('CHD8 - chromodomain helicase DNA binding protein 8');
    expect(result.html).toContain('Autosomal dominant');
    expect(result.html).toContain('PMID:22495309');
    expect(result.jsonLd['@type']).toBe('WebPage');
  });

  it('builds entity metadata with gene, disease, inheritance, classification, and PMID facts', () => {
    const payload: EntitySeoPayload = {
      entityId: '123',
      symbol: 'CHD8',
      hgncId: 'HGNC:20153',
      diseaseName: 'autism',
      diseaseOntologyId: 'OMIM:209850',
      inheritanceName: 'Autosomal dominant',
      classification: 'Definitive',
      nddStatus: 'NDD',
      synopsis: 'Curated CHD8 association with autism and developmental delay.',
      hpoTerms: [{ id: 'HP:0000729', label: 'Autistic behavior' }],
      variationTerms: [{ id: 'VariO:0133', label: 'loss of function variant' }],
      pmids: ['22495309'],
      lastModified: '2026-05-09',
    };

    const result = buildEntitySeo(payload, 'https://sysndd.dbmr.unibe.ch');

    expect(result.title).toBe('Entity 123: CHD8, Autosomal dominant, autism | SysNDD');
    expect(result.description).toContain('Definitive');
    expect(result.canonicalUrl).toBe('https://sysndd.dbmr.unibe.ch/Entities/123');
    expect(result.h1).toBe('CHD8 - autism');
    expect(result.html).toContain('HP:0000729');
    expect(result.html).toContain('PMID:22495309');
  });

  it('escapes text used in generated HTML', () => {
    expect(escapeHtml('CHD8 <script>alert("x")</script>')).toBe(
      'CHD8 &lt;script&gt;alert(&quot;x&quot;)&lt;/script&gt;'
    );
  });
});
```

- [ ] **Step 2: Run tests to verify failure**

Run:

```bash
cd app && npx vitest run src/seo/__tests__/seoMeta.spec.ts
```

Expected: fails because `app/src/seo/seoMeta.ts` and `seoTypes.ts` do not exist.

- [ ] **Step 3: Implement types and pure functions**

Create focused implementations in `seoTypes.ts` and `seoMeta.ts` with no browser dependencies. The functions must escape all visible text, trim generated descriptions to roughly search-snippet length, and return serializable JSON-LD objects.

- [ ] **Step 4: Run tests to verify pass**

Run:

```bash
cd app && npx vitest run src/seo/__tests__/seoMeta.spec.ts
```

Expected: all tests pass.

- [ ] **Step 5: Commit**

```bash
git add app/src/seo/seoTypes.ts app/src/seo/seoMeta.ts app/src/seo/__tests__/seoMeta.spec.ts
git commit -m "feat: add SEO metadata builders"
```

## Task 2: Add Sitemap Generation

**Files:**
- Create: `app/src/seo/sitemap.ts`
- Create: `app/src/seo/__tests__/sitemap.spec.ts`

- [ ] **Step 1: Write failing tests**

Create tests that cover sitemap index output, URL escaping, `lastmod`, and exclusion of auth/admin routes.

- [ ] **Step 2: Run tests**

```bash
cd app && npx vitest run src/seo/__tests__/sitemap.spec.ts
```

Expected: fails because sitemap helpers do not exist.

- [ ] **Step 3: Implement sitemap helpers**

Implement `buildSitemapIndex()` and `buildUrlSet()` with XML escaping and deterministic ordering.

- [ ] **Step 4: Run tests**

```bash
cd app && npx vitest run src/seo/__tests__/sitemap.spec.ts
```

Expected: pass.

- [ ] **Step 5: Commit**

```bash
git add app/src/seo/sitemap.ts app/src/seo/__tests__/sitemap.spec.ts
git commit -m "feat: generate SEO sitemaps"
```

## Task 3: Add Fixture-Based Prerender Script

**Files:**
- Create: `app/scripts/generate-seo-pages.mjs`
- Create: `app/scripts/fixtures/seo/routes.json`
- Create: `app/scripts/fixtures/seo/genes/CHD8.json`
- Create: `app/scripts/fixtures/seo/entities/123.json`
- Modify: `app/package.json`

- [ ] **Step 1: Add fixture payloads**

Create deterministic fixture payloads matching the test data from Task 1.

- [ ] **Step 2: Add script command**

Add scripts:

```json
"seo:generate:fixture": "node scripts/generate-seo-pages.mjs --fixture scripts/fixtures/seo --out dist --base-url https://sysndd.dbmr.unibe.ch",
"seo:generate": "node scripts/generate-seo-pages.mjs --api-base ${SEO_API_BASE_URL:-http://localhost/api} --out dist --base-url ${SEO_PUBLIC_BASE_URL:-https://sysndd.dbmr.unibe.ch}",
"build:seo": "npm run build:production && npm run seo:generate:fixture"
```

Adjust shell portability if npm rejects inline env defaults; use a small JS default inside the script rather than relying on shell expansion.

- [ ] **Step 3: Implement script**

The script must:

- read `dist/index.html`
- generate `dist/Genes/CHD8/index.html`
- generate `dist/Entities/123/index.html`
- replace title, meta description, canonical, Open Graph/Twitter tags, JSON-LD, and `<div id="app"></div>` with `<div id="app"><main>...</main></div>`
- write sitemap index and child sitemap files
- exit non-zero if required tags are missing

- [ ] **Step 4: Verify generated HTML**

Run:

```bash
cd app
npm run build:production
npm run seo:generate:fixture
rg "CHD8 Gene-Disease Associations|canonical|application/ld\\+json|PMID:22495309" dist/Genes/CHD8/index.html
rg "sitemap-genes.xml|sitemap-entities.xml" dist/sitemap.xml
```

Expected: all `rg` commands find matches.

- [ ] **Step 5: Commit**

```bash
git add app/scripts/generate-seo-pages.mjs app/scripts/fixtures/seo app/package.json
git commit -m "feat: prerender SEO pages from fixtures"
```

## Task 4: Add Public API SEO Payloads

**Files:**
- Create: `api/services/seo-service.R`
- Create: `api/endpoints/seo_endpoints.R`
- Create: `api/tests/testthat/test-seo-endpoints.R`
- Modify if required: `api/start_sysndd_api.R` only if endpoint source order needs registration

- [ ] **Step 1: Write service tests**

Add tests with mocked DB/service fixtures proving:

- `svc_seo_routes()` returns only public routes.
- `svc_seo_gene("CHD8")` returns compact gene facts.
- `svc_seo_entity("123")` returns compact entity facts.
- missing records return a 404-friendly result.

- [ ] **Step 2: Run tests**

```bash
cd api && Rscript -e "testthat::test_file('tests/testthat/test-seo-endpoints.R')"
```

Expected: fails because service/endpoints do not exist.

- [ ] **Step 3: Implement services**

Use existing repository/query helpers where possible. Namespace `dplyr::select(...)`. Use only approved/public records. Keep endpoint functions prefixed with `svc_` or `service_` to avoid global-source collisions.

- [ ] **Step 4: Implement endpoints**

Add:

```r
#* @get /seo/routes
#* @get /seo/gene/<symbol>
#* @get /seo/entity/<entity_id>
#* @get /seo/static
```

Responses should be JSON, cacheable, and free of auth requirements.

- [ ] **Step 5: Run API test**

```bash
cd api && Rscript -e "testthat::test_file('tests/testthat/test-seo-endpoints.R')"
```

Expected: pass.

- [ ] **Step 6: Commit**

```bash
git add api/services/seo-service.R api/endpoints/seo_endpoints.R api/tests/testthat/test-seo-endpoints.R api/start_sysndd_api.R
git commit -m "feat: expose public SEO payloads"
```

## Task 5: Switch Prerender Script to API Mode

**Files:**
- Modify: `app/scripts/generate-seo-pages.mjs`
- Add: `app/scripts/generate-seo-pages.spec.mjs` or Vitest coverage if preferred

- [ ] **Step 1: Add API-mode tests**

Test that `--api-base` fetches `/seo/routes`, `/seo/gene/:symbol`, and `/seo/entity/:id`, and that failures exit non-zero.

- [ ] **Step 2: Implement API mode**

Use global `fetch` from Node. Add retry with a small fixed backoff for startup races. Validate payload shape before writing HTML.

- [ ] **Step 3: Verify against local stack**

Run:

```bash
make dev
cd app
npm run build:production
node scripts/generate-seo-pages.mjs --api-base http://localhost/api --out dist --base-url https://sysndd.dbmr.unibe.ch
rg "CHD8|application/ld\\+json|canonical" dist/Genes/CHD8/index.html
```

Expected: generated page contains route-specific crawlable content.

- [ ] **Step 4: Commit**

```bash
git add app/scripts/generate-seo-pages.mjs app/scripts/generate-seo-pages.spec.mjs
git commit -m "feat: prerender SEO pages from API payloads"
```

## Task 6: Wire Build-Time Generation into Docker

**Files:**
- Modify: `app/Dockerfile`
- Modify: `.env.example` if SEO build args are exposed there
- Modify: `Makefile` if a local shortcut is useful

- [ ] **Step 1: Add Docker build arguments**

Add build args:

```dockerfile
ARG SEO_GENERATE=false
ARG SEO_API_BASE_URL=
ARG SEO_PUBLIC_BASE_URL=https://sysndd.dbmr.unibe.ch
```

- [ ] **Step 2: Run generation conditionally**

After `npm run build:${VUE_MODE}`, run the generator only when `SEO_GENERATE=true`. Use fixture mode for CI/builds without API access and API mode for deploy environments that provide `SEO_API_BASE_URL`.

- [ ] **Step 3: Verify app image build**

Run:

```bash
docker build -f app/Dockerfile --build-arg VUE_MODE=production --build-arg SEO_GENERATE=false app
docker build -f app/Dockerfile --build-arg VUE_MODE=production --build-arg SEO_GENERATE=true app
```

Expected: both builds complete; SEO-enabled build includes generated HTML.

- [ ] **Step 4: Commit**

```bash
git add app/Dockerfile .env.example Makefile
git commit -m "feat: support SEO generation during app image build"
```

## Task 7: Add Optional Compose Ops Sidecar

**Files:**
- Modify: `docker-compose.yml`
- Modify: `documentation/09-deployment.qmd`

- [ ] **Step 1: Add profiled service**

Add `seo-prerender` with `profiles: ["ops"]`, `depends_on: api: condition: service_healthy`, and a command that runs the generator against `http://api:7777/api`. Use a shared volume only if runtime refresh is needed after the app container is already built.

- [ ] **Step 2: Keep nginx single-purpose**

Do not add cron or Node to the nginx app container. The app container continues to run nginx only.

- [ ] **Step 3: Verify profile behavior**

Run:

```bash
docker compose config --profiles
docker compose --profile ops config
```

Expected: core services stay enabled without `ops`; `seo-prerender` appears only with the profile.

- [ ] **Step 4: Document host cron**

Document:

```bash
docker compose --profile ops run --rm seo-prerender
docker compose restart app
```

as the preferred periodic refresh mechanism when runtime regeneration is enabled.

- [ ] **Step 5: Commit**

```bash
git add docker-compose.yml documentation/09-deployment.qmd
git commit -m "docs: add optional SEO prerender operations"
```

## Task 8: Add SEO Verification Gates

**Files:**
- Create: `app/scripts/verify-seo-build.mjs`
- Modify: `app/package.json`
- Modify: `Makefile`
- Modify: `.github/workflows/ci.yml` if adding CI coverage is desired

- [ ] **Step 1: Implement verifier**

The verifier checks generated HTML for:

- non-generic `<title>`
- meta description
- canonical link
- H1
- JSON-LD
- visible route-specific text
- absence of `/Login` and `/Register` from sitemap

- [ ] **Step 2: Add npm script**

Add:

```json
"seo:verify": "node scripts/verify-seo-build.mjs dist"
```

- [ ] **Step 3: Verify locally**

Run:

```bash
cd app
npm run build:production
npm run seo:generate:fixture
npm run seo:verify
```

Expected: pass.

- [ ] **Step 4: Add Makefile target**

Add `make verify-seo-app` that runs the three commands above.

- [ ] **Step 5: Commit**

```bash
git add app/scripts/verify-seo-build.mjs app/package.json Makefile .github/workflows/ci.yml
git commit -m "test: verify prerendered SEO output"
```

## Task 9: Documentation and Agent Guidance

**Files:**
- Modify: `AGENTS.md`
- Modify: `documentation/08-development.qmd`
- Modify: `documentation/09-deployment.qmd`
- Modify: `README.md` if deployment commands change

- [ ] **Step 1: Update AGENTS.md**

Add the SEO generation invariant:

```markdown
- Public SEO pages are generated by the frontend prerender pipeline. If public route content, canonical URL policy, sitemap behavior, or SEO payload endpoints change, run `make verify-seo-app` and update `documentation/08-development.qmd` / `documentation/09-deployment.qmd`.
```

- [ ] **Step 2: Update development docs**

Document fixture generation, API-backed generation, and verification commands.

- [ ] **Step 3: Update deployment docs**

Document build-time generation, optional `ops` sidecar, host cron refresh, and why generation does not run inside API startup.

- [ ] **Step 4: Commit**

```bash
git add AGENTS.md documentation/08-development.qmd documentation/09-deployment.qmd README.md
git commit -m "docs: document SEO prerender workflow"
```

## Task 10: Final Verification

**Files:**
- No new files.

- [ ] **Step 1: Run frontend SEO verification**

```bash
make verify-seo-app
```

Expected: pass.

- [ ] **Step 2: Run frontend quality gates**

```bash
make lint-app
cd app && npm run type-check && npm run test:unit
```

Expected: pass.

- [ ] **Step 3: Run API quality gates**

```bash
make test-api-fast
```

Expected: pass.

- [ ] **Step 4: Run full local CI before handoff**

```bash
make ci-local
```

Expected: pass.

## Operational Decision

Default production path: build-time prerender into the app image.

Optional production refresh path: profiled `seo-prerender` sidecar run manually or by host cron after data releases. Restart the app container only after successful generation.

Avoided path: cron inside nginx or API startup generation.

## Self-Review Notes

Spec coverage:

- Rendering architecture: covered by Tasks 1, 3, 5, and 6.
- SEO payload API: covered by Task 4.
- Sitemap/canonical policy: covered by Tasks 1 and 2.
- Docker startup and periodic refresh: covered by Tasks 6 and 7.
- Verification and docs: covered by Tasks 8, 9, and 10.

Placeholder scan: no intentional placeholders remain. Each task names exact files and commands.

Type consistency: `GeneSeoPayload`, `EntitySeoPayload`, and generated result fields are consistently referenced across tasks.

