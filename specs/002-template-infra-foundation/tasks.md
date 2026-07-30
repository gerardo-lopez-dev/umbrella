# Tasks: Template Base Core Infrastructure (Posts 03-07)

**Input**: Design documents from `specs/002-template-infra-foundation/`

**Ponytail mode:** Active — each task flags what was simplified and when to upgrade.

## Phase 1: Setup — Module & Branch Verification

**Purpose**: Confirm the submodule is on the right branch and the build compiles.

- [X] T001 Verify `modules/microservice-template` is on `002-template-infra-foundation` branch
- [X] T002 [P] Run `./mvnw spotless:check -B` — no formatting violations
- [X] T003 [P] Run `./mvnw verify -B` — all tests pass, jacoco report generated

---

## Phase 2: Foundational — Pom.xml, Config, CI (Blocking)

**Purpose**: Shared infrastructure that all layers depend on.

- [X] T004 [P] Add Flyway deps to `pom.xml` — `flyway-core` + `flyway-database-postgresql`
      *ponytail: Spring Boot manages Flyway version. No custom Flyway config class — auto-configuration covers it.*
- [X] T005 [P] Configure Flyway per profile in `application-dev.yaml` (enabled), `application-local.yaml` (disabled), `application-test.yaml` (disabled)
      *ponytail: H2 profiles keep `ddl-auto: create-drop`; Flyway only for PostgreSQL. Simpler than running Flyway on H2 too.*
- [X] T006 [P] Update `.github/workflows/ci.yml` — add Docker build step on main branch push
- [X] T007 [P] Create `.github/dependabot.yml` — weekly checks for Maven + GitHub Actions
- [X] T008 [P] Add coverage badge + update project structure docs in `README.md`
      *ponytail: Badge is a static placeholder; real value requires Badge API service. Add when CI publishes coverage to a hosted service.*

---

## Phase 3: User Story 1 — Hexagonal Core (All Posts)

**Goal**: Developer clones template and has Actuator health, hexagonal structure, Flyway migrations, JPA persistence, and CI/CD.

**Independent Test**: `./mvnw spring-boot:run -Dspring-boot.run.profiles=local` → `curl localhost:8080/actuator/health` returns UP

### Implementation for User Story 1

- [X] T009 [P] [US1] Create hexagonal dirs under `src/main/java/com/template/microservicetemplate/`
      `domain/model/entity/`, `domain/model/valueobject/`, `domain/port/inbound/`, `domain/port/outbound/`, `domain/service/`,
      `application/usecase/`, `application/dto/request/`, `application/dto/response/`, `application/mapper/`,
      `infrastructure/config/`, `infrastructure/adapter/inbound/rest/`, `infrastructure/adapter/outbound/persistence/`
      *ponytail: Empty dirs establish the pattern. No marker interfaces, no abstract base classes. Add when a second impl exists.*
- [X] T010 [P] [US1] Create `Money` value object in `domain/model/valueobject/Money.java`
      Record with `BigDecimal amount` + `Currency currency`. Factory method `Money.usd()`.
      `ponytail: Only USD factory for now. Add EUR/GBP factories when a second currency appears.`
- [X] T011 [P] [US1] Create `Product` domain entity in `domain/model/entity/Product.java`
      Pure record: `UUID id`, `String name`, `String description`, `Money price`, `String status`.
- [X] T012 [P] [US1] Create inbound port `CreateProductUseCase` in `domain/port/inbound/CreateProductUseCase.java`
      `ponytail: Single-method interface. One implementation exists — inline if CI allows, keep for hexagonal convention.`
- [X] T013 [P] [US1] Create outbound port `ProductRepository` in `domain/port/outbound/ProductRepository.java`
      Methods: `save(Product)`, `findById(UUID)`.
- [X] T014 [US1] Implement `CreateProductUseCaseImpl` in `application/usecase/CreateProductUseCaseImpl.java`
      Creates `Product` with random UUID, calls `repository.save()`.
- [X] T015 [P] [US1] Create request DTO `CreateProductRequest` in `application/dto/request/CreateProductRequest.java`
      With `@NotBlank`, `@PositiveOrZero` validation annotations.
- [X] T016 [P] [US1] Create response DTO `ProductResponse` in `application/dto/response/ProductResponse.java`
- [X] T017 [P] [US1] Create `ProductMapper` in `application/mapper/ProductMapper.java`
      Static method `toResponse(Product)` — no MapStruct dependency.
      `ponytail: Manual mapping. No MapStruct dependency needed for one mapper. Add MapStruct when 5+ mappers exist.`
