# SEO Prerender Improvement Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Expand SysNDD's build-time SEO prerendering from a minimal gene/entity baseline into a verified public discovery layer for biomedical Vue pages.

**Architecture:** Keep Vite SPA deployment and build-time prerendering. Improve API SEO route/payload coverage, make frontend SEO builders richer and DRYer, and strengthen generated-output verification.

**Tech Stack:** R/Plumber API, Vue 3, TypeScript, Vite, Node generator scripts, Vitest, testthat, existing Makefile SEO gate.

---

## File Map

- Modify `api/services/seo-service.R`: add public static route records, collection SEO payloads, route counts, and optional related links.
- Modify `api/endpoints/seo_endpoints.R`: expose any new SEO payload endpoints with public cache headers.
- Modify `api/tests/testthat/test-seo-endpoints.R`: cover new route lists and payloads.
- Modify `app/src/seo/seoTypes.ts`: add static/collection payload and richer JSON-LD types.
- Modify `app/src/seo/seoMeta.ts`: enrich gene/entity builders and add collection/static builders.
- Modify `app/src/seo/sitemap.ts`: add chunking helpers if production route counts approach protocol limits; keep private filtering.
- Modify `app/scripts/generate-seo-pages.mjs`: consume all public static routes and write generated files for collection pages.
- Modify `app/scripts/verify-seo-build.mjs`: verify route coverage, robots, canonical/sitemap alignment, JSON-LD parseability, and non-generic metadata.
- Modify `app/scripts/fixtures/seo/`: add static route fixture payloads and richer CHD8/entity payloads.
- Modify `app/src/seo/__tests__/seoMeta.spec.ts`, `app/src/seo/__tests__/sitemap.spec.ts`, and `app/src/scripts/__tests__/generate-seo-pages.spec.ts`: test builders and generated output.
- Modify `documentation/08-development.qmd` and `documentation/09-deployment.qmd`: document SEO route scope and deployment requirements.

## PR 1: Fix Route Scope and Static Page Prerendering

- [ ] Add failing API tests in `api/tests/testthat/test-seo-endpoints.R` asserting `svc_seo_routes()` includes `/`, `/Genes`, `/Entities`, `/Phenotypes`, `/API`, `/Documentation`, and `/About` in `routes$static`.

Run:

```bash
cd api && Rscript -e "testthat::test_file('tests/testthat/test-seo-endpoints.R')"
```

Expected before implementation: failure because only `/` is returned from `svc_seo_routes()`.

- [ ] Update `api/services/seo-service.R` so `svc_seo_routes()` calls a shared static route helper used by `svc_seo_static()`.

Implementation shape:

```r
seo_public_static_routes <- function() {
  today <- as.character(Sys.Date())
  list(
    list(path = "/", lastModified = today),
    list(path = "/Genes", lastModified = today),
    list(path = "/Entities", lastModified = today),
    list(path = "/Phenotypes", lastModified = today),
    list(path = "/API", lastModified = today),
    list(path = "/Documentation", lastModified = today),
    list(path = "/About", lastModified = today)
  )
}
```

- [ ] Add static page fixtures under `app/scripts/fixtures/seo/static/` for the listed routes.

- [ ] Add a `buildStaticSeo()` or `buildCollectionSeo()` builder in `app/src/seo/seoMeta.ts` and matching tests in `app/src/seo/__tests__/seoMeta.spec.ts`.

- [ ] Update `app/scripts/generate-seo-pages.mjs` to write `index.html` files for static routes from `source.routes.static`.

- [ ] Update `app/src/scripts/__tests__/generate-seo-pages.spec.ts` to expect generated `Genes/index.html`, `Entities/index.html`, and `API/index.html`.

- [ ] Run verification:

```bash
cd api && Rscript -e "testthat::test_file('tests/testthat/test-seo-endpoints.R')"
cd app && npx vitest run src/seo/__tests__/seoMeta.spec.ts src/scripts/__tests__/generate-seo-pages.spec.ts
make verify-seo-app
```

Commit:

```bash
git add api/services/seo-service.R api/tests/testthat/test-seo-endpoints.R app/src/seo app/scripts app/src/scripts app/scripts/fixtures documentation
git commit -m "feat(seo): prerender public static discovery routes"
```

## PR 2: Enrich Gene and Entity Source HTML

- [ ] Add failing tests in `app/src/seo/__tests__/seoMeta.spec.ts` requiring gene/entity HTML to include a summary paragraph, PubMed links, last modified date, and internal links.

- [ ] Extend `GeneSeoPayload` and `EntitySeoPayload` in `app/src/seo/seoTypes.ts` only for data already available or safe to add through public API queries.

