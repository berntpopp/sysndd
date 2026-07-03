# Analysis validation diagnostics (operator-run)

Standalone, operator-run diagnostic scripts that quantify the clustering
correctness/approximation choices behind the public analysis snapshots. They are
**not** wired into production: no endpoint, no public surface, no startup hook.

| Script | What it answers |
|---|---|
| `functional-resolution-sweep.R` | Functional Leiden resolution sweep (gamma in {0.5, 0.7, 1.0, 1.4, 2.0}) reporting `{n_clusters, weighted_modularity, ari_vs_gamma1}`, plus a factorial `{unweighted, weighted} x {n_iterations 2, converged}` attribution with pairwise ARI. Justifies the default gamma on a stability plateau and quantifies how much the old unweighted/non-converged settings changed the partition. |
| `phenotype-approximation-ari.R` | ARI(partition(ncp=8) vs partition(ncp=15)) and ARI across >= 5 `kk` k-means pre-partition seeds. Keep the fast `ncp = 8` / `kk = 50` settings only if ARI is high (>= ~0.9); otherwise the report prints a `FLAG_review_*` decision. Records that FactoMineR 2.13 disables `consol` when `kk != Inf`. |

## Running

These need the full API runtime (STRINGdb, FactoMineR, igraph, cluster) and a DB
connection, so run them inside the running API/worker container:

```bash
docker exec sysndd-api-1 Rscript /app/scripts/analysis-validation/functional-resolution-sweep.R
docker exec sysndd-api-1 Rscript /app/scripts/analysis-validation/phenotype-approximation-ari.R
```

Each writes a timestamped `reports/<name>-<date>.json` + `.md`. The committed
reports under `reports/` are archived operator output; regenerate them after a
material data refresh or an algorithm change.
