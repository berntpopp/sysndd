# #552 MCP SELECT-Only Principal — Codex Plan Review

**Reviewer:** `codex exec` (`gpt-5.6-sol`, read-only, `model_reasoning_effort=xhigh`)

**Command:**

```bash
codex exec -s read-only -c approval_policy=never -c model_reasoning_effort=xhigh --skip-git-repo-check < .planning/reviews/2026-07-13-security-535-mcp-select-principal-plan-codex-prompt.md > /tmp/535-mcp-select-principal-plan-codex.out 2>&1
```

**Verdict (round 1):** `REJECT — unresolved BLOCKER/HIGH findings remain.`

## Findings that define the required safe design

### BLOCKER — normal API credentials remain readable

The MCP Compose service currently mounts `./api/config.yml:/app/config.yml:ro`, and `api/start_sysndd_mcp.R` loads it before replacing the DB user/password. A compromised MCP process can therefore read the normal API database credential and other secrets. The resumed design must remove that mount and construct a minimal DB pool configuration from `MCP_DB_NAME`, `MCP_DB_HOST`, `MCP_DB_PORT`, `MCP_DB_USER`, and `MCP_DB_PASSWORD` only. It must not set or load `API_CONFIG` / `config::get()` for MCP.

### BLOCKER — public projections are mandatory

`044_mcp_public_read_projections.sql` is mandatory, not conditional. Existing `SQL SECURITY INVOKER` views plus raw review, snapshot, and cache-table queries cannot be granted directly without either failing at runtime or making draft/non-public data selectable by the MCP credential.

Migration 044 must create fixed-schema `SQL SECURITY DEFINER` projections and MCP repositories must consume only those projections. The projections must enforce:

- active public entities;
- `is_primary = 1 AND review_approved = 1` for every synopsis, phenotype, variation, and publication row;
- `public_ready = 1 AND status = 'public_ready'` for manifests and every snapshot child row;
- `is_current = TRUE AND validation_status = 'validated'` for LLM cache rows;
- current-only NDDScore and explicit search/lookup projections.

The principal must receive no raw review/status/connect, snapshot, or LLM-cache grant. Manifest changes are therefore required: latest migration `044_mcp_public_read_projections.sql`, count `42L`, and exact manifest tests.

### BLOCKER — identity must be enforced rather than documented

The design cannot accept any nonempty `MCP_DB_USER`. It needs one fixed account identity, used by Compose, startup, and the provisioner; startup must reject the ordinary API account and fail closed unless `CURRENT_USER()`/`SHOW GRANTS` attest the expected identity and exact SELECT-only projection surface.

### HIGH — privileged account reconciliation

The provisioner must use an authorized MySQL administrator and runtime-only secrets. It must: validate the fixed user/host and database identifier; remove roles and existing privileges before setting/rotating the password; quote dynamic identifiers and the password correctly; prevent RMariaDB error text from exposing a password-bearing `ALTER USER`; and verify final `SHOW GRANTS` before success. The MCP service must never receive root credentials.

### HIGH — test and live proof expansion

TDD/integration verification must seed approved, secondary, draft, and in-progress sentinel rows and prove only approved-primary projections are visible. It must prove direct SELECT denial on raw review, snapshot, and LLM-cache objects, and INSERT/UPDATE/DELETE denial on both a granted projection and an ungranted raw table. It must also verify `SECURITY_TYPE = 'DEFINER'`, a valid non-MCP definer, exact view predicates/columns, read-only source/cache/data/script/resource/startup mounts, internal-only network, absence of external/LLM credentials, and real normal/snapshot/NDDScore MCP tool calls in addition to `tools/list`.

## Initial live authority blocker (resolved 2026-07-12)

Observed 2026-07-12 against the running persistent local stack:

```text
$ docker exec sysndd_mysql sh -ceu 'mysql -N -uroot -p"$MYSQL_ROOT_PASSWORD" ...'
mysql: [Warning] Using a password on the command line interface can be insecure.
ERROR 1045 (28000): Access denied for user 'root'@'localhost' (using password: YES)
```

The API account can connect, but reports only:

```text
GRANT RELOAD, PROCESS, REPLICATION CLIENT ON *.* TO `bernt`@`%`
GRANT ALL PRIVILEGES ON `sysndd_db`.* TO `bernt`@`%`
```

It has no `WITH GRANT OPTION`, so it cannot safely create/reconcile the new account. No valid administrator credential or delegated `CREATE USER`, `GRANT OPTION`, and role-revocation authority is available in this session. The mandatory live SELECT/INSERT/UPDATE/DELETE/MCP proof cannot be performed.

The local persistent MySQL root password was recovered with explicit operator
authorization after a stopped-volume snapshot. Fresh socket and container-network
connections now authenticate as `root@localhost` / `root@%` and show full
administrative privileges with `GRANT OPTION`. The normal stack was restarted
healthy. This blocker no longer prevents implementation or live verification.

## Round 1 disposition

The original plan was rejected without product-code changes. Its findings are
now folded into the revised plan: normal config removal, mandatory projections,
fixed identity/effective-grant attestation, hostile-account reconciliation, and
expanded confidentiality/live proof. Round 2 re-review is required before TDD.

## Round 2

**Verdict:** `REJECT — unresolved BLOCKER/HIGH findings remain.`

The second review found that the revised design still left several privilege and
confidentiality paths underspecified. It required all of the following before
implementation:

- route MCP source-version calculation through its own approved-public
  projection instead of retaining any raw-table path;
- attest role-derived authority using `CURRENT_ROLE()`,
  `INFORMATION_SCHEMA.APPLICABLE_ROLES`, `@@GLOBAL.mandatory_roles`, bare
  `SHOW GRANTS`, and `SHOW GRANTS FOR CURRENT_USER()`, with live dormant,
  default, active, and mandatory-role rejection cases;
- freeze the exact ordered columns for every projection and omit job, warning,
  error, curator, and validation-user fields;
- normalize a potentially hostile pre-existing account by dropping and
  recreating it while MCP is stopped, then attest through a fresh connection;
- require one exact durable non-MCP definer, reject extra `mcp_public_%` views,
  and prepare every projection with `LIMIT 0`;
- filter inactive lookup/connect/entity rows, remove MCP egress from effective
  Compose configuration, split the 600-line snapshot repository, and replace
  permissive smoke checks with committed confidentiality fixtures and strict
  successful real-tool calls.

## Round 2 disposition

All BLOCKER/HIGH findings above are now incorporated into the implementation
plan, including the complete projection/column contract, exact definer and view
inventory, source-version projection, hostile-account reset, role-surface
attestation, internal-only Compose topology, and strict committed-fixture live
verification. Round 3 was required before TDD; its rejecting result and
disposition follow.

## Round 3

**Verdict:** `REJECT — unresolved BLOCKER/HIGH findings remain.`

The third review found one additional process-level confidentiality boundary and
six remaining high-impact gaps:

- **BLOCKER:** read-only access to the shared `api_cache` volume is still a
  confidentiality breach because it contains log and other non-public memoised
  payloads, while the legacy MCP helper enumerates and deserializes arbitrary
  RDS files. MCP must remove the volume, `bootstrap_bind_memoised()`, and the
  legacy disk scanner, and use durable public-ready database snapshots only.
- **HIGH:** review-child views must require child/review `entity_id` equality,
  the same active public entity, and active referenced modifier/VariO rows;
  malformed cross-entity and inactive-vocabulary sentinels are required.
- **HIGH:** current/validated LLM rows must additionally match a cluster in the
  currently public-ready snapshot and the database-visible active prompt
  contract; orphan hashes and obsolete prompt versions must be invisible.
- **HIGH:** the source-version formula must be one approved-public definition
  shared by normal API snapshot building and MCP. The old API formula includes
  non-public influences, while a separately repaired MCP formula would cause a
  permanent mismatch. Both runtimes must query the canonical projection and
  snapshots must be force-refreshed after deployment.
- **HIGH:** hostile account reconciliation must run under an advisory lock,
  account-lock the old identity, enumerate/reject MCP-owned views/routines/
  triggers/events, kill and recheck every old MCP session, drop/create the
  account initially locked, verify before unlock, and fail on warnings.
- **HIGH:** `CREATE USER` must bind the runtime password through a prepared DBI
  statement rather than interpolate it into SQL; forced-error and MySQL-log
  tests must prove a unique secret sentinel never appears.
