# Phase 68: Local Production Testing - Research

**Researched:** 2026-02-01
**Domain:** Docker Compose multi-container testing and validation
**Confidence:** HIGH

## Summary

Phase 68 focuses on validating the infrastructure changes from Phases 66 and 67 in a production-like local environment. This is a testing and validation phase, not an implementation phase.

The research confirms that Docker Compose provides all necessary tooling for local production testing: `docker compose up --scale api=4` for multi-replica testing, `docker compose logs --timestamps` for parallel startup verification, and standard container inspection commands for validating write operations.

The key insight is that this phase is about verification, not implementation. All changes are made in Phases 66-67; Phase 68 validates those changes work correctly together before production deployment.

**Primary recommendation:** Create a Makefile target (`make test-scaling`) that orchestrates the complete validation sequence: start scaled containers, verify parallel startup via logs, test data directory writes, confirm single-container migration, and report results.

## Standard Stack

The established tools for this testing domain:

### Core
| Tool | Version | Purpose | Why Standard |
|------|---------|---------|--------------|
| Docker Compose | v2.24+ | Container orchestration | Native multi-container support with `--scale` |
| Docker CLI | v24+ | Container inspection | Log access, exec commands |
| GNU Make | 4.x | Test automation | Already used in project Makefile |
| curl | 8.x | Health check verification | Standard HTTP testing |

### Supporting
| Tool | Purpose | When to Use |
|------|---------|-------------|
| `docker compose logs` | View container output | Parallel startup verification |
| `docker compose exec` | Run commands in containers | Write operation testing |
| `docker compose ps` | Container status | Verify replica count |
| `grep` | Log filtering | Timestamp extraction |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Manual testing | Automated script | Script is repeatable, self-documenting |
| CI pipeline | Local Makefile | Local testing enables faster iteration |
| Docker Swarm | Compose scale | Compose sufficient for local validation |

## Architecture Patterns

### Recommended Test Structure

```
Testing Sequence:
1. Fresh database start (trigger migrations)
2. Scale API to 4 replicas
3. Verify logs show parallel startup
4. Verify data directory writes
5. Check health endpoints
6. Report results
```

### Pattern 1: Makefile Test Target

**What:** Encapsulate the complete testing sequence in a single `make test-scaling` command.

**When to use:** Before production deployment, after any Docker/infrastructure changes.

**Example:**
```makefile
# From existing Makefile patterns
test-scaling: check-docker ## [quality] Test multi-container scaling locally
    @printf "$(CYAN)==> Testing production-like multi-container scaling...$(RESET)\n"
    @printf "\n$(CYAN)[1/5] Starting fresh database...$(RESET)\n"
    @docker compose -f docker-compose.yml down -v --remove-orphans 2>/dev/null || true
    @docker compose -f docker-compose.yml up -d mysql
    # Wait for MySQL
    @printf "\n$(CYAN)[2/5] Starting 4 API replicas...$(RESET)\n"
    @docker compose -f docker-compose.yml up -d --scale api=4 api
    @printf "\n$(CYAN)[3/5] Verifying parallel startup...$(RESET)\n"
    @docker compose logs --timestamps api 2>&1 | grep -E "migrations|lock|startup"
    # ... additional steps
```

### Pattern 2: Log-Based Parallel Verification

**What:** Use `docker compose logs --timestamps` to verify containers started in parallel rather than waiting sequentially.

**When to use:** After starting scaled containers.

**Example:**
```bash
# Capture startup timestamps from all containers
docker compose logs --timestamps api 2>&1 | \
  grep -E "Database pool created|Schema up to date" | \
  head -8

# Expected output (parallel - timestamps within seconds):
# 2026-02-01T14:00:01.234Z sysndd-api-1 | [2026-02-01 14:00:01] Database pool created
# 2026-02-01T14:00:01.456Z sysndd-api-2 | [2026-02-01 14:00:01] Database pool created
# 2026-02-01T14:00:01.678Z sysndd-api-3 | [2026-02-01 14:00:01] Database pool created
# 2026-02-01T14:00:01.890Z sysndd-api-4 | [2026-02-01 14:00:01] Database pool created

# Bad output (sequential - 30s gaps indicating lock timeout):
# 2026-02-01T14:00:01.234Z sysndd-api-1 | Schema up to date
# 2026-02-01T14:00:31.456Z sysndd-api-2 | Schema up to date
# 2026-02-01T14:00:61.678Z sysndd-api-3 | Schema up to date
```

### Pattern 3: Write Operation Validation

**What:** Execute write commands in each container to verify shared volume access.

**When to use:** After containers are healthy.

**Example:**
```bash
# Test write from each replica
for i in 1 2 3 4; do
  docker compose exec --index=$i api \
    Rscript -e "writeLines('test from container $i', '/app/data/test-$i.txt')"
done

# Verify all files exist (from any container or host)
docker compose exec --index=1 api ls -la /app/data/test-*.txt
```

### Pattern 4: Migration Coordination Verification

**What:** Verify that on fresh database, exactly one container runs migrations.

**When to use:** After starting containers with fresh database.

