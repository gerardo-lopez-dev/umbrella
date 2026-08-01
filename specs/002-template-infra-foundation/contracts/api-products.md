# REST API: Products

Base path: `/api/v1/products`

## Create Product

```
POST /api/v1/products
Content-Type: application/json
```

### Request

```json
{
  "name": "Laptop",
  "description": "16GB RAM, 512GB SSD",
  "price": 1299.99,
  "currency": "USD"
}
```

### Response (201 Created)

```json
{
  "id": "a1b2c3d4-...",
  "name": "Laptop",
  "description": "16GB RAM, 512GB SSD",
  "price": 1299.99,
  "currency": "USD",
  "status": "ACTIVE"
}
```

### Validation

| Field | Rule |
|-------|------|
| name | Required, not blank |
| price | Optional (nullable), >= 0 |
| currency | Required, valid ISO 4217 |

### Errors

| Status | Case |
|--------|------|
| 400 | Validation failure (invalid/missing fields) |
| 500 | Server error |

## Health

```
GET /actuator/health
```

### Response (200 OK)

```json
{
  "status": "UP",
  "components": {
    "db": { "status": "UP" },
    "diskSpace": { "status": "UP" },
    "ping": { "status": "UP" }
  }
}
```
