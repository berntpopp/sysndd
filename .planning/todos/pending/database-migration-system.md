# Database Migration System

**Priority:** High
**Category:** Infrastructure
**Created:** 2026-01-26
**Status:** Backlog

## Problem

Currently, database schema changes are managed through ad-hoc SQL scripts (e.g., `api/scripts/create_about_content_table.sql`) that require manual execution. This doesn't scale for production deployment or team collaboration.

## Current State

- `db/` folder contains R scripts for initial table creation
- `db/migrations/` folder created with numbered SQL migrations (see below)
- No version tracking of applied migrations
- No rollback capability
- Manual `mysql < script.sql` execution required

### Existing Migrations (to integrate)

| Version | File | Description | Status |
|---------|------|-------------|--------|
| 001 | [`db/migrations/001_add_about_content.sql`](../../db/migrations/001_add_about_content.sql) | CMS about_content table | Applied manually |

See also: [`db/migrations/README.md`](../../db/migrations/README.md)

## Requirements

1. **Versioned migrations**: Track which migrations have been applied
2. **Production-safe**: Work on running production database with existing schema
3. **Stack-compatible**: Fit with R/Plumber API and MySQL
4. **Atomic**: Each migration should be complete or fail cleanly
5. **Rollback-aware**: At minimum, document rollback steps

## Research Summary

### Industry Best Practices

- **Migration-based approach** is recommended for production databases
- Each migration should be **atomic, versioned, and focused**
- MySQL DDL is **not transactional** - rollback needs careful planning
- For large tables, use tools like `pt-online-schema-change` or `gh-ost`

### Tool Options

| Tool | Language | Pros | Cons |
|------|----------|------|------|
| [Flyway](https://github.com/flyway/flyway) | Java (CLI) | Industry standard, plain SQL, 50+ DBs | Java dependency |
| [Liquibase](https://www.liquibase.org/) | Java (CLI) | XML/YAML/SQL, good rollback | More complex |
| [Sqitch](https://sqitch.org/) | Perl (CLI) | Pure open-source, full rollback | Perl dependency |
| Custom R | R | Fits stack, no new deps | Build from scratch |

### Recommended Approach for SysNDD

Given the R/Plumber stack, a **simple custom migration system** is recommended:

```
db/
├── migrations/
│   ├── 001_initial_schema.sql
│   ├── 002_add_about_content.sql
│   ├── 003_add_async_jobs_table.sql
│   └── ...
├── migrate.R              # R script to apply migrations
└── schema_version.sql     # Table to track applied migrations
```

**schema_version table:**
```sql
CREATE TABLE IF NOT EXISTS schema_version (
  version INT PRIMARY KEY,
  filename VARCHAR(255) NOT NULL,
  applied_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  checksum VARCHAR(64)
);
```

**migrate.R pseudo-code:**
```r
# 1. Connect to database
# 2. Create schema_version table if not exists
# 3. Get max applied version
# 4. Find migration files with version > max
# 5. For each migration in order:
#    - Execute SQL
#    - Insert into schema_version
#    - Log success/failure
```

## Implementation Tasks

### Phase A: Foundation (estimate: 1 plan)
- [ ] Create `db/migrations/` folder structure
- [ ] Create `schema_version` tracking table
- [ ] Write `migrate.R` script using DBI
- [ ] Document rollback procedures

### Phase B: Existing Migrations (estimate: 1 plan)
- [ ] Move existing ad-hoc scripts to numbered migrations
- [ ] Create baseline migration for existing tables
- [ ] Test on fresh database

### Phase C: Integration (estimate: 1 plan)
- [ ] Add migration check to Docker compose startup
- [ ] Create CI/CD migration verification
- [ ] Document production deployment process

## Sources

- [Database Migrations in the Real World](https://blog.jetbrains.com/idea/2025/02/database-migrations-in-the-real-world/)
- [MySQL Schema Migration Best Practice](https://www.bytebase.com/blog/mysql-schema-migration-best-practice/)
- [Database Version Control: State-based vs Migration-based](https://www.bytebase.com/blog/database-version-control-state-based-vs-migration-based/)
- [Flyway GitHub](https://github.com/flyway/flyway)

## Decision Needed

**Option 1: Custom R solution** - Build simple migration runner in R
- Pros: No new dependencies, fits stack, educational
- Cons: More code to maintain

**Option 2: Flyway CLI** - Use industry-standard tool
- Pros: Battle-tested, full features, documentation
- Cons: Java dependency in Docker image

**Recommendation:** Start with **Option 1** (custom R) for simplicity, with migration to Flyway later if needed.

---
*This backlog item should be scheduled after v6.0 milestone completion.*
