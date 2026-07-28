# Research: Docker Multi-Stage Builds & Docker Compose

## 1. Docker Layer Caching for Maven

**Decision**: Copy `pom.xml` and `.mvn/` first, run `dependency:go-offline`, then copy `src/`.

**Rationale**: Maven dependencies change infrequently. By downloading them in a separate layer before copying source code, Docker reuses the cached dependency layer on every rebuild where only source changes. This is the standard pattern for Java Docker builds.

**Alternatives considered**:
- Copy everything at once: simpler but loses caching benefit (re-downloads deps every build)
- Use BuildKit `--mount=type=cache`: more complex, requires BuildKit, less portable

## 2. Kafka: KRaft vs Zookeeper

**Decision**: Use KRaft mode (no Zookeeper).

**Rationale**: Zookeeper is deprecated in Kafka 3.5+ and removed in Kafka 4.0. KRaft simplifies the compose stack by eliminating a separate Zookeeper container. The spec assumes KRaft.

**Alternatives considered**:
- Zookeeper: more documentation available but deprecated, adds an extra container
- Confluent Platform: commercial features not needed for local dev

## 3. Docker Network Configuration

**Decision**: Define a single bridge network (`microservice-net`) shared by all services.

**Rationale**: All services in the compose file need to communicate. A shared bridge network is the simplest approach for local development. Services discover each other by service name.

**Alternatives considered**:
- Multiple networks per service group: over-engineered for local dev
- Default compose network: works but explicit naming is clearer

## 4. Health Check Patterns

**Decision**: Use command-based health checks for infrastructure, HTTP for the app.

**Rationale**: PostgreSQL uses `pg_isready`, Redis uses `redis-cli ping`, Kafka uses `kafka-broker-api-versions` (KRaft) or `cub kafka-ready`. The app uses Spring Actuator `/actuator/health`.

**Alternatives considered**:
- Docker built-in `HEALTHCHECK` only: insufficient for dependency ordering
- `depends_on` without conditions: starts app before infra is ready

## 5. Volume Persistence

**Decision**: Named volume for PostgreSQL data only.

**Rationale**: Redis and Kafka in local dev don't need persistence beyond defaults. PostgreSQL data is the only state worth preserving across `docker compose down` cycles.

**Alternatives considered**:
- Volumes for all services: unnecessary for local dev cache/broker data
- Bind mounts: platform-specific, less portable

## 6. .dockerignore Optimization

**Decision**: Exclude `.git`, IDE files, `target/`, `docker-compose*`, `*.md`, `doc/`, `.env*` (keep `.env.example`).

**Rationale**: These files are never needed inside the container. Excluding them reduces build context size and prevents cache invalidation from irrelevant file changes.

**Alternatives considered**:
- Minimal ignore: larger context, more cache misses
- Whitelist approach: harder to maintain, easy to miss new files
