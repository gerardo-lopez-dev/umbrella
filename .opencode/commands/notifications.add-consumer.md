---
description: "Add an event consumer for Kafka or RabbitMQ"
handoffs: ["hexagonal.add-test", "hexagonal.add-event"]
---

# Add Event Consumer (Notifications)

You are adding a consumer that listens to events from other microservices.

## Inputs

The user provides:
- **Event name** (e.g., `OrderPaidEvent`, `UserRegisteredEvent`)
- **Source service** (e.g., `orders-service`, `users-service`)
- **Consumer action** (e.g., "send confirmation email", "create welcome notification")
- **Broker type** (`kafka` or `rabbitmq`)
- **Package base** (e.g., `com.template.notifications`)

## Instructions

1. **Load constitution** from `.specify/memory/constitution.md` — section VII (Domain Events) applies.

### Step 1: Event DTO

Create in `application/dto/event/`:

```java
package {base}.application.dto.event;

import java.time.Instant;
import java.util.UUID;

public record {EventName}Dto(
    UUID eventId,
    UUID aggregateId,
    Instant occurredAt,
    // Event-specific fields
    UUID userId,
    String eventType
) {}
```

### Step 2: Use Case for Event Processing

Create in `application/usecase/`:

```java
package {base}.application.usecase;

import {base}.domain.port.inbound.{Action}UseCase;
import {base}.application.dto.event.{EventName}Dto;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class {Action}UseCaseImpl implements {Action}UseCase {

    private static final Logger log = LoggerFactory.getLogger({Action}UseCaseImpl.class);

    private final {OutboundPort1} port1;
    private final {OutboundPort2} port2;

    public {Action}UseCaseImpl({OutboundPort1} port1, {OutboundPort2} port2) {
        this.port1 = port1;
        this.port2 = port2;
    }

    @Override
    @Transactional
    public void execute({EventName}Dto event) {
        log.info("Processing {} for aggregate: {}", event.eventType(), event.aggregateId());

        // 1. Validate event
        // 2. Execute business logic
        // 3. Persist result
        // 4. Optionally publish downstream event

        log.info("Successfully processed {} for aggregate: {}", event.eventType(), event.aggregateId());
    }
}
```

### Step 3: Consumer (Kafka)

Create in `infrastructure/adapter/inbound/messaging/`:

```java
package {base}.infrastructure.adapter.inbound.messaging;

import {base}.application.dto.event.{EventName}Dto;
import {base}.application.usecase.{Action}UseCaseImpl;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.apache.kafka.clients.consumer.ConsumerRecord;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.kafka.annotation.KafkaListener;
import org.springframework.kafka.support.Acknowledgment;
import org.springframework.stereotype.Component;

@Component
public class {EventName}KafkaConsumer {

    private static final Logger log = LoggerFactory.getLogger({EventName}KafkaConsumer.class);

    private final {Action}UseCaseImpl useCase;
    private final ObjectMapper objectMapper;

    public {EventName}KafkaConsumer({Action}UseCaseImpl useCase, ObjectMapper objectMapper) {
        this.useCase = useCase;
        this.objectMapper = objectMapper;
    }

    @KafkaListener(
        topics = "${kafka.topics.order-events:order-events}",
        groupId = "${spring.application.name}-consumer",
        containerFactory = "kafkaListenerContainerFactory"
    )
    public void consume(ConsumerRecord<String, String> record, Acknowledgment ack) {
        try {
            log.info("Received event from topic: {}, partition: {}, offset: {}",
                record.topic(), record.partition(), record.offset());

            // Parse event type from value
            String value = record.value();
            String eventType = extractEventType(value);

            if (!"{EventName}".equals(eventType)) {
                log.debug("Skipping event type: {}", eventType);
                ack.acknowledge();
                return;
            }

            // Deserialize to event DTO
            {EventName}Dto event = objectMapper.readValue(value, {EventName}Dto.class);

            // Execute use case
            useCase.execute(event);

            // Acknowledge
            ack.acknowledge();
            log.info("Successfully processed event: {} for aggregate: {}", eventType, event.aggregateId());

        } catch (Exception e) {
            log.error("Failed to process event from topic: {}, offset: {}",
                record.topic(), record.offset(), e);
            // Don't acknowledge — Kafka will retry
            // After max retries, goes to DLQ
        }
    }

    private String extractEventType(String json) {
        try {
            var node = objectMapper.readTree(json);
            return node.has("eventType") ? node.get("eventType").asText() : "";
        } catch (Exception e) {
            return "";
        }
    }
}
```

### Step 4: Consumer (RabbitMQ)

Create in `infrastructure/adapter/inbound/messaging/`:

