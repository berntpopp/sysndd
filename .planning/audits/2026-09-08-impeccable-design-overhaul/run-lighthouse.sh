#!/usr/bin/env bash
set -u
BASE="https://sysndd.dbmr.unibe.ch"
OUT="$(cd "$(dirname "$0")" && pwd)/lighthouse"
LH="npx --no-install lighthouse"
FLAGS="--quiet --preset=desktop --only-categories=performance,accessibility,best-practices,seo --chrome-flags=--headless=new\ --no-sandbox\ --disable-gpu --max-wait-for-load=45000"

PAGES=(
  "home|/"
  "entities|/Entities?sort=%2Bentity_id&page_size=10"
  "genes|/Genes?sort=%2Bsymbol&page_after=0&page_size=10"
  "phenotypes|/Phenotypes?sort=entity_id&filter=all(modifier_phenotype_id,HP:0001249)&page_size=10"
  "panels|/Panels/All/All"
  "curationcomparisons|/CurationComparisons"
  "curationcomparisons-similarity|/CurationComparisons/Similarity"
  "curationcomparisons-table|/CurationComparisons/Table"
  "phenotypecorrelations|/PhenotypeCorrelations"
  "phenotypecounts|/PhenotypeCorrelations/PhenotypeCounts"
  "phenotypeclusters|/PhenotypeCorrelations/PhenotypeClusters"
  "nddscore|/NDDScore"
)

echo "name,performance,accessibility,best_practices,seo,url" > "$OUT/summary.csv"
for entry in "${PAGES[@]}"; do
  name="${entry%%|*}"
  path="${entry#*|}"
  url="$BASE$path"
  echo ">>> [$name] $url"
  timeout 90 $LH "$url" $FLAGS --output=json --output-path="$OUT/$name.json" >/dev/null 2>"$OUT/$name.err"
  if [ -f "$OUT/$name.json" ]; then
    node -e "
      const r=require('$OUT/$name.json');
      const c=r.categories||{};
      const g=k=>c[k]&&c[k].score!=null?Math.round(c[k].score*100):'';
      console.log(['$name',g('performance'),g('accessibility'),g('best-practices'),g('seo'),'$url'].join(','));
    " >> "$OUT/summary.csv" 2>>"$OUT/$name.err" || echo "$name,ERR,ERR,ERR,ERR,$url" >> "$OUT/summary.csv"
  else
    echo "$name,FAIL,FAIL,FAIL,FAIL,$url" >> "$OUT/summary.csv"
  fi
done
echo "=== LIGHTHOUSE RUN COMPLETE ==="
cat "$OUT/summary.csv"