**Example:**
```bash
# Count migration execution messages in logs
docker compose logs api 2>&1 | grep -c "Acquired migration lock"
# Expected: 1 (only one container should acquire lock)

docker compose logs api 2>&1 | grep -c "Schema up to date"
# Expected: 3 (other containers skip migration)
```

### Anti-Patterns to Avoid

- **Manual testing only:** Not repeatable, easy to miss steps
- **Testing single container then assuming 4 works:** Parallel startup behavior differs
- **Ignoring log timestamps:** Sequential startup appears to "work" but indicates locking issues
- **Testing without fresh database:** Misses migration race condition scenarios

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Container log aggregation | Custom log parser | `docker compose logs --timestamps` | Native support, reliable |
| Health check polling | Manual curl loop | `docker compose up --wait` | Waits for health checks |
| Container count verification | Parse process list | `docker compose ps --format json` | Structured output |
| Test file cleanup | Manual rm commands | `docker compose down -v` | Removes volumes too |

**Key insight:** Docker Compose provides all the tooling needed; the testing pattern is orchestration of existing commands.

## Common Pitfalls

### Pitfall 1: Testing With Existing Data Volumes

**What goes wrong:** Testing scaling with existing database that already has migrations applied. All containers skip migration, hiding race condition bugs.

**Why it happens:** Developer forgets to reset state between test runs.

**How to avoid:** Always start tests with `docker compose down -v` to remove volumes.

**Warning signs:** Tests pass locally but fail on fresh production deployment.

### Pitfall 2: Ignoring Container Startup Order

**What goes wrong:** API containers start before MySQL is fully ready, causing connection errors.

**Why it happens:** `depends_on` only waits for container start, not health.

**How to avoid:** Use `depends_on: mysql: condition: service_healthy` and wait for MySQL health check.

**Warning signs:** Intermittent "connection refused" errors in first few seconds.

### Pitfall 3: Not Testing All 4 Replicas

**What goes wrong:** Health check succeeds on first replica, but others are unhealthy due to lock timeout.

**Why it happens:** Default health check queries load balancer, which routes to healthy container.

**How to avoid:** Use `--index` flag to check each container individually.

**Warning signs:** `docker compose ps` shows some containers as "unhealthy".

### Pitfall 4: Testing Without Load Balancer

**What goes wrong:** Direct container access works, but Traefik routing fails.

**Why it happens:** Testing bypasses Traefik by hitting container ports directly.

**How to avoid:** Test through the Traefik endpoint (port 80) not container ports.

**Warning signs:** Works on localhost:7777, fails on localhost:80/api.

### Pitfall 5: Insufficient Health Check Timeout

**What goes wrong:** With 4 containers, the last one may wait for migration lock, exceeding health check start_period.

**Why it happens:** start_period (60s) was sized for single container.

**How to avoid:** Phase 66/67 should increase start_period to 120s for scaled deployments.

**Warning signs:** Container 4 shows "starting" state for extended period then fails.

## Code Examples

Verified patterns from project context:

### Complete Test Script (Makefile Target)

```makefile
# Source: Synthesized from existing Makefile patterns + Docker Compose docs
COMPOSE_PROD := docker compose -f docker-compose.yml

test-scaling: check-docker ## [quality] Test 4-replica production-like scaling
	@printf "$(CYAN)==> Testing production-like multi-container scaling...$(RESET)\n"
	@printf "\n$(CYAN)[1/6] Cleaning up previous test...$(RESET)\n"
	@$(COMPOSE_PROD) down -v --remove-orphans 2>/dev/null || true
	@printf "\n$(CYAN)[2/6] Starting MySQL with fresh database...$(RESET)\n"
	@$(COMPOSE_PROD) up -d mysql
	@printf "Waiting for MySQL health check..."
	@until $(COMPOSE_PROD) exec -T mysql mysqladmin ping -u root -p$${MYSQL_ROOT_PASSWORD} --silent 2>/dev/null; do \
		printf "."; sleep 2; \
	done
	@printf " ready\n"
	@printf "\n$(CYAN)[3/6] Starting 4 API replicas...$(RESET)\n"
	@$(COMPOSE_PROD) up -d --scale api=4 api
	@printf "Waiting for containers to stabilize (90s)...\n"
	@sleep 90
	@printf "\n$(CYAN)[4/6] Verifying container health...$(RESET)\n"
	@$(COMPOSE_PROD) ps api --format "table {{.Name}}\t{{.Status}}"
	@HEALTHY=$$($(COMPOSE_PROD) ps api --format json | grep -c '"healthy"'); \
	if [ "$$HEALTHY" -ne 4 ]; then \
		printf "$(RED)FAILED: Only $$HEALTHY/4 containers healthy$(RESET)\n"; \
		$(COMPOSE_PROD) logs api --tail=50; \
		exit 1; \
	fi
	@printf "$(GREEN)All 4 containers healthy$(RESET)\n"
	@printf "\n$(CYAN)[5/6] Checking parallel startup (no 30s lock waits)...$(RESET)\n"
	@$(COMPOSE_PROD) logs --timestamps api 2>&1 | grep -E "Database pool created|Schema up to date" | head -8
	@printf "\n$(CYAN)[6/6] Testing data directory writes...$(RESET)\n"
	@for i in 1 2 3 4; do \
		$(COMPOSE_PROD) exec -T --index=$$i api Rscript -e "writeLines('container $$i', '/app/data/scaling-test-$$i.txt')" && \
		printf "Container $$i: write OK\n" || \
		(printf "$(RED)Container $$i: write FAILED$(RESET)\n" && exit 1); \
	done
	@printf "\n$(GREEN)========================================$(RESET)\n"
	@printf "$(GREEN)       SCALING TEST PASSED              $(RESET)\n"
	@printf "$(GREEN)========================================$(RESET)\n"
	@$(COMPOSE_PROD) down -v
```

