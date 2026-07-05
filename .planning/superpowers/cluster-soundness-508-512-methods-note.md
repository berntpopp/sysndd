# Cluster-analysis soundness (#508–#512) — methods note & verification

Companion to the spec/plan (`2026-07-05-cluster-soundness-508-512-*.md`). Records the
statistical rationale, the state-of-the-art basis, and the real-data verification.

## What changed and why

| Issue | Defect | Fix |
|---|---|---|
| #508 | HPO root `HP:0000118` + near-universal terms as active MCA variables; no near-constant filtering | Prevalence-band filter (drop <5% / >95% and the root) + `{absent,present}` encoding; Greenacre 1/Q ncp diagnostic reported |
| #509 | k-selection curve computed on a *different* (plain Ward) partition than the reported labels; FactoMineR silently disabled consolidation at `kk=50` | Curve re-runs the exact served procedure per k (anchors `curve[k]==mean_silhouette`); `kk=Inf` so consolidation actually runs; relative-inertia-loss decision curve + honest silhouette band |
| #510 | Modularity on STRING `combined_score` (incl. text-mining), no null model, no giant-component handling | Text-mining-free exp+db weights (STRING OR recombine); degree-preserving configuration-model null → modularity z-score + empirical p; largest-component restriction + isolate/component counts |
| #511 | silhouette vs modularity — incommensurable scales/nulls | Unit-free `separation_z` on both axes (modularity-z / silhouette-z vs matched nulls) + dip test of unimodality (representation-agnostic) + shared modularity-z on the MCA kNN graph |
| #512 | Snapshot ships validation numbers but not the inputs to recompute them | Reproducibility bundle (full edges, complete membership, MCA coords) + `reproducibility_hash` + two read-only endpoints |

## Real-data verification (live stack, reduced null counts)

Validators run on the actual approved-public data (functional: 3214 genes; phenotype: 1932 entities);
production snapshots were not modified.

**Functional (text-mining-free):** `weight_channel=experimental_database`, modularity 0.679,
**modularity_z ≈ 394** vs degree-preserving null (p_emp = 1/51), giant component 2575/3214 nodes,
**542 isolates + 564 components** (these genes had STRING edges *only* via text-mining), dip **p=0 →
multimodal_discrete**.

**Phenotype (filtered MCA + real consolidation):** 30 active terms (dropped `Intellectual disability`
@99.1%, the HPO root, + 7 rare), **consolidation=TRUE**, mean silhouette 0.180 →
`no_substantial_structure_continuum`, silhouette_z ≈ 48, shared_modularity_z ≈ 94, dip **p=0.94 →
unimodal_continuum**, **anchor exact: `k_selection_curve[3] == mean_silhouette`, diff 0.0**.

**Cross-axis:** the dip test is the clean, representation-agnostic discriminator — function
multimodal/discrete, phenotype unimodal/continuum — which is the defensible "modular vs continuum"
evidence, not the raw 0.18-vs-0.68 comparison.

## State-of-the-art basis (selected)

- **MCA junk/rare categories, 1/Q rule, adjusted inertia:** Greenacre, *Correspondence Analysis in
  Practice* (2007); Le Roux & Rouanet, *Multiple Correspondence Analysis* (2010, the <5% rule);
  Husson, Lê & Pagès (2017).
- **HPO term selection / information content:** Köhler et al., *NAR* (2021); Robinson et al., *AJHG*
  (2008); Laurie et al., *JPM* (2021).
- **HCPC / k-selection / silhouette interpretation:** FactoMineR HCPC (Husson & Josse); Rousseeuw
  (1987) + Kaufman & Rousseeuw (1990) ≤0.25 = "no substantial structure"; Tibshirani et al. (2001).
- **Modularity null / random-graph inflation / resolution limit / Leiden:** Guimerà, Sales-Pardo &
  Amaral, *PRE* (2004); Fortunato & Barthélemy, *PNAS* (2007); Miyauchi & Kawase (2016, Z-modularity);
  Traag, Waltman & van Eck, *Sci. Rep.* (2019); Fortunato & Hric (2016).
- **STRING channels / physical vs full network / combined-score OR:** Szklarczyk et al., *NAR*
  (2015/2019/2023).
- **Cross-axis / dip / clusterability:** Hartigan & Hartigan (1985, dip test); von Luxburg (2007,
  mutual-kNN graphs); Adolfsson, Ackerman & Brownstein (2019). Study-bias for a future control set:
  Schaefer et al. (2015); Fulcher et al. (2021).

## Deferred (v1 non-goals)

Matched non-NDD **control gene set** (degree/study-bias matched) to show the modular/continuum
signature is NDD-specific — a later phase. The framework (z on both axes; identical pipeline) is
control-ready.
