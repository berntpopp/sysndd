# #551 Dead `create_job()` Arguments — Codex DIFF Review

## Scope

- Model: `gpt-5.6-sol`
- Reasoning: `xhigh`
- Base: `master` (`dfb6d8fc`)
- Diff: `git diff master...HEAD`
- Review execution: detached/background; long tool phases were stopped and resumed by session id for concise final verdicts.

## Round 1

Final verdict: `APPROVE WITH NON-BLOCKING FOLLOW-UPS`; `BLOCKER/HIGH remaining: no`.

Findings:

- MED: pre-existing synthetic capacity-error seams document responses that the current `create_job()` facade cannot return. The facade return documentation was corrected. Removing all injectable error seams or adding new admission behavior was not folded because either changes endpoint behavior beyond #551; public clustering already has its separate pre-submit capacity guard.
- LOW: exact formals and positional/injected-alias arity were not fully frozen. Folded with exact missing-default formals, AST alias discovery, named-symbol detection, and positional-extra regression cases.
- LOW: affected submission tests did not freeze all durable-handler payload names. Folded for functional, phenotype, ontology, HGNC, and comparisons submissions.
- LOW: stale mirai terminology remained. Folded in endpoint, service, function, and `AGENTS.md` documentation, including the removed LLM timeout claim.

## Round 2

Final verdict: `SHIP`; `BLOCKER/HIGH remaining: no`.

The only finding was LOW: a positional call through a `submit_fn = create_job` injected alias could evade the initial arity heuristic. Folded by deriving alias names from function formal defaults before walking calls. The focused guard test passes after the fold.

## Final Review Bar

- BLOCKER: none
- HIGH: none
- Cheap MEDIUM/LOW findings: folded where in scope
- Residual: the pre-existing injectable capacity-error response seams remain intentionally unchanged; they are not caused by removing `executor_fn`/`timeout_ms` and require a separate behavior decision.
