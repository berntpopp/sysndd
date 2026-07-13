# #552 MCP SELECT-Only Principal Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans task-by-task. TDD RED must precede product code.

**Goal:** Run MCP as fixed `sysndd_mcp@%`, configured only by dedicated `MCP_DB_*` injection and granted object-level `SELECT` on exactly 23 filtered approved-public views.

**Architecture:** Migration 044 creates `DEFINER=CURRENT_USER SQL SECURITY DEFINER` `mcp_public_*` views through the ordinary migration runner. Catalog/review/NDDScore views are flat; analysis uses one bounded DAG: `mcp_public_analysis_source_version` → `mcp_public_analysis_manifest` → analysis children and LLM. `CURRENT_USER` is the existing schema migrator/API database identity; it defines views but is never an MCP connection credential. A privileged operator provisioner only reconciles the dedicated reader after 044 exists. MCP gets `USAGE` plus exact view `SELECT`, with no raw/schema/global/DML/DDL/routine/role/PROXY/`SHOW VIEW`/grant-option authority. MCP startup uses only `MCP_DB_*`, attests identity/grants/roles and every projection, and fails closed.

**Scope:** This is a bounded database least-privilege change. It adds no ProxySQL, separate definer account, staged/root migration runner, provider proxy, sealed cohort, source-generation control plane, host lock, dedicated image, or worker mutex. Ordinary migration/bootstrap/dev/smoke/Playwright paths remain valid because 044 is executed by their existing schema principal. MCP repositories read projections only.

## Exact 23-view contract

- Catalog/comparison (8): `mcp_public_gene`, `mcp_public_hgnc_symbol`, `mcp_public_entity`, `mcp_public_disease`, `mcp_public_phenotype`, `mcp_public_variation`, `mcp_public_comparison`, `mcp_public_comparison_metadata`.
- Approved curation (4): `mcp_public_review`, `mcp_public_review_phenotype`, `mcp_public_review_variation`, `mcp_public_review_publication`; modifier/publication fields are flattened, not separately granted.
- Public analysis (7): `mcp_public_analysis_manifest`, `mcp_public_analysis_network_node`, `mcp_public_analysis_network_edge`, `mcp_public_analysis_cluster`, `mcp_public_analysis_cluster_member`, `mcp_public_analysis_correlation`, `mcp_public_analysis_source_version`.
- Derived content (4): `mcp_public_llm_cluster_summary`, `mcp_public_nddscore_release`, `mcp_public_nddscore_gene_prediction`, `mcp_public_nddscore_hpo_prediction`.

Predicates are enforced in SQL, not by repository convention:

- Every entity-derived shape requires active entity, HGNC `status='Approved'`, and accepted active disease/MOI/status/category rows. Reviews additionally require primary+approved; children require review/connect/entity equality, active connect and active referenced vocabulary. Reviewed publications only.
- Comparison rebuilds both branches from raw dependencies. The SysNDD branch uses the same gates plus `ndd_entity.ndd_phenotype=1`. Every external row must inner-join its exact non-NULL `hgnc_id` to `non_alt_loci_set.status='Approved'`; withdrawn, alias-only, unknown, and NULL mappings are excluded. Metadata exposes the current singleton's four consumed non-secret fields and no error/ID.
- `mcp_public_analysis_source_version` implements the existing `analysis_snapshot_source_data_version()` SQL formula byte-for-byte; the R function reads that singleton so API and MCP cannot drift. This issue does not change snapshot input semantics, memoise keys, clustering builders, or correlation provenance.
- Manifest eligibility joins the singleton source view and requires both public-ready fields, `stale_after IS NOT NULL AND stale_after > UTC_TIMESTAMP()`, equality to the existing current source version, and current `ANALYSIS_SNAPSHOT_SCHEMA_VERSION`. Every child and LLM view joins the eligible manifest. Tests freeze the exact DAG and forbid every other projection dependency. Filtered stale/source/schema failures intentionally collapse to `snapshot_missing`; MCP cannot read an ineligible row merely to diagnose it.
- LLM rows are current+validated, match the code-level `LLM_SUMMARY_PROMPT_VERSION` literal and eligible cluster/hash; they do not join the separately administered active-template table. A test freezes 044's literal against the R constant. SQL reconstructs `summary_json` from a frozen user-facing key allowlist; judge/status/reasoning/unknown nested keys never pass through. NDDScore children join an active successfully imported release.

## Task 1: Write and capture RED

**Create:**

- `api/tests/testthat/test-mcp-select-principal-config.R`
- `api/tests/testthat/test-mcp-select-principal-projections.R`
- `api/tests/testthat/test-mcp-select-principal-provisioner.R`
- `api/tests/testthat/test-mcp-result-cache-withdrawal.R`
- `api/tests/testthat/helper-mcp-select-principal.R`, explicitly sourced.

