---
description: "Add CQRS with separate read and write models"
handoffs: ["hexagonal.add-test", "hexagonal.add-entity"]
---

# Add CQRS (Orders)

You are implementing Command Query Responsibility Segregation — separating the write model from the read model.

## Inputs

The user provides:
- **Aggregate** (e.g., `Order`)
- **Write model** (existing entity)
- **Read model** (e.g., `OrderSummaryReadModel` for list views, `OrderDetailReadModel` for detail views)
- **Query scenarios** (e.g., "list orders by user with pagination", "order summary with stats")
- **Package base** (e.g., `com.template.orders`)

## Instructions

1. **Load constitution** from `.specify/memory/constitution.md`.

2. **Detect existing write model** — the existing entity is the write model.

### Step 1: Read Model Entity

Create in `infrastructure/adapter/outbound/persistence/readmodel/`:

```java
package {base}.infrastructure.adapter.outbound.persistence.readmodel;

import jakarta.persistence.*;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "{snake_case_read_model}")
@Immutable // Hibernet @Immutable for read-only optimization
public class {ReadModel} {

    @Id
    private UUID id;

    // Denormalized fields optimized for queries
    private String status;
    private UUID userId;
    private String userName;
    private java.math.BigDecimal totalAmount;
    private String currency;
    private int itemCount;
    private Instant createdAt;

    // Getters only (immutable)
}
```

### Step 2: Read Model Repository

Create in `infrastructure/adapter/outbound/persistence/readmodel/`:

```java
package {base}.infrastructure.adapter.outbound.persistence.readmodel;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

@Repository
public interface {ReadModel}Repository extends JpaRepository<{ReadModel}, UUID> {

    Page<{ReadModel}> findByUserIdOrderByCreatedAtDesc(UUID userId, Pageable pageable);

    @Query("SELECT r FROM {ReadModel} r WHERE r.status = :status AND r.createdAt BETWEEN :from AND :to")
    Page<{ReadModel}> findByStatusAndDateRange(
        @Param("status") String status,
        @Param("from") Instant from,
        @Param("to") Instant to,
        Pageable pageable
    );

    @Query("SELECT COUNT(r) FROM {ReadModel} r WHERE r.userId = :userId AND r.status = 'COMPLETED'")
    long countCompletedByUserId(@Param("userId") UUID userId);
}
```

### Step 3: Write Model (Existing Entity) — Add Event Publishing

The existing write entity already publishes events via the outbox. No changes needed here.

### Step 4: Projector (Event → Read Model)

Create in `infrastructure/adapter/inbound/messaging/`:

```java
package {base}.infrastructure.adapter.inbound.messaging;

import {base}.infrastructure.adapter.outbound.persistence.readmodel.*;
import {base}.domain.model.event.*;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.kafka.annotation.KafkaListener;
import org.springframework.kafka.support.Acknowledgment;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

@Component
public class {ReadModel}Projector {

    private static final Logger log = LoggerFactory.getLogger({ReadModel}Projector.class);

    private final {ReadModel}Repository readModelRepository;

    public {ReadModel}Projector({ReadModel}Repository readModelRepository) {
        this.readModelRepository = readModelRepository;
    }

    @KafkaListener(
        topics = "${kafka.topics.order-events:order-events}",
        groupId = "{read-model}-projector"
    )
    @Transactional
    public void project(ConsumerRecord<String, String> record, Acknowledgment ack) {
        try {
            String eventType = parseEventType(record.value());
            UUID aggregateId = UUID.parse(record.key());

            switch (eventType) {
                case "OrderCreatedEvent" -> projectCreated(aggregateId, record.value());
                case "OrderPaidEvent" -> projectPaid(aggregateId);
                case "OrderShippedEvent" -> projectShipped(aggregateId);
                case "OrderCancelledEvent" -> projectCancelled(aggregateId);
            }

            ack.acknowledge();
        } catch (Exception e) {
            log.error("Failed to project event: {}", record.value(), e);
        }
    }

    private void projectCreated(UUID orderId, String eventPayload) {
        // Create or update read model from event data
        var readModel = new {ReadModel}();
        readModel.setId(orderId);
        readModel.setStatus("CREATED");
        readModel.setCreatedAt(Instant.now());
        // ... map other fields from event
        readModelRepository.save(readModel);
    }

    private void projectPaid(UUID orderId) {
        readModelRepository.findById(orderId).ifPresent(rm -> {
            rm.setStatus("PAID");
            readModelRepository.save(rm);
        });
    }

    private void projectShipped(UUID orderId) {
        readModelRepository.findById(orderId).ifPresent(rm -> {
            rm.setStatus("SHIPPED");
            readModelRepository.save(rm);
        });
    }

    private void projectCancelled(UUID orderId) {
        readModelRepository.findById(orderId).ifPresent(rm -> {
            rm.setStatus("CANCELLED");
            readModelRepository.save(rm);
        });
    }
}
```

