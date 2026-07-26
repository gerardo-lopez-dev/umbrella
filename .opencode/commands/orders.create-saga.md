---
description: "Create a Saga with steps and compensating actions"
handoffs: ["hexagonal.add-test", "orders.add-state"]
---

# Create Saga (Orders)

You are creating an orchestrated Saga with steps, compensating actions, and timeout handling.

## Inputs

The user provides:
- **Saga name** (e.g., `OrderProcessingSaga`)
- **Steps** (e.g., `ReserveInventory → ProcessPayment → ConfirmOrder`)
- **Compensating actions** for each step (e.g., `ReleaseInventory ← RefundPayment ← CancelOrder`)
- **Timeouts** per step (e.g., 30s, 60s)
- **Package base** (e.g., `com.template.orders`)

## Instructions

1. **Load constitution** from `.specify/memory/constitution.md` — section VIII (Saga Rules) is authoritative.

### Step 1: Saga Step Enum

Create in `domain/model/saga/`:

```java
package {base}.domain.model.saga;

public enum {SagaName}Step {
    RESERVE_INVENTORY("Reserve inventory", "Release inventory"),
    PROCESS_PAYMENT("Process payment", "Refund payment"),
    CONFIRM_ORDER("Confirm order", "Cancel order"),
    SEND_NOTIFICATION("Send notification", "Revoke notification");

    private final String forwardAction;
    private final String compensatingAction;

    {SagaName}Step(String forwardAction, String compensatingAction) {
        this.forwardAction = forwardAction;
        this.compensatingAction = compensatingAction;
    }

    public String getForwardAction() { return forwardAction; }
    public String getCompensatingAction() { return compensatingAction; }
}
```

### Step 2: Saga State

Create in `domain/model/saga/`:

```java
package {base}.domain.model.saga;

import java.time.Instant;
import java.util.UUID;

public record SagaInstance(
    UUID sagaId,
    UUID aggregateId,
    {SagaName}Step currentStep,
    SagaStatus status,
    Instant startedAt,
    Instant updatedAt,
    String errorMessage
) {
    public enum SagaStatus {
        STARTED, IN_PROGRESS, COMPENSATING, COMPLETED, FAILED
    }

    public static SagaInstance create(UUID aggregateId) {
        return new SagaInstance(
            UUID.randomUUID(),
            aggregateId,
            {SagaName}Step.values()[0],
            SagaStatus.STARTED,
            Instant.now(),
            Instant.now(),
            null
        );
    }

    public SagaInstance advance() {
        int nextOrdinal = currentStep.ordinal() + 1;
        if (nextOrdinal >= {SagaName}Step.values().length) {
            return new SagaInstance(sagaId, aggregateId, currentStep, SagaStatus.COMPLETED, startedAt, Instant.now(), null);
        }
        return new SagaInstance(sagaId, aggregateId, {SagaName}Step.values()[nextOrdinal], SagaStatus.IN_PROGRESS, startedAt, Instant.now(), null);
    }

    public SagaInstance compensate(String error) {
        return new SagaInstance(sagaId, aggregateId, currentStep, SagaStatus.COMPENSATING, startedAt, Instant.now(), error);
    }

    public SagaInstance fail(String error) {
        return new SagaInstance(sagaId, aggregateId, currentStep, SagaStatus.FAILED, startedAt, Instant.now(), error);
    }
}
```

### Step 3: Saga Instance Repository (Outbound Port)

Create in `domain/port/outbound/`:

```java
package {base}.domain.port.outbound;

import {base}.domain.model.saga.SagaInstance;
import java.util.Optional;
import java.util.UUID;

public interface SagaRepository {
    SagaInstance save(SagaInstance saga);
    Optional<SagaInstance> findById(UUID sagaId);
    Optional<SagaInstance> findByAggregateId(UUID aggregateId);
}
```

### Step 4: Saga Orchestrator

Create in `domain/service/impl/`:

```java
package {base}.domain.service.impl;

import {base}.domain.model.saga.*;
import {base}.domain.port.outbound.*;
import {base}.domain.port.inbound.*;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.UUID;

@Service
public class {SagaName}Orchestrator {

    private static final Logger log = LoggerFactory.getLogger({SagaName}Orchestrator.class);

    private final SagaRepository sagaRepository;
    private final {Step1Port} step1Port;
    private final {Step2Port} step2Port;
    private final {Step3Port} step3Port;

    // Constructor injection...

    @Transactional
    public SagaInstance startSaga(UUID aggregateId) {
        SagaInstance saga = SagaInstance.create(aggregateId);
        saga = sagaRepository.save(saga);
        log.info("Saga {} started for aggregate {}", saga.sagaId(), aggregateId);
        return executeStep(saga);
    }

    @Transactional
    public SagaInstance executeStep(SagaInstance saga) {
        try {
            // Check timeout
            if (isTimedOut(saga)) {
                return handleTimeout(saga);
            }

            switch (saga.currentStep()) {
                case RESERVE_INVENTORY -> {
                    step1Port.execute(saga.aggregateId());
                    return advanceAndContinue(saga);
                }
                case PROCESS_PAYMENT -> {
                    step2Port.execute(saga.aggregateId());
                    return advanceAndContinue(saga);
                }
                case CONFIRM_ORDER -> {
                    step3Port.execute(saga.aggregateId());
                    SagaInstance completed = saga.advance();
                    return sagaRepository.save(completed);
                }
                case SEND_NOTIFICATION -> {
                    // Optional step
                    return advanceAndContinue(saga);
                }
            }
        } catch (Exception e) {
            log.error("Saga {} failed at step {}: {}", saga.sagaId(), saga.currentStep(), e.getMessage());
            return startCompensation(saga, e.getMessage());
        }
        return saga;
    }

    private SagaInstance advanceAndContinue(SagaInstance saga) {
        SagaInstance advanced = saga.advance();
        advanced = sagaRepository.save(advanced);
        return executeStep(advanced);
    }

    @Transactional
    public SagaInstance startCompensation(SagaInstance saga, String error) {
        SagaInstance compensating = saga.compensate(error);
        compensating = sagaRepository.save(compensating);
        log.info("Saga {} starting compensation from step {}", compensating.sagaId(), compensating.currentStep());
        return executeCompensation(compensating);
    }

    @Transactional
    public SagaInstance executeCompensation(SagaInstance saga) {
        try {
            switch (saga.currentStep()) {
                case CONFIRM_ORDER -> {
                    step3Port.compensate(saga.aggregateId());
                    return compensateAndContinue(saga);
                }
                case PROCESS_PAYMENT -> {
                    step2Port.compensate(saga.aggregateId());
                    return compensateAndContinue(saga);
                }
                case RESERVE_INVENTORY -> {
                    step1Port.compensate(saga.aggregateId());
                    SagaInstance failed = saga.fail(saga.errorMessage());
                    return sagaRepository.save(failed);
                }
                default -> {
                    return saga.fail(saga.errorMessage());
                }
            }
        } catch (Exception e) {
            log.error("Compensation failed for saga {} at step {}: {}", saga.sagaId(), saga.currentStep(), e.getMessage());
            SagaInstance failed = saga.fail("Compensation failed: " + e.getMessage());
            return sagaRepository.save(failed);
        }
    }

    private SagaInstance compensateAndContinue(SagaInstance saga) {
        int prevOrdinal = saga.currentStep().ordinal() - 1;
        if (prevOrdinal < 0) {
            return saga.fail(saga.errorMessage());
        }
        SagaInstance compensating = new SagaInstance(
            saga.sagaId(), saga.aggregateId(),
            {SagaName}Step.values()[prevOrdinal],
            SagaStatus.COMPENSATING,
            saga.startedAt(), Instant.now(), saga.errorMessage()
        );
        compensating = sagaRepository.save(compensating);
        return executeCompensation(compensating);
    }

    private boolean isTimedOut(SagaInstance saga) {
        long minutesElapsed = ChronoUnit.MINUTES.between(saga.updatedAt(), Instant.now());
        return minutesElapsed > 30; // configurable timeout
    }

    private SagaInstance handleTimeout(SagaInstance saga) {
        log.warn("Saga {} timed out at step {}", saga.sagaId(), saga.currentStep());
        return startCompensation(saga, "Saga timed out");
    }
}
```

### Step 5: Step Ports (with compensation)

Create in `domain/port/inbound/`:

```java
package {base}.domain.port.inbound;

import java.util.UUID;

public interface {StepName}Port {
    void execute(UUID aggregateId);
    void compensate(UUID aggregateId);
}
```