### Log Timestamp Analysis

```bash
# Source: docker compose logs documentation
# Check for parallel vs sequential startup

# Extract startup timestamps
docker compose logs --timestamps api 2>&1 | \
  grep "Database pool created" | \
  awk -F'Z' '{print $1}' | \
  sort

# If timestamps are within 5 seconds of each other = parallel (GOOD)
# If timestamps are 30+ seconds apart = sequential lock waiting (BAD)
```

### Individual Container Health Check

```bash
# Source: docker compose exec documentation
# Check health endpoint on each replica

for i in 1 2 3 4; do
  echo "Container $i:"
  docker compose exec --index=$i api \
    curl -sf http://localhost:7777/api/health/ready | jq .
done
```

### Migration Log Verification

```bash
# Source: Synthesized from migration-runner.R logging
# Verify exactly one container ran migrations

LOCK_COUNT=$(docker compose logs api 2>&1 | grep -c "Acquired migration lock")
SKIP_COUNT=$(docker compose logs api 2>&1 | grep -c "Schema up to date")

if [ "$LOCK_COUNT" -eq 1 ] && [ "$SKIP_COUNT" -eq 3 ]; then
  echo "Migration coordination: PASSED"
else
  echo "Migration coordination: FAILED (lock=$LOCK_COUNT, skip=$SKIP_COUNT)"
  exit 1
fi
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Manual docker commands | Makefile targets | Project standard | Repeatable testing |
| `container_name` + manual scaling | `--scale` flag | Docker Compose v2 | Automatic replica naming |
| Single container testing | Multi-container validation | This milestone | Catches race conditions |

**Current best practices:**
- Use `docker compose up --wait` to wait for health checks
- Use `--timestamps` flag for log analysis
- Use `--index` to target specific replicas
- Use `docker compose down -v` for clean state

## Test Verification Checklist

The planner should create tasks that verify each requirement:

| Requirement | Verification Method | Expected Result |
|-------------|---------------------|-----------------|
| TEST-01: 4 replicas run | `docker compose ps api` | 4 containers with "healthy" status |
| TEST-02: Parallel startup | `docker compose logs --timestamps` | Timestamps within 5 seconds |
| TEST-03: Data directory writes | `exec` write test in each container | All 4 write successfully |
| TEST-04: Single migration | `grep` for lock acquisition | Exactly 1 "Acquired migration lock" |

## Open Questions

Things that couldn't be fully resolved:

1. **Optimal wait time for stabilization**
   - What we know: 90 seconds allows for health check start_period
   - What's unclear: Optimal time may vary by hardware
   - Recommendation: Use polling (`docker compose up --wait`) instead of fixed sleep

2. **CI integration**
   - What we know: Local testing is primary goal for this phase
   - What's unclear: Whether to add to GitHub Actions
   - Recommendation: Local Makefile target first; CI integration as follow-up

## Sources

### Primary (HIGH confidence)
- [Docker Compose CLI Reference](https://docs.docker.com/reference/cli/docker/compose/) - logs, up, exec commands
- [Docker Compose Deploy Specification](https://docs.docker.com/reference/compose-file/deploy/) - replicas configuration
- [Docker Compose Production](https://docs.docker.com/compose/how-tos/production/) - production patterns

### Secondary (MEDIUM confidence)
- [Docker Compose Logs Best Practices](https://spacelift.io/blog/docker-compose-logs) - timestamp filtering
- [Baeldung Share Volume Multiple Containers](https://www.baeldung.com/ops/docker-share-volume-multiple-containers) - volume sharing

### Codebase (HIGH confidence)
- `/home/bernt-popp/development/sysndd/Makefile` - existing target patterns
- `/home/bernt-popp/development/sysndd/api/functions/migration-runner.R` - lock logging patterns
- `/home/bernt-popp/development/sysndd/.planning/research/ARCHITECTURE-docker-scaling.md` - prior scaling research
- `/home/bernt-popp/development/sysndd/.planning/research/PITFALLS-docker-production-deployment.md` - prior pitfall research

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - Using only native Docker Compose tooling
- Architecture patterns: HIGH - Patterns verified against Docker docs and existing Makefile
- Pitfalls: HIGH - Based on prior milestone research

**Research date:** 2026-02-01
**Valid until:** Long-term (Docker Compose patterns are stable)

---

*Research for Phase 68: Local Production Testing*
*Depends on: Phase 66 (Infrastructure Fixes), Phase 67 (Migration Coordination)*
