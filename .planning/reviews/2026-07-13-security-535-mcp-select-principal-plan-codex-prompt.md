You are a hostile staff-level security reviewer. Review the complete plan at
`.planning/superpowers/plans/2026-07-13-security-535-mcp-select-principal-plan.md`
against current SysNDD and #552. Use xhigh reasoning and inspect repository
files. Report only exploitable, correctness-breaking, or implementation-blocking
findings ordered BLOCKER/HIGH/MEDIUM/LOW.

This is a bounded database least-privilege change. Do not require ProxySQL, a
separate locked view-definer, staged/root migration runner, provider proxy,
sealed cohort/generation, host lock, dedicated image, worker mutex, or topology
redesign unless a direct #552 requirement cannot be enforced otherwise.

Required contract:

1. MCP constructs its pool only from fail-closed `MCP_DB_*`; no API config,
   credential, direct fallback, or shared cache mount.
2. `CURRENT_USER()` is exactly `sysndd_mcp@%`; startup verifies exact effective
   grants/roles, empty mandatory roles, and all views before listening.
3. Ordinary migration 044 creates exactly 23 `DEFINER=CURRENT_USER SQL SECURITY
   DEFINER` views. Only one bounded DAG is allowed: source-version → eligible
   manifest → children/LLM; other projections are flat. It updates latest/count
   and needs no special bootstrap. The migrator credential is never used by MCP.
4. Reader gets `USAGE` plus object `SELECT` on those views only: no raw/schema/
   global/DML/DDL/routine/role/PROXY/SHOW VIEW/grant option.
5. Entity-derived/review/comparison views enforce approved HGNC, active entity/
   vocab/status, primary+approved review, connect equality/activity, reviewed
   publication, and NDD phenotype where applicable. Both comparison branches
   require an exact non-NULL approved HGNC row; external aliases/unknowns fail.
6. The source-version view preserves the API's existing formula exactly and the
   R function reads that singleton. This issue does not redesign builders,
   memoise keys, or correlation provenance. Eligible manifests require public-
   ready, non-NULL future expiry, existing source equality and current schema;
   children/LLM join them and filtered states collapse to `snapshot_missing`.
7. LLM rows gate on code-level `LLM_SUMMARY_PROMPT_VERSION`, not the unrelated
   active-template table; JSON is reconstructed from an exact allowlist. NDDScore joins
   active successful release. Forbidden columns/nested/status/error data absent.
8. Every MCP repository uses projections only with bound values; MCP-owned
   snapshot/NDDScore readers replace raw delegates; metadata fallback and every
   result-cache call/capability are removed.
9. Privileged reader provisioner requires serialized operator invocation and
   makes no concurrent/advisory-lock safety claim. On one pinned admin connection
   it locks every host variant before cleanup,
   removes bidirectional role/PROXY edges and proxy sessions, requires mandatory
   roles empty, binds password, grants exact views, attests then unlocks. Failure
   leaves variants unusable; catalog-derived names are connection-quoted. Before
   unlock it compares normalized stored view SQL/dependencies/columns/security/
   definer against trusted 044, catching same-shape malicious replacement.
10. Filtered analysis failure reasons collapse to `snapshot_missing`; resources
    and capabilities contain no removed result-cache claims. TDD captures RED.
    Standard tests are injectable; a standalone UUID-isolated
    verifier owns real administrator/hostile-account tests and never touches the
    persistent project. It proves approved SELECT, denied raw/DML, confidentiality,
    identity/grants, the exact 12+6 `tools/list` inventory, and every listed tool returning a nonempty
    expected seeded identifier with no error/missing/substitute/SKIP.
11. Every touched handwritten source/test/script file stays under 600 lines.

Challenge raw SQL/delegation left reachable, view/member/source/schema gates,
JSON leakage, provisioner quoting/effective authority, env/config fallbacks,
migration compatibility with every normal startup path, stale legacy tests,
and live tests that accept mocks/empty/missing/SKIP or persistent mutation.
Also challenge an unloaded Make fragment or projection dependency outside the
explicit analysis DAG.
Challenge same-shape hostile view replacement and prompt-version drift.
Challenge eligible LLM rows containing forbidden nested/service-added fields,
but do not require an adjacent snapshot-production redesign.

Do not prescribe unrelated platform machinery. Finish with exactly one line:

`Verdict: ACCEPT — no unresolved BLOCKER/HIGH findings.`

or

`Verdict: REJECT — unresolved BLOCKER/HIGH findings remain.`

## Round 27 focused credential-lifecycle delta prompt

