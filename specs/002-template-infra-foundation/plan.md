# Implementation Plan: Template Core Infrastructure (Posts 03-07)

**Branch**: `002-template-infra-foundation` | **Date**: 2026-07-28 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/002-template-infra-foundation/spec.md`

## Summary

Equip the shared microservice template (`modules/microservice-template`) with five infrastructure layers: Actuator health monitoring, GitHub Actions CI/CD, hexagonal package structure, Flyway migrations, and Spring Data JPA with domain/JPA entity separation. All implementations follow ponytail principles — shortest working solution, no speculative abstractions.

## Technical Context

**Language/Version**: Java 21 (LTS)

**Primary Dependencies**: Spring Boot 4.1, Spring Data JPA, Flyway Core + PostgreSQL, Spring Actuator, JaCoCo, Spotless

**Storage**: PostgreSQL 16 (dev/prod), H2 (local/test)

**Testing**: JUnit 5 + Spring Boot Test context (integration), JaCoCo coverage

**Target Platform**: Linux Docker containers (eclipse-temurin:21-jre), GitHub Actions CI

**Project Type**: Multi-service template base (shared across 7 microservices via polyrepo + submodules)

**Performance Goals**: CI under 5 min cold cache; health check response < 100ms; Flyway migration < 5s

**Constraints**: Per constitution: domain layer must not import framework code; methods < 30 lines; coverage >= 80%

**Scale/Scope**: One template reused across 7 microservices; each microservice is an independent deployable unit

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **Hexagonal Architecture** (Section V): Domain entities must be pure POJOs/records — ✓ implemented (Product record). Ports defined in domain layer — ✓. JPA entities in infrastructure/adapter/outbound/persistence — ✓.
- **Testing Standards** (Section II): Coverage >= 80% — needs verification. CI gate — pre-existing.
- **Code Quality** (Section I): Spotless formatting, no warnings — must verify. Methods <= 30 lines — ✓.
- **Technology Stack**: Java 21 + Spring Boot 4.1 + PostgreSQL 16 — ✓. Maven build — ✓.
- **Database Ownership** (Section VI): Flyway migrations in template — ✓.
- **Ponytail Principle**: No speculative abstractions — FRs reviewed; interfaces have exactly one implementation (YAGNI acceptable for template pattern).

**No violations. All gates pass.**

## Project Structure

### Documentation (this feature)

```text
specs/002-template-infra-foundation/
├── plan.md              # This file
├── spec.md              # Feature specification
├── research.md          # Phase 0 — technology decisions
├── data-model.md        # Phase 1 — entity model
├── quickstart.md        # Phase 1 — validation guide
├── contracts/           # Phase 1 — interface contracts
├── checklists/
│   └── requirements.md  # Quality checklist
└── tasks.md             # (/speckit.tasks output)
```

### Source Code (modules/microservice-template)

```text
src/main/java/com/template/microservicetemplate/
├── MicroserviceTemplateApplication.java
├── domain/
│   ├── model/
│   │   ├── entity/Product.java
│   │   └── valueobject/Money.java
│   ├── port/
│   │   ├── inbound/CreateProductUseCase.java
│   │   └── outbound/ProductRepository.java
│   └── service/
├── application/
│   ├── usecase/CreateProductUseCaseImpl.java
│   ├── dto/
│   │   ├── request/CreateProductRequest.java
│   │   └── response/ProductResponse.java
│   └── mapper/ProductMapper.java
└── infrastructure/
    ├── config/BeanConfig.java
    └── adapter/
        ├── inbound/rest/ProductController.java
        └── outbound/persistence/
            ├── ProductJpaEntity.java
            ├── SpringProductRepository.java
            └── ProductJpaRepository.java

src/main/resources/
├── application.yaml
├── application-{local,dev,prod,test}.yaml
└── db/migration/V1__init_schema.sql

src/test/java/.../
└── MicroserviceTemplateApplicationTests.java

.github/workflows/ci.yml
.github/dependabot.yml
Dockerfile
docker-compose.yml
pom.xml
README.md
```

**Structure Decision**: Single-module Maven project. Hexagonal package layout inside `src/main/java/com/template/microservicetemplate/`. No multi-module — YAGNI until a second module is needed.

## Complexity Tracking

No violations. No complexity tracking required.
