# Tasks: Spring Profiles y Configuracion 12-Factor

**Input**: Design documents from `/specs/001-spring-profiles-12factor/`

**Prerequisites**: plan.md (required), spec.md (required for user stories), research.md, data-model.md, contracts/

**Tests**: Not requested in feature specification. Test tasks omitted.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Add missing test dependency to pom.xml

- [x] T001 Add `spring-boot-starter-test` dependency to `modules/microservice-template/pom.xml` (test scope)

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Review and improve existing profile YAML files (local, dev, prod)

**⚠️ CRITICAL**: User story work depends on these profiles being correct

- [x] T002 Review and improve `modules/microservice-template/src/main/resources/application.yaml` — ensure base config is clean, server port uses `${SERVER_PORT:8080}`, actuator config is profile-appropriate
- [x] T003 [P] Review and improve `modules/microservice-template/src/main/resources/application-local.yaml` — ensure H2 console enabled, DEBUG logging for com.template, `ddl-auto: create-drop`
- [x] T004 [P] Review and improve `modules/microservice-template/src/main/resources/application-dev.yaml` — ensure PostgreSQL with default env var values (`${DB_URL:...}`, `${DB_USERNAME:...}`, `${DB_PASSWORD:...}`), INFO logging
- [x] T005 [P] Review and improve `modules/microservice-template/src/main/resources/application-prod.yaml` — ensure PostgreSQL with mandatory env vars (`${DB_URL}`, `${DB_USERNAME}`, `${DB_PASSWORD}` — NO defaults), WARN logging, health-only actuator

**Checkpoint**: Existing profiles are correct and consistent

---

## Phase 3: User Story 1 - Profile-based Configuration (Priority: P1) 🎯 MVP

**Goal**: Add `test` profile with its own `application-test.yaml` for integration tests

**Independent Test**: Run `./mvnw test -Dspring.profiles.active=test` and verify H2 is used, no external services needed

### Implementation for User Story 1

- [x] T006 [US1] Create `modules/microservice-template/src/main/resources/application-test.yaml` with H2 in-memory database, `create-drop` DDL, WARN logging, banner-mode off
- [x] T007 [US1] Create `modules/microservice-template/src/test/resources/application-test.yaml` with test-specific overrides (if needed beyond main resources)
- [x] T008 [US1] Update `modules/microservice-template/src/test/java/com/template/MicroserviceTemplateApplicationTests.java` to add `@ActiveProfiles("test")` annotation

**Checkpoint**: Application starts with `test` profile, tests run with H2

---

## Phase 4: User Story 2 - Environment Variable Documentation (Priority: P1)

**Goal**: Complete `.env.example` with all environment variables

**Independent Test**: Compare `${VAR}` references in all `application*.yaml` files against `.env.example` entries — zero mismatches

### Implementation for User Story 2

- [x] T009 [US2] Rewrite `modules/microservice-template/.env.example` with all 6 environment variables: `SPRING_PROFILES_ACTIVE`, `SERVER_PORT`, `DB_URL`, `DB_USERNAME`, `DB_PASSWORD`, `LOG_LEVEL` — include descriptions and example values per `contracts/env-variables.md`
- [x] T010 [US2] Verify every `${VAR}` reference in `modules/microservice-template/src/main/resources/application*.yaml` has a corresponding entry in `.env.example`

**Checkpoint**: `.env.example` is complete and matches all YAML references

---

## Phase 5: User Story 3 - Startup Validation of Required Variables (Priority: P2)

**Goal**: Application fails fast with clear error when required variables are missing in `prod` profile

**Independent Test**: Start with `SPRING_PROFILES_ACTIVE=prod` without `DB_URL` — verify startup fails with descriptive error

### Implementation for User Story 3

- [ ] T011 [US3] Verify `application-prod.yaml` uses `${DB_URL}`, `${DB_USERNAME}`, `${DB_PASSWORD}` without defaults — Spring's built-in resolution handles fail-fast
- [ ] T012 [US3] Test startup validation: run with prod profile and missing `DB_URL`, confirm error message is clear and actionable
- [ ] T013 [US3] Test startup success: run with prod profile and all variables set, confirm normal startup

