# Immutable Public Analysis-Snapshot Releases + Category-Selected Clustering — Design

Date: 2026-07-18
Issues: **#573** (feat: publish immutable public analysis-snapshot releases with verifiable lineage — PRIMARY), **#574** (feat: category-selected gene universes for functional clustering jobs — companion), **#572** (bug: production serves a phenotype-functional snapshot without dependency lineage — deployment prerequisite).
Reference: `../nddscore` Zenodo dataset-release flow (`scripts/package_sysndd_zenodo_dataset.py`, `scripts/upload_sysndd_zenodo_dataset.py`, `src/models/sysndd_export.py`, `.planning/specs/2026-05-17-sysndd-zenodo-dataset-release-design.md`).

---

## 1. Summary

Add a **read-only, immutable, content-addressed public "analysis-snapshot release"** layer on top of the existing durable analysis snapshots, so a manuscript can cite and any reader can independently verify the *exact* linked functional-clustering, phenotype-clustering, and phenotype-functional-correlation results (with their cross-snapshot dependency lineage) without access to server disks, mutable caches, curator records, or admin endpoints. A later snapshot refresh mints a *new* release and never mutates an existing one.

The primary deliverable is entirely in-app (DB-materialized frozen release + public retrieval API + verification UI). A separate **operator archival slice** mirrors the `../nddscore` flow to package a published release for Zenodo (draft-only, guarded publish, DOI recorded back as additive external provenance).

Two companions ride along because the user grouped all three issues and each is manuscript-reproducibility work:
- **#574**: a server-side `category_filter` selector for the async functional-clustering submit endpoint (a Definitive-only sensitivity run), sharing the release program's provenance philosophy (sorted-HGNC SHA-256, resolved gene count, code/data versions, STRING channel/threshold).
- **#572**: a production deployment + force-refresh runbook that must land *before* the first real release, because a release built from a pre-#571 correlation snapshot would lack the dependency lineage the release must pin.

---

## 2. Context & current state (grounded)

### 2.1 The snapshot infrastructure already provides the provenance primitives

- `analysis_snapshot_manifest` (`db/migrations/024`) is already a manifest/head table with content-address hashes (`input_hash`, `payload_hash`), a status lifecycle (`pending → validated → public_ready → superseded → failed`), a single-active invariant (`public_ready_slot` UNIQUE per `(analysis_type, parameter_hash)`), and provenance columns (`source_versions_json`, `source_data_version`, `db_release_version/commit`, `validation_json`).
- Per-snapshot **reproducibility bundle** `analysis_snapshot_reproducibility` (`db/migrations/041`, `api/functions/analysis-reproducibility.R`): gzipped canonical JSON of the inputs to independently recompute the served separation metric (functional LCC edge list + membership + served modularity; phenotype MCA coords + membership + served silhouette), plus a SHA-256 `reproducibility_hash`. Served today via public `GET /api/analysis/{functional,phenotype}_clustering/reproducibility` as `{reproducibility_hash, kind, byte_size, snapshot_id, bundle}`.
- **#571 dependency lineage** (`api/functions/analysis-snapshot-dependencies.R`): the `phenotype_functional_correlations` snapshot binds to the active `functional_clusters` (`{algorithm:"leiden"}`) and `phenotype_clusters` (`{}`) snapshots by `{snapshot_id, payload_hash}`, stored in `source_versions_json.dependencies`. On public read, `analysis_snapshot_dependency_status_code()` re-checks those against the currently active cluster manifests and returns `dependency_snapshot_mismatch` (fail-closed → 503) on drift. The lineage is exposed as `meta.snapshot.dependencies`.
- `meta.snapshot` (`api/services/analysis-snapshot-service.R`, "W3C-PROV / FAIR provenance, #347") already emits `snapshot_id, analysis_type, parameter_hash, schema_version, data_class, generated_at, stale_after, source_data_version, dependencies, input_hash, payload_hash, validation_hash, record_counts, db_release{version,commit}`.
- Canonical hashing: `analysis_snapshot_canonical_json()` = `jsonlite::toJSON(auto_unbox=TRUE, null="null", dataframe="rows")`; `payload_hash = sha256(canonical(payload_without[raw, partition_validation, reproducibility]))`. Reuse this serializer verbatim so release file bytes match the public API bytes and hash identically.

### 2.2 There is already a complete immutable-release precedent in this repo

`nddscore_release` (`db/migrations/023`) is a full content-addressed public-release table: `release_id` PK, `is_active` + generated `active_release_slot` UNIQUE, `import_status` ENUM, `artifact_hashes_json`, `source_archive_checksum/bytes`, `zenodo_record_url/version_doi/concept_doi/source_record_id`, `imported_by` FK, `*_current` views. The analysis-snapshot release table mirrors this shape (minus the single-active constraint — analysis releases coexist and are all retained). The frontend `NddScoreModelCard.vue` (Version / Version DOI / Concept DOI / Zenodo links, fed by `fetchCurrentRelease()`) is the exact per-release manifest UI precedent to generalize into a list + detail.