- **HIGH:** confidentiality proof needs a named executable verifier and Make
  target that applies 044 through the normal runner, uses committed sentinels,
  runs every positive/negative DB check, and requires real entity, snapshot, and
  NDDScore tool success with zero accepted skips or degraded substitutes.

The reviewer also identified two cheap MEDIUM corrections: add `alphafold_id` to
the gene projection, make comparison metadata a one-row latest view and remove
the repository's raw `ORDER BY id`; and split projection contract, config,
grant normalization, and live attestation into focused modules with explicit
line guards for every touched handwritten file.

## Round 3 disposition

All round-3 BLOCKER/HIGH and both cheap MEDIUM findings are incorporated into
the revised plan. The plan now deletes the shared-cache path, freezes the
stronger child/summary/source-version predicates, specifies the complete
advisory-locked and leak-tested account lifecycle, names
`api/scripts/verify-mcp-select-principal-live.R` and
`make verify-mcp-select-principal-live` as mandatory zero-skip gates, corrects
the two query/column mismatches, and decomposes the principal implementation.
Round 4 xhigh plan review is required before TDD or product-code changes.

## Round 4

**Verdict:** `REJECT — unresolved BLOCKER/HIGH findings remain.`

The fourth review found three remaining blockers, five high-impact gaps, and
three cheap medium corrections:

- **BLOCKER:** removing `config.yml` and the cache volume was not a sufficient
  filesystem boundary. The shared API image and `/app/config` mount still expose
  OpenAPI samples containing draft/secondary reviews, curator identity,
  comments, status/re-review state, administrator details, and LLM logs. MCP
  requires a dedicated minimal image that copies only its dependency-closed
  runtime and exact MCP resources, with live absence checks for config,
  endpoints, samples, tests, admin scripts, and other sensitive paths.
- **BLOCKER:** hostile-account handling inspected definers before it reliably
  neutralized incoming/outgoing PROXY, roles, grants, direct sessions, and proxy
  sessions. Account locking alone does not disable existing connections, proxy
  use, or definer programs. Every abort must leave the identity locked,
  privilege/role/proxy-free, and session-free, and the probe must use a temporary
  unlock/relock fence before the final unlock.
- **BLOCKER:** MCP startup cannot verify definer existence through `mysql.user`
  without receiving a prohibited system-table grant. The administrator must own
  that check; MCP may verify exact `INFORMATION_SCHEMA.VIEWS.DEFINER`, execute
  every view with `LIMIT 0`, and inspect only its own account with
  `SHOW CREATE USER CURRENT_USER()`.
- **HIGH:** count/maximum-timestamp source versioning misses real in-place public
  content changes. The source identity must be a typed canonical ordered hash
  over every field/artifact actually consumed by all five builders, with
  mutations that preserve counts and maximum timestamps.
- **HIGH:** snapshot construction itself must share one approved-public input
  gate that filters inactive disease, inheritance, category, modifier, and
  VariO state and enforces review/child entity equality. Because this can change
  membership, `CLUSTER_LOGIC_VERSION` must be bumped and summaries regenerated
  for changed cluster hashes.
- **HIGH:** the transition covered only two of five presets. It must force and
  wait for functional and phenotype clusters first, then correlations,
  cross-axis correlations, and gene-network edges, and require all five current
  manifests at the exact canonical version before MCP can unlock.
- **HIGH:** deleting the cache repository would break four service-facing
  availability adapters while the full loader would still expose the generic
  network-layout `readRDS()` path. A minimal MCP module loader must replace all
  four adapters with database availability checks, build the registry, and
  invoke every registered tool without loading the layout reader or broader API
  runtime.
- **HIGH:** credential separation did not reject root-password reuse or prove
  that the candidate MCP password cannot authenticate as the configured
  definer from the MCP network location.
- **MEDIUM:** current NDDScore requires both `is_active = 1` and
  `import_status = 'active'`, and every child must join that release projection.
- **MEDIUM:** provisioning must reject `log_raw=ON` and inspect `SHOW WARNINGS`
  immediately after every statement rather than once per phase.
- **MEDIUM:** live negatives must be generated from the projections' complete
  transitive raw/invoker object inventory, and cleanup must preserve and restore
  pre-existing public-ready manifests, summaries, releases, account state, and
  server variables.

## Round 4 disposition

All round-4 BLOCKER/HIGH and MEDIUM findings are now incorporated into the
revised plan. The runtime boundary is a dedicated minimal MCP image plus a
minimal dependency-closed loader and all-tool registry test. The database
boundary now has administrator-only definer/account inspection, statement-level
warning/log checks, complete grant/role/PROXY/session neutralization with
fail-safe abort state, candidate-password separation checks, and a fenced probe
before final unlock. The analysis transition now uses one approved-public input
object and canonical ordered content hash across all five builders, bumps the
cluster logic version, force/waits every preset in dependency order, and
regenerates summaries when membership hashes change. The live verifier now
checks the built filesystem, the complete transitive denial set, and exact
state restoration. Round 5 xhigh plan review is required before TDD or any
product-code change.

## Round 5

**Verdict:** `REJECT — unresolved BLOCKER/HIGH findings remain.`

**Evidence:** `/tmp/535-mcp-select-principal-plan-codex-round5.out`

The fifth review found one startup blocker, five high-impact design gaps, four
medium corrections, and one cheap defense-in-depth improvement:

- **BLOCKER:** `SELECT` on a view is insufficient for the proposed real
  `INFORMATION_SCHEMA.VIEWS` attestation. MySQL requires `SHOW VIEW`. Grant and
  attest `SHOW VIEW` at each individual projection beside `SELECT`; continue to
  reject schema/global `SHOW VIEW`, and exercise metadata through the actual MCP
  connection rather than an administrator stub.
- **HIGH:** the canonical hash omitted live STRING enrichment, cached fCoSE
  coordinates, combined-score sensitivity inputs, validation environment
  parameters, layout parameters, and relevant helper/package versions. Prefetch
  each exact typed input once, hash it, seal it, and force builders, validators,
  sensitivity computation, enrichment shaping, and layout application to
  consume the same object. Mutation tests must cover every one of these inputs.
- **HIGH:** membership-only `cluster_hash` does not bind an LLM summary to the
  enrichment or phenotype descriptors it summarized. Add canonical
  `summary_input_hash` over the exact generator `cluster_data`, persist it in
  both snapshot clusters and LLM cache rows, require equality in the public
  projection/cache lookup, and regenerate whenever it changes.
- **HIGH:** five old manifests agreeing with one another are not evidence that
  they match current inputs. Maintain an independent trusted source-state row
  with content hash plus dirty/valid state. Invalidate it on approved-input
  mutation and runtime-artifact deployment, recompute it in a trusted worker,
  and expose a source version only when clean state and all five manifests
  agree.
- **HIGH:** the proposed image reused the broad API library bootstrap/base and
  could not start from its stated manifest because `init_globals.R` reads the
  omitted `version_spec.json`. Create `init_mcp_libraries.R`, restore only its
  transitive package closure into a fresh runtime-only OS stage, remove
  `init_globals` when unnecessary, use a distinct `SYSNDD_MCP_IMAGE` tag, and
  test real `Rscript start_sysndd_mcp.R` image startup.
- **HIGH:** destructive refresh/prune/regeneration verification could not
  faithfully restore the persistent database. Run the gate in a unique Compose
  project against a disposable MySQL volume restored from a read-only snapshot,
  and destroy that project/volume after proof.
- **MEDIUM:** omit constant review/connect lifecycle/status columns and remove
  redundant MCP-side filters.
- **MEDIUM:** MCP metadata visibility can prove only its exact granted
  projection inventory. The administrator must separately compare the complete
  database-wide inventory, including unexpected ungranted projections.
- **MEDIUM:** union generated transitive raw dependencies with a frozen
  sensitive denylist covering users, logs, jobs, generation logs, status, and
  re-review tables.
- **MEDIUM:** extract payload construction before adding plumbing to the
  existing 595-line `analysis-snapshot-builder.R`.
- **LOW:** configure and attest bounded per-account connection/query resources,
  and prove direct connections cannot exceed the cap.

## Round 5 disposition

