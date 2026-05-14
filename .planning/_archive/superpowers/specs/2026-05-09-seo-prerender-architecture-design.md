# SEO Prerender Architecture Design

## Goal

Make public SysNDD pages indexable and competitive for gene, disease, inheritance, and neurodevelopmental disorder search terms by serving route-specific HTML before JavaScript executes, while keeping the existing Vue/Vite SPA interaction model.

## Current Findings

SysNDD is a Vue 3 + TypeScript SPA built by Vite and served as static files from nginx behind Traefik. The production app container is built in `app/Dockerfile`, copies `app/dist` into `/usr/share/nginx/html`, and serves routes through the nginx SPA fallback. The API container owns migrations at startup, and the worker container owns durable async jobs.

The live `/Genes/CHD8` and `/Entities/1` responses currently return the generic SPA shell: `<title>SysNDD</title>`, site-level JSON-LD, and an empty `<div id="app"></div>`. Route-specific titles and descriptions are set by `@unhead/vue` in client code, after JavaScript execution. SFARI's CHD8 page returns crawlable server HTML with a gene-specific title, H1, evidence narrative, reports, external links, and tabular facts in the initial response. Gene2Phenotype's current public app appears closer to SysNDD technically, but benefits from EMBL-EBI authority and ecosystem links.

The sitemap already lists many public gene and entity URLs, but the listed URLs do not serve route-specific HTML on first fetch. This creates a discovery signal without enough page content to rank well.

## Researched Guidance

Google Search Central guidance supports this direction:

- Google should be able to see the page as users do, including CSS and JavaScript resources, but initial crawl/render reliability still matters for SPAs.
- JavaScript-routed SPAs should use History API URLs and meaningful HTTP handling for not-found pages.
- Page titles should be unique, descriptive, concise, and avoid vague labels such as `Home`.
- Programmatic meta descriptions are appropriate for large database-driven sites when they are human-readable and page-specific.
- Structured data must describe visible page content.
- Canonical signals should be clear; when client-side rendering is used, canonical URL information should be especially unambiguous.

Vue/Vite/Unhead guidance supports a stack-native implementation:

- Vite has first-class low-level SSR support and explicitly supports pre-rendering/SSG when routes and data are known ahead of time.
- Vue SSR uses `vue/server-renderer` and `renderToString()`.
- Vue SSR should create a new app/router/store instance per render to avoid cross-request state pollution.
- Unhead supports SSR and can transform the rendered template with server-produced head tags.

Docker guidance supports keeping SEO generation separate from nginx:

- Docker recommends one service concern per container and connecting services through networks and shared volumes.
- Compose `depends_on` with `service_healthy` and `service_completed_successfully` can coordinate startup sequencing.
- Compose profiles are appropriate for optional operational services.

## Recommended Approach

Use static pre-rendering for public SEO pages, not request-time SSR.

Build a small Node-based prerender pipeline inside the frontend codebase. It will use the existing Vite/Vue stack to render route-specific HTML files into `app/dist` during frontend image build. The generated HTML will hydrate with the existing SPA bundle for user interaction.

Static prerender is the right first step because SysNDD's high-value public pages are database records with known canonical routes. It avoids adding a new always-on Node SSR server to production, preserves nginx static hosting, keeps Traefik routing unchanged, and fits the current container model.

## Rendering Model

The frontend gains three focused modules:

- `app/src/seo/seoTypes.ts`: shared TypeScript shapes for SEO route records and payloads.
- `app/src/seo/seoMeta.ts`: pure functions that convert gene/entity/static route data into title, description, canonical URL, JSON-LD, H1, and HTML summary fragments.
- `app/scripts/generate-seo-pages.mjs`: Node script that fetches SEO payloads from the API or reads a checked-in manifest fixture, writes route-specific `index.html` files, and writes sitemap files.

The initial implementation should not attempt to server-render the full interactive Vue detail pages. Instead, it should generate a crawlable SEO shell for each public URL:

- correct `<title>`
- `<meta name="description">`
- `<link rel="canonical">`
- Open Graph and Twitter tags
- route-specific JSON-LD
- one semantic `<main>` block with H1 and concise factual content
- links to related SysNDD pages and external authorities
- normal SPA bundle scripts and styles so Vue hydrates/replaces the page for users

This reduces SSR risk from browser-only visualization dependencies such as D3, NGL, Bootstrap tooltips, and `window`-dependent components. The SEO shell is a stable public contract and does not need every interactive card.

## Public Route Scope

Phase 1 routes:

- `/`
- `/Genes`
- `/Entities`
- `/Phenotypes`
- `/About`
- `/Documentation`
- `/API`
- `/Genes/:symbol` for canonical gene symbols
- `/Entities/:entity_id` for public entities

Phase 2 routes:

- `/Ontology/:disease_term`
- `/CurationComparisons`
- `/Analysis`
- selected landing pages for `neurodevelopmental disorder gene database`, `developmental delay gene database`, `intellectual disability gene curation`, and `autism gene disease associations`

Search result pages, authenticated pages, admin pages, and arbitrary table query URLs stay non-indexable or omitted from sitemap.

## Canonical URL Policy

Canonical gene URLs use `/Genes/{symbol}`. HGNC-id route access can continue for application convenience, but generated canonical metadata points to the symbol URL. If duplicate route access becomes common, add API- or nginx-level redirects later.

Entity URLs use `/Entities/{entity_id}`.

Static public pages use their exact route casing for phase 1 to avoid a broad URL migration. A later SEO cleanup can migrate to lowercase slugs with 301 redirects.

## Data Contract