**Checkpoint**: Production startup validation works without custom Java code

---

## Phase 6: User Story 4 - Integration Test Profile (Priority: P2)

**Goal**: Integration tests run with `test` profile by default, using H2

**Independent Test**: Run `./mvnw test` — verify `test` profile is active, tests pass, no external services required

### Implementation for User Story 4

- [ ] T014 [US4] Configure Maven to activate `test` profile by default during `mvn test` — add `<activation><activeByDefault>true</activeByDefault></activation>` or `<properties><spring.profiles.active>test</spring.profiles.active></properties>` in `pom.xml`
- [ ] T015 [US4] Verify existing `MicroserviceTemplateApplicationTests` runs with `test` profile and passes
- [ ] T016 [US4] Run full test suite: `./mvnw test` — confirm no external services required, all tests pass

**Checkpoint**: Test suite is self-contained with the `test` profile

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Documentation and final validation

- [ ] T017 Run quickstart.md validation scenarios V1-V7 from `specs/001-spring-profiles-12factor/quickstart.md`
- [ ] T018 [P] Verify Actuator endpoints differ by profile: `local` exposes health+info, `prod` exposes health only
- [ ] T019 [P] Verify logging levels differ by profile: `local` has DEBUG for com.template, `prod` has WARN
- [ ] T020 Verify application starts with zero external config in `local` profile: `./mvnw spring-boot:run` in `modules/microservice-template/`

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — can start immediately
- **Foundational (Phase 2)**: Depends on T001 (test dependency)
- **US1 (Phase 3)**: Depends on Phase 2 completion
- **US2 (Phase 4)**: Depends on Phase 2 completion (needs final YAML files)
- **US3 (Phase 5)**: Depends on Phase 2 completion (needs prod YAML correct)
- **US4 (Phase 6)**: Depends on US1 (needs `test` profile YAML) and T001 (needs test dependency)
- **Polish (Phase 7)**: Depends on all user stories complete

### User Story Dependencies

- **US1 (P1)**: Can start after Phase 2 — no dependencies on other stories
- **US2 (P1)**: Can start after Phase 2 — no dependencies on other stories (parallel with US1)
- **US3 (P2)**: Can start after Phase 2 — no dependencies on other stories (parallel with US1, US2)
- **US4 (P2)**: Depends on US1 (needs `test` profile to exist)

### Parallel Opportunities

- T003, T004, T005 can run in parallel (different YAML files)
- US1, US2, US3 can run in parallel after Phase 2
- T018, T019 can run in parallel (different verification checks)

---

## Parallel Example: User Story 1

```bash
# US1 tasks are sequential (each builds on previous):
Task: "Create application-test.yaml in src/main/resources/"
Task: "Create application-test.yaml in src/test/resources/"
Task: "Add @ActiveProfiles("test") to test class"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Add test dependency
2. Complete Phase 2: Fix existing profiles
3. Complete Phase 3: Add `test` profile
4. **STOP and VALIDATE**: Run `./mvnw test` with test profile
5. Deploy/demo if ready

### Incremental Delivery

1. Setup + Foundational → Foundation ready
2. Add US1 (test profile) → Test independently → Deploy/Demo (MVP!)
3. Add US2 (.env.example) → Test independently → Deploy/Demo
4. Add US3 (startup validation) → Test independently → Deploy/Demo
5. Add US4 (Maven test config) → Test independently → Deploy/Demo
6. Polish → Final validation

### Parallel Team Strategy

With multiple developers:

1. Team completes Setup + Foundational together
2. Once Foundational is done:
   - Developer A: US1 (test profile)
   - Developer B: US2 (.env.example) — parallel with A
   - Developer C: US3 (startup validation) — parallel with A
3. US4 depends on US1 — sequential after A finishes

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- No Java code changes needed — startup validation uses Spring's built-in `${VAR}` resolution
- All changes go to `modules/microservice-template/` (the submodule)
- Commit after each task or logical group
- Stop at any checkpoint to validate story independently