All findings are folded into the plan. Every projection now receives only
object-level `SELECT, SHOW VIEW`; startup verifies the granted inventory while
the administrator verifies complete inventory. The analysis design now seals a
canonical approved-public bundle containing deterministic intermediates,
enrichment, layouts, sensitivity inputs, validation/environment parameters,
and implementation versions. A trigger/refresh/deployment-invalidated trusted
source-state row gates five-manifest consensus, and activation rechecks the same
bundle generation. Snapshot and LLM rows carry equal `summary_input_hash`, with
regeneration on descriptor changes. The MCP image is a distinctly tagged fresh
runtime stage with its own minimal library bootstrap/lock and an actual startup
test. Live destructive proof runs only in an isolated Compose project and
disposable restored MySQL volume. Constant gate columns are omitted, the
sensitive denylist is frozen, payload builders are extracted before plumbing,
and account resource limits are enforced. Round 6 xhigh plan review is required
before TDD or product-code changes.

## Round 6

**Verdict:** `REJECT — unresolved BLOCKER/HIGH findings remain.`

**Evidence:** `/tmp/535-mcp-select-principal-plan-codex-round6.out`

The sixth review found two remaining blockers, four high-impact operational or
correctness gaps, and two medium hardening corrections:

- **BLOCKER:** migration 044 and snapshot rebuilding preceded hostile-account
  neutralization. A compromised credential could connect outside the named MCP
  container and replace objects or derived state. Reconciliation must therefore
  be phase A lock/strip/kill plus a persisted generation before 044, phase B
  trusted DDL/rebuild while locked, and phase C exact generation/state match
  before grant, probe, and unlock, all under one advisory lock.
- **BLOCKER:** name/column/definer checks could not detect a same-name,
  same-column exfiltrating DEFINER view or altered invalidation trigger. Every
  projection and trigger must be recreated after neutralization and compared by
  normalized `SHOW CREATE VIEW`/`SHOW CREATE TRIGGER` digest, exact recursive
  dependencies, and normalized predicates. Unexpected protected stored objects
  must be rejected regardless of definer.
- **HIGH:** five per-preset jobs were actually default-lane work and had no safe
  serialization/recovery; single-preset force could strand four stale manifests.
  One single-flight cohort job now runs on the existing single maintenance
  worker, seals one unique bundle/generation, builds all five presets in order,
  makes single-preset force a whole cohort, and resumes/supersedes durably. It
  adds no cross-type mutex and blocks maintenance scaling on #556.
- **HIGH:** sealed inputs omitted `ANALYSIS_SILHOUETTE_NULL_N`,
  `ANALYSIS_PHENOTYPE_KNN_K`, hard coherence,
  `ANALYSIS_SNAPSHOT_STALE_AFTER_DAYS`, `db_version`, and reproducibility. The
  manifest is now machine-readable/exhaustive, `db_version` is trigger-covered,
  coherence cannot be disabled, reproducibility is injected, and post-seal
  accessors become fail-on-call doubles in tests.
- **HIGH:** migration 044 was not restart-safe across implicit DDL commits. It
  now requires guarded columns/indexes, idempotent tables/control rows,
  drop/recreate triggers, replaceable views, and interruption/rerun tests after
  every DDL class.
- **HIGH:** revocation did not fence event-scheduler execution or other users
  already invoking hostile DEFINER programs. Phase A now stops every writer,
  cron, and worker; preserves then disables `event_scheduler`; kills every
  non-system/non-provisioner session; neutralizes suspect programs; and tests a
  running event plus a routine invoked through another account. Failure remains
  fenced until exact finalization.
- **MEDIUM:** the denylist omitted `llm_prompt_templates`, sealed bundle/control
  tables, and other LLM/user/session/job/event/log/status/re-review families.
  The expanded frozen inventory and schema guard prevent silent omission.
- **MEDIUM:** the 578-line layout file needed extraction before plumbing.
  Artifact filesystem/cache/generation operations are now extracted first and
  both files must remain below 600 lines.

## Round 6 disposition

All round-6 findings are incorporated. Deployment is phase A fence/neutralize,
phase B trusted 044/object rebuild/whole-cohort recovery, then phase C exact
generation/object/grant/probe attestation and final unlock/fence restoration.
Trusted DDL digests and recursive contracts close same-shape exfiltration. The
snapshot transition uses one unique-bundle cohort on the current single
maintenance worker with restart/resume and the explicit #556 scale prerequisite,
not speculative locking. Input provenance, migration restart safety, running
stored-program tests, the denylist, and layout extraction are explicit TDD
contracts. Round 7 xhigh plan review is required before product-code changes.

## Round 7

**Verdict:** `REJECT — unresolved BLOCKER/HIGH findings remain.`

**Evidence:** `/tmp/535-mcp-select-principal-plan-codex-round7.out`

The seventh review found seven blockers, eight high-impact gaps, and four
medium corrections:

- **BLOCKER:** snapshot manifests had no relational bundle/generation binding.
  Migration 044 must add nullable legacy `input_bundle_id` and
  `invalidation_generation`, exact indexes/FKs, mandatory non-NULL new-write
  validation, and a manifest projection that joins bundle, generation, and
  content hash together.
- **BLOCKER:** creating an absent MCP account before removing orphan objects
  with that definer can fail. Orphan definers are enumerated and removed first;
  an existing account is locked/revoked and its sessions killed first.
- **BLOCKER:** a hostile client can pre-hold both named MySQL advisory locks.
  Reconciliation now begins with an operator-level lock outside MySQL, then
  emergency-neutralizes hostile accounts/sessions and kills hostile lock owners
  before acquiring the retained database locks.
- **BLOCKER:** indiscriminate protected-dependency deletion would remove
  legitimate core API views. The plan now partitions committed trusted core
  objects from hostile/unexpected objects by schema-aware digest/dependency
  closure and deterministically restores every missing/altered trusted object.
- **BLOCKER:** queued LLM children would deadlock behind the sole maintenance
  cohort. Summary generation is synchronous and resumable from sealed
  `cluster_data`, with validated success required before clean activation.
- **BLOCKER:** hostile control tables or a forged filename-only migration ledger
  could bypass 044. Exact table schema/digest/row invariants and a migration
  checksum are attested; hostile controls are rebuilt and trusted 044 is
  explicitly re-executed under the fence.
- **BLOCKER:** the live gate depended on gitignored artifacts and live STRING /
  Gemini. A small committed checksummed pack now supplies exp+db/combined edges,
  SFARI, layouts, STRING enrichment, Gemini generation, and judge responses
  through production paths with external networking disabled.
- **HIGH:** normal API snapshot reads could fail open while source state was
  dirty. Both API and MCP now use the cohort-gated availability decision and
  treat missing/unreadable/dirty/mismatched state as unavailable.
- **HIGH:** DDL normalization erased schema identity. It now canonicalizes
  unqualified names to `sysndd_db`, preserves schema identity, and rejects every
  cross-schema reference.
- **HIGH:** JSON blobs remained future-field exfiltration channels. Exact nested
  per-analysis key/type schemas and explicit serialization allowlists are
  frozen and tested.
- **HIGH:** stopping known containers did not prevent reconnecting writers. The
  fence now combines account locks, offline/network isolation, exact saved
  state, continuous allowed-session checks, and exact restoration.
- **HIGH:** the warning policy conflicted with idempotent DDL. Migration 044 gets
  strict per-statement diagnostics, metadata guards instead of note-producing
  clauses, and guarded temporary-helper cleanup.
- **HIGH:** mergeable views plus unbounded statements/transactions allowed
  locking abuse. Projections prefer `TEMPTABLE`; server-side limits and live
  `FOR SHARE`, `SLEEP`, and abandoned-transaction tests are mandatory.
- **HIGH:** the dedicated definer lacked a clean-install lifecycle. Root creates
  and attests the exact minimally privileged, maintenance-network-restricted
  definer; it is locked/restricted after DDL and tested on a pristine volume.
- **HIGH:** more-specific `sysndd_mcp@host` accounts could survive. Administrator
  reconciliation neutralizes every host variant and final inventory permits
  only `sysndd_mcp@%`.
- **MEDIUM:** nullable modifier links must remain visible; only referenced
  inactive modifiers are rejected.
- **MEDIUM:** remove the dynamic INFORMATION_SCHEMA column probe and use the
  frozen projection contract.
- **MEDIUM:** MCP needs a dedicated internal network shared only with MySQL, not
  the API/backend or proxy networks, including explicit override resets.
