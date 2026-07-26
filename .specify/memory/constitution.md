<!--
Sync Impact Report
==================
Version change: 1.0.0 → 2.0.0
Modified principles: N/A
Added sections:
  - V. Hexagonal Architecture
  - VI. Microservice Conventions
  - VII. Domain Events
  - VIII. Saga Rules
  - IX. Testing by Layer
Templates requiring updates:
  - .specify/templates/plan-template.md ✅ no changes needed (generic)
  - .specify/templates/spec-template.md ✅ no changes needed (generic)
  - .specify/templates/tasks-template.md ✅ no changes needed (generic)
Skills requiring updates:
  - .opencode/commands/hexagonal.scaffold.md ✅ created
  - .opencode/commands/hexagonal.add-entity.md ✅ created
  - .opencode/commands/hexagonal.add-usecase.md ✅ created
  - .opencode/commands/hexagonal.add-event.md ✅ created
  - .opencode/commands/hexagonal.add-test.md ✅ created
  - .opencode/commands/orders.add-state.md ✅ created
  - .opencode/commands/orders.add-strategy.md ✅ created
  - .opencode/commands/orders.create-saga.md ✅ created
  - .opencode/commands/orders.add-cqrs.md ✅ created
  - .opencode/commands/payments.idempotent.md ✅ created
  - .opencode/commands/notifications.add-consumer.md ✅ created
  - .opencode/commands/shared.add-feign-client.md ✅ created
  - .opencode/commands/shared.add-circuit-breaker.md ✅ created
Follow-up TODOs: none
-->

# Microservice Template Constitution

## Core Principles

### I. Code Quality

All production code MUST adhere to the following standards:

- **Formatting**: Code MUST pass Spotless formatting checks (`./mvnw spotless:check`) before commit. No manual overrides permitted.
- **Static analysis**: Code MUST compile without warnings. All warnings MUST be evaluated and either resolved or explicitly suppressed with justification.
- **Complexity**: Methods MUST NOT exceed 30 lines. Classes MUST NOT exceed 300 lines. Cyclomatic complexity per method MUST NOT exceed 10. Refactor when limits are reached.
- **Naming**: Classes, methods, and variables MUST use descriptive names that convey intent. No abbreviations except well-established ones (e.g., `id`, `url`, `db`).
- **Error handling**: Checked exceptions MUST NOT be silently swallowed. All catch blocks MUST either log, rethrow, or handle explicitly. Custom exceptions MUST extend appropriate base types.
- **Immutability**: Domain objects and value objects MUST be immutable where feasible. Use `record` types for DTOs and data carriers.
- **Documentation**: Public APIs MUST have Javadoc. Internal logic MUST be self-documenting through clear naming and structure. Comments MUST explain *why*, not *what*.

### II. Testing Standards

Testing is a non-negotiable gate for all changes:

- **Coverage**: JaCoCo line coverage MUST NOT fall below 80% for new code. Existing code coverage MUST NOT decrease.
- **Unit tests**: Every service class and utility MUST have unit tests. Tests MUST follow Arrange-Act-Assert pattern. Test method names MUST describe the scenario (e.g., `shouldReturn404WhenEntityNotFound`).
- **Integration tests**: All repository integrations MUST have integration tests using `@SpringBootTest` with Testcontainers or H2 (local profile). External API integrations MUST be tested with WireMock or equivalent.
- **Test isolation**: Tests MUST NOT depend on execution order or shared mutable state. Each test MUST be runnable independently. Use `@BeforeEach` for setup, not `@BeforeAll` with shared state.
- **TDD preference**: New features SHOULD be developed test-first. Red-Green-Refactor cycle is encouraged but not enforced for all changes.
- **CI gate**: All tests MUST pass before merge. Flaky tests MUST be fixed or quarantined immediately — never ignored.

### III. API Consistency

All external-facing APIs MUST follow uniform conventions:

