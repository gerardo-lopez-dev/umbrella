# Docker Multi-Stage Builds & Docker Compose

## Overview

Optimize the Dockerfile with efficient multi-stage builds and expand docker-compose to orchestrate all base infrastructure services (PostgreSQL, Redis, Kafka) needed by the microservices ecosystem, with proper networking, persistence, and health checks.

## User Scenarios & Testing

### Primary User Story
As a developer cloning the microservice template, I want a ready-to-use Docker setup so that I can run my microservice with all its infrastructure dependencies locally with a single command.

### Acceptance Scenarios
1. **Given** a developer clones the template, **When** they run `docker compose up`, **Then** the microservice starts with PostgreSQL, Redis, and Kafka available and healthy.
2. **Given** the Dockerfile is built, **When** dependencies haven't changed, **Then** the build reuses cached layers and completes in under 60 seconds.
3. **Given** the compose stack is running, **When** the microservice connects to infrastructure, **Then** all services communicate over a dedicated Docker network.
4. **Given** the compose stack is running, **When** containers restart, **Then** PostgreSQL data persists across restarts.
5. **Given** Kafka is running, **When** a developer produces a message, **Then** the message is available to consumers on the same network.

### Edge Cases
- What happens when a required infrastructure service fails to start? → The app service waits via `depends_on` health conditions.
- What if ports conflict with local services? → Developers override via `.env` or `docker-compose.override.yml`.

## Functional Requirements

1. **FR-01**: The Dockerfile must use multi-stage builds with separate build and runtime stages.
2. **FR-02**: The build stage must cache Maven dependencies separately from source code changes.
3. **FR-03**: The runtime stage must run as a non-root user.
4. **FR-04**: The runtime stage must include a health check endpoint.
5. **FR-05**: Docker Compose must define PostgreSQL, Redis, and Kafka services.
6. **FR-06**: All services must be connected via a dedicated Docker network.
7. **FR-07**: PostgreSQL data must persist via a named volume.
8. **FR-08**: Each infrastructure service must have a health check defined.
9. **FR-09**: The app service must depend on infrastructure health conditions before starting.
10. **FR-10**: The `.dockerignore` must exclude build artifacts, IDE files, and unnecessary configuration.
11. **FR-11**: Kafka must include a Zookeeper or KRaft controller for coordination.
12. **FR-12**: Redis must be accessible on the default port with no authentication for local development.

## Success Criteria

- A developer can run `docker compose up` and have a fully functional local environment in under 3 minutes.
- Docker layer caching reduces rebuild time by at least 70% when only source code changes.
- All infrastructure services report healthy before the application starts.
- Data persists across container restarts for stateful services (PostgreSQL).
- The .dockerignore excludes at least 90% of non-essential files from the build context.

## Key Entities

- **Dockerfile**: Multi-stage build definition (build stage, runtime stage)
- **docker-compose.yml**: Service orchestration (app, postgres, redis, kafka)
- **Docker Network**: Isolated network for inter-service communication
- **Named Volumes**: Persistent storage for stateful services
- **Health Check**: HTTP-based readiness verification per service

## Assumptions

- Developers have Docker and Docker Compose v2 installed locally.
- The microservice uses Spring Boot with Actuator (health endpoint at `/actuator/health`).
- PostgreSQL 16 is the target database version.
- Kafka runs in KRaft mode (no Zookeeper) for simplicity.
- Redis is used for caching only, no persistence required beyond default.
- Port mappings follow the project convention (PostgreSQL 5432, Redis 6379, Kafka 9092).
- The template targets Java 21 with Eclipse Temurin images.

## Scope

**In scope:**
- Dockerfile optimization with layer caching
- docker-compose.yml with PostgreSQL, Redis, Kafka
- Docker network configuration
- Named volumes for persistence
- Health checks for all services
- .dockerignore optimization

**Out of scope:**
- Production deployment configurations
- Kubernetes manifests
- CI/CD pipeline modifications
- Application code changes
- Monitoring stacks (Prometheus, Grafana)
- Message schema registry
