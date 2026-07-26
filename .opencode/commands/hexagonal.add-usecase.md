---
description: "Add a use case with port, implementation, and REST endpoint"
handoffs: ["hexagonal.add-entity", "hexagonal.add-test"]
---

# Add Use Case (Hexagonal)

You are adding a new use case following hexagonal architecture.

## Inputs

The user provides:
- **Use case name** (e.g., `CreateOrder`, `ProcessPayment`, `GetUserProfile`)
- **HTTP method and path** (e.g., `POST /api/v1/orders`)
- **Input DTO fields** (e.g., `userId: UUID, items: List<OrderItemRequest>`)
- **Output DTO fields** (e.g., `orderId: UUID, status: String, total: Money`)
- **Package base** (e.g., `com.template.orders`)

## Instructions

1. **Load constitution** from `.specify/memory/constitution.md`.

2. **Detect existing patterns** — look for existing use cases, ports, controllers to follow conventions.

### Step 1: Inbound Port (Domain Layer)

Create in `domain/port/inbound/`:

```java
package {base}.domain.port.inbound;

import {base}.application.dto.request.{UseCaseName}Request;
import {base}.application.dto.response.{UseCaseName}Response;

public interface {UseCaseName}UseCase {
    {UseCaseName}Response execute({UseCaseName}Request request);
}
```

**Note**: The port lives in domain but references DTOs from application. This is acceptable — DTOs are the contract boundary. If strict separation is needed, the port can accept domain parameters and the use case adapter maps DTOs.

### Step 2: Use Case Implementation (Application Layer)

Create in `application/usecase/`:

```java
package {base}.application.usecase;

import {base}.domain.port.inbound.{UseCaseName}UseCase;
import {base}.domain.port.outbound.*;
import {base}.application.dto.request.{UseCaseName}Request;
import {base}.application.dto.response.{UseCaseName}Response;
import {base}.application.mapper.*;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class {UseCaseName}UseCaseImpl implements {UseCaseName}UseCase {

    private final {OutboundPort1} port1;
    private final {OutboundPort2} port2;
    private final {Entity}Mapper mapper;

    public {UseCaseName}UseCaseImpl(
            {OutboundPort1} port1,
            {OutboundPort2} port2,
            {Entity}Mapper mapper) {
        this.port1 = port1;
        this.port2 = port2;
        this.mapper = mapper;
    }

    @Override
    @Transactional
    public {UseCaseName}Response execute({UseCaseName}Request request) {
        // 1. Map request to domain objects
        // 2. Execute business logic
        // 3. Persist via outbound port
        // 4. Map domain object to response DTO
        // 5. Return response
    }
}
```

**CRITICAL**: Business logic lives HERE, not in the controller. The use case orchestrates domain objects and outbound ports.

### Step 3: Request/Response DTOs

Create in `application/dto/request/`:

```java
package {base}.application.dto.request;

import jakarta.validation.constraints.*;
import java.util.List;

public record {UseCaseName}Request(
    @NotNull UUID userId,
    @NotEmpty List<ItemRequest> items
) {
    public record ItemRequest(
        @NotNull UUID productId,
        @Min(1) int quantity
    ) {}
}
```

Create in `application/dto/response/`:

```java
package {base}.application.dto.response;

import java.util.UUID;

public record {UseCaseName}Response(
    UUID id,
    String status,
    // ... other fields
) {}
```

### Step 4: Outbound Port (if needed)

Create in `domain/port/outbound/`:

```java
package {base}.domain.port.outbound;

import {base}.domain.model.entity.{Entity};
import java.util.Optional;
import java.util.UUID;

public interface {Entity}Repository {
    {Entity} save({Entity} entity);
    Optional<{Entity}> findById(UUID id);
    // ... other methods
}
```

### Step 5: REST Adapter (Infrastructure Layer)

Create in `infrastructure/adapter/inbound/rest/`:

```java
package {base}.infrastructure.adapter.inbound.rest;

import {base}.domain.port.inbound.{UseCaseName}UseCase;
import {base}.application.dto.request.{UseCaseName}Request;
import {base}.application.dto.response.{UseCaseName}Response;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/{resources}")
@Tag(name = "{Entity}", description = "{Description}")
public class {Entity}Controller {

    private final {UseCaseName}UseCase useCase;

    public {Entity}Controller({UseCaseName}UseCase useCase) {
        this.useCase = useCase;
    }

    @PostMapping
    @Operation(summary = "{Description}")
    public ResponseEntity<{UseCaseName}Response> create(
            @Valid @RequestBody {UseCaseName}Request request) {
        {UseCaseName}Response response = useCase.execute(request);
        return ResponseEntity.status(HttpStatus.CREATED).body(response);
    }
}
```

### Step 6: Global Exception Handler (if not exists)

Create in `infrastructure/config/`:

```java
package {base}.infrastructure.config;

import org.springframework.http.*;
import org.springframework.web.bind.annotation.*;
import java.time.Instant;
import java.util.Map;

@RestControllerAdvice
public class GlobalExceptionHandler {

    @ExceptionHandler(Exception.class)
    public ResponseEntity<Map<String, Object>> handleGeneral(Exception ex) {
        return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(Map.of(
            "timestamp", Instant.now().toString(),
            "status", 500,
            "error", "Internal Server Error",
            "message", ex.getMessage()
        ));
    }

    @ExceptionHandler(IllegalArgumentException.class)
    public ResponseEntity<Map<String, Object>> handleIllegalArgument(IllegalArgumentException ex) {
        return ResponseEntity.badRequest().body(Map.of(
            "timestamp", Instant.now().toString(),
            "status", 400,
            "error", "Bad Request",
            "message", ex.getMessage()
        ));
    }
}
```

## Output

Print:
- All files created with paths
- The dependency flow: Controller → UseCase → OutboundPort → RepositoryAdapter
- Reminder to create tests via `hexagonal.add-test`

## Rules (from Constitution)

- Controllers MUST NOT contain business logic — delegate to use cases.
- Use cases MUST be annotated with `@Transactional` for write operations.
- Request DTOs MUST use Bean Validation annotations.
- Endpoints MUST follow REST conventions (POST → 201, GET → 200, etc.).
- API versioning via URI path: `/api/v1/...`.