- [ ] Test fail-closed config: ordinary `MYSQL_*`, direct `MCP_DB_PASSWORD`, and readable `config.yml` never satisfy MCP; require valid host/port/db, fixed user, bounded pool, and an owner-only `MCP_DB_PASSWORD_FILE`. Use `base::get`/`base::exists` where masked.
- [ ] Parse 044 and freeze exact view/column/dependency set, `DEFINER=CURRENT_USER`, `SQL SECURITY DEFINER`, the sole approved analysis DAG, no `SELECT *`, every lifecycle/entity/source/schema/member/JSON predicate, and no forbidden columns/JSON keys. External comparison fixtures cover approved exact HGNC, withdrawn HGNC, alias-only, unknown and NULL IDs.
- [ ] Test the source-version view and `analysis_snapshot_source_data_version()` return exactly the same value on approved fixtures. Test manifest/children empty for non-public, stale, NULL-expiry, source-mismatch, and old-schema rows.
- [ ] Test provisioner statement planning with quoted/wildcard hosts, excessive grants, roles/default roles, PROXY, mandatory roles and sessions. Require a non-secret, newline-free `MCP_EXPECTED_VIEW_DEFINER=user@host`; all catalog-derived account/role pieces use connection-aware quoting and session IDs are bounded positive integers. A stored otherwise-exact view created by a different definer must fail attestation.
- [ ] Static guards require every MCP repository `FROM`/`JOIN` to name projections only; remove metadata fallback and shared raw NDDScore/snapshot delegates. Warm and withdraw every former result-cache tool.
- [ ] Run the four files and preserve expected RED before product code.

## Task 2: Implement migration and shared public-source contract

**Files:**

- Create `db/migrations/044_mcp_public_read_projections.sql`.
- Create `api/functions/mcp-readonly-contract.R` (split columns if needed).
- Modify `api/functions/migration-manifest.R` to latest 044/count `42L`.
- Modify migration manifest/count/core-view tests.
- Modify `api/functions/analysis-snapshot-repository.R` so currentness reads the projection's existing-semantic singleton rather than duplicating SQL.

- [ ] Implement exact flat views with explicit columns and predicates. Migration contains no password, account creation, grant, trigger, procedure, or control table. The normal runner creates them as its own `CURRENT_USER`.
- [ ] Implement machine-readable projection/columns/dependencies/JSON/lifecycle/grant contract plus deterministic normalization of trusted 044 view SQL. Administrator attestation compares every stored `VIEW_DEFINITION`/`SHOW CREATE VIEW`, dependency DAG, ordered columns, security mode, and actual migration definer against the trusted normalized definition; columns/definer alone are insufficient.
- [ ] Run projection/migration runner/count tests, then bootstrap a disposable MySQL 000–044 twice. Expected GREEN, no skips, no special administrator choreography.

## Task 3: Dedicated MCP configuration and projection-only reads

**Files:**

- Create `api/functions/mcp-readonly-config.R`, `api/bootstrap/create_mcp_pool.R`, `api/functions/mcp-readonly-attestation.R`.
- Modify `api/start_sysndd_mcp.R`, `api/functions/db-helpers.R`, all `mcp-*repository.R` files and focused snapshot/NDDScore readers.
- Modify `mcp-service.R`, `mcp-record-service.R`, `mcp-query-service.R`, `mcp-capabilities-service.R`, `mcp-analysis-service.R`, `mcp-research-context-service.R`, `mcp-analysis-llm-cache-service.R`.
- Modify `api/config/mcp/resources/sysndd-schema.md` and snapshot-diagnostic tests to remove cache claims and collapse filtered states to `snapshot_missing`.
- Modify `test-mcp-cache-bootstrap.R`, `test-mcp-tools.R`, `test-mcp-repository.R`, `test-mcp-analysis-repository.R`, `test-mcp-analysis-service.R`, `test-mcp-analysis-research-context.R`, `test-mcp-search-analysis-fixes.R`, `test-mcp-search-ranking.R`, and `test-mcp-snapshot-diagnostics.R`.

- [ ] Build config/pool only from explicit `MCP_DB_*`; set runtime before setup; MCP `get_db_connection()` aborts if its pool is absent. Remove normal config, broad config directory and API cache mounts; retain only required MCP resource config.
- [ ] Before listener startup require `CURRENT_USER()='sysndd_mcp@%'`, `CURRENT_ROLE()='NONE'`, global `mandatory_roles` empty, exact normalized own grants, and `LIMIT 0` on every projection. Missing/extra/effective privilege fails closed.
- [ ] Repoint every MCP read to projections with bound values and constant identifiers. Remove all `mcp_cached()` call sites and cache claims. Shape LLM output through the same allowlist.
- [ ] Invert legacy tests to require projection SQL/MCP-owned readers and cache absence; assert capabilities/resources expose no result-cache claim and no stale/source-mismatch diagnostic. Run focused suite GREEN with zero skips.

## Task 4: Reader provisioner and deployment wiring

**Files:**

- Create `api/functions/mcp-readonly-provisioner.R`, `api/scripts/provision-mcp-readonly-principal.R`.
- Modify `docker-compose.yml`, `docker-compose.override.yml`, `.env.example`, deployment docs.