### 2.3 Reusable building blocks

- **Byte-streaming download**: `backup_endpoints.R` + `services/backup-endpoint-service.R` (`@serializer octet`, `Content-Type`, `Content-Disposition: attachment`, `Content-Length`, path-traversal guard, `readBin` stream). Template for `/bundle` and `/files/<path>`.
- **Checksum helpers**: `digest::digest(..., algo="sha256", serialize=FALSE)` (repo-wide), `digest::digest(file=path, algo="sha256")` (`nddscore-release-source.R:224`).
- **Zenodo download/verify precedent (consumer side)**: `nddscore-release-source.R` (`nddscore_fetch_zenodo_metadata`, `nddscore_verify_archive_checksum`, `nddscore_extract_and_verify` per-file SHA-256). The producer script mirrors the `../nddscore` upload flow.
- **`mount_endpoint()`** (RFC 9457 problem+json), `require_role()`, `with_test_db_transaction()`, cheap-route / external-budget static guards.

### 2.4 Live production evidence for #572

`GET https://sysndd.dbmr.unibe.ch/api/analysis/phenotype_functional_cluster_correlation` (2026-07-18) returns HTTP 200, snapshot 40, schema 1.2, **no `meta.snapshot.dependencies`**. The active `functional_clusters` snapshot is 41 (generated 10:46) while the correlation (40, generated 10:39) predates it — exactly the drift #571 guards. Production is running pre-#571 code; on `master` this read now fails closed as `dependency_snapshot_mismatch`. **A release must not be built from a lineage-less correlation snapshot**, so #572 is a hard prerequisite (Part 3).

---

## 3. Goals / Non-goals

