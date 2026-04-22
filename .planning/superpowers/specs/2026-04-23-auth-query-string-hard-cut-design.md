# Auth Query-String Hard Cut Design

**Date:** 2026-04-23  
**Scope:** Remove sensitive auth/signup/password data from URL query strings and request logging with a hard cut, no compatibility period.

## Goal

Eliminate the remaining insecure auth-related query-string behavior in SysNDD by moving `signup` to JSON-body transport, removing legacy query-param auth/password paths, and stopping raw query-string persistence in request logs.

## Decision

Use a single hard-cut change set instead of a compatibility rollout.

Why:

- The frontend already uses body-based login and password-change flows.
- OWASP guidance is clear that sensitive data must not be sent in query params.
- Keeping transitional support would preserve the insecure path and add removal debt.

## Roadmap Relationship

This change preempts the security-removal slice previously deferred to Phase E auth consolidation.

Decision:

- Treat this as an early extraction of the Phase E removal work for insecure query-param auth flows.
- Phase E should be updated later to avoid re-planning the same endpoint-removal work.
- This change does not replace broader auth consolidation work; it only pulls forward the security-critical transport and logging cleanup.

## In Scope

1. Frontend registration switches from `GET /api/auth/signup?signup_data=...` to `POST /api/auth/signup` with a JSON body.
2. API signup endpoint becomes body-only.
3. Legacy `GET /api/auth/authenticate` is removed.
4. Password-update endpoint removes any query-param compatibility and accepts body data only.
5. Request logging stops storing raw `req$QUERY_STRING` in both application logs and DB logging.
6. Tests are updated to enforce body-only behavior on these sensitive paths.
7. Durable docs are updated so repo guidance matches the removed endpoint surface.

## Out of Scope

1. General auth architecture refactors beyond these endpoints.
2. Token storage redesign.
3. Broader logging schema redesign beyond removing raw query strings.
4. Compatibility shims for external clients.
5. Historical file-log cleanup beyond the targeted DB/application-log scrub described below.

## Design

### API

- `api/endpoints/authentication_endpoints.R`
  - Replace `@get signup` with `@post signup`.
  - Require `Content-Type: application/json`.
  - Parse JSON request body directly.
  - Reject missing or non-JSON content types with `415 Unsupported Media Type`.
  - Reject malformed JSON or empty/whitespace-only bodies with `400 Bad Request`.
  - Validate and insert the same fields as today.
  - Remove the deprecated `@get authenticate` handler entirely.
  - Keep `@post authenticate` as the only login path.

- `api/endpoints/user_endpoints.R`
  - Keep password update body-only.
  - Require `Content-Type: application/json`.
  - Reject missing or non-JSON content types with `415 Unsupported Media Type`.
  - Reject malformed JSON or empty/whitespace-only bodies with `400 Bad Request`.
  - Remove any fallback that accepts password fields from decoded query params.

### Frontend

- `app/src/views/RegisterView.vue`
  - Submit registration via `axios.post(...)` with JSON body.
  - Preserve current UX and validation behavior.

Confirmed current frontend query-string signup usage:

- `RegisterView.vue` still builds `GET /api/auth/signup?signup_data=...`.
- Matching assumptions also exist in registration view tests, MSW handlers, and API user-lifecycle tests.
- No additional live frontend production call sites were found in the current grep beyond registration.

### Logging

- `api/bootstrap/mount_endpoints.R`
  - Stop including `req$QUERY_STRING` in the semicolon-delimited application log entry.
  - Stop sending raw query strings to `log_message_to_db()`.
  - Leave method, path, status, duration, host, agent, and sanitized body handling intact.
  - Persist a fixed placeholder value: `[redacted]`.

### Historical Log Handling

- Add a one-shot cleanup/redaction step for historical DB log rows that already contain raw sensitive query strings.
- Scope file-log cleanup out of this change unless there is already a safe scripted path; document that limitation and create follow-up work if needed.
- The minimum acceptable outcome for this change is: no new raw query strings are written, and existing DB log rows are scrubbed.

### Pre-Removal Usage Check

Before deleting `GET /api/auth/authenticate`, verify there are no remaining repo-local callers and no known operational hooks depending on it:

1. Grep the repo for `GET /api/auth/authenticate` and direct query-param auth construction.
2. Check local scripts, docs, cron-like helpers, and test fixtures for callers.
3. If current request logs are available in the dev/prod-operational workflow, inspect one sample window to confirm there is no live usage before deletion.

## Testing

### API regression coverage

- Update auth endpoint tests to assert:
  - `POST /api/auth/signup` exists and is body-driven.
  - `POST /api/auth/authenticate` remains supported.
  - `GET /api/auth/authenticate` is gone.
  - non-JSON content types fail with `415`.
  - malformed or empty JSON bodies fail with `400`.
- Update user lifecycle tests to send signup and password-change fields in the request body, not query params.
- Add or update logging tests so raw query strings are not persisted.

### Frontend regression coverage

- Update registration view tests and any mock handlers that still expect query-string signup.
- Preserve current success/error UX assertions.

### Documentation updates

- Update `documentation/08-development.qmd` to reflect the body-only auth/signup/password transport.
- Update agent-facing durable guidance that still references the removed GET auth flow.
- If the endpoint surface is documented elsewhere in-repo, update that in the same change.

## Parallel Execution Shape

The work splits cleanly into three streams:

1. Frontend registration transport and frontend tests.
2. API auth/password endpoint hard cut and auth lifecycle tests.
3. Logging change, DB-log scrub, and logging regression tests.

These streams should converge only at final verification.

## Verification

Minimum hard gate:

1. `make lint-api`
2. targeted auth/logging API tests
3. relevant frontend registration tests
4. `make ci-local` before completion

## Risks

1. Undiscovered external clients may still call removed query-param endpoints.
2. Logging tests may need fixture adjustments if they assert the old field layout literally.
3. Historical file logs may still contain pre-change sensitive query strings if no existing safe scrub path exists.

## Recommendation

Proceed with the hard cut in one batch, then verify with targeted tests and full local CI parity before claiming completion.
