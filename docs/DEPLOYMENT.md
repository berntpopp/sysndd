# SysNDD Deployment Guide

**Last Updated:** 2026-02-03
**Applies to:** SysNDD API v2.x

This guide covers deployment configuration for the SysNDD API, with focus on memory optimization for different server sizes.

## Quick Start

For most deployments, the defaults work well:

```bash
# Clone and configure
git clone https://github.com/berntpopp/sysndd.git
cd sysndd
cp .env.example .env

# Edit .env with your credentials
nano .env

# Start with Docker Compose
docker compose up -d
```

## Memory Configuration

The SysNDD API uses [mirai](https://github.com/shikokuchuo/mirai) for background task processing (gene cluster analysis, LLM summaries, etc.). Each worker consumes memory proportional to the data it processes.

### MIRAI_WORKERS Environment Variable

Controls the number of background worker processes.

| Setting | Default | Range | Description |
|---------|---------|-------|-------------|
| `MIRAI_WORKERS` | 2 (prod), 1 (dev) | 1-8 | Number of mirai daemon workers |

**Configuration:**

```yaml
# docker-compose.yml
services:
  api:
    environment:
      MIRAI_WORKERS: ${MIRAI_WORKERS:-2}
```

Or via `.env` file:

```bash
MIRAI_WORKERS=2
```

### Server Profiles

Choose a profile based on your server's available RAM:

#### Small Server (4-8GB RAM)

Best for: Development, testing, low-traffic deployments

```bash
# .env
MIRAI_WORKERS=1
DB_POOL_SIZE=3
```

**Expected behavior:**
- Memory usage: ~2-3GB peak during cluster analysis
- Concurrent analysis: Limited to 1 at a time
- Response time: Slightly slower for large gene sets

#### Medium Server (16GB RAM)

Best for: Production with moderate traffic

```bash
# .env
MIRAI_WORKERS=2
DB_POOL_SIZE=5
```

**Expected behavior:**
- Memory usage: ~4-6GB peak
- Concurrent analysis: 2 parallel operations
- Response time: Good balance of speed and resource usage

#### Large Server (32GB+ RAM)

Best for: High-traffic production, research institutions

```bash
# .env
MIRAI_WORKERS=4
DB_POOL_SIZE=10
```

**Expected behavior:**
- Memory usage: ~8-12GB peak
- Concurrent analysis: 4 parallel operations
- Response time: Fast for all operations

### Memory Calculation

Each mirai worker can consume up to:
- **Cluster analysis:** 1-2GB per worker (depends on gene set size)
- **LLM summaries:** 500MB per worker
- **Base overhead:** ~500MB for API process

**Formula:**
```
Peak Memory = Base (500MB) + Workers x 2GB
```

| Workers | Estimated Peak | Recommended Server RAM |
|---------|---------------|----------------------|
| 1 | ~2.5GB | 4-8GB |
| 2 | ~4.5GB | 8-16GB |
| 4 | ~8.5GB | 16-32GB |
| 8 | ~16.5GB | 32GB+ |

### Monitoring

Check current worker configuration via the health endpoint:

```bash
curl http://localhost:8000/api/health/performance | jq '.workers'
```

Response includes:
- `configured`: Number of workers configured via MIRAI_WORKERS
- `connections`: Active worker connections

### Troubleshooting

**Symptom: API crashes during cluster analysis**
- Cause: Insufficient memory for workers
- Solution: Reduce `MIRAI_WORKERS` or increase server RAM

**Symptom: Slow response times for analysis**
- Cause: Too few workers for concurrent requests
- Solution: Increase `MIRAI_WORKERS` if memory allows

**Symptom: Workers = 2 but I set MIRAI_WORKERS=10**
- Cause: Value bounded to maximum of 8
- Solution: Maximum is 8 workers; for more parallelism, scale horizontally

**Symptom: Out of memory errors in Docker**
- Cause: Container memory limit too low for configured workers
- Solution: Increase `deploy.resources.limits.memory` in docker-compose.yml or reduce workers

## Database Configuration

### DB_POOL_SIZE

Controls the database connection pool size.

| Setting | Default | Range | Description |
|---------|---------|-------|-------------|
| `DB_POOL_SIZE` | 5 | 3-20 | Database connection pool size |

**Recommendation:** Set to `MIRAI_WORKERS x 2 + 3` to ensure workers don't wait for connections.

| MIRAI_WORKERS | Recommended DB_POOL_SIZE |
|---------------|-------------------------|
| 1 | 3-5 |
| 2 | 5-7 |
| 4 | 10-12 |
| 8 | 18-20 |

## Docker Compose Files

SysNDD includes multiple compose files for different environments:

| File | Purpose | Default MIRAI_WORKERS |
|------|---------|----------------------|
| `docker-compose.yml` | Production | 2 |
| `docker-compose.override.yml` | Development override | 1 |
| `docker-compose.dev.yml` | Database-only (local API dev) | N/A |

**Production deployment:**
```bash
docker compose -f docker-compose.yml up -d
```

**Development (with override):**
```bash
docker compose up -d  # Uses override automatically
```

## Environment Variables Reference

### Required

| Variable | Description |
|----------|-------------|
| `PASSWORD` | API admin password |
| `MYSQL_ROOT_PASSWORD` | Database root password |
| `MYSQL_DATABASE` | Database name |
| `MYSQL_USER` | Database user |
| `MYSQL_PASSWORD` | Database password |

### Optional (with defaults)

| Variable | Default | Description |
|----------|---------|-------------|
| `MIRAI_WORKERS` | 2 | Background worker count (1-8) |
| `DB_POOL_SIZE` | 5 | Database connection pool size |
| `CORS_ALLOWED_ORIGINS` | (none) | CORS allowed origins (comma-separated) |
| `GEMINI_API_KEY` | (none) | Google Gemini API key for LLM features |
| `HOST_UID` | 1000 | UID for container user |
| `HOST_GID` | 1000 | GID for container user |

## Health Checks

### Basic Health
```bash
curl http://localhost:8000/api/health/
```

### Performance Stats
```bash
curl http://localhost:8000/api/health/performance
```

Includes:
- Worker status (configured count, active connections)
- Database pool stats
- Memory usage

### Container Health

All services include Docker health checks:

```bash
# Check all container health status
docker compose ps
```

## Security Considerations

- All containers run with `no-new-privileges:true`
- MySQL uses `caching_sha2_password` authentication
- Backend network is internal (no external access)
- Traefik dashboard is disabled by default
- Use HTTPS in production (configure Traefik TLS)

## Scaling

For horizontal scaling beyond 8 workers:

1. **Multiple API containers:**
   ```yaml
   services:
     api:
       deploy:
         replicas: 2
   ```

2. **Sticky sessions enabled:** Traefik configured with cookie-based sticky sessions for job state consistency

3. **Shared cache volume:** Consider external Redis for distributed caching

---

*For development setup, see [CLAUDE.md](../CLAUDE.md)*
*For API documentation, see [/api/docs](http://localhost:8000/__docs__/)*
