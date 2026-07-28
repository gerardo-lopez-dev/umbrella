# Data Model: Docker Multi-Stage Builds & Docker Compose

This feature modifies infrastructure configuration files only. No application data entities are involved.

## Infrastructure Services

### PostgreSQL
| Property | Value |
|----------|-------|
| Image | `postgres:16-alpine` |
| Port | 5432 |
| Volume | `pgdata` (named volume) |
| Health check | `pg_isready -U postgres` |
| Env vars | `POSTGRES_DB`, `POSTGRES_USER`, `POSTGRES_PASSWORD` |

### Redis
| Property | Value |
|----------|-------|
| Image | `redis:7-alpine` |
| Port | 6379 |
| Volume | None (ephemeral) |
| Health check | `redis-cli ping` |
| Auth | None (local dev) |

### Kafka (KRaft)
| Property | Value |
|----------|-------|
| Image | `apache/kafka:latest` |
| Port | 9092 (internal), 9094 (external) |
| Volume | None (ephemeral) |
| Health check | `kafka-broker-api-versions --bootstrap-server localhost:9092` |
| Mode | KRaft (no Zookeeper) |

### App Service
| Property | Value |
|----------|-------|
| Build | Multi-stage Dockerfile |
| Port | 8080 |
| Depends on | postgres (healthy), redis (healthy), kafka (healthy) |
| Health check | `curl -f http://localhost:8080/actuator/health` |

## Docker Network

| Property | Value |
|----------|-------|
| Name | `microservice-net` |
| Driver | bridge |
| Services | app, postgres, redis, kafka |

## Named Volumes

| Volume | Service | Mount Path |
|--------|---------|------------|
| `pgdata` | postgres | `/var/lib/postgresql/data` |
