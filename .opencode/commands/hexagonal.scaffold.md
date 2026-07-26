---
description: "Scaffold hexagonal architecture structure for a new microservice"
handoffs: ["hexagonal.add-entity", "hexagonal.add-usecase"]
---

# Hexagonal Scaffold

You are scaffolding a new microservice with hexagonal architecture.

## Inputs

The user provides:
- **Domain name** (e.g., `orders`, `users`, `payments`)
- **Port number** (e.g., `8085`)
- **Base package** (default: `com.template.{domain}`)

## Instructions

1. **Load the project constitution** from `.specify/memory/constitution.md` — sections V (Hexagonal Architecture), VI (Microservice Conventions), and IX (Testing by Layer) are authoritative.

2. **Create the directory structure** under `src/main/java/{basePackagePath}/`:

```
{domain}/
├── domain/
│   ├── model/
│   │   ├── entity/
│   │   ├── valueobject/
│   │   └── event/
│   ├── port/
│   │   ├── inbound/
│   │   └── outbound/
│   └── service/
│       └── impl/
├── application/
│   ├── usecase/
│   ├── dto/
│   │   ├── request/
│   │   └── response/
│   └── mapper/
└── infrastructure/
    ├── config/
    ├── adapter/
    │   ├── inbound/
    │   │   ├── rest/
    │   │   └── messaging/
    │   └── outbound/
    │       ├── persistence/
    │       ├── messaging/
    │       └── external/
    └── {Domain}Application.java
```

3. **Create test structure** under `src/test/java/{basePackagePath}/`:

```
{domain}/
├── domain/
│   └── service/
├── application/
│   └── usecase/
└── infrastructure/
    ├── adapter/
    └── config/
```

4. **Create the main application class** in `infrastructure/`:

```java
package {basePackage}.infrastructure;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

@SpringBootApplication
public class {Domain}Application {
    public static void main(String[] args) {
        SpringApplication.run({Domain}Application.class, args);
    }
}
```

5. **Create resource directories**:
- `src/main/resources/db/migration/` — for Flyway migrations
- `src/main/resources/application.yaml` — base configuration
- `src/main/resources/application-local.yaml` — local profile (H2)
- `src/main/resources/application-dev.yaml` — dev profile (PostgreSQL)
- `src/main/resources/application-prod.yaml` — production profile

6. **Update `application.yaml`**:

```yaml
spring:
  application:
    name: {domain}-service
  profiles:
    active: local

server:
  port: ${SERVER_PORT:{port}}

management:
  endpoints:
    web:
      exposure:
        include: health,info
  endpoint:
    health:
      show-details: when-authorized
```

7. **Update `docker-compose.yaml`** — add the new service:

```yaml
  {domain}-service:
    build: .
    ports:
      - "{port}:{port}"
    environment:
      SPRING_PROFILES_ACTIVE: dev
      DB_URL: jdbc:postgresql://postgres:5432/{domain}_db
      DB_USERNAME: postgres
      DB_PASSWORD: postgres
      SERVER_PORT: "{port}"
    depends_on:
      postgres:
        condition: service_healthy
    restart: unless-stopped
```

8. **Output**: Print the created structure and list all files generated.

## Rules (from Constitution)

- Domain layer MUST NOT import Spring or framework packages.
- Ports MUST be Java interfaces, not abstract classes.
- Entities MUST be pure POJOs (no JPA annotations).
- The application class MUST live in `infrastructure/`, NOT in the domain root.