- **MEDIUM:** split the already-large LLM cache and MCP repository modules before
  adding plumbing, alongside the existing builder/layout splits.

## Round 7 disposition

All round-7 findings are explicit implementation/test contracts in the plan.
The plan now binds each new manifest to the unique bundle and cohort generation;
orders absent/existing-account neutralization safely; uses external exclusivity
before advisory-lock recovery; preserves or deterministically rebuilds trusted
core objects; performs synchronous sealed-input summary checkpoints; distrusts
and reconstructs control/ledger state; and makes the live proof deterministic
and offline. API fail-closed gating, schema-preserving digest normalization,
frozen nested JSON, reconnect-proof fencing, strict diagnostics, query/locking
limits, exact definer/host-account lifecycles, nullable modifiers, fixed query
shape, network isolation through a pinned non-bypassable SQL guard (separate
MCP-front and MySQL-back networks), and four pre-plumbing splits are included.
The guard preserves the MCP MySQL identity while enforcing statement and
transaction bounds the compromised client cannot relax. Round 8
xhigh plan review is required before TDD or product-code changes.

The SQL-guard contract was checked against current official ProxySQL
documentation before round 8: per-user/schema firewall rules support
`PROTECTING` allowlist mode; `mysql_query_rules.timeout` kills overlong backend
queries; `mysql-default_query_timeout`, `mysql-wait_timeout`,
`mysql-max_transaction_idle_time`, and `mysql-enforce_autocommit_on_reads` are
runtime controls; user configuration exposes `schema_locked`, `fast_forward`,
and connection limits; and query/event logging is explicitly configurable and
can expose SQL if enabled. Sources: [Firewall Whitelist](https://proxysql.com/documentation/firewall-whitelist/),
[MySQL tables/query rules](https://proxysql.com/documentation/main-runtime/mysql-tables/),
[MySQL variables](https://proxysql.com/documentation/global-variables/mysql-variables/),
and [MySQL users](https://proxysql.com/documentation/users-management/mysql-users-management/).

## Round 8 findings

**Verdict:** `REJECT — unresolved BLOCKER/HIGH findings remain.`

- **BLOCKER:** phase A performed hostile-account/advisory-lock inspection before
  the reconnect-proof fence, while ordinary API startup could apply 044 using
  the API identity. Phase A0 now immediately stops and network-disconnects every
  API/MCP/worker/cron/writer, locks writer identities, kills sessions, disables
  events, and isolates root before any MySQL inspection. Ordinary API startup
  refuses 044; a one-shot dedicated-definer migrator owns it, and normal startup
  requires finalized reconciliation plus the exact checksum.
- **BLOCKER:** the claimed checksum ledger and strict diagnostics omitted
  `migration-runner.R` and `migration-state-repository.R`; rebuilding a hostile
  ledger could replay unsafe 000-043. Both files and a committed all-migration
  checksum/postcondition manifest are now explicit. Existing-database recovery
  reconstructs history from deterministic schema/data postconditions without
  executing historical bodies, with migration 018 specifically guarded.
- **BLOCKER:** continuously forced `offline_mode` could not admit the definer or
  cohort worker without forbidden `CONNECTION_ADMIN`. The plan now defines an
  executable state machine: account/network fencing never drops; forced offline
  is disabled only for root plus one explicit isolated identity under continuous
  session allowlisting, then that identity is relocked/disconnected and forced
  offline resumes. Original offline state is restored only after finalization.
- **HIGH:** process-local MCP result caches could serve withdrawn data for 30
  minutes. They are removed, and warm-every-tool/immediate-withdrawal tests are
  mandatory.
- **HIGH:** normal API reads had a manifest-to-raw-child TOCTOU. Public API and
  MCP now both read the cohort-gated projections for manifest and children; a
  concurrent invalidation test must discard the response.
- **HIGH:** the dedicated definer had no steady-state grant contract. Temporary
  exact DDL grants and steady exact raw SELECT/TRIGGER/control-state UPDATE
  grants are separate manifests; all DDL is revoked before the account is
  locked and both transitions are attested.
- **HIGH:** unconditional triggers would invalidate on no-op `db_version` and
  irrelevant drafts. Generated triggers compare consumed fields null-safely,
  apply approved-public eligibility, and invalidate eligibility transitions.
- **HIGH:** MCP could not reach the administrator-only guard socket it was told
  to attest. Only the finalizer performs full guard attestation; MCP consumes a
  non-secret policy digest bound to the finalized generation.
- **HIGH:** dynamic repository SQL could evade an exact firewall manifest. The
  implementation must use a finite prepared-shape contract and execute every
  allowed argument shape through the live guard.
- **HIGH:** NDDScore JSON remained an arbitrary nested serialization channel.
  Every projected JSON column now has a frozen key/type/shape contract,
  activation validation, explicit allowlisted reconstruction, and forbidden
  nested sentinels.
- **MEDIUM:** PID-only verifier project cleanup could collide. It now uses a
  cryptographic run UUID plus PID, labels every resource, refuses collision,
  and removes only resources bearing that UUID.

## Round 8 disposition

All round-8 findings are explicit file, ordering, state-machine, privilege, and
RED/GREEN contracts in the plan. Phase A0 precedes account, advisory-lock,
object, ledger, and migration inspection. The migration runner has a complete
checksum ledger and safe historical reconstruction path; 044 has one dedicated
migrator and cannot run during normal API startup. Offline transitions admit
only one explicitly isolated identity without granting `CONNECTION_ADMIN`.
Warm-cache withdrawal, API invalidation races, selective triggers, exact
temporary/steady definer grants, generation-bound guard proof, fixed SQL shape
coverage, NDDScore JSON sentinels, and UUID-scoped cleanup are mandatory.
Round 9 xhigh plan review is required before TDD or product-code changes.

## Round 9 findings

**Verdict:** `REJECT — unresolved BLOCKER/HIGH findings remain.`

**Evidence:** `/tmp/535-mcp-select-principal-plan-codex-round9.out`

- **BLOCKER:** the real MCP probe could not see the guard-policy projection
  until after the probe finalized reconciliation. The state machine now has a
  persisted `security_attested` phase visible only to a generation-bound,
  one-use probe descriptor; normal startup requires `released`, and every probe
  failure invalidates policy state and re-neutralizes before returning control.
- **BLOCKER:** a pristine volume had no route through migrations 000-043 and no
  pre-044 table in which to persist reconciliation. The host-owned fence now
  keeps an fsynced mode-0600 generation journal bound to its live lock and
  volume; a pinned admin image checksum-runs 000-043 with a temporary trusted
  bootstrap identity, then 044 imports that journal into the final controls.
- **HIGH:** inactive variation-connect rows were not filtered or invalidated.
  The exact projection predicate, source hash, null-safe trigger contract, and
  dedicated confidentiality sentinel now include `connect.is_active = 1`.
- **HIGH:** reproducibility remained a manifest-gate/raw-child race. An exact
  cohort-gated projection is now mandatory, both public routes use it and
  recheck generation before serialization, and missing/invalid bundles prevent
  clustering cohort activation.
- **HIGH:** credentials were still passed as environment values. MCP, root,
  definer, candidate, and ProxySQL administrator paths now accept only strict
  `*_PASSWORD_FILE` descriptors, read once with owner/mode/inode checks; live
  checks inspect environments, argv, image metadata, and logs.
- **HIGH:** restart-safe migration branching depended on a stored procedure
  without matching routine grants. Metadata guards now live entirely in the R
  runner; migration 044 creates no routine and both grant manifests explicitly
  exclude routine authority.
- **HIGH:** JSON validation alone allowed future fields to escape. Every
  projected analysis, LLM, tag, and NDDScore JSON value is reconstructed in SQL
  from an exact path/type/bound contract, including a bounded inheritance-mode
  enum array.
- **HIGH:** A0 inspected account state while claiming inspection had not begun.
  The executable order is now host stop/network isolation, global offline/event
  fence, kill/prove root-only, then account inspection/record/lock.
- **HIGH:** hostile base tables could occupy reserved projection names. The
  administrator reserves/attests every expected name across all table object
  types and tests hostile base-table fixtures.
- **HIGH:** no executable artifact owned host `flock`/A0 and handed completion
  to Compose. The file plan now names a thin host command, pinned admin-only
  image and exact entrypoints, fsynced journal, and checksummed generation-bound
  completion marker verified by every service pre-start.
- **MEDIUM:** all three omitted contract tests are now in RED, GREEN, and live
  commands; the approved-input manifest freezes exact R/BLAS/LAPACK/R-package/
  Node/Cytoscape/fCoSE/artifact dependency keys and fails undeclared runtime
  dependencies; the MySQL healthcheck is credential-free and live inspection
  covers healthcheck/process arguments and container environments.

## Round 9 disposition

All round-9 findings are normative contracts in Tasks 2-5. The probe has no
finalization circularity, pristine and existing database paths are distinct and
fenced, all credentials introduced or consumed by the reconciliation/MCP guard
path are secret-file-only, migration 044 is routine-free, projection-side JSON
and reproducibility gates are explicit, reserved names cover wrong object types,
and host orchestration has an executable checksummed handoff. Round 10 xhigh
plan review is required before TDD or product-code changes.

## Round 10 findings

**Verdict:** `REJECT — unresolved BLOCKER/HIGH findings remain.`

**Evidence:** `/tmp/535-mcp-select-principal-plan-codex-round10.out`

- **BLOCKER:** the dedicated migration identity had DDL but no authority to
  update the checksum ledger or exact 044 control rows. The plan now freezes a
  temporary object/operation/ordered-column DML submanifest, forbids wildcard
  application DML, and revokes/attests it before steady state. Root-owned
  bookkeeping is permitted only as an explicit alternative paired with
  committed `DEFINER=` clauses; implicit mixed ownership is forbidden.
- **BLOCKER:** the pristine bootstrap identity could not connect while A0
  forced `offline_mode`. The pristine path now has a third explicit
  root-plus-bootstrap window with writer/network/event fencing retained,
  continuous two-session allowlisting, then kill/revoke/drop/root-only proof
  and forced-offline restoration before the 044 window.
- **BLOCKER:** ordinary worker startup was release-marker-gated, leaving no
  executable pre-release cohort path. A distinct generation/job-bound one-shot
  runner now uses the pinned worker image, one-use descriptor, exact conditional
  claim/refusal, isolated DB/provider network and separate DB/Gemini/judge
  secret files; it exits at a durable checkpoint and cannot satisfy ordinary
  worker startup.
- **HIGH:** raw gzip reproducibility was a nested-data escape hatch. Migration
  044 now creates a separate generation-bound normalized public
  reproducibility representation populated only after exact validation; its
  projection reconstructs allowlisted JSON and never depends on or grants the
  raw gzip table.
- **HIGH:** elapsed time did not empty public snapshots. The manifest now
  requires `stale_after > UTC_TIMESTAMP(6)`, every child/source projection
  derives from it, and direct plus post-start expiry tests are mandatory.
- **HIGH:** ProxySQL digest normalization could erase comments/annotations.
  The contract now has earlier terminal raw-text deny rules for ordinary,
  optimizer, versioned, encoded and obfuscated comments, pins/attests comment
  and first-comment variables, disables annotation processing, and tests rule
  order.
- **HIGH:** the cap test expected five direct connections despite two retained
  guard backends. It now proves two guard plus two direct succeed and the next
  direct connection fails.
- **HIGH:** the completion marker was portable across volumes/locks. The
  released row and marker now bind volume identity, host-lock device/inode,
  journal/run nonce, generation-unique marker nonce and all policy digests;
  every verifier compares them and replay cases fail.
- **HIGH:** bind-mounted artifacts could change after startup without dirtying
  source state. Runtime artifacts are now immutable content-addressed read-only
  paths, switched only by a fenced checksum-verified deployment that dirties
  state before the descriptor changes.
- **MEDIUM/LOW:** MCP and API readers are physically split, so the MCP image has
  no raw resolver or mutable runtime switch; the bundle freezes/attests locale,
  RNG, timezone, MySQL/sql-mode/charset/collation/isolation execution state;
  MCP schema/capability resources now state database snapshots and zero
  process-local caching.

## Round 10 disposition

All round-10 findings are normative file, privilege, offline-state,
entrypoint, projection, guard, artifact, marker, and RED/GREEN contracts in
Tasks 2-5. Round 11 xhigh review must find no unresolved BLOCKER/HIGH before
TDD or product-code changes.

## Round 11 findings

**Verdict:** `REJECT — unresolved BLOCKER/HIGH findings remain.`

**Evidence:** `/tmp/535-mcp-select-principal-plan-codex-round11.out`

- **BLOCKER:** the new normalized reproducibility table declared an unsigned
  `snapshot_id` FK against the existing signed `analysis_snapshot_manifest`
  parent. The plan now fixes and tests `BIGINT NOT NULL` signedness exactly.
- **BLOCKER:** the MCP pre-start verifier could read only an abbreviated guard
  digest and had no independent host/volume observation. The exact projection
  inventory now includes a filtered non-secret release-binding projection with
  every marker/database comparison field, while every verifier separately
  mounts and live-stats a host-owned volume/lock identity record. Cross-paired,
  copied, omitted, and hot-replaced three-source bindings must fail.
- **BLOCKER:** child definer views depended on parent definer views without
  dependency SELECT grants. The plan chooses the smaller authority model:
  every projection is flattened directly onto raw/control objects, the
  dependency graph must contain zero `mcp_public_*` edges, and creation plus
  execution is tested after temporary grants are revoked.
- **BLOCKER:** temporary bookkeeping authority was categorical rather than an
  exhaustive executable contract, and ordinary DML cannot use `DEFINER=`. The
  plan chooses one coherent migration/reconciliation model: the continuously
  retained root connection alone executes 044/final-release bookkeeping, while
  a disjoint one-connection cohort contract owns runtime generation writes. A
  machine-readable manifest freezes every
  prepared statement's connection identity, table, verb, ordered read/write
  columns, placeholders, key predicate, affected-row cardinality, and allowed
  transition; the migration/definer identity has zero bookkeeping DML.
- **HIGH:** the named cohort code still read Gemini credentials from process
  environment. `llm-client.R` and `llm-judge.R` are now explicit modifications;
  they accept separate credential closures backed by already-opened secret
  descriptors and explicit `api_key` injection, never `Sys.setenv()`, with
  live `/proc/*/environ` sentinel proof.
- **HIGH:** the cohort image/network/provider route was not enforceable. A
  dedicated digest-pinned one-shot image, internal cohort DB/front networks,
  and digest-pinned deny-by-default HTTPS authority proxy are now named files
  and effective-Compose/live contracts. DNS/IP/plain-HTTP/other-destination
  bypass attempts must fail.
- **HIGH:** claim/progress/heartbeat/snapshot/LLM paths could open multiple DB
  sessions despite the root-plus-one window. The one-shot path now threads one
  explicit connection and exact `CONNECTION_ID()` through every operation,
  bans new pool/connect/global fallbacks, and continuously attests that ID.
- **HIGH:** the physical reader split omitted `mcp-search-repository.R`, which
  contains the metadata resolver. That file is now explicitly modified; the
  resolver and `INFORMATION_SCHEMA.COLUMNS` branch are deleted, and a positive
  source-token guard freezes the absence of metadata/raw/dynamic identifiers.
- **HIGH:** ProxySQL first-comment configuration did not neutralize min-GTID
  annotations, PROXY input, cache, or mirroring. The exact runtime contract now
  pins first-comment parsing to integer zero, ignores min-GTID annotations,
  disables PROXY listeners/cache/mirroring globally, freezes rule actions, and
  compares internal-session/query-processor state before/after hostile input.
- **MEDIUM:** the plan incorrectly applied the strict 600-line source threshold
  to an already-large Makefile/docs file. The target moves to an included make
  fragment, the full operator procedure moves to a focused document with only
  a short deployment-doc link, and the strict threshold is scoped to touched
  handwritten source/tests/scripts/fixtures per `AGENTS.md`.

## Round 11 disposition

All round-11 findings are now explicit schema, privilege, statement, source
closure, single-connection, secret-descriptor, immutable-image, network-route,
ProxySQL runtime-state, release-binding, documentation, and RED/GREEN
contracts. Round 12 must re-audit all earlier invariants and find no unresolved
BLOCKER/HIGH before TDD or product-code changes.

## Round 12 findings

**Verdict:** `REJECT — unresolved BLOCKER/HIGH findings remain.`

**Evidence:** `/tmp/535-mcp-select-principal-plan-codex-round12.out`

Round 12 showed that repeated reviews had expanded the plan far beyond #552's
accepted boundary. The plan is therefore rewritten, not incrementally enlarged.
The normative plan is now the bounded MySQL least-privilege change requested by
the issue: dedicated fail-closed MCP configuration, filtered definer views,
projection-only repositories, exact reader grants, an operator provisioner,
confidentiality tests, and real live MCP proof.

- **BLOCKER — source-generation release deadlock:** resolved by deleting the
  source/cohort/reconciliation release model. Existing `public_ready` source
  rows remain authoritative; #552 adds filtered projections over them and no
  new release finalizer or generation exists to deadlock.
- **BLOCKER — sealed cohort cannot fetch STRING enrichment:** resolved by
  deleting the sealed cohort and offline-provider design. Snapshot production
  is unchanged and outside #552; MCP only reads existing eligible public rows.
- **BLOCKER — circular ProxySQL administrator bootstrap:** resolved by deleting
  ProxySQL entirely. The fixed least-privilege MySQL principal connects directly
  and its database grants are the security boundary.
- **HIGH — shared raw/config-capable database primitives:** retained only where
  necessary and closed at the actual boundary. The plan adds a dedicated
  `MCP_DB_*` parser/pool, sets MCP runtime before setup, and makes
  `get_db_connection()` fail if the MCP pool is absent; it may not fall back to
  `MYSQL_*`, `config.yml`, or a daemon connection. MCP-owned NDDScore/snapshot
  repositories become projection-only. A dedicated image/minimal loader is not
  required to enforce the database principal's authority.
- **HIGH — missed query-service caches:** accepted. The rewrite explicitly
  removes every `mcp_cached()` call from `mcp-service.R`,
  `mcp-record-service.R`, and `mcp-query-service.R`, and warms/repeats search,
  gene, entity, publication, and stats withdrawal tests.
- **HIGH — strict pristine diagnostics conflict with historical migrations:**
  resolved by deleting checksum-ledger/strict-runner redesign. Migration 044 is
  ordinary declarative SQL through the existing runner; historical migrations
  and diagnostic behavior are untouched.
- **HIGH — post-seal mutation can be lost:** resolved with the deleted seal/
  generation model. The retained relevant risk is stale process caching, which
  is addressed by complete cache-call removal.
- **HIGH — worker-only runtime preflight absent:** resolved by deleting all
  source-state/runtime-manifest preflights. #552 changes no worker behavior or
  snapshot-production algorithm.
- **MEDIUM — HGNC lifecycle:** accepted. `mcp_public_gene` and alias resolution
  now freeze `non_alt_loci_set.status = 'Approved'`, with approved/withdrawn
  sentinel tests.
- **MEDIUM — ambiguous reproducibility representation:** resolved by deleting
  the new normalization schema and the proposed projection. MCP has no current
  reproducibility read or tool, so adding a new exposure would expand rather
  than restrict #552. The exact inventory instead includes the source-version
  projection needed by the current analysis-freshness path.
- **MEDIUM — undeclared isolated services:** resolved by deleting ProxySQL,
  provider proxy, and cohort services. The verifier needs only disposable
  MySQL, existing migration/API support, provisioner, and MCP resources.

## Round 12 disposition

The rewritten plan removes ProxySQL; provider routing and offline STRING packs;
sealed bundles/cohort generations; source state and release markers; host flock,
`offline_mode`, and event-scheduler fencing; DB-wide hostile-object
reconciliation; a dedicated MCP image; API/worker preflights; and speculative
JSON normalization. These mechanisms were not required by #552 and created the
round-12 deadlocks. The plan retains every same-class confidentiality control:
exact filtered projections, a locked narrow definer, exact projection-only
reader grants (without `SHOW VIEW`), fixed identity/effective-grant checks,
fail-closed MCP-only credentials, hostile reader-account reconciliation,
projection-only repository routing, complete cache withdrawal, and zero-skip
live negative/real-tool proof. A fresh xhigh review must use the revised bounded
prompt and must find no unresolved BLOCKER/HIGH before product-code changes.

## Round 13 findings and disposition

**Verdict:** `REJECT — unresolved BLOCKER/HIGH findings remain.`

**Evidence:** `/tmp/535-mcp-select-principal-plan-codex-round13.out`

- **BLOCKER — pristine migration path and upgrade race:** accepted. API and MCP
  are stopped. The locked definer is created at `USAGE`, then the administrator
  wrapper uses the existing runner/ledger in exact 000--043 and 044 stages.
  MySQL 8.4 was probed in a disposable schema and permits administrator-created
  explicit-definer view DDL before granting the locked definer its dependency;
  exact dependency grants/attestation therefore follow object creation. API
  starts only after 044 and both account attestations complete.
- **HIGH — hard-coded Compose resources defeated project isolation:** accepted.
  The verifier is now a standalone Compose file with no inherited explicit
  container/network/volume names or external resources, plus UUID labels and
  inspected resource-ID ownership before mutation and cleanup.
- **MEDIUM — file-backed Compose secret modes were incompatible:** accepted.
  MCP uses a direct read-only bind of an operator-created, gitignored UID-1000,
  mode-0600 file matching `apiuser`, with startup type/owner/mode/content checks;
  no ineffective Compose file-secret mode is assumed.

Round 14 must find no unresolved BLOCKER/HIGH before TDD or product changes.

## Round 14 findings and disposition

**Verdict:** `REJECT — unresolved BLOCKER/HIGH findings remain.`

**Evidence:** `/tmp/535-mcp-select-principal-plan-codex-round14.out`

- **HIGH — upgrade could replay a missing historical ledger row:** accepted.
  Before any runner call, the wrapper now distinguishes a truly object-free,
  ledger-free pristine database from an upgrade. Upgrade requires the exact
  000--043 (or idempotent 000--044) ledger; any existing schema plus missing,
  extra, or out-of-order historical row aborts with zero mutation. Tests cover
  pristine, exact upgrade, idempotence, and the missing-row negative.
- **HIGH — snapshot children stayed readable after source withdrawal:**
  accepted. Manifest, every child, and LLM projections now require equality to
  the same current approved-public source hash exposed by the source-version
  projection. Live proof withdraws source data after activation and requires
  direct projection reads to empty without relying on repository call order.
- **MEDIUM — comparison metadata was misdescribed as successful history:**
  accepted. The projection explicitly preserves the existing mutable singleton
  current-attempt semantics, exposes the four consumed non-secret fields, and
  omits ID/error text without filtering or relabeling it as last-success data.

Round 15 must find no unresolved BLOCKER/HIGH before TDD or product changes.

## Round 15 findings and disposition

**Verdict:** `REJECT — unresolved BLOCKER/HIGH findings remain.`

**Evidence:** `/tmp/535-mcp-select-principal-plan-codex-round15.out`

- **HIGH — entity-derived lifecycle leaks:** accepted. Complete eligible-entity
  gates (active entity, approved HGNC, accepted disease/MOI/status/category)
  now apply to every derived review/child/publication shape, with linked inactive
  sentinels rather than isolated catalog-only fixtures.
- **HIGH — source hash omitted the new lifecycle boundary:** accepted. The API
  hash and SQL source projection now share the projection-consistent inputs;
  deployment refreshes snapshots and live tests toggle every lifecycle family.
- **HIGH — old snapshot schema remained selectable:** accepted. Manifest, child,
  and LLM eligibility includes the current snapshot schema version, with an
  old-schema direct-SELECT sentinel.
- **HIGH — unsafe/unproved hostile account cleanup:** accepted. All derived
  account/host/role values use connection-aware quoting, session IDs are strict
  integers, and live MySQL fixtures include quotes/wildcards, excess grants,
  roles, PROXY, and an open session before the real provisioner runs.
- **MEDIUM — cache test contradicted cache removal:** accepted. The existing test
  is explicitly rewritten to assert bootstrap and mount absence.
- **MEDIUM — password path/UID was underspecified:** accepted. The exact ignored
  host path and container path are fixed; ownership follows configurable
  `HOST_UID`/runtime `Sys.getuid()` rather than assuming 1000.

Round 16 must find no unresolved BLOCKER/HIGH before TDD or product changes.

## Round 16 findings and disposition

**Verdict:** `REJECT — unresolved BLOCKER/HIGH findings remain.`

**Evidence:** `/tmp/535-mcp-select-principal-plan-codex-round16.out`

- **HIGH — definer failure preceded reader quarantine:** accepted. Reader lock,
  session kill, revoke, role/PROXY removal, and hostile-host removal now happen
  immediately after acquiring the provisioner lock, before any definer work.
- **HIGH — shared source-hash change was absent from the task inventory:**
  accepted. `analysis-snapshot-repository.R` now explicitly reads the one SQL
  content fingerprint; count/max logic is removed and equal-count/max lifecycle
  swaps are mandatory RED/GREEN/live cases.
- **MEDIUM — comparison lifecycle leak:** accepted. The SysNDD comparison branch
  is rebuilt from fully gated raw dependencies rather than the legacy view.
- **MEDIUM — LLM JSON leaked judge/status fields:** accepted. SQL reconstructs
  only a frozen user-facing key allowlist and service shaping repeats it;
  forbidden nested/future keys are tested.
- **MEDIUM — wrapper trusted stale definer preparation:** accepted. Immediately
  before 044 it attests exact locked, sessionless, roleless, PROXY-free `USAGE`.
- **MEDIUM — host secret path remained overrideable:** accepted. The bind source
  is exactly `./.secrets/mcp-db-password`, with no path substitution.

Round 17 must find no unresolved BLOCKER/HIGH before TDD or product changes.

## Round 17 findings and disposition

**Verdict:** `REJECT — unresolved BLOCKER/HIGH findings remain.`

**Evidence:** `/tmp/535-mcp-select-principal-plan-codex-round17.out`

- **BLOCKER — reader quarantine still occurred after migration:** accepted.
  Quarantine is now the first operator phase; every host variant is locked before
  kill/revoke/drop, remains locked through 044, and live failure injection proves
  definer/migration failure cannot leave a usable reader.
- **MEDIUM — upgrade stage contradiction:** accepted. Stage one always invokes
  the existing runner; preclassified upgrades require zero applied rows and an
  unchanged captured schema/data fingerprint.
- **MEDIUM — snapshots were not refreshed before MCP start:** accepted. API
  starts alone, all supported public presets are forced/awaited and public-route
  verified under the new hash, then MCP starts.
- **MEDIUM — cache capability and LLM shaping files/tests omitted:** accepted.
  Both services and `test-mcp-tools.R` are explicit implementation inventory.

Round 18 must find no unresolved BLOCKER/HIGH before TDD or product changes.

## Round 18 findings and disposition

**Verdict:** `REJECT — unresolved BLOCKER/HIGH findings remain.`

**Evidence:** `/tmp/535-mcp-select-principal-plan-codex-round18.out`

- **HIGH — inbound role/PROXY authority escaped the locked definer:** accepted.
  Both fixed identities receive bidirectional role/PROXY reconciliation,
  mandatory-role rejection, and inbound proxy-grantee session termination before
  raw grants; live fixtures exercise active inbound/proxy/mandatory cases.
- **MEDIUM — comparison lost the NDD phenotype gate:** accepted. The rebuilt
  branch requires `ndd_phenotype = 1` with a non-NDD regression sentinel.
- **MEDIUM — password-reuse comparison lacked inputs:** accepted and removed.
  No extra privileged plaintext inputs are introduced.
- **MEDIUM — API-only refresh could never execute jobs:** accepted. API and the
  default worker run with MCP stopped; durable refresh jobs are awaited before
  MCP startup.

Round 19 must find no unresolved BLOCKER/HIGH before TDD or product changes.

## Round 19 findings and disposition

**Verdict:** `REJECT — unresolved BLOCKER/HIGH findings remain.`

**Evidence:** `/tmp/535-mcp-select-principal-plan-codex-round19.out`

- **BLOCKER — pristine smoke/CI bypassed staged bootstrap:** accepted. The smoke
  script now starts only its disposable MySQL, uses its generated administrator
  secret for staged provisioning/migrations and an ephemeral fixed reader file,
  then starts API/MCP. Ordinary unit lanes use injectable plans; real privileged
  fixtures remain in the standalone verifier.
- **HIGH — unrelated mandatory roles could privilege the reader:** accepted.
  Pre-grant/pre-unlock administrator attestation requires global
  `mandatory_roles` entirely empty, with an unrelated raw-SELECT role fixture.
- **HIGH — later modes did not enforce quarantine ordering:** accepted. Every
  mode and migration wrapper reacquires the lock and re-attests full quarantine
  before its first mutation; out-of-order calls must be zero-mutation failures.
- **MEDIUM — legacy tests still required raw SQL/delegation:** accepted. All
  named repository/analysis tests are explicit modifications and inverted to
  projection-only MCP-owned readers.

Round 20 must find no unresolved BLOCKER/HIGH before TDD or product changes.

## Round 20 findings and architectural disposition

**Verdict:** `REJECT — unresolved BLOCKER/HIGH findings remain.`

**Evidence:** `/tmp/535-mcp-select-principal-plan-codex-round20.out`

Round 20 demonstrated that the separate locked definer was review-induced scope
and the root cause of repeated bootstrap/topology failures. #552 requires SQL
SECURITY DEFINER projections and a dedicated MCP reader; it does not require a
separate definer account. The normative plan is therefore rewritten around
`DEFINER=CURRENT_USER`: the ordinary schema migrator defines the views through
the existing runner, while MCP still authenticates only as the separately
provisioned view-only reader. The API credential is never an MCP credential.

- **HIGH — refresh could republish ineligible analysis members:** retained as a
  same-class fix. Complete manifest eligibility now fails when any member, node,
  or edge endpoint is outside the eligible-public shape, including after a fresh
  refresh.
- **HIGH — production smoke used persistent resources:** the privileged staged
  smoke path is deleted with the separate definer. Ordinary smoke runs migration
  044 normally; real privileged reader tests remain only in the standalone
  UUID-isolated verifier.
- **HIGH — normal startup paths bypassed staged ordering:** resolved by deleting
  staged ordering. Migration 044 now works through every ordinary startup path.
- **MEDIUM — smoke harness changes omitted:** resolved because smoke control flow
  no longer changes for privileged staging.
- **MEDIUM — ambiguous fingerprint row encoding:** accepted. Row encoding is
  typed, NULL-preserving canonical `JSON_ARRAY`, with NULL/delimiter collision
  tests before per-row hashing.

Round 21 must review this simplified boundary and find no unresolved
BLOCKER/HIGH before TDD or product changes.

## Round 21 finding and disposition

**Verdict:** `REJECT — unresolved BLOCKER/HIGH findings remain.`

**Evidence:** `/tmp/535-mcp-select-principal-plan-codex-round21.out`

- **HIGH — external comparisons bypassed approved HGNC:** accepted. The external
  branch now requires an exact non-NULL `hgnc_id` join to an approved HGNC row;
  withdrawn, alias-only, unknown, and NULL fixtures are explicitly excluded.

Round 22 must find no unresolved BLOCKER/HIGH before TDD or product changes.

## Round 22 findings and disposition

**Verdict:** `REJECT — unresolved BLOCKER/HIGH findings remain.`

**Evidence:** `/tmp/535-mcp-select-principal-plan-codex-round22.out`

- **HIGH — contradictory flat views versus shared eligibility:** accepted. The
  exact bounded DAG is now source-version → manifest → children/LLM; all other
  projection dependencies are forbidden and tested.
- **MEDIUM — ineligible diagnostics required reading hidden rows:** accepted.
  Filtered stale/source/schema/member states collapse to `snapshot_missing` and
  compatibility tests/capabilities are updated.
- **MEDIUM — resource text retained cache claims:** accepted. The reachable MCP
  resource and `resources/read` assertions are explicit changes.
- **MEDIUM — live tools could false-green empty:** accepted. Every named tool
  must match nonempty seeded identifiers with no error/missing/substitute/SKIP.
- **MEDIUM — Make fragment was not loaded:** accepted. Root Makefile include and
  phony target are explicit inventory.

Round 23 must find no unresolved BLOCKER/HIGH before TDD or product changes.

## Round 23 findings and disposition

**Verdict:** `REJECT — unresolved BLOCKER/HIGH findings remain.`

**Evidence:** `/tmp/535-mcp-select-principal-plan-codex-round23.out`

- **HIGH — hostile reader could pre-hold advisory lock:** accepted. Quarantine
  now precedes `GET_LOCK`; one pinned administrator connection then retains the
  acquired lock through final attestation/unlock. Pre-held-lock live proof must
  still leave the reader unusable.
- **HIGH — live verifier omitted registered tools:** accepted. Exact 12 core + 6
  analysis inventory is frozen and every listed tool gets a nonempty seeded
  assertion.
- **HIGH — fingerprint source domain unspecified:** accepted. The machine
  contract enumerates typed source families/columns, statically covers builder
  DB inputs, and mutates every field independently.
- **MEDIUM — JSON proof only used rejected row:** accepted. An eligible validated
  matching row carries allowed plus forbidden top-level/nested sentinels; direct
  SQL and every LLM consumer must return exactly the allowlist.

Round 24 must find no unresolved BLOCKER/HIGH before TDD or product changes.

## Round 24 findings and scope disposition

**Verdict:** `REJECT — unresolved BLOCKER/HIGH findings remain.`

**Evidence:** `/tmp/535-mcp-select-principal-plan-codex-round24.out`

Round 24 crossed from #552's reader boundary into snapshot-production redesign:
memoise keys, builder eligibility, correlation provenance, and a new exhaustive
source domain. Those belong to the analysis-snapshot program, not this
least-privilege issue. The normative plan now preserves the existing source-
version semantics exactly in one projection read by the existing R function.

- **BLOCKER — stale memoised output stamped with new fingerprint:** resolved by
  deleting the new fingerprint/builder contract; no source version changes.
- **BLOCKER — cold builders read beyond new approved contract:** resolved by
  deleting that new contract; builder semantics remain unchanged.
- **HIGH — boolean field omitted from exhaustive inventory:** resolved with the
  deleted exhaustive inventory.
- **HIGH — omitted MCP service/test paths:** retained. The named analysis and
  research services plus legacy tests remain explicit changes for cache and
  diagnostic removal.
- **MEDIUM — NULL expiry fail-open:** accepted. Eligibility now requires a
  non-NULL future `stale_after`, with RED/live coverage.

Round 25 must review the bounded #552 design and find no unresolved
BLOCKER/HIGH before TDD or product changes.

## Round 25 findings and disposition

**Verdict:** `REJECT — unresolved BLOCKER/HIGH findings remain.`

**Evidence:** `/tmp/535-mcp-select-principal-plan-codex-round25.out`

- **HIGH — same-shape malicious view survived migration ledger:** accepted.
  Administrator pre-unlock attestation now compares normalized stored view SQL,
  dependencies, columns, security, and definer against trusted 044; live proof
  replaces a view maliciously and requires refusal until operator reapplication.
- **MEDIUM — wrong active-prompt contract:** accepted. LLM view gates on the
  code-level prompt-version constant, frozen against migration SQL.
- **MEDIUM — pre-lock quarantine defeated mutual exclusion claim:** accepted by
  removing the concurrency/advisory-lock claim. Provisioning is explicitly a
  serialized operator action; no speculative mutex is added.

Round 26 must find no unresolved BLOCKER/HIGH before TDD or product changes.

## Round 26 findings and disposition

**Verdict:** `ACCEPT — no unresolved BLOCKER/HIGH findings.`

**Evidence:** `/tmp/535-mcp-select-principal-plan-codex-round26.out`

- **MEDIUM — expected view definer was not independently derivable:** accepted.
  The provisioner now requires a non-secret
  `MCP_EXPECTED_VIEW_DEFINER=user@host`, documented as the identity that applied
  migration 044. It is neither inferred from the administrator connection nor
  trusted from stored metadata. Unit and disposable live tests recreate an
  otherwise-exact view under a different definer and require quarantine/refusal.

Plan review is cleared for TDD: no BLOCKER/HIGH remains after 26 rounds.

## Implementation-time MySQL 8.4 correction

Disposable TDD proved that MySQL 8.4 rejects prepared placeholders in
`CREATE/ALTER USER ... IDENTIFIED BY ?` with error 1064. Interpolating the
caller-supplied credential would violate the accepted no-password-in-SQL/log
boundary, so that design was not weakened or worked around.

The bounded replacement uses MySQL's documented `IDENTIFIED BY RANDOM
PASSWORD` protocol. MySQL returns one in-memory row (`user`, `host`, `generated
password`, `auth_factor`); the provisioner validates the fixed account/factor,
finishes exact view/grant/role/session attestation while the account is locked,
atomically installs the value into an owner-only ignored output file, and only
then unlocks. Compose injects that file read-only. Unit and disposable live
tests cover creation, rotation, old-password rejection, mode 0600, failure
quarantine, and leak scans.

## Round 27 findings and disposition

**Verdict:** `REJECT — unresolved BLOCKER/HIGH findings remain.`

**Evidence:** `/tmp/535-mcp-select-principal-plan-codex-round27.out`

- **HIGH — failure did not restore quarantine:** accepted. Reconciliation now
  installs an `on.exit` compensator before mutation; failure or interrupt
  re-locks every reader variant, terminates reader sessions, removes roles and
  PROXY grants, and revokes privileges. Exact failure-phase tests require no
  unlock and repeated quarantine.
- **HIGH — hostile MFA/account state survived rotation:** accepted. After
  quarantine and authority attestation, every fixed-reader host variant is
  dropped and only a fresh locked `sysndd_mcp@%` account is created with
  `IDENTIFIED BY RANDOM PASSWORD`, clearing prior factors, plugins, secondary
  passwords, roles, attributes, and account options.
- **HIGH — owner-only secret lifecycle was incomplete:** accepted. The writer
  requires an existing owner-matching 0700 parent, rejects symlinks/directories,
  creates the temporary file inside that parent, checks chmod operations,
  atomically renames, and verifies final owner, type, mode, and bytes.
- **MEDIUM — direct environment password remained:** accepted. Runtime config is
  file-only and rejects `MCP_DB_PASSWORD` even when a password file is present.
- **LOW — factor validation was lossy:** accepted. Validation accepts only exact
  base integer `1L` or DBI's exact `integer64("1")`; strings, ordinary doubles,
  fractions, NA, other factors, and large values fail.
- **LOW — short bind created a missing directory:** accepted. Compose uses long
  bind syntax with `create_host_path: false`.

Round 28 must verify these corrections and find no unresolved BLOCKER/HIGH
before the branch can proceed to final DIFF review.

## Round 28 findings and disposition

**Verdict:** `REJECT — unresolved BLOCKER/HIGH findings remain.`

**Evidence:** interactive detached Codex xhigh review, 2026-07-13.

- **HIGH — reverse PROXY authority and effective-reader sessions survived:**
  accepted. Quarantine and final attestation now inspect both PROXY directions,
  revoke mappings before session discovery, resolve effective-reader proxy
  sessions through `performance_schema`, and kill direct and proxied sessions.
  The disposable MySQL proof authenticates a reverse-proxy session and proves
  reconciliation terminates it.
- **HIGH — ambiguous unlock failure could leave a usable reader and secret:**
  accepted. The compensator removes the generated secret first and uses an
  independent fresh administrator connection for strict re-quarantine after a
  primary-connection failure. Live proof simulates a lost unlock acknowledgement
  after MySQL executes the unlock, then proves the secret is absent and login is
  denied before reprovisioning.
- **HIGH — ordinary Compose required a missing MCP bind:** accepted. MCP is now
  an explicit `mcp` profile; ordinary stack configuration has no MCP secret
  dependency, while profile activation remains fail-closed on a missing bind.
- **HIGH — documented host provisioner could not reach the internal database or
  output mount:** accepted. A one-shot `mcp-provisioner` service runs on the
  internal backend network, reads its administrator password from a file, and
  writes only to the owner-only ignored secrets directory.
- **MEDIUM — late failure proof was incomplete:** accepted through the ambiguous
  unlock live scenario and independent recovery tests.
- **MEDIUM — leak scan omitted the generated reader credential:** accepted. The
  final gate reads the generated secret only inside the verifier container and
  scans actual verifier/MCP logs, tool payloads, and process argv.
- **LOW — final file type/mode was not exact:** accepted. Post-install checks
  require a regular file with exact mode `0600`, expected owner, and bytes.

Round 29 must verify these corrections and find no unresolved BLOCKER/HIGH
before the branch can proceed to final DIFF review.
