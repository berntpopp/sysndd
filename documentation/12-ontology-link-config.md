# Ontology link configuration and the VariO replacement path

This note documents (1) how external ontology term links are built in the
frontend, (2) the fix applied for the broken VariO links (issue #98), and (3)
the **deferred, curator-gated** path for replacing VariO with a different
ontology. It is a developer/operator reference, not a public book chapter.

## Background: the VariO broken-link bug (#98)

SysNDD curates variant effect/consequence terms in the `variation_ontology_list`
table, keyed by a `vario_id` in the `VariO:NNNN` form (Variation Ontology,
VariO). The entity detail page rendered each term as an outbound link to an
external term browser.

The original link was hardcoded in `app/src/views/pages/EntityView.vue` to an
`aber-owl.net` fragment URL:

```
http://aber-owl.net/ontology/VARIO/#/Browse/%3Chttp%3A%2F%2Fpurl.obolibrary.org%2Fobo%2FVariO_0001%3E
```

VariO is an **orphaned** OBO ontology. Its OBO PURL, OntoBee, and Bioregistry
routes no longer resolve to term pages, and the aber-owl link used insecure
`http://` plus a brittle SPA fragment. The links were effectively broken for
users.

## The fix (this PR): configurable base + verified working target

The bug is purely a link-construction problem, so the fix is frontend-only and
introduces **no database change**.

- New module `app/src/assets/js/constants/ontology_links.ts` centralizes the
  VariO term-browser base URL and exposes a pure `varioTermUrl(varioId)` helper
  that converts the stored `VariO:NNNN` id to the OBO PURL IRI the browser
  expects (`VariO:0001` -> `http://purl.obolibrary.org/obo/VariO_0001`,
  percent-encoded).
- `EntityView.vue`'s `varioUrl()` now delegates to that helper instead of the
  hardcoded string.
- The base is overridable at deploy time via the `VITE_VARIO_BASE_URL`
  environment variable (typed in `app/src/env.d.ts`, documented in `app/.env`).
  When unset, the verified default is used.

### Verified working target: EBI OLS4

Despite the issue's premise that VariO is "no longer in OLS", the EBI **OLS4**
service does currently serve live VariO term pages. Verified 2026-06:

- `GET https://www.ebi.ac.uk/ols4/api/ontologies/vario` -> HTTP 200
- `GET https://www.ebi.ac.uk/ols4/api/ontologies/vario/terms?iri=http://purl.obolibrary.org/obo/VariO_0001`
  -> HTTP 200, returns the real term: label `variation`, definition
  "Alteration in biological macromolecule.", `obo_id: VariO:0001`.
- `VariO_0002` likewise resolves to `variation affecting protein`.
- UI term page
  `https://www.ebi.ac.uk/ols4/ontologies/vario/classes?iri=<encoded-IRI>`
  -> HTTP 200.

Default base used by the app:

```
https://www.ebi.ac.uk/ols4/ontologies/vario/classes?iri=
```

Candidates that were checked and rejected: OBO PURL / OntoBee / Bioregistry all
404 for VariO terms; BioPortal bot-blocks and its REST API requires an API key;
variationontology.org is live but hosts no term browser of its own.

### Important caveat: SysNDD-local VariO ids

Some `vario_id` values in `variation_ontology_list` are SysNDD-internal and are
**not** present in the published VARIO ontology (e.g. `VariO:0133`, used in test
fixtures, returns 404 from OLS4). Those links will still 404 at OLS4 because the
term genuinely does not exist upstream. This is a data-curation gap, not a
link-construction bug, and is part of why a real ontology migration (below) must
be a deliberate, curator-reviewed exercise rather than an automatic rewrite.

## Deferred: replacing VariO with another ontology (curator decision)

The issue also proposes migrating curated `vario_id` / `vario_name` values to a
replacement ontology (e.g. Sequence Ontology, SO). **This is intentionally NOT
done in this PR.** Rewriting `vario_id` changes the *meaning* of curated variant
records — it is a curation decision with scientific consequences, and it must be
reviewed and signed off by curators, not performed autonomously by a bug-fix.

When a future curator-approved migration happens, the recommended shape is:

1. **Choose the replacement ontology and pin a version.** Sequence Ontology (SO)
   is the issue's suggested target and is well maintained in OLS4
   (`https://www.ebi.ac.uk/ols4/ontologies/so`). Note SO describes *sequence
   feature/variant types*; VariO additionally covers *effect/consequence and
   mechanism* at DNA/RNA/protein level. The mappings will not all be 1:1.

2. **Build a reviewed mapping table** `vario_id -> {new_id, new_name, status}`
   where `status` is one of `exact`, `broad`, `narrow`, `related`, or
   `no_equivalent`. This must be produced and reviewed by curators. SysNDD-local
   VariO ids (no upstream term) will frequently land in `no_equivalent` and need
   an explicit curation decision. A mapping scaffold lives at
   `db/data/ontology-migrations/vario-to-replacement.mapping.template.csv`.

3. **Add a new ontology list table** (e.g. `variant_ontology_list`) and a
   *compatibility/back-mapping* column rather than destructively overwriting
   `variation_ontology_list`, so historical curated records and their
   provenance remain intact and auditable. This mirrors the existing
   ontology-update safeguard pattern (keep superseded rows as `is_active = 0`
   compatibility rows so foreign keys stay valid).

4. **Migrate via a normal versioned migration** in `db/migrations/`, applied at
   API startup by the migration runner, only after the mapping table is approved.
   Keep the old ids/links resolvable (or clearly marked legacy) for any term
   that has no equivalent.

5. **Make the new ontology's link base configurable too**, following the same
   `ontology_links.ts` + `VITE_*` pattern added here.

Until that curator-approved migration lands, the current fix keeps existing
VariO ids pointing at the best working external browser (EBI OLS4) and makes the
base trivially repointable without a code change.

## Where things live

- Link helper + base: `app/src/assets/js/constants/ontology_links.ts`
- Consumer: `app/src/views/pages/EntityView.vue` (`varioUrl`)
- Env override: `VITE_VARIO_BASE_URL` (`app/src/env.d.ts`, `app/.env`)
- Tests: `app/src/assets/js/constants/ontology_links.spec.ts` and the VariO-link
  assertion in `app/src/views/pages/__tests__/EntityView.spec.ts`
- Curated VariO data: `variation_ontology_list` (see
  `db/migrations/000_initialize_base_schema.sql`)
- Migration scaffold:
  `db/data/ontology-migrations/vario-to-replacement.mapping.template.csv`
