#!/usr/bin/env bash
set -eu

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

if [ -e deployment.sh ]; then
  fail "deployment.sh must remain retired; use documentation/09-deployment.qmd"
fi

if rg -n 'deployment[.]sh|no-check-certificate|copy_files[.]sh|docker-compose[.]sh' README.md documentation/09-deployment.qmd >/tmp/sysndd-deployment-retirement.matches; then
  cat /tmp/sysndd-deployment-retirement.matches >&2
  fail "stale unsafe deployment script reference found"
fi

printf 'OK: legacy deployment script is retired.\n'