Add public API endpoints dedicated to SEO payloads rather than scraping existing table endpoints:

- `GET /api/seo/routes`: returns canonical public route records with route type, URL path, last modified timestamp, priority, and change frequency.
- `GET /api/seo/gene/:symbol`: returns a compact gene SEO payload.
- `GET /api/seo/entity/:entity_id`: returns a compact entity SEO payload.
- `GET /api/seo/static`: returns site counts, last update date, and static-page facts.

These endpoints must be public, cacheable, read-only, and must not expose authenticated or draft curation data. They should use approved/public records only, mirroring what the current public UI shows.

## Generated Content Rules

Gene pages should include:

- symbol and gene name
- HGNC, Ensembl, Entrez, OMIM identifiers where available
- number of associated SysNDD entities
- disease names and inheritance modes
- classification/status summary
- NDD status summary
- publication count and representative PMIDs
- links to entity pages
- links to external authority resources

Entity pages should include:

- gene symbol
- disease name and ontology ID
- inheritance mode
- classification/status
- NDD status
- synopsis excerpt when public
- HPO term names and IDs
- variation ontology terms
- publication PMIDs
- link back to gene page

Text must stay factual and database-derived. Avoid medical advice language.

## Structured Data

Keep site-level `WebSite` and `DataCatalog`, but move it into a reusable generator to avoid hand-maintaining JSON in `index.html`.

Add page-level JSON-LD:

- `WebPage` for every generated route.
- `Dataset` for table/download/API pages.
- `BreadcrumbList` for public routes.
- `Thing` or `BioChemEntity`-like gene nodes using `sameAs` links where available.
- `MedicalCondition` should only be used when the disease concept is explicit and already visible on the page.

All structured data must match visible generated HTML.

## Sitemap and Robots

Generate sitemap files during prerender:

- `sitemap.xml` as a sitemap index.
- `sitemap-static.xml`.
- `sitemap-genes.xml`.
- `sitemap-entities.xml`.

Each URL includes `<lastmod>` from data timestamps when available. Exclude `/Login`, `/Register`, password reset, admin, review, create/modify/approve, arbitrary search, and arbitrary filtered table query URLs.

Keep `robots.txt` simple and point it to the sitemap index.

## Docker and Operations

Phase 1 build-time generation:

1. Build API image and app image normally.
2. During `app/Dockerfile` builder stage, run Vite build.
3. Run `node scripts/generate-seo-pages.mjs --mode build --base-url "$SEO_API_BASE_URL"`.
4. Copy the resulting `dist` into nginx as today.

For production deploys where the app image cannot reach the API at build time, support a checked-in or CI-generated route manifest artifact. The script should fail clearly when neither API access nor manifest input is available.

Phase 2 runtime regeneration:

Add an optional `seo-prerender` Compose service with profile `ops`. It uses the app builder image or a small Node image, waits for `api` to be healthy, writes generated HTML into a shared `seo_dist` volume, then exits successfully. The nginx app service can serve from that shared volume if enabled. For periodic refresh, prefer host/system cron that runs:

```bash
docker compose --profile ops run --rm seo-prerender
docker compose restart app
```

Do not put cron inside the nginx app container. Do not run SEO generation inside API migration startup. Keep generation failures visible but isolated from database migration correctness.

## Error Handling

The generator exits non-zero when:

- route manifest cannot be fetched or parsed
- required fields for a route are missing
- generated canonical URL is invalid
- generated HTML lacks title, description, canonical, H1, or main content

The generator skips individual stale records only when the API marks them unavailable and logs a structured warning. It should not silently emit empty shells.

For missing pages in the SPA, add `noindex` on client-side not-found views and plan a later nginx/API route for a real 404 HTML response.

## Testing

Add focused unit tests for pure SEO functions:

- title generation
- description generation
- canonical path normalization
- JSON-LD shape
- HTML escaping
- sitemap XML escaping

Add build-level tests:

- run Vite build
- run prerender against fixture payloads
- assert `dist/Genes/CHD8/index.html` contains route-specific title, description, canonical, H1, JSON-LD, and visible CHD8 text before JavaScript
- assert sitemap index and child sitemaps validate basic XML shape

Add local Playwright or curl smoke checks:

```bash
curl -s http://localhost/Genes/CHD8 | rg "CHD8|canonical|application/ld\\+json"
```

## Documentation

Update durable docs with the behavior change:

- `AGENTS.md`: SEO generation and verification notes.
- `documentation/08-development.qmd`: local prerender commands and fixture mode.
- `documentation/09-deployment.qmd`: build-time and optional runtime regeneration operations.
- `README.md`: public SEO/static generation note if deployment entrypoints change.

## Alternatives Considered

### Full request-time SSR

Pros: freshest data on every request, best dynamic head rendering, no static regeneration cycle.

Cons: requires a new Node SSR server in production, more memory, more operational moving parts, SSR-hardening browser-only components, and careful Pinia/router request isolation. This is overkill for the first SEO pass.

### Dynamic rendering for crawlers only

Pros: can preserve current SPA for users.

Cons: fragile, crawler-specific, harder to validate, and not aligned with modern Google guidance that favors SSR/static rendering over special bot-only rendering.

### API startup generation

Pros: has immediate database access after migrations.

Cons: couples SEO artifact generation to API boot and migration reliability. A slow or broken prerender pass could delay or destabilize API startup. This violates the current clean boundary where migrations fail startup, while frontend static assets are app-container responsibility.

## Approval Gate

This design is ready for implementation planning. The recommended path is static prerendered SEO shells at build time, plus an optional Compose `ops` sidecar for periodic regeneration after data updates.