```java
package {base}.infrastructure.adapter.inbound.messaging;

import {base}.application.dto.event.{EventName}Dto;
import {base}.application.usecase.{Action}UseCaseImpl;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.amqp.rabbit.annotation.RabbitListener;
import org.springframework.amqp.support.AmqpHeaders;
import org.springframework.messaging.handler.annotation.Header;
import org.springframework.stereotype.Component;

@Component
public class {EventName}RabbitConsumer {

    private static final Logger log = LoggerFactory.getLogger({EventName}RabbitConsumer.class);

    private final {Action}UseCaseImpl useCase;
    private final ObjectMapper objectMapper;

    public {EventName}RabbitConsumer({Action}UseCaseImpl useCase, ObjectMapper objectMapper) {
        this.useCase = useCase;
        this.objectMapper = objectMapper;
    }

    @RabbitListener(
        queues = "${rabbitmq.queues.order-events:order-events-queue}",
        containerFactory = "rabbitListenerContainerFactory"
    )
    public void consume(String message, @Header(AmqpHeaders.MESSAGE_ID) String messageId) {
        try {
            log.info("Received message from queue, messageId: {}", messageId);

            {EventName}Dto event = objectMapper.readValue(message, {EventName}Dto.class);

            useCase.execute(event);

            log.info("Successfully processed event: {} for aggregate: {}", event.eventType(), event.aggregateId());

        } catch (Exception e) {
            log.error("Failed to process message messageId: {}", messageId, e);
            // Let RabbitMQ retry (will go to DLQ after max retries)
            throw e; // Re-throw to trigger retry
        }
    }
}
```

### Step 5: Kafka Configuration

Create in `infrastructure/config/`:

```java
package {base}.infrastructure.config;

import org.apache.kafka.clients.consumer.ConsumerConfig;
import org.apache.kafka.common.serialization.StringDeserializer;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.kafka.config.ConcurrentKafkaListenerContainerFactory;
import org.springframework.kafka.core.*;
import org.springframework.kafka.listener.*;
import org.springframework.util.backoff.FixedBackOff;
import java.util.HashMap;
import java.util.Map;

@Configuration
public class KafkaConsumerConfig {

    @Value("${spring.kafka.bootstrap-servers:localhost:9092}")
    private String bootstrapServers;

    @Value("${spring.kafka.consumer.group-id:default-group}")
    private String groupId;

    @Bean
    public ConsumerFactory<String, String> consumerFactory() {
        Map<String, Object> props = new HashMap<>();
        props.put(ConsumerConfig.BOOTSTRAP_SERVERS_CONFIG, bootstrapServers);
        props.put(ConsumerConfig.GROUP_ID_CONFIG, groupId);
        props.put(ConsumerConfig.KEY_DESERIALIZER_CLASS_CONFIG, StringDeserializer.class);
        props.put(ConsumerConfig.VALUE_DESERIALIZER_CLASS_CONFIG, StringDeserializer.class);
        props.put(ConsumerConfig.AUTO_OFFSET_RESET_CONFIG, "earliest");
        props.put(ConsumerConfig.ENABLE_AUTO_COMMIT_CONFIG, false);
        return new DefaultKafkaConsumerFactory<>(props);
    }

    @Bean
    public ConcurrentKafkaListenerContainerFactory<String, String> kafkaListenerContainerFactory() {
        ConcurrentKafkaListenerContainerFactory<String, String> factory =
            new ConcurrentKafkaListenerContainerFactory<>();
        factory.setConsumerFactory(consumerFactory());
        factory.getContainerProperties().setAckMode(ContainerProperties.AckMode.MANUAL_IMMEDIATE);
        factory.setCommonErrorHandler(defaultErrorHandler());
        return factory;
    }

    @Bean
    public DefaultErrorHandler defaultErrorHandler() {
        // Retry 3 times with 1 second delay, then go to DLQ
        return new DefaultErrorHandler(
            new DeadLetterPublishingRecoverer(kafkaTemplate()),
            new FixedBackOff(1000L, 3L)
        );
    }

    @Bean
    public KafkaTemplate<String, String> kafkaTemplate() {
        return new KafkaTemplate<>(new DefaultKafkaProducerFactory<>(new HashMap<>()));
    }
}
```

### Step 6: RabbitMQ Configuration (Alternative)

Create in `infrastructure/config/`:

