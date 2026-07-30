# Data Model: Template Base Example

## Entity: Product

### Domain Entity (`Product`)

| Field | Type | Constraints |
|-------|------|-------------|
| id | `UUID` | Primary key, assigned on creation |
| name | `String` | Required, not blank |
| description | `String` | Optional |
| price | `Money` (Value Object) | Required, non-negative |
| status | `String` | Required, default "ACTIVE" |

### Value Object: Money

| Field | Type | Constraints |
|-------|------|-------------|
| amount | `BigDecimal` | Non-negative |
| currency | `Currency` (java.util) | Required, ISO 4217 code |

### JPA Entity (`ProductJpaEntity`)

| Column | Type | DB Constraints |
|--------|------|----------------|
| id | `UUID` | PK |
| name | `VARCHAR(255)` | NOT NULL |
| description | `TEXT` | — |
| price | `NUMERIC(10,2)` | NOT NULL |
| currency | `VARCHAR(3)` | NOT NULL |
| status | `VARCHAR(50)` | NOT NULL |

### Flyway Schema (V1)

```sql
CREATE TABLE products (
    id          UUID         PRIMARY KEY,
    name        VARCHAR(255) NOT NULL,
    description TEXT,
    price       NUMERIC(10,2) NOT NULL,
    currency    VARCHAR(3)   NOT NULL,
    status      VARCHAR(50)  NOT NULL
);
```

## Entity Relationships

Single entity — no relationships in example. The pattern demonstrates:
- **Domain entity** (pure record) → **JPA entity** (annotated) → **Mapper** between them
- **Port interface** → **Use case implementation** → **Controller**

## State Transitions

Product status: `ACTIVE` → (no transitions defined in example — extensible via enum).
