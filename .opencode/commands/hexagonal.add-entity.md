---
description: "Add a new domain entity with all hexagonal layers"
handoffs: ["hexagonal.add-usecase", "hexagonal.add-test"]
---

# Add Hexagonal Entity

You are adding a new domain entity following hexagonal architecture.

## Inputs

The user provides:
- **Entity name** (e.g., `Order`, `Product`, `Payment`)
- **Attributes** with types (e.g., `id: UUID, name: String, price: Money, status: OrderStatus`)
- **Value objects** needed (e.g., `Money`, `Address`, `OrderStatus`)
- **Package base** (e.g., `com.template.orders`)

## Instructions

1. **Load constitution** from `.specify/memory/constitution.md` — sections V (Hexagonal Architecture) and VII (Domain Events) apply.

2. **Detect existing project structure** — look for existing entities to follow the same patterns.

### Step 1: Value Objects

Create immutable value objects in `domain/model/valueobject/`:

```java
package {base}.domain.model.valueobject;

import java.util.Objects;

public record Money(String currency, java.math.BigDecimal amount) {
    public Money {
        Objects.requireNonNull(currency, "Currency must not be null");
        Objects.requireNonNull(amount, "Amount must not be null");
        if (amount.compareTo(java.math.BigDecimal.ZERO) < 0) {
            throw new IllegalArgumentException("Amount must not be negative");
        }
    }

    public Money add(Money other) {
        if (!this.currency.equals(other.currency)) {
            throw new IllegalArgumentException("Cannot add different currencies");
        }
        return new Money(currency, this.amount.add(other.amount));
    }

    public static Money of(String currency, String amount) {
        return new Money(currency, new java.math.BigDecimal(amount));
    }
}
```

Create status enum if needed:

```java
package {base}.domain.model.valueobject;

public enum {Entity}Status {
    CREATED, ACTIVE, CANCELLED, COMPLETED
    // Add domain-specific transitions
}
```

### Step 2: Domain Entity

Create in `domain/model/entity/`:

```java
package {base}.domain.model.entity;

import {base}.domain.model.valueobject.*;
import java.time.Instant;
import java.util.Objects;
import java.util.UUID;

public class {Entity} {
    private final UUID id;
    private {attributes...}
    private final Instant createdAt;
    private Instant updatedAt;

    // Private constructor — use factory method or builder
    private {Entity}(UUID id, {params...}) {
        this.id = Objects.requireNonNull(id);
        // assign fields
        this.createdAt = Instant.now();
        this.updatedAt = Instant.now();
    }

    // Factory method
    public static {Entity} create({params without id, createdAt, updatedAt...}) {
        return new {Entity}(UUID.randomUUID(), {params...});
    }

    // Getters (no setters for immutability where feasible)
    public UUID getId() { return id; }
    // ... other getters

    // Domain methods (business logic)
    // e.g., public void cancel() { this.status = CANCELLED; }

    @Override
    public boolean equals(Object o) {
        if (this == o) return true;
        if (!(o instanceof {Entity} other)) return false;
        return Objects.equals(id, other.id);
    }

    @Override
    public int hashCode() {
        return Objects.hash(id);
    }
}
```

**CRITICAL**: NO JPA annotations (`@Entity`, `@Column`, `@Table`). Domain entities are pure Java.

### Step 3: JPA Entity (Infrastructure)

Create in `infrastructure/adapter/outbound/persistence/`:

```java
package {base}.infrastructure.adapter.outbound.persistence;

import jakarta.persistence.*;
import java.util.UUID;

@Entity
@Table(name = "{snake_case_entity_name}")
public class {Entity}JpaEntity {
    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    // Map all attributes with @Column annotations

    // Getters and setters for JPA
}
```

### Step 4: Mapper

Create in `application/mapper/`:

```java
package {base}.application.mapper;

import {base}.domain.model.entity.{Entity};
import {base}.infrastructure.adapter.outbound.persistence.{Entity}JpaEntity;
import org.mapstruct.Mapper;

@Mapper(componentModel = "spring")
public interface {Entity}Mapper {
    {Entity} toDomain({Entity}JpaEntity jpaEntity);
    {Entity}JpaEntity toJpa({Entity} domainEntity);
}
```

### Step 5: Flyway Migration

Create in `src/main/resources/db/migration/`:

```sql
-- V{N}__create_{snake_case_table}.sql
CREATE TABLE {snake_case_table} (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    {columns...},
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_{table}_{column} ON {snake_case_table}({column});
```

## Output

Print:
- All files created with their paths
- The directory structure
- A reminder to create use cases and endpoints via `hexagonal.add-usecase`

## Rules (from Constitution)

- Domain entity: NO Spring, NO JPA annotations. Pure POJO.
- JPA entity: SEPARATE class in infrastructure adapter package.
- Mapper: MUST use MapStruct (`@Mapper`).
- Value objects: MUST be immutable (records preferred).
- Database table: MUST use snake_case naming.
