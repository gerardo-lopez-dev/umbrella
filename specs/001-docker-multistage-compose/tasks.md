# Tasks: Docker Multi-Stage Builds & Docker Compose

**Input**: Design documents from `/specs/001-docker-multistage-compose/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, quickstart.md

**Tests**: Not requested. No test tasks generated.

**Organization**: Two user stories derived from acceptance scenarios, both at P1 priority (equally critical for the feature).

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1, US2)
- Exact file paths included in descriptions

## Phase 1: Setup

**Purpose**: No project initialization needed. Template already exists.

*(Skipped — no tasks)*

---

## Phase 2: User Story 1 — Optimized Dockerfile (Priority: P1)

**Goal**: Docker build reuses dependency layer cache, runs as non-root, includes health check.

**Independent Test**: Build the image twice; second build completes in <60s with no source-dependent layer changes.

### Implementation

- [x] T001 [P] [US1] Optimize Dockerfile multi-stage build with dependency caching in `modules/microservice-template/Dockerfile`
- [x] T002 [P] [US1] Optimize `.dockerignore` to exclude build artifacts, IDE files, and non-essential files in `modules/microservice-template/.dockerignore`

**Checkpoint**: Dockerfile builds efficiently with layer caching. `.dockerignore` keeps build context small.

---

## Phase 3: User Story 2 — Docker Compose Full Stack (Priority: P1)

**Goal**: `docker compose up` starts app with PostgreSQL, Redis, and Kafka, all healthy, on a shared network.

**Independent Test**: Run `docker compose up -d`, verify all 4 services healthy, verify connectivity between services.

### Implementation

- [x] T003 [P] [US2] Add Redis service with health check to `modules/microservice-template/docker-compose.yml`
- [x] T004 [P] [US2] Add Kafka KRaft service with health check to `modules/microservice-template/docker-compose.yml`
- [x] T005 [US2] Add Docker network `microservice-net` and attach all services in `modules/microservice-template/docker-compose.yml`
- [x] T006 [US2] Add `depends_on` health conditions to app service in `modules/microservice-template/docker-compose.yml`
- [x] T007 [P] [US2] Add Redis and Kafka connection properties to `modules/microservice-template/src/main/resources/application-local.yaml`

**Checkpoint**: Full stack runs with all services healthy and connected.

---

## Phase 4: Polish & Validation

**Purpose**: Verify everything works end-to-end per quickstart.md

- [ ] T008 Run quickstart.md validation steps to verify full stack functionality
- [ ] T009 Verify layer caching by building image twice and confirming <60s rebuild

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 2 (US1)**: No dependencies — can start immediately
- **Phase 3 (US2)**: No dependencies on US1 — can start in parallel
- **Phase 4 (Polish)**: Depends on both US1 and US2 being complete

### User Story Dependencies

- **US1 (Dockerfile)**: Independent. Only touches `Dockerfile` and `.dockerignore`.
- **US2 (Docker Compose)**: Independent. Only touches `docker-compose.yml` and `application-local.yaml`.
- Both stories can be implemented simultaneously by different developers.

### Parallel Opportunities

- T001 and T002 can run in parallel (different files)
- T003, T004, and T007 can run in parallel (different files or independent additions)
- US1 and US2 can be worked on simultaneously

---

## Parallel Example: User Story 1

```bash
Task: "Optimize Dockerfile multi-stage build with dependency caching in modules/microservice-template/Dockerfile"
Task: "Optimize .dockerignore to exclude build artifacts, IDE files, and non-essential files in modules/microservice-template/.dockerignore"
```

## Parallel Example: User Story 2

```bash
Task: "Add Redis service with health check to modules/microservice-template/docker-compose.yml"
Task: "Add Kafka KRaft service with health check to modules/microservice-template/docker-compose.yml"
Task: "Add Redis and Kafka connection properties to modules/microservice-template/src/main/resources/application-local.yaml"
```

---

## Implementation Strategy

### MVP First (Both stories are MVP — they're equally critical)

1. Complete T001-T002 (Dockerfile optimization)
2. Complete T003-T007 (Docker Compose)
3. Run T008-T009 (validation)
4. **Done**: Full stack operational

### Incremental Delivery

Since both stories are P1 and independent:
1. Implement US1 + US2 in parallel
2. Validate with quickstart.md
3. Commit and done

---

## Notes

- All tasks modify existing files — no new files to create
- T003-T006 all modify `docker-compose.yml` sequentially (same file)
- T007 is independent (different file) and can run alongside T003-T004
- No tests requested — validation is manual via quickstart.md
