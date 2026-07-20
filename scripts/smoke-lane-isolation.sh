#!/usr/bin/env bash
# #344 two-lane bulkhead smoke. Requires the PROD two-lane stack up:
#   docker compose -f docker-compose.yml up -d --build
# Saturates the enrichment lane with a concurrent burst of /api/external
# aggregator requests (each fans out to up to 7 upstream sources, so the single
# enrichment process stays busy regardless of cache warmth), and concurrently
# probes /api/health on the core lane, asserting the core probe stays fast.
# Best-effort operator smoke (needs the running stack), not a fast-unit gate.
set -euo pipefail

BASE="${SMOKE_BASE_URL:-http://localhost}"
HEALTH_BUDGET_MS="${HEALTH_BUDGET_MS:-1500}"
SYM="${SMOKE_SYMBOL:-SCN2A}"        # a seeded gene; the aggregator hits live upstreams
BURST="${SMOKE_BURST:-24}"          # > enrichment replica count -> queues on that process

echo "[smoke] saturating the enrichment lane: ${BURST} concurrent /api/external/gene/${SYM}"
pids=()
for _ in $(seq 1 "$BURST"); do
  curl -s -o /dev/null "${BASE}/api/external/gene/${SYM}" &
  pids+=($!)
done

sleep 1   # let the burst occupy the single enrichment process
worst=0
for i in 1 2 3 4 5 6 7 8; do
  ms=$(curl -s -o /dev/null -w '%{time_total}' "${BASE}/api/health/" | awk '{printf "%d", $1*1000}')
  echo "[smoke] /api/health/ probe ${i}: ${ms}ms"
  (( ms > worst )) && worst=$ms
  sleep 0.25
done
for p in "${pids[@]}"; do wait "$p" 2>/dev/null || true; done

if (( worst > HEALTH_BUDGET_MS )); then
  echo "[smoke] FAIL: worst /api/health/ ${worst}ms > ${HEALTH_BUDGET_MS}ms while the enrichment lane was saturated — cheap routes are still blocked."
  exit 1
fi
echo "[smoke] PASS: /api/health/ stayed under ${HEALTH_BUDGET_MS}ms (worst ${worst}ms) under enrichment-lane saturation."