- [X] T018 [US1] Create JPA entity `ProductJpaEntity` in `infrastructure/adapter/outbound/persistence/ProductJpaEntity.java`
- [X] T019 [P] [US1] Create Spring Data repo `SpringProductRepository` in `infrastructure/adapter/outbound/persistence/SpringProductRepository.java`
- [X] T020 [US1] Create adapter `ProductJpaRepository` in `infrastructure/adapter/outbound/persistence/ProductJpaRepository.java`
      Implements `ProductRepository`, delegates to `SpringProductRepository`. Maps domain ↔ JPA entity.
- [X] T021 [US1] Create `ProductController` in `infrastructure/adapter/inbound/rest/ProductController.java`
      `POST /api/v1/products` — calls use case, returns `ProductResponse` with 201.
- [X] T022 [US1] Create `BeanConfig` in `infrastructure/config/BeanConfig.java`
      Wires `SpringProductRepository` → `ProductJpaRepository` → `CreateProductUseCaseImpl` → `ProductController`.
- [X] T023 [P] [US1] Create Flyway migration `V1__init_schema.sql` in `src/main/resources/db/migration/`
      Creates `products` table matching `ProductJpaEntity` fields.
- [X] T024 [US1] Enable health detail visibility in `application-dev.yaml` and `application-local.yaml`
      `show-details: when-authorized`, `show-components: when-authorized`.
      *ponytail: No custom HealthIndicator class — `DataSourceHealthIndicator` auto-configured by Actuator. Custom class would be a no-op wrapper.*
- [X] T025 [US1] Verify `./mvnw verify -B` passes with all new code
- [X] T026 [US1] Run quickstart validation from `quickstart.md`
      Health endpoint, product API, Flyway migration check.

---

## Phase 4: Polish & Cross-Cutting

- [X] T027 [P] Run `./mvnw spotless:check` — verify formatting
- [X] T028 [P] Run `./mvnw verify` — verify all tests + jacoco report
- [X] T029 Verify `git status` shows expected changes only (no stray files)
- [X] T030 Confirm umbrella root: `git add specs/002-template-infra-foundation/ .specify/feature.json modules/microservice-template`

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies
- **Foundational (Phase 2)**: Depends on Setup — blocks User Story 1
- **User Story 1 (Phase 3)**: Depends on Foundational
- **Polish (Final Phase)**: Depends on User Story 1

### Parallel Opportunities

| Task IDs | Why parallel |
|----------|-------------|
| T002–T003 | Independent checks |
| T004–T008 | Different files, no cross-deps |
| T009–T013, T015–T016, T019, T023 | All different files, no implementation deps |
| T014, T018, T020–T022 | Chained — use case → entity → adapter → controller → config |

### Parallel Example: User Story 1

```bash
# All independent tasks in parallel:
Task: "T009 Create hexagonal dirs"
Task: "T010 Create Money value object"
Task: "T011 Create Product domain entity"
Task: "T012 Create CreateProductUseCase port"
Task: "T013 Create ProductRepository port"
Task: "T015 Create CreateProductRequest DTO"
Task: "T016 Create ProductResponse DTO"
Task: "T019 Create SpringProductRepository"
Task: "T023 Create Flyway V1 migration"

# Then sequential chain:
Task: "T014 CreateProductUseCaseImpl"   # needs T012, T013
Task: "T017 ProductMapper"               # needs T011, T016
Task: "T018 ProductJpaEntity"           # needs T011
Task: "T020 ProductJpaRepository"       # needs T019, T018
Task: "T021 ProductController"          # needs T014, T016
Task: "T022 BeanConfig"                 # needs T020, T014, T021
```

---

## Implementation Strategy

### MVP (Phase 1 → Phase 2 → Phase 3 only)

1. Setup: branch + verify build
2. Foundational: Flyway deps + CI + Dependabot + README
3. User Story 1: all hexagonal layers + health config
4. Validate: `./mvnw verify`, health endpoint, product API
5. Polish: spotless check, final verification

### Ponytail shortcuts summary

| Shortcut | Applied where | Upgrade trigger |
|----------|---------------|-----------------|
| No custom HealthIndicator | Post 03 | If DB health needs custom logic beyond connectivity |
| Manual mapper (no MapStruct) | Post 07 | When 5+ mapper methods exist |
| Single-currency Money factory | Post 05 | When second currency format appears |
| No DEB/CI publishing for badge | Post 04 | When CI publishes to Pages/Badge服务 |
| No marker interfaces in empty dirs | Post 05 | When package needs discoverability tooling |
| Flyway disabled on H2 profiles | Post 06 | When H2 schema needs versioning |

## Notes

- [P] tasks = different files, no dependencies — can run in parallel
- [US1] = the single user story (template infrastructure)
- All code has been written in the initial pass; these tasks serve as verification and documentation
- Commit after each logical group: foundational → hexagonal → persistence → polish
