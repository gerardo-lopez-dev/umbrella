# Quickstart: Template Core Infrastructure (Posts 03-07)

## Prerequisites

- Java 21 (JDK)
- Docker + Docker Compose v2
- Maven wrapper (`.mvn/wrapper` — included)

## Setup

```bash
# From umbrella root — enter the template submodule
cd modules/microservice-template

# Ensure you're on the right branch
git checkout 002-template-infra-foundation

# Build (includes lint + test + jacoco)
./mvnw clean verify
```

## Validation Scenarios

### 1. Health endpoint

```bash
# Run in dev mode (PostgreSQL via Docker)
docker compose up -d postgres
./mvnw spring-boot:run -Dspring-boot.run.profiles=dev

# In another terminal:
curl http://localhost:8080/actuator/health
# Expected: {"status":"UP","components":{"db":{"status":"UP"},...}}

curl http://localhost:8080/actuator/metrics
# Expected: JSON with jvm.memory.used, jvm.threads.live, process.uptime
```

### 2. Product API

```bash
# With the app running (dev profile):
curl -X POST http://localhost:8080/api/v1/products \
  -H "Content-Type: application/json" \
  -d '{"name":"Laptop","description":"16GB RAM","price":1299.99,"currency":"USD"}'
# Expected: 201 Created + product JSON with id, status "ACTIVE"
```

### 3. Flyway migration

```bash
# After starting app with dev profile, verify in PostgreSQL:
docker exec -it microservice-template-postgres-1 \
  psql -U postgres -d dev_db -c "SELECT version, success FROM flyway_schema_history;"
# Expected: V1, true
```

### 4. CI pipeline

```bash
# Push branch and verify in GitHub Actions UI:
# .github/workflows/ci.yml runs: spotless:check → verify → package → docker build
```

## What to Check After Changes

| Check | How |
|-------|-----|
| Spotless passes | `./mvnw spotless:check` |
| All tests pass | `./mvnw verify` |
| Coverage >= 80% | `./mvnw jacoco:report` then check `target/site/jacoco/index.html` |
| Health endpoint responds | `curl localhost:8080/actuator/health` |
| Flyway applied | Check `flyway_schema_history` in PostgreSQL |
| Product API works | POST then GET from the endpoint |
