# Requirements: SysNDD v10.1 Production Deployment Fixes

**Defined:** 2026-02-01
**Core Value:** A new developer can clone the repo and be productive within minutes, with confidence that their changes won't break existing functionality.

## v10.1 Requirements

Requirements for fixing production deployment issues discovered on VPS. Each maps to roadmap phases.

### Deployment Infrastructure

- [ ] **DEPLOY-01**: API container can write to bind-mounted /app/data directory without permission errors
- [ ] **DEPLOY-02**: Dockerfile UID is configurable via build-arg (default 1000)
- [ ] **DEPLOY-03**: Multiple API containers can start in parallel without migration lock timeout
- [ ] **DEPLOY-04**: container_name directive removed from API service to enable scaling

### Bug Fixes

- [ ] **BUG-01**: Favicon image (brain-neurodevelopmental-disorders-sysndd.png) loads without 404 errors

### Migration Coordination

- [ ] **MIGRATE-01**: Migration check happens before lock acquisition (fast path for up-to-date schema)
- [ ] **MIGRATE-02**: Double-check after lock handles race condition (another container migrated)
- [ ] **MIGRATE-03**: Health endpoint shows migration status (lock acquired, migrations applied)

### Local Production Testing

- [ ] **TEST-01**: Production-like multi-container setup (4 API replicas) runs locally
- [ ] **TEST-02**: Parallel API container startup verified via container logs
- [ ] **TEST-03**: Data directory write operations work across all containers
- [ ] **TEST-04**: Migration coordination verified with fresh database startup

## Future Requirements

None - this is a focused bug fix milestone.

## Out of Scope

| Feature | Reason |
|---------|--------|
| Init container for migrations | Double-checked locking is simpler and sufficient |
| Redis for shared cache | Named volume sufficient for current scale |
| User namespace remapping | Overkill - build-time UID fix is simpler |
| Entrypoint script with gosu | Build-time UID fix doesn't require runtime permission fixing |
| Kubernetes deployment | Docker Compose is current deployment target |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| DEPLOY-01 | Phase 66 | Pending |
| DEPLOY-02 | Phase 66 | Pending |
| DEPLOY-03 | Phase 67 | Pending |
| DEPLOY-04 | Phase 66 | Pending |
| BUG-01 | Phase 66 | Pending |
| MIGRATE-01 | Phase 67 | Pending |
| MIGRATE-02 | Phase 67 | Pending |
| MIGRATE-03 | Phase 67 | Pending |
| TEST-01 | Phase 68 | Pending |
| TEST-02 | Phase 68 | Pending |
| TEST-03 | Phase 68 | Pending |
| TEST-04 | Phase 68 | Pending |

**Coverage:**
- v10.1 requirements: 12 total
- Mapped to phases: 12
- Unmapped: 0

---
*Requirements defined: 2026-02-01*
*Last updated: 2026-02-01 after roadmap creation*
