---
description: "Add a state transition to the Order State pattern"
handoffs: ["hexagonal.add-test", "orders.add-strategy"]
---

# Add State Transition (Orders)

You are adding a new state and its transitions to the Order lifecycle using the State pattern.

## Inputs

The user provides:
- **Current state** (e.g., `CREATED`, `PAID`)
- **New state** (e.g., `SHIPPED`)
- **Transition action** (e.g., `ship()`)
- **Preconditions** (e.g., payment must be completed)
- **Side effects** (e.g., publish `OrderShippedEvent`, notify customer)
- **Package base** (e.g., `com.template.orders`)

## Instructions

1. **Load constitution** from `.specify/memory/constitution.md` — section VIII (Saga Rules) applies.

2. **Detect existing states** — look for existing state implementations in `domain/model/entity/` or `domain/service/`.

### Step 1: Create the New State Class

Create in `domain/model/entity/state/`:

```java
package {base}.domain.model.entity.state;

import {base}.domain.model.entity.Order;
import {base}.domain.model.valueobject.OrderStatus;
import {base}.domain.model.event.*;
import {base}.domain.port.outbound.EventPublisher;

public class {NewState}State implements OrderState {

    @Override
    public void pay(Order order, EventPublisher eventPublisher) {
        throw new InvalidStateTransitionException(
            order.getStatus(), OrderStatus.{NEW_STATE}, "pay"
        );
    }

    @Override
    public void ship(Order order, EventPublisher eventPublisher) {
        // Validate preconditions
        if (!order.isPaymentCompleted()) {
            throw new IllegalStateException("Cannot ship order without payment");
        }

        // Transition state
        order.setStatus(OrderStatus.{NEW_STATE});

        // Publish event
        eventPublisher.publish(
            OrderShippedEvent.of(order.getId(), order.getUserId(), order.getShippingAddress())
        );
    }

    @Override
    public void cancel(Order order, EventPublisher eventPublisher) {
        // Allow cancellation from {NEW_STATE}
        order.setStatus(OrderStatus.CANCELLED);
        eventPublisher.publish(
            OrderCancelledEvent.of(order.getId(), order.getUserId())
        );
    }

    @Override
    public OrderStatus getStatus() {
        return OrderStatus.{NEW_STATE};
    }
}
```

### Step 2: Update the Order Entity

Add the state transition method in `domain/model/entity/Order.java`:

```java
public class Order {
    private OrderState state;
    // ... existing fields

    public void ship(EventPublisher eventPublisher) {
        this.state.ship(this, eventPublisher);
        this.updatedAt = Instant.now();
    }

    // Update the status setter to use the state pattern
    public void setStatus(OrderStatus status) {
        this.status = status;
        this.state = OrderStateFactory.getState(status);
    }
}
```

### Step 3: Create the State Factory

Create in `domain/model/entity/state/`:

```java
package {base}.domain.model.entity.state;

import {base}.domain.model.valueobject.OrderStatus;
import java.util.Map;
import java.util.function.Supplier;

public final class OrderStateFactory {

    private static final Map<OrderStatus, Supplier<OrderState>> STATES = Map.of(
        OrderStatus.CREATED, CreatedState::new,
        OrderStatus.PAID, PaidState::new,
        OrderStatus.{NEW_STATE}, {NewState}State::new,
        OrderStatus.CANCELLED, CancelledState::new
    );

    private OrderStateFactory() {}

    public static OrderState getState(OrderStatus status) {
        Supplier<OrderState> supplier = STATES.get(status);
        if (supplier == null) {
            throw new IllegalArgumentException("No state implementation for: " + status);
        }
        return supplier.get();
    }
}
```

### Step 4: Add Status to Enum

Update `domain/model/valueobject/OrderStatus.java`:

```java
public enum OrderStatus {
    CREATED,
    PAID,
    {NEW_STATE},
    CANCELLED
}
```

### Step 5: Create Exception for Invalid Transitions

Create in `domain/model/entity/state/`:

```java
package {base}.domain.model.entity.state;

import {base}.domain.model.valueobject.OrderStatus;

public class InvalidStateTransitionException extends RuntimeException {
    public InvalidStateTransitionException(OrderStatus from, OrderStatus to, String action) {
        super(String.format(
            "Cannot execute '%s': transition from %s to %s is not allowed",
            action, from, to
        ));
    }
}
```

### Step 6: Create Flyway Migration (if adding new status)

```sql
-- V{N}__add_{new_status}_order_status.sql
-- Only needed if the status affects existing data
UPDATE orders SET status = '{new_status}' WHERE status = '{old_status}';
```

### Step 7: Tests for State Transitions

Create in `src/test/java/{packagePath}/domain/model/entity/`:

```java
package {base}.domain.model.entity;

import {base}.domain.model.entity.state.*;
import {base}.domain.model.valueobject.*;
import {base}.domain.port.outbound.EventPublisher;
import org.junit.jupiter.api.*;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import static org.assertj.core.api.Assertions.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class OrderStateTest {

    @Mock
    private EventPublisher eventPublisher;

    @Test
    @DisplayName("should transition from {from} to {newState} when ship is called")
    void shouldTransitionToNewState() {
        // Arrange
        var order = Order.create(userId, items);
        order.pay(eventPublisher); // move to PAID first
        reset(eventPublisher);

        // Act
        order.ship(eventPublisher);

        // Assert
        assertThat(order.getStatus()).isEqualTo(OrderStatus.{NEW_STATE});
        verify(eventPublisher).publish(any(OrderShippedEvent.class));
    }

    @Test
    @DisplayName("should reject ship when payment is not completed")
    void shouldRejectShipWithoutPayment() {
        // Arrange
        var order = Order.create(userId, items); // status = CREATED

        // Act & Assert
        assertThatThrownBy(() -> order.ship(eventPublisher))
            .isInstanceOf(InvalidStateTransitionException.class);
    }
}
```

## Output

Print:
- All files created/modified with paths
- The complete state transition diagram
- All valid transitions from the new state

## Rules (from Constitution)

- Every state transition MUST have a precondition check.
- Invalid transitions MUST throw `InvalidStateTransitionException`.
- Each transition MAY publish a domain event.
- State implementations MUST be in `domain/model/entity/state/`.
- State factory MUST be immutable and stateless.
