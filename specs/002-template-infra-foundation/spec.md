# Template Base: Core Infrastructure Foundation (Posts 03-07)

## Overview

Equip the shared microservice template with five essential infrastructure layers: health monitoring and metrics (Actuator), automated CI/CD pipeline (GitHub Actions), architectural package structure (Hexagonal), database migration management (Flyway), and a persistence layer with domain separation (Spring Data JPA). Each is implemented once in the template and inherited by every microservice cloned from it. All implementations follow ponytail principles: the simplest working solution, no speculative abstractions, stdlib and native platform features preferred over custom code.

## User Scenarios & Testing

### Primary User Story

As a developer cloning the microservice template, I want a ready-to-use set of infrastructure capabilities — health checks, CI/CD, package structure, migrations, and persistence — so that I can start building business features immediately without configuring these cross-cutting concerns from scratch.

### Acceptance Scenarios

1. **Given** the template runs locally, **When** I hit `/actuator/health`, **Then** it returns `UP` and includes database connectivity status.
2. **Given** the database is stopped, **When** I check the health endpoint, **Then** it returns `DOWN` with a descriptive message.
3. **Given** I push code to the repository, **When** CI completes, **Then** it ran lint → test → build → coverage → Docker build in sequence.
4. **Given** CI succeeded, **When** I view the README, **Then** a coverage badge displays the latest percentage.
5. **Given** I inspect the template structure, **When** I list packages, **Then** the hexagonal layout (`domain`, `application`, `infrastructure`) is immediately visible.
6. **Given** the application starts against an empty database, **When** Flyway runs, **Then** `V1__init_schema.sql` executes and `flyway_schema_history` records it.
7. **Given** Flyway has run, **When** I query the database, **Then** the initial schema tables exist.
8. **Given** the template includes JPA support, **When** I examine an entity, **Then** the domain class has zero JPA annotations and the JPA mapping lives in a separate adapter.

### Edge Cases

- What if Actuator exposes sensitive info in production? → Endpoints are scoped by profile; only `health` and `info` in prod.
- What if CI fails on lint? → Subsequent stages are skipped, commit is flagged with failure status.
- What if Flyway finds a checksum mismatch? → Flyway fails fast with a descriptive error; never silently re-runs.
- What if domain and JPA entity fields diverge? → The mapper layer explicitly converts; tests verify field parity.

## Functional Requirements

### Post 03 — Actuator & Health Checks

1. **FR-01**: A custom health indicator must verify database connectivity and be exposed at `/actuator/health`.
2. **FR-02**: Actuator endpoints must be gated per Spring profile: all endpoints in local/dev, only `health` and `info` in prod.
3. **FR-03**: Basic JVM metrics — uptime, heap memory, thread count — must be available at `/actuator/metrics`.
4. **FR-04**: Docker Compose health checks must reference the `/actuator/health` endpoint.

### Post 04 — GitHub Actions CI/CD

5. **FR-05**: The CI workflow must execute lint → test → build → coverage → Docker build, in that order.
6. **FR-06**: Maven dependencies must be cached between runs to skip re-downloading unchanged artifacts.
7. **FR-07**: Coverage output must be published and a badge displayed in the README.
8. **FR-08**: Dependabot must check weekly for Maven dependency updates.

### Post 05 — Hexagonal Architecture Package Structure

9. **FR-09**: The template must include `domain/` with sub-packages for `model/entity`, `model/valueobject`, `port/inbound`, `port/outbound`, and `service/`.
10. **FR-10**: The template must include `application/` with sub-packages for `usecase`, `dto/request`, `dto/response`, and `mapper`.
11. **FR-11**: The template must include `infrastructure/` with sub-packages for `config`, `adapter/inbound/rest`, `adapter/outbound/persistence`, and `adapter/outbound/external`.
12. **FR-12**: An example use case with a matching REST controller, DTOs, mapper, and persistence adapter must exist as compilable reference code.

### Post 06 — Flyway Database Migrations

13. **FR-13**: Flyway must run automatically on application startup.
14. **FR-14**: A baseline migration `V1__init_schema.sql` must create the initial schema.
15. **FR-15**: Flyway must be configurable per profile (enabled in dev/prod, disabled in test when using Testcontainers).

### Post 07 — Spring Data JPA & Repository Pattern

16. **FR-16**: Domain entity classes must be pure POJOs with no JPA annotations, framework imports, or persistence concerns.
17. **FR-17**: A JPA-annotated entity class must mirror each domain entity, with explicit mapping annotations.
18. **FR-18**: A Spring Data repository interface must exist for each JPA entity.
19. **FR-19**: An adapter/service class must convert between domain and JPA entities via an explicit mapper.

## Success Criteria

- A developer can clone the template, start it, and verify health and metrics at `/actuator/health` and `/actuator/metrics` in under 2 minutes.
- CI pipeline completes from push to Docker image in under 5 minutes cold cache, under 2 minutes warm cache.
- The hexagonal package structure is discoverable on first `ls`; no documentation needed to find the three layers.
- Flyway applies the baseline migration on first boot; every subsequent start shows `success` in the history table.
- Adding a new entity requires exactly one domain class, one JPA entity, one repository, and one mapper — no framework pollution in the domain.
- Every feature is implemented with the minimum code that works per ponytail principles: no unused interfaces, no config for values that never change, no speculative abstractions.

## Key Entities

- **CustomHealthIndicator**: Health check verifying database connectivity
- **CiWorkflow**: GitHub Actions workflow (`.github/workflows/ci.yml`)
- **DependabotConfig**: Automated dependency updates (`.github/dependabot.yml`)
- **HexagonalPackages**: Three-layer package layout (`domain/`, `application/`, `infrastructure/`)
- **DomainEntity**: Pure Java class in `domain/model/entity/`, framework-free
- **JpaEntity**: JPA-annotated class in `infrastructure/adapter/outbound/persistence/`
- **EntityMapper**: Converter between domain and JPA entities
- **FlywayMigration**: SQL scripts in `src/main/resources/db/migration/`

## Assumptions

- The template uses Spring Boot 4.1 with Java 21 and PostgreSQL 16, per the project constitution.
- The repository hosts on GitHub; CI uses GitHub Actions.
- Coverage is computed by JaCoCo (already present in the template).
- Flyway uses PostgreSQL-compatible SQL.
- JPA implementation defaults to Hibernate via Spring Data JPA.
- All implementations follow ponytail principles: shortest working solution, no speculative abstractions, prefer stdlib and native platform features over custom code.

## Scope

**In scope:**
- Actuator configuration per profile with custom DB health indicator and basic JVM metrics
- GitHub Actions CI with lint, test, build, coverage, Docker build stages
- README coverage badge
- Dependabot config for weekly Maven updates
- Hexagonal package structure with one example use case across all layers
- Flyway dependency, configuration, and single baseline migration
- JPA persistence adapter: domain entity, JPA entity, repository, mapper

**Out of scope:**
- Advanced Actuator features (audit, shutdown, custom business metrics)
- CD pipeline or deployment stages
- Multi-module Maven or shared libraries
- Specific business entities or use cases beyond the single example
- Complex Flyway features (repeatable migrations, callbacks, undo)
- CQRS, event sourcing, or read models
- Test infrastructure (Testcontainers, WireMock, ArchUnit — covered in later posts)