### Step 6: Step Implementations

Example for inventory step:

```java
package {base}.domain.service.impl;

import {base}.domain.port.inbound.ReserveInventoryPort;
import org.springframework.stereotype.Service;
import java.util.UUID;

@Service
public class ReserveInventoryStep implements ReserveInventoryPort {

    private final InventoryGateway inventoryGateway;

    public ReserveInventoryStep(InventoryGateway inventoryGateway) {
        this.inventoryGateway = inventoryGateway;
    }

    @Override
    public void execute(UUID orderId) {
        // Call inventory service to reserve stock
        inventoryGateway.reserve(orderId);
    }

    @Override
    public void compensate(UUID orderId) {
        // Release reserved stock
        inventoryGateway.release(orderId);
    }
}
```

### Step 7: Saga State Repository (JPA)

Create in `infrastructure/adapter/outbound/persistence/`:

```java
package {base}.infrastructure.adapter.outbound.persistence;

import {base}.domain.model.saga.SagaInstance;
import jakarta.persistence.*;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "saga_instances")
public class SagaInstanceJpaEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID sagaId;

    @Column(nullable = false)
    private UUID aggregateId;

    @Column(nullable = false)
    private String currentStep;

    @Column(nullable = false)
    private String status;

    @Column(nullable = false)
    private Instant startedAt;

    @Column(nullable = false)
    private Instant updatedAt;

    @Column(columnDefinition = "TEXT")
    private String errorMessage;
}
```

### Step 8: Flyway Migration

```sql
-- V{N}__create_saga_instances.sql
CREATE TABLE saga_instances (
    saga_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    aggregate_id UUID NOT NULL,
    current_step VARCHAR(100) NOT NULL,
    status VARCHAR(50) NOT NULL,
    started_at TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL,
    error_message TEXT,
    CONSTRAINT fk_saga_aggregate FOREIGN KEY (aggregate_id) REFERENCES orders(id)
);

CREATE INDEX idx_saga_instances_aggregate ON saga_instances(aggregate_id);
CREATE INDEX idx_saga_instances_status ON saga_instances(status);
```

### Step 9: Tests

Create in `src/test/java/{packagePath}/domain/service/impl/`:

```java
package {base}.domain.service.impl;

import {base}.domain.model.saga.*;
import {base}.domain.port.outbound.*;
import {base}.domain.port.inbound.*;
import org.junit.jupiter.api.*;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.*;
import org.mockito.junit.jupiter.MockitoExtension;
import static org.assertj.core.api.Assertions.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class {SagaName}OrchestratorTest {

    @Mock private SagaRepository sagaRepository;
    @Mock private {Step1Port} step1Port;
    @Mock private {Step2Port} step2Port;
    @Mock private {Step3Port} step3Port;

    @InjectMocks
    private {SagaName}Orchestrator orchestrator;

    @Test
    @DisplayName("should complete saga when all steps succeed")
    void shouldCompleteSaga() {
        // Arrange
        var aggregateId = UUID.randomUUID();
        var saga = SagaInstance.create(aggregateId);
        when(sagaRepository.save(any())).thenReturn(saga, saga.advance(), saga.advance().advance());

        // Act
        var result = orchestrator.startSaga(aggregateId);

        // Assert
        verify(step1Port).execute(aggregateId);
        verify(step2Port).execute(aggregateId);
        verify(step3Port).execute(aggregateId);
    }

    @Test
    @DisplayName("should compensate when step fails")
    void shouldCompensateOnFailure() {
        // Arrange
        var aggregateId = UUID.randomUUID();
        var saga = SagaInstance.create(aggregateId);
        when(sagaRepository.save(any())).thenReturn(saga, saga.advance());
        doThrow(new RuntimeException("Payment failed")).when(step2Port).execute(any());

        // Act
        var result = orchestrator.startSaga(aggregateId);

        // Assert
        verify(step1Port).compensate(aggregateId);
    }
}
```

## Output

Print:
- All files created with paths
- The saga flow diagram
- Compensating actions for each step
- Timeout configuration

## Rules (from Constitution)

- Every forward action MUST have a compensating action.
- Saga state MUST be persisted in a dedicated table.
- Steps MUST be idempotent.
- Timeouts MUST be configurable.
- Compensation MUST be triggered automatically on failure.
- Saga failures MUST be logged and monitorable.