### Step 5: Read Use Case (Query)

Create in `application/usecase/`:

```java
package {base}.application.usecase;

import {base}.domain.port.inbound.GetOrderSummaryUseCase;
import {base}.application.dto.response.OrderSummaryResponse;
import {base}.infrastructure.adapter.outbound.persistence.readmodel.*;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional(readOnly = true);

@Service
public class GetOrderSummaryUseCaseImpl implements GetOrderSummaryUseCase {

    private final {ReadModel}Repository readModelRepository;
    private final {ReadModel}Mapper mapper;

    public GetOrderSummaryUseCaseImpl({ReadModel}Repository readModelRepository, {ReadModel}Mapper mapper) {
        this.readModelRepository = readModelRepository;
        this.mapper = mapper;
    }

    @Override
    @Transactional(readOnly = true)
    public Page<OrderSummaryResponse> execute(UUID userId, Pageable pageable) {
        return readModelRepository.findByUserIdOrderByCreatedAtDesc(userId, pageable)
            .map(mapper::toSummaryResponse);
    }
}
```

### Step 6: Read Controller

Create in `infrastructure/adapter/inbound/rest/`:

```java
package {base}.infrastructure.adapter.inbound.rest;

import {base}.domain.port.inbound.GetOrderSummaryUseCase;
import {base}.application.dto.response.OrderSummaryResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/orders/summaries")
@Tag(name = "Order Summaries", description = "Read-optimized order queries")
public class OrderSummaryController {

    private final GetOrderSummaryUseCase useCase;

    public OrderSummaryController(GetOrderSummaryUseCase useCase) {
        this.useCase = useCase;
    }

    @GetMapping("/user/{userId}")
    @Operation(summary = "Get order summaries for a user")
    public ResponseEntity<Page<OrderSummaryResponse>> getUserSummaries(
            @PathVariable UUID userId,
            Pageable pageable) {
        return ResponseEntity.ok(useCase.execute(userId, pageable));
    }
}
```

### Step 7: Flyway Migration for Read Model

```sql
-- V{N}__create_{read_model_table}.sql
CREATE TABLE {read_model_table} (
    id UUID PRIMARY KEY,
    status VARCHAR(50) NOT NULL,
    user_id UUID NOT NULL,
    user_name VARCHAR(255),
    total_amount DECIMAL(19, 4),
    currency VARCHAR(3),
    item_count INT DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL
);

CREATE INDEX idx_{read_model_table}_user ON {read_model_table}(user_id, created_at DESC);
CREATE INDEX idx_{read_model_table}_status ON {read_model_table}(status);
```

### Step 8: Tests

```java
package {base}.application.usecase;

import {base}.infrastructure.adapter.outbound.persistence.readmodel.*;
import org.junit.jupiter.api.*;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.*;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.data.domain.PageRequest;
import static org.assertj.core.api.Assertions.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class GetOrderSummaryUseCaseImplTest {

    @Mock private {ReadModel}Repository readModelRepository;
    @Mock private {ReadModel}Mapper mapper;
    @InjectMocks private GetOrderSummaryUseCaseImpl useCase;

    @Test
    @DisplayName("should return paginated summaries for user")
    void shouldReturnPaginatedSummaries() {
        // Arrange
        var userId = UUID.randomUUID();
        var pageable = PageRequest.of(0, 10);
        var readModel = new {ReadModel}();
        readModel.setId(UUID.randomUUID());
        when(readModelRepository.findByUserIdOrderByCreatedAtDesc(userId, pageable))
            .thenReturn(new org.springframework.data.domain.PageImpl<>(List.of(readModel)));

        // Act
        var result = useCase.execute(userId, pageable);

        // Assert
        assertThat(result.getContent()).hasSize(1);
    }
}
```

## Output

Print:
- All files created with paths
- The CQRS flow: Write → Event → Projector → Read Model
- Which queries go to the read model vs the write model

## Rules (from Constitution)

- Read model MUST be updated via events (projector), NOT by the write use case directly.
- Read model queries MUST be `@Transactional(readOnly = true)`.
- Read model MUST be denormalized for query performance.
- Write model MUST NOT read from the read model (enforce separation).
- Projectors MUST be idempotent.