- **Response format**: All endpoints MUST return responses wrapped in a consistent envelope: `{"data": ..., "error": null}` for success, `{"data": null, "error": {"code": "...", "message": "..."}}` for errors.
- **HTTP semantics**: Use correct HTTP methods (GET for reads, POST for creates, PUT/PATCH for updates, DELETE for removals). Status codes MUST accurately reflect the outcome (201 for creation, 204 for no content, 4xx for client errors, 5xx for server errors).
- **Error responses**: Error responses MUST include a machine-readable `code` and a human-readable `message`. Stack traces MUST NOT be exposed to clients.
- **Versioning**: API versioning MUST be handled via URI path prefix (e.g., `/api/v1/...`). Breaking changes MUST increment the major version. Non-breaking additions (new fields, new endpoints) MUST NOT require version changes.
- **Pagination**: List endpoints MUST support pagination via `page` and `size` query parameters. Responses MUST include `totalElements`, `totalPages`, and current `page`.
- **Validation**: Request validation errors MUST return 400 with structured details. Bean validation annotations (`@NotNull`, `@Size`, etc.) MUST be used on all request DTOs.

### IV. Performance Requirements

Performance targets are mandatory, not aspirational:

- **Latency**: API response time MUST NOT exceed 200ms at p95 under expected load. Database queries MUST NOT exceed 50ms at p95.
- **Throughput**: Each service instance MUST handle at least 500 requests per second for simple read operations.
- **Memory**: JVM heap usage MUST NOT exceed 512MB in production profile. Memory leaks MUST be treated as critical bugs.
- **Database**: N+1 query patterns MUST be eliminated. All database queries MUST use indexed columns. Connection pool size MUST be tuned per environment.
- **Caching**: Read-heavy endpoints SHOULD implement appropriate caching (HTTP cache headers, Redis, or in-memory). Cache invalidation strategies MUST be documented.
- **Load testing**: Performance-critical changes MUST include load test results or justification for deviation from targets.

### V. Hexagonal Architecture

All microservices MUST follow hexagonal architecture (ports and adapters):

- **Domain layer** (`domain/`): Contains entities, value objects, domain events, ports, and service implementations. MUST NOT contain Spring annotations, framework imports, or infrastructure concerns. Domain classes MUST be pure POJOs or records.
- **Application layer** (`application/`): Contains use case implementations, DTOs, and mappers. Implements inbound ports. MUST NOT contain framework-specific annotations beyond `@Component` or `@Service` when needed for DI.
- **Infrastructure layer** (`infrastructure/`): Contains all framework-specific code: REST controllers, JPA repositories, messaging producers/consumers, external API clients. This is the ONLY layer that may import Spring, JPA, or other framework packages.
- **Ports**: Inbound ports are use case interfaces (e.g., `RegisterUserUseCase`). Outbound ports are persistence/messaging interfaces (e.g., `UserRepository`). Ports MUST be defined in the domain layer, NOT in infrastructure.
- **Adapters**: Each adapter implements a port and lives in `infrastructure/adapter/`. REST controllers implement inbound ports. JPA repositories implement outbound ports. Adapters MUST be replaceable without modifying domain code.
- **Entities**: Domain entities MUST NOT have JPA annotations (`@Entity`, `@Column`, etc.). JPA entities are separate classes in the persistence adapter. Mapping between domain and JPA entities MUST use MapStruct or manual mapping.

### VI. Microservice Conventions

Each microservice is an independent deployable unit with its own repository:

- **Package naming**: `com.template.{domain}` (e.g., `com.template.orders`, `com.template.payments`).
- **Database ownership**: Each service MUST have its own database schema. Direct database access across services MUST NOT occur. Data sharing MUST happen via APIs or events.
- **Inter-service communication**: Synchronous calls via OpenFeign (through outbound ports). Asynchronous via Kafka/RabbitMQ (through outbound messaging ports). Services MUST NOT share repositories, entities, or JPA configurations.
- **Configuration**: All configuration MUST be externalized via environment variables. Secrets MUST NOT appear in code or configuration files. Use Spring profiles per environment.
- **Port assignment**: Each service MUST have a unique port (8081-8087 assigned per domain). Local development uses the assigned port; Docker Compose maps accordingly.

### VII. Domain Events

Domain events represent significant business occurrences and enable decoupled communication:

- **Naming convention**: `{Entity}{PastVerb}Event` (e.g., `OrderCreatedEvent`, `PaymentCompletedEvent`, `StockReservedEvent`).
- **Structure**: Events MUST be immutable records containing: eventId (UUID), occurredAt (Instant), aggregateId, and event-specific data.
- **Publishing**: Events MUST be published via the Transactional Outbox pattern. The event is written to an outbox table in the same transaction as the business operation, then published asynchronously to the broker.
- **Consumption**: Consumers MUST be idempotent (process the same event multiple times without side effects). Consumer failures MUST NOT block the consumer group. Failed events MUST go to a Dead Letter Queue.
- **Versioning**: Events MUST include a version field. Consumers MUST handle backward-compatible changes gracefully. Breaking event changes require a new event type, not modification of the existing one.