```java
package {base}.infrastructure.config;

import org.springframework.amqp.core.*;
import org.springframework.amqp.rabbit.config.SimpleRabbitListenerContainerFactory;
import org.springframework.amqp.rabbit.connection.ConnectionFactory;
import org.springframework.amqp.rabbit.retry.RejectAndDontRequeueRecoverer;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.retry.backoff.FixedBackOffPolicy;
import org.springframework.retry.support.RetryTemplate;

@Configuration
public class RabbitMQConfig {

    public static final String ORDER_EVENTS_EXCHANGE = "order-events-exchange";
    public static final String ORDER_EVENTS_QUEUE = "order-events-queue";
    public static final String ORDER_EVENTS_ROUTING_KEY = "order.events";

    @Bean
    public TopicExchange orderEventsExchange() {
        return new TopicExchange(ORDER_EVENTS_EXCHANGE);
    }

    @Bean
    public Queue orderEventsQueue() {
        return QueueBuilder.durable(ORDER_EVENTS_QUEUE)
            .withArgument("x-dead-letter-exchange", "dlx-exchange")
            .withArgument("x-dead-letter-routing-key", "dlq.order-events")
            .build();
    }

    @Bean
    public Binding orderEventsBinding(Queue orderEventsQueue, TopicExchange orderEventsExchange) {
        return BindingBuilder.bind(orderEventsQueue)
            .to(orderEventsExchange)
            .with(ORDER_EVENTS_ROUTING_KEY);
    }

    @Bean
    public SimpleRabbitListenerContainerFactory rabbitListenerContainerFactory(
            ConnectionFactory connectionFactory) {
        SimpleRabbitListenerContainerFactory factory = new SimpleRabbitListenerContainerFactory();
        factory.setConnectionFactory(connectionFactory);
        factory.setDefaultRequeueRejected(false);
        factory.setAdviceChain(
            RetryTemplate.builder()
                .maxAttempts(3)
                .backoffOptions(1000, 2.0, 10000)
                .build()
        );
        factory.setErrorHandler(new ConditionalRejectingErrorHandler(
            new RejectAndDontRequeueRecoverer()
        ));
        return factory;
    }
}
```

### Step 7: Application Configuration

Add to `application.yaml`:

```yaml
# Kafka configuration
spring:
  kafka:
    bootstrap-servers: ${KAFKA_BOOTSTRAP_SERVERS:localhost:9092}
    consumer:
      group-id: ${spring.application.name}-consumer
      auto-offset-reset: earliest
      enable-auto-commit: false

# Topic configuration
kafka:
  topics:
    order-events: ${KAFKA_TOPIC_ORDER_EVENTS:order-events}
    user-events: ${KAFKA_TOPIC_USER_EVENTS:user-events}
    payment-events: ${KAFKA_TOPIC_PAYMENT_EVENTS:payment-events}
```

### Step 8: Dead Letter Queue Configuration

```java
package {base}.infrastructure.config;

import org.apache.kafka.clients.admin.NewTopic;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.kafka.config.TopicBuilder;

@Configuration
public class DlqConfig {

    @Bean
    public NewTopic orderEventsDlqTopic() {
        return TopicBuilder.name("order-events.dlq")
            .partitions(3)
            .replicas(1)
            .build();
    }
}
```

### Step 9: Tests

```java
package {base}.infrastructure.adapter.inbound.messaging;

import {base}.application.dto.event.*;
import {base}.application.usecase.*;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.apache.kafka.clients.consumer.ConsumerRecord;
import org.junit.jupiter.api.*;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.*;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.kafka.support.Acknowledgment;
import static org.assertj.core.api.Assertions.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class {EventName}KafkaConsumerTest {

    @Mock private {Action}UseCaseImpl useCase;
    @Mock private Acknowledgment ack;
    @InjectMocks private {EventName}KafkaConsumer consumer;

    private final ObjectMapper objectMapper = new ObjectMapper();

    @Test
    @DisplayName("should process valid event and acknowledge")
    void shouldProcessAndAcknowledge() throws Exception {
        // Arrange
        var event = new {EventName}Dto(UUID.randomUUID(), UUID.randomUUID(), Instant.now(), UUID.randomUUID(), "{EventName}");
        String json = objectMapper.writeValueAsString(event);
        var record = new ConsumerRecord<>("order-events", 0, 0L, "key", json);

        // Act
        consumer.consume(record, ack);

        // Assert
        verify(useCase).execute(event);
        verify(ack).acknowledge();
    }

    @Test
    @DisplayName("should not acknowledge when processing fails")
    void shouldNotAcknowledgeOnFailure() throws Exception {
        // Arrange
        var event = new {EventName}Dto(UUID.randomUUID(), UUID.randomUUID(), Instant.now(), UUID.randomUUID(), "{EventName}");
        String json = objectMapper.writeValueAsString(event);
        var record = new ConsumerRecord<>("order-events", 0, 0L, "key", json);
        doThrow(new RuntimeException("Processing failed")).when(useCase).execute(any());

        // Act & Assert
        assertThrows(RuntimeException.class, () -> consumer.consume(record, ack));
        verify(ack, never()).acknowledge();
    }
}
```

## Output

Print:
- All files created with paths
- The consumer flow: Kafka/RabbitMQ → Consumer → Use Case → Business Logic
- DLQ configuration
- Monitoring: how to check consumer lag

## Rules (from Constitution)

- Consumers MUST be idempotent.
- Failed events MUST go to DLQ after max retries.
- Consumer failures MUST NOT block the consumer group.
- Events MUST be logged with trace_id for distributed tracing.
- Consumer group MUST be named after the consuming service.
