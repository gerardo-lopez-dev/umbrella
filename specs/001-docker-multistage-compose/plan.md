# Implementation Plan: Docker Multi-Stage Builds & Docker Compose

**Branch**: `001-docker-multistage-compose` | **Date**: 2026-07-28 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/001-docker-multistage-compose/spec.md`

## Summary

Optimize the existing Dockerfile with efficient multi-stage builds and expand docker-compose.yml to orchestrate PostgreSQL, Redis, and Kafka as base infrastructure services with networking, persistence, and health checks.

## Technical Context

**Language/Version**: Java 21 (Eclipse Temurin)
**Primary Dependencies**: Spring Boot 3.x, Maven
**Storage**: PostgreSQL 16, Redis 7, Apache Kafka (KRaft mode)
**Testing**: Docker Compose health checks
**Target Platform**: Linux (Docker)
**Project Type**: Microservice template (polyrepo, hexagonal architecture)
**Performance Goals**: `docker compose up` ready in <3 minutes, rebuild <60s with cache
**Constraints**: Layer caching must separate dependency download from source compilation
**Scale/Scope**: Single template repo, cloned per microservice

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

No constitution file found. Gate passes by default.

## Project Structure

### Documentation (this feature)

```text
specs/001-docker-multistage-compose/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output
└── tasks.md             # Phase 2 output (not created by /speckit.plan)
```

### Source Code (repository root)

```text
modules/microservice-template/
├── Dockerfile                    # MODIFY: optimize multi-stage build
├── docker-compose.yml            # MODIFY: add Redis, Kafka, networks
├── .dockerignore                 # MODIFY: optimize exclusions
└── src/main/resources/
    └── application-local.yaml    # MODIFY: add Redis/Kafka connection props
```

**Structure Decision**: Single template project. All changes are within `modules/microservice-template/`. No new directories or files outside the existing structure.

## Complexity Tracking

No constitution violations to justify.
