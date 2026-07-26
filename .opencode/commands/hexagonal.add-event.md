---
description: "Add a domain event with outbox producer and consumer"
handoffs: ["hexagonal.add-entity", "hexagonal.add-test"]
---

# Add Domain Event

You are adding a domain event with Transactional Outbox publishing and event consumer.

## Inputs

The user provides:
- **Event name** (e.g., `OrderCreatedEvent`, `PaymentCompletedEvent`)
- **Aggregate** (e.g., `Order`, `Payment`)
- **Event data fields** (e.g., `orderId: UUID, userId: UUID, total: Money`)
- **Consumer service** (optional — which microservice consumes this event)
- **Package base** (e.g., `com.template.orders`)

## Instructions

1. **Load constitution** from `.specify/memory/constitution.md` — section VII (Domain Events) is authoritative.

### Step 1: Event Record (Domain Layer)

Create in `domain/model/event/`:

```java
package {base}.domain.model.event;

import java.time.Instant;
import java.util.UUID;

public record {EventName}(
    UUID eventId,
    UUID aggregateId,
    Instant occurredAt,
    // Event-specific fields
    UUID userId,
    String data
) {
    public {EventName} {
        // Compact constructor for auto-generated fields
    }

    // Factory method with defaults
    public static {EventName} of(UUID aggregateId, UUID userId, String data) {
        return new {EventName}(
            UUID.randomUUID(),
            aggregateId,
            Instant.now(),
            userId,
            data
        );
    }
}
```

**Rules**:
- Events MUST be `record` types (immutable).
- MUST include `eventId` (UUID) and `occurredAt` (Instant).
- MUST include `aggregateId` (the entity that originated the event).
- Naming: `{Entity}{PastVerb}Event` (e.g., `OrderCreatedEvent`).

### Step 2: Outbox Entity (Infrastructure Layer)

Create in `infrastructure/adapter/outbound/messaging/`:

```java
package {base}.infrastructure.adapter.outbound.messaging;

import jakarta.persistence.*;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "outbox_events")
public class OutboxEventEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(nullable = false)
    private String aggregateType;

    @Column(nullable = false)
    private UUID aggregateId;

    @Column(nullable = false)
    private String eventType;

    @Column(nullable = false, columnDefinition = "TEXT")
    private String payload;

    @Column(nullable = false)
    private Instant occurredAt;

    @Column(nullable = false)
    private boolean published;

    // Getters and setters
}
```

### Step 3: Outbox Repository (Infrastructure Layer)

```java
package {base}.infrastructure.adapter.outbound.messaging;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;
import java.util.List;
import java.util.UUID;

@Repository
public interface OutboxEventRepository extends JpaRepository<OutboxEventEntity, UUID> {

    List<OutboxEventEntity> findByPublishedFalseOrderByOccurredAtAsc();

    @Modifying
    @Query("UPDATE OutboxEventEntity e SET e.published = true WHERE e.id IN :ids")
    void markAsPublished(List<UUID> ids);
}
```

### Step 4: Outbox Publisher (Infrastructure Layer)

Create in `infrastructure/adapter/outbound/messaging/`:

```java
package {base}.infrastructure.adapter.outbound.messaging;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;
import java.util.List;
import java.util.UUID;

@Component
public class OutboxEventPublisher {

    private static final Logger log = LoggerFactory.getLogger(OutboxEventPublisher.class);

    private final OutboxEventRepository outboxRepository;
    private final KafkaTemplate<String, String> kafkaTemplate;
    private final ObjectMapper objectMapper;

    public OutboxEventPublisher(
            OutboxEventRepository outboxRepository,
            KafkaTemplate<String, String> kafkaTemplate,
            ObjectMapper objectMapper) {
        this.outboxRepository = outboxRepository;
        this.kafkaTemplate = kafkaTemplate;
        this.objectMapper = objectMapper;
    }

    @Scheduled(fixedDelayString = "${outbox.poll-interval:5000}")
    @Transactional
    public void publishPendingEvents() {
        List<OutboxEventEntity> pending = outboxRepository.findByPublishedFalseOrderByOccurredAtAsc();
        if (pending.isEmpty()) return;

        List<UUID> publishedIds = new java.util.ArrayList<>();

        for (OutboxEventEntity event : pending) {
            try {
                String payload = objectMapper.writeValueAsString(event);
                kafkaTemplate.send(event.getEventType(), event.getAggregateId().toString(), payload);
                publishedIds.add(event.getId());
                log.info("Published event: {} for aggregate: {}", event.getEventType(), event.getAggregateId());
            } catch (Exception e) {
                log.error("Failed to publish event: {}", event.getId(), e);
            }
        }

        if (!publishedIds.isEmpty()) {
            outboxRepository.markAsPublished(publishedIds);
        }
    }
}
```