- [ ] Privileged connection input is only `MCP_ADMIN_DB_*`; independently require non-secret `MCP_EXPECTED_VIEW_DEFINER=user@host`, documented as the identity that ran migration 044. Never infer it from the administrator connection or trust stored view metadata. The command has an explicit serialized-operator precondition and does not claim safe concurrent invocation or depend on an advisory lock. On one pinned administrator connection, enumerate reader/proxy sessions and host variants, lock every variant, kill sessions, and revoke effective authority before other fallible work.
- [ ] Remove bidirectional roles/PROXY, require global `mandatory_roles` empty, then recreate/repassword fixed `%` using MySQL 8.4 `IDENTIFIED BY RANDOM PASSWORD`; caller-supplied password literals or unsupported prepared placeholders are forbidden. Validate the exact one-row generated-password result in memory, grant exact 23 views, and compare canonical view hashes plus dependencies/columns/security/explicit definer to trusted 044. Atomically install the generated credential at owner-only `MCP_DB_PASSWORD_OUTPUT_FILE` only after final authority attestation, then unlock. Failure leaves variants locked/privilege-free and no partial secret temp file; serialized re-run is idempotent.
- [ ] Compose removes API credential/config/cache from MCP and injects dedicated `MCP_DB_HOST/PORT/NAME/USER` plus a read-only `MCP_DB_PASSWORD_FILE` only. The long bind uses `create_host_path: false`, so a missing secret fails closed instead of becoming a directory. No committed password. Document: stop MCP; let ordinary API migration complete 044; run provisioner to the ignored owner-only output path; inject/mount that file; start MCP. No snapshot rebuild is required because source-version semantics do not change.

## Task 5: Disposable live proof

**Files:**

- Create `docker-compose.mcp-select-verify.yml`, `api/scripts/verify-mcp-select-principal-live.R`, explicitly sourced fixture helper, and `make/mcp-select-principal.mk`; modify root `Makefile` to include the fragment and expose its phony target.

- [ ] Standalone Compose has no explicit/external production container/network/volume names. UUID-label/resource-ID checks precede mutation and cleanup. Persistent project is never joined or changed.
- [ ] Bootstrap 000–044 normally, capture its actual migrator identity as the explicit expected-definer input, seed hostile reader variants/grants/roles/PROXY/mandatory-role/session fixtures and replace one projection with a same-columns/same-definer/same-security malicious query. Separately recreate an otherwise-exact projection under the wrong definer. Run the real serialized provisioner; it must quarantine the reader and reject either alteration until 044 is operator-reapplied by the expected migrator. Seed approved, draft, secondary, inactive, cross-entity, non-NDD, public/non-public/old-schema, inactive NDDScore, and an **eligible matching validated LLM summary containing both allowed and forbidden top-level/nested sentinels**.
- [ ] As reader: approved SELECT succeeds; every raw catalog/review/status/connect/snapshot/cache/NDDScore SELECT fails; INSERT/UPDATE/DELETE fail on projections and raw objects. Direct projections never expose excluded sentinels/JSON.
- [ ] Start real MCP; freeze the exact 12 core + 6 analysis `tools/list` inventory and invoke **every listed tool** with tool-specific nonempty seeded identifier/value assertions and no `isError`, missing, substitute, or SKIP. Projection SELECT and every LLM-consuming tool must expose exactly the allowed summary key set and no forbidden/service-added sentinel. Flip manifest fixtures through pending/failed/superseded/stale/NULL-expiry/source-mismatch/old-schema states and prove every child/LLM view empties; warm/repeat former result-cache paths.
- [ ] Inspect argv/logs/URLs/payloads/Compose output for credential sentinels. `make verify-mcp-select-principal-live` prints one sanitized PASS after cleanup; no SKIP.

## Task 6: Gates, DIFF review, PR

- [ ] Run targeted tests, `make code-quality-audit`, `make lint-api`, `make test-api-fast`, `make test-mcp-smoke`, and the named live verifier. Every touched handwritten source/test/script file remains under 600 lines.
- [ ] Run detached xhigh DIFF review; fold every BLOCKER/HIGH and cheap MEDIUM/LOW through RED/GREEN until no BLOCKER/HIGH. Commit `.planning/reviews/2026-07-13-security-535-mcp-select-principal-diff-codex-review.md`.
- [ ] Run `git status -sb`, commit intended files, push `fix/535-mcp-select-principal`, and open the PR with separate `Closes #552` / `Refs #535`. Do not merge before local/GitHub green; never close #535.

## Plan self-review

The design satisfies the requested dedicated principal, env/secret-only credential, fixed identity/effective-grant attestation, filtered DEFINER views for every MCP read, contiguous migration/count tests, operator CREATE USER/REVOKE/GRANT, no raw grants, draft/non-public confidentiality, denied raw/DML operations, and real MCP tools. The schema migration identity acts only as view definer; MCP never receives or uses that credential. Removing the review-induced separate definer eliminates staged-bootstrap and startup-topology hazards without weakening the reader's database boundary.
