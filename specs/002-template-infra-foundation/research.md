# Research: Template Core Infrastructure

## Context

All decisions are informed by the [project constitution](../../../.specify/memory/constitution.md) and the existing [microservice-template](../../../modules/microservice-template) state.

## Decisions

### Flyway version and configuration

- **Decision**: Use Spring Boot-managed Flyway (spring-boot-starter-parent 4.1 pins Flyway 10.x). Disabled in local/test profiles (H2 + ddl-auto: create-drop), enabled in dev/prod (PostgreSQL).
- **Rationale**: Flyway manages schema versioning in environments that matter (dev/prod); local and test use H2 auto-DDL for speed. Zero config — Spring Boot auto-configures Flyway when it detects the dependency and `spring.flyway.enabled=true`.
- **Alternatives considered**: Liquibase (more complex, XML/YAML format — YAGNI for simple migrations).

### Hexagonal package layout

- **Decision**: `domain/`, `application/`, `infrastructure/` under base package `com.template.microservicetemplate`.
- **Rationale**: Matches the constitution's hexagonal architecture mandate (Section V) and is the standard for all microservices cloned from this template.
- **Alternatives considered**: Flat package (violates constitution), multi-module Maven (overhead — YAGNI).

### Example entity choice

- **Decision**: `Product` as the example domain entity spanning all layers.
- **Rationale**: Product is neutral across all 7 microservices (every service could have a product-like entity). Not tied to any specific domain, making it a clear reference example.
- **Alternatives considered**: `User` (too auth-specific), `Order` (too complex, state machine needed).

### Database health indicator

- **Decision**: Spring Boot's `DataSourceHealthIndicator` auto-configured by `DataSource` bean — no custom class needed.
- **Rationale**: Actuator already auto-configures a `DataSourceHealthIndicator` when it detects a `DataSource` on the classpath. A custom `HealthIndicator` adds zero value over the built-in one. This is ponytail rung #5 (already-installed dependency solves it).
- **Alternatives considered**: Custom `DatabaseHealthIndicator` class (redundant — removed).

### CI Docker build

- **Decision**: Add `docker/build-push-action` to CI workflow. Builds image on push to main and on PRs.
- **Rationale**: The spec requires Docker build in CI. The existing workflow already has all prerequisites (Dockerfile, JAR artifact). Adding the build step is ~5 lines.
- **Alternatives considered**: Separate CD workflow (YAGNI — no deployment stage yet).

### Dependabot

- **Decision**: Add `.github/dependabot.yml` targeting Maven and GitHub Actions.
- **Rationale**: Automated dependency updates per FR-08. Weekly schedule minimizes noise.
- **Alternatives considered**: Renovate (more features, more config — YAGNI for template).