### VIII. Saga Rules

Distributed transactions MUST use the Saga pattern with explicit compensation:

- **Compensating actions**: Every forward action MUST have a corresponding compensating action (e.g., `ReserveStock` → `ReleaseStock`, `ProcessPayment` → `RefundPayment`). Sagas WITHOUT compensations MUST NOT be implemented.
- **Saga state**: Saga state MUST be persisted in a dedicated table (`saga_instance`, `saga_step`). In-memory saga state MUST NOT be used for production workflows.
- **Timeouts**: Each saga step MUST have a configurable timeout. Timed-out steps MUST trigger compensation of all completed steps.
- **Orchestration vs Choreography**: Use orchestration (central coordinator) for complex, multi-step workflows. Use choreography (event-driven) for simple, 2-3 step flows. Document the chosen approach in the service's README.
- **Idempotency**: Saga steps MUST be idempotent. The same step MUST produce the same result if executed multiple times (e.g., due to retries).

### IX. Testing by Layer

Tests MUST follow the testing pyramid with clear separation by architectural layer:

- **Domain tests** (unit): Pure unit tests with NO Spring context, NO Testcontainers, NO database. Test business rules, state transitions, value object validation, and domain event generation. Use Mockito for port mocks only when testing service implementations.
- **Application tests** (unit): Test use case implementations with mocked outbound ports. Verify that use cases correctly orchestrate domain objects and ports. No framework context.
- **Infrastructure tests** (integration): Use `@SpringBootTest` with Testcontainers for database tests. Use WireMock for external API tests. Test adapter implementations, repository queries, REST endpoint contracts.
- **Architecture tests** (ArchUnit): Enforce hexagonal boundaries: domain MUST NOT import from infrastructure. Controllers MUST NOT import from repositories. Package naming conventions MUST be followed. Dependencies MUST NOT be circular.
- **Contract tests**: When services communicate via APIs, verify request/response contracts. Events published by one service MUST match the schema expected by consumers.

## Technology Stack Constraints

- **Language**: Java 21 (LTS). Use modern language features (records, sealed classes, pattern matching) where appropriate.
- **Framework**: Spring Boot 4.1 with Spring Data JPA.
- **Database**: PostgreSQL 16 for dev/prod. H2 for local development only. Schema changes MUST use Flyway or Liquibase migrations.
- **Build**: Maven with wrapper (`mvnw`). Build MUST complete in under 3 minutes.
- **Containerization**: Multi-stage Docker build. Runtime image MUST use JRE only (not JDK). Base image MUST be `eclipse-temurin:21-jre`.
- **Dependencies**: New dependencies MUST be justified for necessity, maintenance status, and license compatibility.

## Development Workflow

- **Branching**: Feature branches from `main`. Branch names: `feature/description`, `fix/description`, `chore/description`.
- **Commits**: Conventional Commits format (`feat:`, `fix:`, `docs:`, `chore:`, etc.). Each commit MUST be atomic and pass all checks.
- **Code review**: All PRs MUST be reviewed by at least one other developer before merge. Review MUST verify constitution compliance.
- **CI/CD**: GitHub Actions runs formatting check, build, test, coverage, and artifact upload on every push to `main`.
- **Local development**: `./mvnw spring-boot:run` for local profile (H2). Docker Compose for dev profile with PostgreSQL.

## Governance

This constitution is the authoritative reference for all development practices in this project. In the event of conflict between this document and any other project documentation, this constitution takes precedence.

Amendments require:
1. Written proposal describing the change and rationale
2. Version bump following semantic versioning (MAJOR for principle removal/redefinition, MINOR for new principle/section, PATCH for clarification)
3. Updated LAST_AMENDED_DATE
4. Propagation to all dependent templates and workflows

Compliance is verified during code review and CI. Non-compliant code MUST NOT be merged.

**Version**: 2.0.0 | **Ratified**: 2026-07-26 | **Last Amended**: 2026-07-26
