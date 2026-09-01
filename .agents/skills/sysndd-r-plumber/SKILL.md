---
name: sysndd-r-plumber
description: Use when writing or debugging R/Plumber API code in SysNDD — request bodies, serializers, path parameters, error handling on mounted routers, DBI parameter binding, or any "works in Rscript but fails in the API/worker" package-masking failure
---

# SysNDD R / Plumber Runtime Footguns

These are runtime failures that parse fine and only bite in the fully-loaded API/worker environment, or that silently produce the wrong JSON.

## Non-negotiables

- **Namespace `dplyr::select()` / `dplyr::filter()` explicitly.** `biomaRt` exports an S4 `select` and `stats` a `filter`; resolution depends on package attach order, which differs between the API, the worker, the mirai pool and a standalone `Rscript`. Guard: `test-unit-dplyr-namespace-guard.R`.
- **Loaded packages mask base functions too.** `config::get` masks `base::get` and has **no `mode` argument**, so `get(x, mode = "function")` errors at runtime (while `exists(..., mode=)` still works — the two are asymmetric). Use `base::get()` or dispatch by name. This failed every cluster-snapshot refresh in #514 and host unit tests did not catch it.
- **Plumber parses a JSON array of objects into a `data.frame`** (`simplifyVector = TRUE`), so `body[[1]]` is the first *column*. Any handler iterating a body array must accept both shapes. A test that hand-builds `req$argsBody` as a list of lists tests the wrong shape and stays green.
- **A route serving a list-column with possible `NULL`s must declare `@serializer json list(na="string", null="null")`**, or a `NULL` element renders as `{}` instead of `null`.
- **Plumber does not auto-unbox** (scalars nested in lists serialize as length-1 arrays; unwrap field-by-field on the client) and **does not percent-decode path parameters** (`URLdecode()` defensively; convert the malformed-escape warning into a 400).
- **Every endpoint file must be mounted via `mount_endpoint()`**, never a bare `pr_mount()` — Plumber does not propagate the root error handler to sub-routers, so a classed error degrades to an opaque 500. Guard: `test-unit-endpoint-error-handler.R`.
- **`DBI::dbBind()` with `?` placeholders needs `unname(params)`** — named lists can fail silently.
- Use `inherits(x, "Date")`, not `is.Date(x)`, in library-light contexts.

## Deep reference

- `references/runtime-footguns.md` — the full text of each rule with its failure mode and guard test.