### Step 5: Outbound Port for Event Publishing (Domain Layer)

Create in `domain/port/outbound/`:

```java
package {base}.domain.port.outbound;

import {base}.domain.model.event.*;
import java.util.UUID;

public interface EventPublisher {
    void publish(Object event);
}
```

### Step 6: Use Case Integration

In your use case, publish the event after the business operation:

```java
@Override
@Transactional
public {UseCaseName}Response execute({UseCaseName}Request request) {
    // 1. Business logic
    {Entity} entity = {Entity}.create(...);

    // 2. Persist (via outbound port)
    {Entity} saved = repository.save(entity);

    // 3. Create and publish event
    var event = {EventName}.of(saved.getId(), ...);
    eventPublisher.publish(event);

    // 4. Return response
    return mapper.toResponse(saved);
}
```

**IMPORTANT**: The event is written to the outbox table in the SAME transaction as the business operation. The publisher polls and sends asynchronously — guaranteeing at-least-once delivery.

### Step 7: Consumer (if consuming from another service)

Create in `infrastructure/adapter/inbound/messaging/`:

```java
package {base}.infrastructure.adapter.inbound.messaging;

import org.apache.kafka.clients.consumer.ConsumerRecord;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.kafka.annotation.KafkaListener;
import org.springframework.kafka.support.Acknowledgment;
import org.springframework.stereotype.Component;

@Component
public class {EventName}Consumer {

    private static final Logger log = LoggerFactory.getLogger({EventName}Consumer.class);

    private final {UseCaseName}UseCase useCase;

    public {EventName}Consumer({UseCaseName}UseCase useCase) {
        this.useCase = useCase;
    }

    @KafkaListener(
        topics = "${kafka.topics.{event-name}:{topic-name}}",
        groupId = "${spring.application.name}-consumer-group"
    )
    public void consume(ConsumerRecord<String, String> record, Acknowledgment ack) {
        try {
            log.info("Received event: {} for key: {}", record.topic(), record.key());
            // Parse event and execute use case
            {EventName} event = parseEvent(record.value());
            useCase.execute(event);
            ack.acknowledge();
        } catch (Exception e) {
            log.error("Failed to process event from topic: {}", record.topic(), e);
            // Let Kafka retry (will go to DLQ after max retries)
        }
    }
}
```

### Step 8: Flyway Migration for Outbox Table

Create in `src/main/resources/db/migration/`:

```sql
-- V{N}__create_outbox_events.sql
CREATE TABLE outbox_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    aggregate_type VARCHAR(255) NOT NULL,
    aggregate_id UUID NOT NULL,
    event_type VARCHAR(255) NOT NULL,
    payload TEXT NOT NULL,
    occurred_at TIMESTAMP WITH TIME ZONE NOT NULL,
    published BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE INDEX idx_outbox_events_published ON outbox_events(published, occurred_at);
```

## Output

Print:
- All files created with paths
- The flow: UseCase → Outbox (same tx) → Publisher (async poll) → Kafka → Consumer
- Configuration needed in `application.yaml` for Kafka topics

## Rules (from Constitution)

- Events MUST use the Transactional Outbox pattern — NEVER publish directly to Kafka from the use case.
- Events MUST be immutable records.
- Consumers MUST be idempotent.
- Failed events MUST go to DLQ after max retries.
- Event naming: `{Entity}{PastVerb}Event`.
