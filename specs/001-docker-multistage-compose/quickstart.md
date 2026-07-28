# Quickstart: Docker Multi-Stage Builds & Docker Compose

Validate the feature by running the full stack and verifying infrastructure connectivity.

## Prerequisites

- Docker Engine 24+ and Docker Compose v2 installed
- Ports 5432, 6379, 8080, 9092, 9094 available

## Validation Steps

### 1. Full Stack Up

```bash
cd modules/microservice-template
docker compose up -d
```

**Expected**: All 4 services start (app, postgres, redis, kafka). App waits for infra health checks.

### 2. Verify Health Checks

```bash
docker compose ps
```

**Expected**: All services show `healthy` status.

### 3. Verify PostgreSQL

```bash
docker compose exec postgres psql -U postgres -d microservice_template -c "SELECT 1;"
```

**Expected**: Returns `1`. Data persists after `docker compose down && docker compose up -d`.

### 4. Verify Redis

```bash
docker compose exec redis redis-cli ping
```

**Expected**: Returns `PONG`.

### 5. Verify Kafka

```bash
docker compose exec kafka kafka-topics --bootstrap-server localhost:9092 --list
```

**Expected**: Returns empty list (no topics yet) without error.

### 6. Verify App Health

```bash
curl http://localhost:8080/actuator/health
```

**Expected**: Returns `{"status":"UP"}`.

### 7. Verify Layer Caching

```bash
# First build
time docker compose build app
# Touch only a source file
touch src/main/java/com/template/microservicetemplate/MicroserviceTemplateApplication.java
# Second build (should be fast)
time docker compose build app
```

**Expected**: Second build completes in <60 seconds (dependency layer cached).

### 8. Verify .dockerignore

```bash
docker compose build app 2>&1 | grep -i "sending build context"
```

**Expected**: Build context size is small (<5MB after excluding target/, .git/, etc.).

## Teardown

```bash
docker compose down -v  # -v removes volumes
```
