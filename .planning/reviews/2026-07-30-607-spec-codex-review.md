## Verdict: BLOCK

The design fixes the reported string-substring bug, but it is not implementation-complete and its exact-match policy demonstrably undercounts real ClinVar pathogenic classifications outside the six-gene sample.

1. **P0 — The proposed vocabulary drops real, documented pathogenic aggregate labels.**

   Evidence: [external-proxy-gnomad.R:220](/home/bernt-popp/development/sysndd/api/functions/external-proxy-gnomad.R:220) forwards gnomAD’s raw `clinical_significance`; the proposed table only recognizes two slash compounds. ClinVar documents aggregate values such as `Pathogenic/Established risk allele`, mixed semicolon forms, and a current record with `Pathogenic/Likely pathogenic/Pathogenic, low penetrance/Established risk allele; risk factor`. The design maps all of these to `unknown`/`other`, removing them from P/LP counts and default-off plots. [NCBI ClinVar classification rules](https://www.ncbi.nlm.nih.gov/clinvar/docs/clinsig/#clinsig_agg), [example current record](https://www.ncbi.nlm.nih.gov/clinvar/variation/13310/)

   Minimal fix: define and test an explicit policy for ClinVar’s documented aggregate grammar/known aggregate vocabulary. If retaining “never guess,” surface an unmapped count prominently in the card and API summary; a console warning plus an omitted chip is not recoverable to users.

2. **P1 — `PathogenicityClass = 'Conflicting'` will fail TypeScript unless a missed exhaustive renderer map is updated.**

   Evidence: [lollipop-render.ts:250](/home/bernt-popp/development/sysndd/app/src/composables/d3-lollipop/lollipop-render.ts:250) has an exhaustive `Record<PathogenicityClass, number>` with only six members. It is separate from `PATHOGENICITY_SEVERITY`, so adding the union member produces a type error and, if patched ad hoc, can disagree with aggregate ordering.

   Minimal fix: derive the individual-render stacking rank from `PATHOGENICITY_SEVERITY` (or one shared rank map) and add the Conflicting class once.

3. **P1 — The lollipop’s stated default is false, so the spec leaves a material product decision ambiguous.**

   Evidence: [ProteinDomainLollipopPlot.vue:104](/home/bernt-popp/development/sysndd/app/src/components/gene/ProteinDomainLollipopPlot.vue:104)-[122](/home/bernt-popp/development/sysndd/app/src/components/gene/ProteinDomainLollipopPlot.vue:122) initializes only P/LP as visible; VUS, LB, and B are off. The spec says this surface is “all-on today” and makes Conflicting default-on.

   Concrete failure: an implementation following the prose could turn every category on, changing initial rendering and likely aggregation; one following current code could make Conflicting visible while VUS/benign remain hidden. Both differ materially.

   Minimal fix: explicitly choose the initial state for all seven classes and add a regression test for it. My recommendation: retain P/LP-only default and make Conflicting explicitly off unless there is a user-facing rationale for highlighting it.

4. **P1 — Both filter-control type surfaces are omitted from the concrete change list.**

   Evidence: [proteinLollipopControls.ts:18](/home/bernt-popp/development/sysndd/app/src/components/gene/proteinLollipopControls.ts:18)-[23](/home/bernt-popp/development/sysndd/app/src/components/gene/proteinLollipopControls.ts:23), [121](/home/bernt-popp/development/sysndd/app/src/components/gene/proteinLollipopControls.ts:121)-[141](/home/bernt-popp/development/sysndd/app/src/components/gene/proteinLollipopControls.ts:141); [GeneStructurePlotControls.vue:171](/home/bernt-popp/development/sysndd/app/src/components/gene/GeneStructurePlotControls.vue:171)-[185](/home/bernt-popp/development/sysndd/app/src/components/gene/GeneStructurePlotControls.vue:185).

   Concrete failure: adding `conflicting`/`other` to parent legend items cannot satisfy the child key unions; “only” and “all” omit the new categories. The lollipop’s `Other chip only when count > 0` also will not happen automatically: its child renders every supplied item ([ProteinLollipopControlsPanel.vue:79](/home/bernt-popp/development/sysndd/app/src/components/gene/ProteinLollipopControlsPanel.vue:79)-[103](/home/bernt-popp/development/sysndd/app/src/components/gene/ProteinLollipopControlsPanel.vue:103)).

   Minimal fix: update both key unions, initial states, legend builders, all/only helpers, and conditionally omit only the `other` legend item in the parent builder.

5. **P1 — The 3D filter change is incomplete without `VariantPanel.vue` state, legend, and watcher changes.**

   Evidence: [variantPanelData.ts:36](/home/bernt-popp/development/sysndd/app/src/components/gene/variantPanelData.ts:36)-[42](/home/bernt-popp/development/sysndd/app/src/components/gene/variantPanelData.ts:42) is exhaustive, but so are [VariantPanel.vue:175](/home/bernt-popp/development/sysndd/app/src/components/gene/VariantPanel.vue:175)-[182](/home/bernt-popp/development/sysndd/app/src/components/gene/VariantPanel.vue:182), [211](/home/bernt-popp/development/sysndd/app/src/components/gene/VariantPanel.vue:211)-[249](/home/bernt-popp/development/sysndd/app/src/components/gene/VariantPanel.vue:249), and [284](/home/bernt-popp/development/sysndd/app/src/components/gene/VariantPanel.vue:284)-[295](/home/bernt-popp/development/sysndd/app/src/components/gene/VariantPanel.vue:284).

   Concrete failure: adding `conflicting` to `AcmgClassification` but missing any of these makes the Conf chip noninteractive or prevents hidden markers from syncing with `ProteinStructure3D`.

   Minimal fix: treat the 3D filter as one vertical slice: type, mapping, initial state, counts, legend, watcher payload, hidden-class builder, only/all, and tests.

6. **P1 — “One shared vocabulary” is not actually a production single source of truth.**

   Evidence: the design calls for a new TS table, while [external-proxy-gnomad.R:302](/home/bernt-popp/development/sysndd/api/functions/external-proxy-gnomad.R:302)-[368](/home/bernt-popp/development/sysndd/api/functions/external-proxy-gnomad.R:368) must retain an independent R table. A JSON fixture exercised by tests is not a shared runtime source and cannot prevent untested-table drift.

   Minimal fix: make one machine-readable vocabulary canonical and generate/import the R and TS lookup data from it, or add bidirectional completeness tests that assert every production table key equals the fixture and vice versa.

7. **P2 — The severity reordering has wider, inconsistent rendering effects than acknowledged.**

   Evidence: aggregate protein markers choose the highest `PATHOGENICITY_SEVERITY` rank in [protein.ts:176](/home/bernt-popp/development/sysndd/app/src/types/protein.ts:176)-[244](/home/bernt-popp/development/sysndd/app/src/types/protein.ts:244). Thus demoting `other` changes every aggregate position containing both an unknown/other label and any recognized class, not only the conflict case. Individual rendering instead uses a separate ordering ([lollipop-render.ts:250](/home/bernt-popp/development/sysndd/app/src/composables/d3-lollipop/lollipop-render.ts:250)-[265](/home/bernt-popp/development/sysndd/app/src/composables/d3-lollipop/lollipop-render.ts:265)). Gene-structure aggregation is frequency-based, not severity-based ([geneStructureVariantPlotUtils.ts:51](/home/bernt-popp/development/sysndd/app/src/components/gene/geneStructureVariantPlotUtils.ts:51)-[58](/home/bernt-popp/development/sysndd/app/src/components/gene/geneStructureVariantPlotUtils.ts:51)).

   Minimal fix: document this as a rendering behavior change, unify protein aggregate/individual ordering, and test mixed `other + P`, `Conflicting + VUS`, and `Conflicting + P` positions.

8. **P2 — Adding categories makes the gene-structure aggregate tooltip silently truncate classification data.**

   Evidence: [gene-structure-tooltip.ts:133](/home/bernt-popp/development/sysndd/app/src/components/gene/gene-structure-plot/gene-structure-tooltip.ts:133)-[140](/home/bernt-popp/development/sysndd/app/src/components/gene/gene-structure-plot/gene-structure-tooltip.ts:140) renders only the top five classes. The revised model has seven possible display classes.

   Minimal fix: render all nonzero classes, or state “top five of N” and provide access to the remainder.

9. **P2 — The summary-client migration requires fixture/type updates not listed in testing.**

   Evidence: `conflicting` becomes a required member of [useGeneClinVarCounts.ts:16](/home/bernt-popp/development/sysndd/app/src/composables/useGeneClinVarCounts.ts:16)-[22](/home/bernt-popp/development/sysndd/app/src/composables/useGeneClinVarCounts.ts:16), while existing mocks provide only five counts ([useGeneClinVarCounts.spec.ts:35](/home/bernt-popp/development/sysndd/app/src/composables/__tests__/useGeneClinVarCounts.spec.ts:35)-[41](/home/bernt-popp/development/sysndd/app/src/composables/__tests__/useGeneClinVarCounts.spec.ts:35), [GeneClinVarCard.spec.ts:5](/home/bernt-popp/development/sysndd/app/src/components/gene/GeneClinVarCard.spec.ts:5)-[12](/home/bernt-popp/development/sysndd/app/src/components/gene/GeneClinVarCard.spec.ts:5)). Also, the claimed `?? 0` stale-response coercion does not exist: [GeneClinVarCard.vue:150](/home/bernt-popp/development/sysndd/app/src/components/gene/GeneClinVarCard.vue:150)-[167](/home/bernt-popp/development/sysndd/app/src/components/gene/GeneClinVarCard.vue:150) returns server counts unchanged.

   Minimal fix: choose backward-compatible `conflicting?: number` at the wire boundary and normalize it to `0` centrally, then update all MSW/component fixtures.

10. **P2 — The “existing `$purple` token” claim is only value equality, not token use.**

    Evidence: `$purple: #6f42c1` exists at [_variables.scss:22](/home/bernt-popp/development/sysndd/app/src/assets/scss/_variables.scss:22), and white-on-`#6f42c1` is approximately 5.94:1, so the AA contrast claim is sound. But the planned TypeScript palette literal is still a hardcoded hex; TypeScript cannot consume that Sass variable directly.

    Minimal fix: either revise the claim to “matches the Sass token,” or expose/use a CSS custom property for rendered UI. Do not claim token-based styling while adding an unrelated JS literal.

I found no additional active substring normalizer beyond the four identified in the spec. The extra [ProteinDomainLollipopCard.vue:182](/home/bernt-popp/development/sysndd/app/src/components/gene/ProteinDomainLollipopCard.vue:182) is an unreferenced legacy data transform that delegates to `normalizeClassification`, not a fifth normalizer. I also found no MCP or export consumer of the `summary=true` payload; its active consumer is the typed frontend hook/card path.

Codex session ID: 019fb464-b977-7f22-9cf7-fcaf324d121f
Resume in Codex: codex resume 019fb464-b977-7f22-9cf7-fcaf324d121f
