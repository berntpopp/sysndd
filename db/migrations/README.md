# Database Migrations

This folder contains SQL migration scripts for the SysNDD database.

## Naming Convention

Migrations are numbered sequentially:
```
001_add_about_content.sql
002_next_migration.sql
...
```

## Current Status

**Manual execution required** - No automated migration runner yet.

To apply a migration:
```bash
docker exec -i sysndd_mysql mysql -u root -proot sysndd_db < db/migrations/001_add_about_content.sql
```

## Migration Tracking

Currently, there is no automated tracking of which migrations have been applied.
See `.planning/todos/pending/database-migration-system.md` for the planned migration system.

## Migrations

| Version | File | Description | Applied |
|---------|------|-------------|---------|
| 001 | `001_add_about_content.sql` | CMS about_content table with draft/publish workflow | Manual |

## Future Plans

A proper migration system will include:
- `schema_version` table to track applied migrations
- `migrate.R` script for automated execution
- Rollback documentation for each migration