- [ ] Update `api/services/seo-service.R` to include related entity links for gene pages and gene links for entity pages when available from public views.

- [ ] Update `buildGeneSeo()` and `buildEntitySeo()` to produce:

```html
<main>
  <h1>...</h1>
  <p>...</p>
  <section aria-labelledby="...">
    <h2>Key facts</h2>
    <dl>...</dl>
  </section>
  <section aria-labelledby="...">
    <h2>Curated evidence</h2>
    ...
  </section>
</main>
```

- [ ] Ensure PubMed links use `https://pubmed.ncbi.nlm.nih.gov/{pmid}/` and all text is escaped.

- [ ] Run:

```bash
cd app && npx vitest run src/seo/__tests__/seoMeta.spec.ts
cd api && Rscript -e "testthat::test_file('tests/testthat/test-seo-endpoints.R')"
make verify-seo-app
```

Commit:

```bash
git add api/services/seo-service.R api/tests/testthat/test-seo-endpoints.R app/src/seo app/scripts app/scripts/fixtures
git commit -m "feat(seo): enrich gene and entity prerender content"
```

## PR 3: Strengthen Structured Data and Canonicals

- [ ] Add tests that parse every generated JSON-LD block and require stable `@context`, `@type`, `url`, `dateModified`, `citation`, and breadcrumb fields.

- [ ] Add `BreadcrumbList` JSON-LD to gene, entity, and collection pages.

- [ ] Add conservative `Dataset` or `DataCatalog` JSON-LD only to collection/dataset landing pages where visible content describes the dataset.

- [ ] Ensure canonical URLs are generated from one helper and match sitemap paths exactly.

- [ ] Add tests for query variants if canonical generation is extended for list pages.

- [ ] Run:

```bash
cd app && npx vitest run src/seo/__tests__/seoMeta.spec.ts src/seo/__tests__/sitemap.spec.ts
make verify-seo-app
```

Commit:

```bash
git add app/src/seo app/scripts app/scripts/fixtures
git commit -m "feat(seo): add structured data graph and canonical checks"
```

## PR 4: Harden Generated Output Verification

- [ ] Update `app/scripts/verify-seo-build.mjs` to discover generated route files from fixture routes instead of checking only CHD8 and entity 123.

- [ ] Verify `app/dist/robots.txt` exists and contains the production sitemap URL.

- [ ] Parse all generated HTML files and fail when:
  - title is generic
  - meta description is missing or duplicated across detail pages
  - canonical is missing
  - H1 is missing
  - JSON-LD is invalid JSON
  - a private route appears in any sitemap
  - sitemap URL count does not match generated fixture route count

- [ ] Add a fixture test case with a private route to prove the sitemap filter still excludes it.

- [ ] Run:

```bash
cd app && npx vitest run src/scripts/__tests__/generate-seo-pages.spec.ts src/seo/__tests__/sitemap.spec.ts
make verify-seo-app
```

Commit:

```bash
git add app/scripts app/src/scripts app/src/seo app/scripts/fixtures
git commit -m "test(seo): verify generated prerender output"
```

## PR 5: Deployment and Documentation Closeout

- [ ] Update `documentation/08-development.qmd` with local fixture and API-backed SEO verification commands.

- [ ] Update `documentation/09-deployment.qmd` to make the production SEO generation requirement explicit: either build with `SEO_GENERATE=true` and `SEO_API_BASE_URL`, or run the `seo-prerender` sidecar after data refresh.

- [ ] Add a short operator checklist:
  - run `make verify-seo-app`
  - inspect representative generated files
  - run Google Rich Results Test for one gene, one entity, and one collection page
  - submit or refresh sitemap in Search Console

- [ ] Run final local gate:

```bash
make lint-app
cd app && npm run type-check
cd app && npm run type-check:strict
cd app && npm run test:unit
make verify-seo-app
cd api && Rscript -e "testthat::test_file('tests/testthat/test-seo-endpoints.R')"
```

Commit:

```bash
git add documentation AGENTS.md README.md
git commit -m "docs(seo): document prerender operations and verification"
```

## Final Review Checklist

- [ ] Source HTML for `/Genes/CHD8`, `/Entities/123`, `/Genes`, `/Entities`, `/Phenotypes`, `/API`, `/Documentation`, and `/About` has route-specific title, description, canonical, H1, visible content, and JSON-LD.
- [ ] Sitemaps list only public canonical URLs.
- [ ] `robots.txt` points to the sitemap.
- [ ] Private/authenticated routes are absent from sitemap and generated output.
- [ ] `make verify-seo-app` fails if a generated route falls back to the generic SPA shell.
- [ ] Documentation says exactly how production gets prerendered HTML.