Re-read the current #552 plan and cumulative review. Review only the bounded
implementation-time correction after disposable MySQL 8.4 proved that
`CREATE/ALTER USER ... IDENTIFIED BY ?` is unsupported. The corrected design:

- never accepts/interpolates a desired reader password;
- locks/quarantines variants and attests canonical view hashes, columns,
  dependencies, explicit expected definer, roles, sessions, and exact grants;
- uses MySQL 8.4 `IDENTIFIED BY RANDOM PASSWORD` while the fixed account is
  locked and validates the exact one-row/four-column fixed-identity result;
- atomically writes the in-memory generated value to an ignored owner-only
  `MCP_DB_PASSWORD_OUTPUT_FILE` only after authority attestation;
- unlocks last; Compose mounts that file read-only as `MCP_DB_PASSWORD_FILE`;
- leaves the account locked/privilege-free and no temp secret on failure.

Disposable proof already covers creation/rotation auth, old-password rejection,
mode 0600, hostile host/role/PROXY/session cleanup, exact 23 SELECT grants,
raw/DML denial, fixed identity/roles, and zero credential leakage across output,
logs, argv, and grants. Challenge atomicity, failure ordering, secret lifecycle,
MySQL result validation, runtime injection, stale-plan contradictions, and any
way a caller-controlled password still reaches SQL/argv/logs. Do not reopen
unrelated platform scope. Classify concrete BLOCKER/HIGH/MEDIUM/LOW findings and
end with exactly one line:

`Verdict: ACCEPT — no unresolved BLOCKER/HIGH findings.`

or

`Verdict: REJECT — unresolved BLOCKER/HIGH findings remain.`

## Round 28 focused correction prompt

Re-read the current #552 plan, cumulative review, and implementation. Round 27
found failure-quarantine, hostile MFA persistence, secret-file ownership,
direct environment password, lossy auth-factor validation, and short-bind
defects. Verify the implemented corrections rather than the stale round-27
line numbers:

- reconciliation installs best-effort re-quarantine compensation before any
  mutation and unlocks only after all grants, attestation, and secret install;
- all hostile reader variants are quarantined and dropped, then one fresh
  locked `sysndd_mcp@%` account is created with a server-generated password;
- the generated secret requires an existing owner-only parent, atomic install,
  and post-install owner/type/mode/content verification;
- runtime accepts only `MCP_DB_PASSWORD_FILE` and rejects direct
  `MCP_DB_PASSWORD`;
- auth factor accepts only exact integer 1 across base integer and DBI integer64
  representations;
- Compose uses a read-only long bind with `create_host_path: false`.

Challenge failure ordering, ambiguous unlock errors, compensation robustness,
account recreation, filesystem races, DBI result types, configuration fallback,
and Compose behavior. Do not reopen unrelated platform scope. Classify concrete
BLOCKER/HIGH/MEDIUM/LOW findings and end with exactly one line:

`Verdict: ACCEPT — no unresolved BLOCKER/HIGH findings.`

or

`Verdict: REJECT — unresolved BLOCKER/HIGH findings remain.`

## Round 29 focused recovery, proxy, and deployment prompt

Re-read the current #552 plan, cumulative review, and implementation. Round 28
found reverse-PROXY/session quarantine, ambiguous-unlock recovery, default
Compose startup, provisioner reachability, generated-secret scanning, and final
file verification defects. Verify the implemented corrections:

- quarantine and final attestation cover both PROXY directions and terminate
  direct/effective-reader sessions; disposable MySQL authenticates a reverse
  proxy session and proves it is killed;
- failure compensation removes the generated secret before using a fresh,
  independent administrator connection for strict re-quarantine; a live lost
  unlock acknowledgement leaves no secret and no usable reader;
- MCP is opt-in by profile and its missing secret bind remains fail-closed;
- the backend-only one-shot provisioner reads the administrator password only
  from a file and writes the generated password only into an existing owner-only
  ignored directory;
- the actual generated reader password is scanned against verifier/MCP logs,
  tool payloads, and process argv without placing it in host argv or shell text;
- post-install validation requires an exact regular file, owner, mode 0600, and
  bytes.

The strengthened disposable live gate passes all 42 migrations through 044,
23 approved projections, exact grants, confidentiality/raw/DML denial, recovery,
the exact 18-tool inventory, and every real tool call with no SKIP. Challenge
concrete remaining recovery, race, authority, configuration, deployment, or
leak defects only; do not reopen unrelated platform scope. Classify concrete
BLOCKER/HIGH/MEDIUM/LOW findings and end with exactly one line:

`Verdict: ACCEPT — no unresolved BLOCKER/HIGH findings.`

or

`Verdict: REJECT — unresolved BLOCKER/HIGH findings remain.`