### Goals
- G1. A stable, immutable, content-addressed public release that pins the functional, phenotype, and phenotype-functional-correlation layers together with their dependency lineage and per-file SHA-256 checksums.
- G2. Public read-only catalog, per-release manifest, per-file retrieval, and a single downloadable bundle via documented stable API URLs — retrieval-only (no compute, refresh, LLM, external calls, or writes).
- G3. Admin can build a release only from coherent, public-ready, non-stale, lineage-verified snapshots; a build from incoherent/stale/mismatched sources is rejected with a specific reason.
- G4. A later snapshot refresh leaves every prior release **byte-identical** and publicly retrievable; releases are retained indefinitely.
- G5. Verification UI + "how to verify" docs; OpenAPI + operator/developer docs describe creation, retention, and the reproducibility boundary.
- G6. Operator Zenodo archival path mirroring `../nddscore` (draft-only, guarded publish, DOI recorded back additively).
- G7 (#574). Server-side `category_filter` for `POST /api/jobs/clustering/submit`, with an auditable provenance record; public GET snapshot endpoint stays a fixed snapshot.
- G8 (#572). Production serves lineage-carrying correlation snapshots and fails closed on drift.

### Non-goals
- Do not rerun or change any biological analysis, cluster membership, validation metrics, cache keys, or LLM-summary validity to publish an archive (release construction is a pure additive provenance layer).
- Do not add an in-app auto-upload-to-Zenodo path or publish a Zenodo record without an explicit operator confirmation.
- Do not make `GET /api/analysis/functional_clustering?category_filter=...` compute on demand (#574).
- Do not expose draft curation, admin/user/job/log data, credentials, internal paths, prompts, cache-only material, or write operations through any public release route.
- No DOI minting logic inside the API (Zenodo/DataCite own DOIs); the API only records a DOI supplied by the operator.

---

## 4. Best-practices grounding

- **Content-addressing / immutability**: release identity is a SHA-256 `content_digest` over the invariant scientific content (per-layer `payload_hash`/`input_hash`/`reproducibility_hash` + `source_data_version` + schema versions). Rebuilding from identical snapshots yields the identical `release_id` (idempotent); any content change yields a new id. Mirrors Software/Data Heritage and the existing snapshot `payload_hash` discipline.
- **FAIR + verifiable manifest**: a custom `manifest.json` (precise snapshot lineage + dependency graph + per-file checksums) is the verifiability core; the Zenodo staging additionally ships a Frictionless **`datapackage.json`** (consistent with `../nddscore`), a **`CITATION.cff`**, and a `checksums.sha256`. RO-Crate / JSON-LD is noted as an optional future enrichment, not v1 (Frictionless is simpler, already in the sibling repo, and sufficient).
- **Zenodo REST flow** (confirmed current): create draft → optionally reserve DOI (registered with DataCite only on publish; 100 files / 50 GB cap) → PUT file to bucket → set metadata → **stop at draft** unless explicit `--publish --confirm-publish`. Exactly the `../nddscore` `upload_sysndd_zenodo_dataset.py` shape.
- **Fail-closed provenance**: reuse the coherence gate (#514) and the #571 dependency gate at build time so an incoherent/stale/mismatched snapshot can never enter a release.
- **Least privilege / retrieval-only public surface**: public routes are DB-only reads over frozen release blobs; no external fetchers (cheap-route isolation guard extended to cover them).

---

# PART 1 — #573 Immutable public analysis-snapshot releases (primary)

## 5. Data model — migration `045_add_analysis_snapshot_release.sql`

Three tables (mirroring `nddscore_release` conventions: `utf8mb4_unicode_ci`, generated-slot pattern where a single-active is wanted). Releases are **self-contained frozen copies** so they survive snapshot pruning/refresh byte-identically.

### `analysis_snapshot_release` (head)
| column | type | notes |
|---|---|---|
| `release_id` | VARCHAR(64) PK | content-addressed, `asr_<content_digest[:12]>` |
| `release_version` | VARCHAR(32) | human date-version, e.g. `2026.07.18` (metadata, not in hash) |
| `title` | VARCHAR(255) | |
| `status` | ENUM('draft','published') NOT NULL DEFAULT 'draft' | drafts are admin-only; publishing exposes publicly and freezes |
| `manifest_schema_version` | VARCHAR(16) | release-manifest schema, start `1.0` |
| `content_digest` | CHAR(64) | SHA-256 over the invariant scientific content; determines `release_id` |
| `manifest_sha256` | CHAR(64) | SHA-256 over the exact stored `manifest.json` bytes |
| `bundle_sha256` | CHAR(64) | SHA-256 over the stored `bundle.tar.gz` bytes |
| `bundle_gzip` | LONGBLOB | the frozen `bundle.tar.gz` bytes, served verbatim |
| `bundle_bytes` | BIGINT | |
| `source_data_version` | VARCHAR(128) | shared source-data version pinned across all layers |
| `db_release_version` | VARCHAR(64) / `db_release_commit` VARCHAR(64) | human DB release label at build time |
| `scope_statement` | TEXT | what is reproducible vs served-only |
| `license` | VARCHAR(64) DEFAULT 'CC-BY-4.0' | |
| `file_count` | INT / `total_bytes` BIGINT | over per-file blobs (excludes bundle) |
| `created_by_user_id` | INT FK user ON DELETE SET NULL | |
| `created_at`/`published_at`/`updated_at` | DATETIME(6) | |
| `zenodo_record_id` VARCHAR(32) / `zenodo_record_url` VARCHAR(255) / `version_doi` VARCHAR(128) / `concept_doi` VARCHAR(128) | | nullable; **additive external provenance, excluded from `content_digest`/`manifest_sha256`** so recording a DOI never changes release identity |
| `last_error_message` | TEXT | |

Keys: PK `release_id`; `KEY (status, created_at)`; `KEY (content_digest)`. No single-active slot — releases coexist; "latest" = newest `published`.

### `analysis_snapshot_release_member` (pinned snapshots)
`release_id` VARCHAR(64) FK→release ON DELETE CASCADE, `analysis_type` VARCHAR(64), `snapshot_id` BIGINT, `parameter_hash` CHAR(64), `input_hash` CHAR(64), `payload_hash` CHAR(64), `schema_version` VARCHAR(16), `reproducibility_hash` CHAR(64) NULL, `role` ENUM('layer','dependency') DEFAULT 'layer'. PK `(release_id, analysis_type, parameter_hash)`; `KEY (snapshot_id)` (used by the prune guard, §9).

### `analysis_snapshot_release_file` (immutable content)
`release_id` VARCHAR(64) FK→release ON DELETE CASCADE, `file_path` VARCHAR(255), `content_sha256` CHAR(64), `byte_size` INT, `media_type` VARCHAR(64) DEFAULT 'application/json', `content_gzip` LONGBLOB (gzipped canonical bytes; decompress on read, mirroring reproducibility storage). PK `(release_id, file_path)`; `KEY (content_sha256)`.

> Storing gzipped copies (not references to snapshot rows) is the immutability guarantee: a release is decoupled from the mutable snapshot lifecycle and from `analysis_snapshot_prune`. Total per release ≈ a few MB gzipped; retaining dozens is negligible.

## 6. Release identity, files, and manifest

**Layer registry** `analysis_snapshot_release_layers()` (new; single source of truth), default 3 manuscript layers, registry-driven so more can be added:
- `functional_clusters` (`{algorithm:"leiden"}`) → files `functional_clusters/payload.json`, `functional_clusters/reproducibility.json`
- `phenotype_clusters` (`{}`) → files `phenotype_clusters/payload.json`, `phenotype_clusters/reproducibility.json`
- `phenotype_functional_correlations` (`{algorithm:"leiden"}`) → file `phenotype_functional_correlations/payload.json` (+ its dependency lineage on the two cluster layers)

**File set per release** (all canonical JSON via `analysis_snapshot_canonical_json`, deterministic bytes):
- per-layer `payload.json` = the **complete** snapshot payload, i.e. the exact object the snapshot's `payload_hash` is computed over (`payload` minus `raw`/`partition_validation`/`reproducibility`), serialized with `analysis_snapshot_canonical_json`. This is the full result set (all clusters/members/correlation rows), **not** a paginated GET page. Consequence: `content_sha256(payload.json) == payload_hash` of the pinned snapshot — a direct cryptographic tie between the release file and the live snapshot manifest. (Build reads the stored/reconstructed payload, not the paginated public endpoint.)
- per-cluster-layer `reproducibility.json` = the decoded reproducibility bundle (`analysis_reproducibility_decode`); `content_sha256(reproducibility.json)` relates to the snapshot's `reproducibility_hash` (same canonical serializer as `analysis_reproducibility_canonical_json`; the plan pins whichever serializer keeps the equality exact).
- `README.md` = generated human scope + verification instructions
- `manifest.json` = the release manifest (below)
- `checksums.sha256` = `"<sha256>  <path>"` for every file **except `checksums.sha256` itself** (includes `manifest.json`)
- `bundle.tar.gz` = deterministic tar (sorted entries, mtime=0, uid/gid=0, mode 0644) of all the above, gzipped; built once, stored on the release row, served verbatim — so its own SHA-256 is fixed and citeable.

**`manifest.json` (the verifiability core):**
```jsonc
{
  "manifest_schema_version": "1.0",
  "release_id": "asr_<12hex>",
  "release_version": "2026.07.18",
  "title": "...",
  "created_at": "2026-07-18T10:00:00Z",
  "content_digest": "<sha256>",              // == basis of release_id
  "license": "CC-BY-4.0",
  "scope_statement": "...",
  "generator": {
    "api_version": "0.30.0",
    "analysis_snapshot_schema_version": "1.2",
    "reproducibility_schema_version": "1.0",
    "cluster_logic_version": "2026-07-06.510-expdb"
  },
  "source": { "source_data_version": "c41b5d8...", "db_release": { "version": "1.0.0", "commit": "..." } },
  "layers": [
    { "analysis_type": "functional_clusters", "parameter_hash": "ef3a...", "snapshot_id": 41,
      "schema_version": "1.2", "input_hash": "390e...", "payload_hash": "a142...",
      "reproducibility_hash": "...", "record_counts": {"members":2605,"clusters":18},
      "files": ["functional_clusters/payload.json","functional_clusters/reproducibility.json"] },
    { "analysis_type": "phenotype_clusters", "...": "..." },
    { "analysis_type": "phenotype_functional_correlations", "snapshot_id": 42, "payload_hash": "...",
      "dependencies": {
        "functional_clusters": { "snapshot_id": 41, "payload_hash": "a142..." },
        "phenotype_clusters":  { "snapshot_id": 39, "payload_hash": "bbce..." } },
      "files": ["phenotype_functional_correlations/payload.json"] }
  ],
  "files": [ { "path": "functional_clusters/payload.json", "sha256": "...", "bytes": 12345, "media_type": "application/json" }, "..." ],
  "reproducibility_boundary": "Reproduces the served separation metrics (functional modularity, phenotype silhouette) and the cross-cluster correlation from the bundled reproducibility inputs. LLM summaries and fCoSE layout coordinates are served-only and excluded."
}
```
- `files[]` excludes `manifest.json` and `checksums.sha256` (Frictionless-style, mirrors `../nddscore` `datapackage.json`).
- `manifest_sha256` (row) = SHA-256 of the exact `manifest.json` bytes — served in LIST/HEAD so a client can verify the manifest itself.
- `content_digest` = `sha256(canonical({ manifest_schema_version, source_data_version, layers:[sorted {analysis_type, input_hash, payload_hash, reproducibility_hash, dependencies}] }))`. **Excludes `created_at`, `title`, and DOI** so identity is a pure function of scientific content. `release_id = "asr_" + content_digest[:12]`.

## 7. Build path — `analysis_snapshot_release_build()` (admin, synchronous, DB-only)

New `api/functions/analysis-snapshot-release.R` (registered in `bootstrap/load_modules.R`) + service `api/services/analysis-snapshot-release-service.R`.

1. **Load + gate each layer**: for each registry layer, `analysis_snapshot_get_public(analysis_type, parameter_hash)` and require `status_code == "available"`. This reuses (a) the coherence gate for clusters and (b) the #571 dependency gate for the correlation. Any `snapshot_missing | snapshot_stale | source_version_mismatch | schema_version_mismatch | dependency_snapshot_mismatch` → **reject build** with HTTP 409 + that exact reason.
2. **Cross-layer coherence** (belt-and-suspenders): assert all layers share one `source_data_version`; assert the correlation's stored `dependencies` point at exactly the pinned functional + phenotype `snapshot_id`+`payload_hash`. Mismatch → 409.
3. **Materialize files**: copy each served payload + decoded reproducibility bundle to canonical-JSON bytes; generate `README.md`; compute per-file `content_sha256` + `byte_size`.
4. **Assemble manifest** (§6), compute `content_digest` → `release_id`. If a release with that `release_id` already exists → 409 `release_already_exists` (idempotent content-addressing; returns the existing head).
5. **Build `checksums.sha256`** and the deterministic **`bundle.tar.gz`**; compute `manifest_sha256`, `bundle_sha256`.
6. **Persist in one transaction**: insert release (status per `publish` flag), members, files. `DBI::dbBind` with `unname()`; blobs bound as `list(raw)`.
7. Return the release head. **No external calls, no clustering recompute, no LLM, no cache writes.**

`POST /api/admin/analysis/releases` body: `{ layers?: [...], title?, scope_statement?, license?, publish?: true }` (default `publish:true`; `false` stages a draft for review before a Zenodo run). Administrator-gated.

## 8. Public read routes (retrieval-only) — `analysis_endpoints.R` (`/api/analysis`, unauthenticated)

Mounted in the same sub-router as the reproducibility routes (Plumber cannot mount a second router on `/api/analysis`). All DB-only; problem+json via `mount_endpoint`. `latest` declared **before** the dynamic `/<release_id>` route (the `/status/_list` shadowing lesson).

| Route | Returns |
|---|---|
| `GET /releases?limit=&offset=` | list of **published** releases: `{release_id, release_version, title, created_at, published_at, source_data_version, manifest_sha256, bundle_sha256, license, file_count, total_bytes, layers:[{analysis_type, snapshot_id, payload_hash}], zenodo:{record_url,version_doi,concept_doi}|null}` + pagination |
| `GET /releases/latest` | newest published release head (same shape as detail) |
| `GET /releases/<release_id>` | release head + full manifest object |
| `GET /releases/<release_id>/manifest.json` | the **exact stored** `manifest.json` bytes (Content-Type `application/json`), so `sha256(bytes)==manifest_sha256` |
| `GET /releases/<release_id>/files/<path>` | one content-addressed file; decompress `content_gzip`; `media_type`; path looked up by exact `(release_id, file_path)` — **anything not in the table → 404** (no filesystem, no traversal surface) |
| `GET /releases/<release_id>/bundle` | `@serializer octet`, `Content-Disposition: attachment; filename="<release_id>.tar.gz"`, stream `bundle_gzip` verbatim (backup-endpoint template) |

- Unknown or `draft` release → 404 (drafts never public).
- A release being minted is a synchronous admin op, so there is no public "preparing" state; still, reuse the friendly-error frontend classifier for any transient 5xx.

## 9. Immutability, retention, pruning

- Published releases are **never** auto-pruned; `manifest.json`/files/bundle are frozen at build.
- A snapshot refresh mints a new snapshot → a fresh admin build mints a **new** release (new `content_digest`/`release_id`); prior releases stay byte-identical (they hold their own frozen copies — no dependency on the source snapshot surviving).
- Defensive guard: extend `analysis_snapshot_prune` to **skip any `snapshot_id` referenced by a `analysis_snapshot_release_member`** so the *live* reproducibility endpoint for a pinned snapshot also keeps working (not required for release integrity, which is self-contained, but avoids a confusing 503 on the live endpoint for a still-cited snapshot).
- Draft delete allowed (`DELETE /api/admin/analysis/releases/<id>` only when `status='draft'`); published delete forbidden.

## 10. Admin routes — `admin_analysis_snapshot_endpoints.R` (`/api/admin/analysis`, Administrator)

| Route | Purpose |
|---|---|
| `POST /releases` | build (+optionally publish) from current coherent snapshots → 201 head / 409 reason |
| `GET /releases` | list all incl. drafts + status |
| `GET /releases/<id>` | admin detail (incl. draft) |
| `POST /releases/<id>/publish` | publish a draft |
| `PATCH /releases/<id>/doi` | record `{zenodo_record_id, zenodo_record_url, version_doi, concept_doi}` (additive; the only post-publish mutation; outside the content hash) |
| `DELETE /releases/<id>` | delete a **draft** only |

## 11. UI/UX

### Public "Data releases" page (`/DataReleases`)
- New view `app/src/views/analyses/DataReleases.vue` (copy `GeneNetworks.vue`: `AnalysisShell` + `useHead`).
- Releases list (`GenericTable`/`BTable`, **flat field keys** — alias any dotted key; bind reactive tooltips via directive value) → row select opens a `SectionCard`-wrapped manifest panel styled like `NddScoreModelCard.vue`'s `<dl>` grid: `release_id`, `release_version`, `created_at`, `source_data_version`, `manifest_sha256`/`bundle_sha256` (mono, truncated + copy button), per-layer `snapshot_id` + `payload_hash`, the dependency lineage (functional↔phenotype↔correlation), license, and DOI links (`doiUrl()`, `target=_blank rel=noopener`) when present.
- Download buttons: `manifest.json`, `bundle.tar.gz` (via `apiClient.raw.get<Blob>(..., {responseType:'blob'})`, `browseComparisonsXlsx` precedent), and per-layer files.
- A **"How to verify"** disclosure: the exact `sha256`/`tar` commands and what is reproducible vs served-only.
- New typed client `app/src/api/releases.ts` (+ `releases.spec.ts`, MSW) mirroring `about.ts`/`nddscore.ts`: `listReleases()`, `getLatestRelease()`, `getReleaseManifest(id)`, `getReleaseFileUrl(id, path)`, `downloadReleaseBundle(id)`. Errors via `extractApiErrorMessage`; Plumber-scalar unwrap via `unwrapScalar`.
- Routing: public route in `routes.ts` with `meta.sitemap: { priority: 0.7, changefreq: 'monthly' }`; nav item under `analyses_dropdown` in `main_nav_constants.ts` ("Data releases"); route-registration assertion in `routes.spec.ts`.
- SEO: add `/DataReleases` to backend `/api/seo/routes` `static`; optionally a `buildReleaseSeo()` prerender branch + `sitemap-releases.xml` + fixture (recommended for a citable dataset landing surface); `make verify-seo-app` must pass.

### Admin surface
- Thin admin panel (extend the analysis-snapshots admin view or add `ManageAnalysisReleases.vue`): "Build release from current snapshots" (shows the current coherence/lineage status first, disables build when any layer is not `available`), a releases table with status + Build/Publish/Record-DOI actions, and a copy-paste operator block for the Zenodo packaging command. Reuse `AuthenticatedPageShell`, typed admin client.

### Public correlation page affordance
- A small "Cite this data" / data-availability note on the phenotype-functional correlation page linking to `latest` release (nice-to-have, low risk).

## 12. Zenodo operator archival (Slice C — mirror `../nddscore`)

Operator-run, never in-app auto-upload. R script `api/scripts/package-analysis-release-zenodo.R` + Make targets `analysis-release-zenodo-package` / `analysis-release-zenodo-upload-draft` (mirroring the sibling `sysndd-zenodo-package` / `-upload-draft`).

1. Given a **published** `release_id`, read its files + manifest (from DB via `Rscript` in-container, or via the public API) into a staging dir:
   ```
   outputs/analysis_release_zenodo/<release_id>/
     README.md  DATA_CARD.md  SCHEMA.md  CHANGELOG.md  CITATION.cff
     datapackage.json  zenodo_metadata.json  checksums.sha256
     manifest.json  functional_clusters/…  phenotype_clusters/…  phenotype_functional_correlations/…
   ```
2. Build `datapackage.json` (Frictionless: resources with `path`/`bytes`/`hash`/`mediatype`, excludes self + `checksums.sha256`), `zenodo_metadata.json` (`upload_type=dataset`, `access_right=open`, `license=cc-by-4.0`, `version`, creators+ORCID, keywords, `language=eng` — DOI never sent as a manual field), `CITATION.cff` (placeholder DOI until reserved).
3. **Safety validator** (mirror `validate_zenodo_staging_directory`): no `.env`/token/credential/internal-path/prompt/draft-curation/private files; scan text files for secret patterns; verify every file's checksum; verify the archive extracts to the expected layout. Because release files are already approved-public snapshot payloads, the scan is a belt-and-suspenders guard, not the primary control.
4. Tar deterministically → `outputs/zenodo/<release_id>.tar.gz` + `.sha256`.
5. `analysis-release-zenodo-upload-draft`: create/reuse a Zenodo **draft** deposition (`ZENODO_TOKEN`), PUT the archive to the bucket, set metadata, **stop at draft** and print the reserved DOI + draft URL. Publish only with explicit `--publish --confirm-publish`. (Same guarded shape as `upload_sysndd_zenodo_dataset.py`.)
6. After Zenodo publish, operator records the DOI back: `PATCH /api/admin/analysis/releases/<id>/doi` → the public LIST/HEAD advertises the DOI (additive; release bytes unchanged).

> Sandbox first: support `--sandbox` (`https://sandbox.zenodo.org/api`) exactly like the sibling script; the real publish is a deliberate human step.

---

# PART 2 — #574 Category-selected gene universes (companion)

## 13. Scope

Extend `POST /api/jobs/clustering/submit` (and `/api/jobs/phenotype_clustering/submit` only if trivially symmetric; else defer) with a server-side `category_filter`. Keep the explicit `genes` pathway and the fixed public GET snapshot unchanged.

Request (mutually exclusive with `genes`):
```json
{ "category_filter": ["Definitive"], "algorithm": "leiden" }
```

### Semantics
- `category_filter` ⊕ `genes` (supplying both → 400).
- Resolve the universe from **NDD entities** (not the gene-level display label): a gene qualifies if it has **≥1 NDD entity** whose curated status category is in `category_filter`. A gene with an additional lower-confidence entity is **not** excluded. Deduplicate HGNC IDs.
- Validate every value against **active curated status categories** (`ndd_entity_status_categories_list`); unknown/empty/contradictory → 400 problem+json.
- Neither `genes` nor `category_filter` → all NDD genes (current behavior preserved).
- Preserve deterministic functional settings (Leiden, seed, weighted STRING exp+db graph, score threshold) unless explicitly versioned.

### Provenance & result contract
- Persist + return: the selector, resolved **distinct-gene count**, a **sorted-HGNC-list SHA-256** (`sha256(canonical(sort(unique(hgnc_ids))))`), analysis code/data version (`CLUSTER_LOGIC_VERSION`, `source_data_version`), STRING channel + threshold.
- Include the resolved gene list (or a retrievable immutable job-input record) so a sensitivity run is independently auditable.
- Keep results **distinct from public-ready snapshots** — never activate as `public_ready`; a category GET remains unsupported (`unsupported_parameter`) until an explicitly-built preset exists.
- **Duplicate-job identity** includes the resolved selector/list + analysis fingerprint (extend the existing dedupe key, e.g. include the sorted-HGNC SHA-256), so a Definitive run and an all-gene run don't collide.
- Respect the existing public submit throttle (`async_job_capacity_exceeded()` / `ASYNC_PUBLIC_JOB_CAP`).

### Tests
Category→gene resolution; multi-entity genes (mixed-confidence gene stays included); validation + mutual exclusion; payload/provenance fields; backward compatibility (explicit-list and no-list unchanged); an integration test asserting the job's universe equals the resolved Definitive set without any client-side filter.

---

# PART 3 — #572 production lineage runbook (deployment prerequisite)

No new code (PR #571 is on `master`). The plan sequences this **before** the first release build:

1. Deploy current `master`; restart `api`, `worker`, `worker-maintenance`.
2. As Administrator, `POST /api/admin/analysis/snapshots/refresh` with `analysis_type=phenotype_functional_correlations`, `force=true`.
3. Confirm `GET /api/analysis/phenotype_functional_cluster_correlation` reports `meta.snapshot.dependencies` for both `functional_clusters` and `phenotype_clusters` (each with `snapshot_id` + `payload_hash`).
4. Confirm a later cluster-axis refresh makes an out-of-date correlation unavailable with `dependency_snapshot_mismatch` until rebuilt.
5. Notify manuscript maintainers to regenerate from the verified live snapshot.
6. **Then** build the first analysis-snapshot release (Part 1) from the now-lineage-carrying snapshots.

---

## 14. Testing & hardening strategy

- **R unit** (`api/tests/testthat/`): manifest determinism (same snapshots → same `content_digest`/`release_id`/`manifest.json` bytes); per-file checksum correctness; canonical-JSON byte-equality with served payloads; immutability (a rebuild after a snapshot refresh mints a new release; the prior release stays byte-identical); **rejection** of incoherent / stale / `source_version_mismatch` / `dependency_snapshot_mismatch` sources with the specific reason; `release_already_exists` idempotency; `latest` route ordering; `/files/<path>` unknown-path → 404 (no traversal); draft never public; DOI patch stays outside the content hash.
- **Integration** (`with_test_db_transaction()`): build → list → fetch manifest/files/bundle → verify checksums via the router; admin auth (public write routes forbidden; drafts hidden from public).
- **Static guards**: `mount_endpoint` wrapping (problem+json) for the new sub-routers; extend cheap-route/external-budget isolation guards to the release routes (DB-only, no external fetcher); bound-parameter SQL only (no interpolation of `<release_id>`/`<path>`); confirm release payloads contain only approved-public snapshot data.
- **#574**: the unit + integration coverage in §13.
- **Frontend**: `releases.spec.ts` (MSW), a `DataReleases.vue` view spec, dotted-key/tooltip-reactivity guards if `BTable` is used, `routes.spec.ts` assertion, `make verify-seo-app`.
- **Verify in running app / production** (per directive): after #572 deploy, re-probe the correlation endpoint for `dependencies`; build a release in the dev stack and verify the "How to verify" recipe end-to-end (download `manifest.json` + `bundle.tar.gz`, recompute SHA-256, confirm they match); drive the public `/DataReleases` page in the browser.
- Gates: `make code-quality-audit`, `make lint-api`, `make lint-app`, `cd app && npm run type-check`, `make test-api-fast` (fast gate) then `make ci-local` before handoff. Keep every touched file < 600 lines (split builder/service/manifest/files helpers).

## 15. Documentation contract

- `AGENTS.md`: add an "Analysis-snapshot releases" invariant block (immutability, content-addressing, retrieval-only public surface, coherence/lineage build gate, DOI-outside-hash, no-prune, worker-not-required-since-synchronous).
- `documentation/09-deployment.qmd`: operator runbook — build/publish/record-DOI, retention, reproducibility boundary, the Zenodo packaging/draft-upload flow, and the #572 prerequisite.
- `documentation/08-development.qmd`: developer flow — building a release locally, verifying a bundle, the manifest schema.
- OpenAPI (`api/version_spec.json` / route annotations), `README.md`/`CHANGELOG.md`, four-surface version bump per repo convention.
- New skill pointer or extend `.agents/skills/sysndd-analysis-snapshots/SKILL.md` with the release layer.

## 16. Slicing & rollout order

- **Slice 0 (#572)**: production deploy + force-refresh + verify lineage (prerequisite; no code).
- **Slice A (#573 core)**: migration 045, `analysis-snapshot-release.R` + service, admin build/publish endpoints, public read routes, unit/integration tests, docs. Independently shippable (usable via API/curl).
- **Slice B (#573 UI)**: `releases.ts` client, `/DataReleases` public page + verify UI, admin panel, SEO/nav, frontend tests.
- **Slice C (#573 Zenodo)**: operator packaging + draft-upload script + Make targets + `PATCH …/doi` wiring + docs. Depends on A.
- **Slice D (#574)**: category-selected clustering submit + provenance + tests. Independent of A–C (can land in parallel).

Each slice = its own branch + PR + Codex diff review, following the repo's plan→Codex-plan-review→TDD→Codex-diff-review→PR workflow.

## 17. Risks & chosen defaults

- **Deterministic tar**: base-R `utils::tar` is not deterministic by default → build the archive once at build time with sorted entries, `mtime=0`, `uid/gid=0`, mode `0644`, store the bytes, serve verbatim. (If R determinism is fiddly, the stored-once approach makes determinism moot; `bundle_sha256` is fixed regardless.)
- **Storage growth**: frozen copies cost a few MB/release; acceptable and bounded by manual, admin-initiated builds. No auto-build.
- **Build cost**: synchronous admin op is DB-only and fast (copy + hash + gzip of a few MB). If it ever grows (more layers), it can move to a durable job; not needed for v1.
- **Idempotency vs timestamps**: `content_digest` excludes `created_at` so identity is pure content; `created_at` is metadata only.
- **DOI immutability**: DOI stored outside the hashed manifest so recording it never changes release bytes; the manifest is minted before Zenodo (no DOI inside), matching Zenodo's "DOI reserved only at publish" model.
- **#574 scope creep**: kept to the async submit endpoint only; the fixed public GET is untouched; category GET stays `unsupported_parameter` until an explicit preset is built.

## 18. Acceptance-criteria mapping (#573)

| #573 AC | Design element |
|---|---|
| Admin creates a release only from coherent, public-ready snapshots | §7 build gate (coherence + #571 dependency + staleness), 409 on failure |
| Public list / manifest / immutable download via stable URLs | §8 routes |
| Manifest has enough lineage + checksums to verify every file locally | §6 manifest + `checksums.sha256` + reproducibility hashes |
| Later refresh leaves prior release byte-identical + retrievable | §5 frozen copies, §9 no-prune |
| Tests: public-only authz, immutability, checksum, dependency-lineage capture, incoherent/stale rejection | §14 |
| OpenAPI + operator/developer docs (creation, retention, reproducibility boundary) | §15 |
| (Manuscript) cite a stable public landing/API URL + checksum; DOI once archived | §8 `/releases/latest`, §12 Zenodo, §5 DOI columns |
