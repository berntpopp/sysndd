#!/usr/bin/env bash
# Re-run Lighthouse a11y on the pages touched by Foundation Sprint 0, print failing a11y/bp audits.
set -u
BASE="http://localhost:5173"
OUT="$(cd "$(dirname "$0")" && pwd)/lighthouse-recheck"
mkdir -p "$OUT"
LH="npx --no-install lighthouse"
FLAGS="--quiet --preset=desktop --only-categories=accessibility,best-practices --chrome-flags=--headless=new\ --no-sandbox\ --disable-gpu --max-wait-for-load=45000"
PAGES=(
  "entities|/Entities?sort=%2Bentity_id&page_size=10"
  "genes|/Genes?sort=%2Bsymbol&page_after=0&page_size=10"
  "phenotypes|/Phenotypes?sort=entity_id&filter=all(modifier_phenotype_id,HP:0001249)&page_size=10"
  "panels|/Panels/All/All"
  "nddscore|/NDDScore?sort=%2Brank&page_size=10"
  "nddscore-modelcard|/NDDScore/ModelCard"
  "pubtatorndd|/PubtatorNDD"
  "publicationsndd|/PublicationsNDD"
  "api|/API"
  "curationcomparisons-table|/CurationComparisons/Table"
)
for entry in "${PAGES[@]}"; do
  name="${entry%%|*}"; path="${entry#*|}"
  timeout 90 $LH "$BASE$path" $FLAGS --output=json --output-path="$OUT/$name.json" >/dev/null 2>"$OUT/$name.err"
done
node -e '
const fs=require("fs");const dir="'"$OUT"'";
for(const f of fs.readdirSync(dir).filter(x=>x.endsWith(".json"))){
  const r=JSON.parse(fs.readFileSync(dir+"/"+f,"utf8"));const c=r.categories||{},a=r.audits||{};
  const fail=[];
  for(const ref of [...(c.accessibility?.auditRefs||[]),...(c["best-practices"]?.auditRefs||[])]){const x=a[ref.id];if(x&&x.score!=null&&x.score<0.9&&!["notApplicable","informative"].includes(x.scoreDisplayMode))fail.push(x.id+"("+(x.details?.items?.length||0)+")");}
  console.log(f.replace(".json","").padEnd(30),"a11y="+(c.accessibility?Math.round(c.accessibility.score*100):"?"),"bp="+(c["best-practices"]?Math.round(c["best-practices"].score*100):"?"),"|",fail.join(", ")||"(clean)");
}'
echo "=== RECHECK DONE ==="
