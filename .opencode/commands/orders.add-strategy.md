---
description: "Add a strategy pattern for tax/discount calculation"
handoffs: ["hexagonal.add-test", "hexagonal.add-entity"]
---

# Add Strategy (Orders)

You are adding a new strategy implementation for tax or discount calculation using the Strategy pattern.

## Inputs

The user provides:
- **Strategy type** (e.g., `TaxCalculator`, `DiscountStrategy`)
- **Strategy name** (e.g., `ReducedTaxCalculator`, `PercentageDiscount`)
- **Algorithm logic** (e.g., "10% discount on orders over $100")
- **Package base** (e.g., `com.template.orders`)

## Instructions

1. **Load constitution** from `.specify/memory/constitution.md`.

2. **Detect existing strategies** — look for existing strategy interfaces and implementations.

### Step 1: Create/Update Strategy Interface

If the interface doesn't exist, create in `domain/port/inbound/`:

```java
package {base}.domain.port.inbound;

import {base}.domain.model.entity.Order;
import {base}.domain.model.valueobject.Money;

public interface {StrategyType} {
    Money calculate(Order order);
    String getName();
}
```

### Step 2: Create the New Strategy Implementation

Create in `domain/service/impl/`:

```java
package {base}.domain.service.impl;

import {base}.domain.model.entity.Order;
import {base}.domain.model.valueobject.Money;
import {base}.domain.port.inbound.{StrategyType};
import org.springframework.stereotype.Component;
import java.math.BigDecimal;

@Component
public class {StrategyName} implements {StrategyType} {

    @Override
    public Money calculate(Order order) {
        // Implement the algorithm
        // Example: 10% discount on orders over $100
        Money total = order.getTotal();
        if (total.amount().compareTo(new BigDecimal("100")) > 0) {
            BigDecimal discount = total.amount()
                .multiply(new BigDecimal("0.10"));
            return new Money(total.currency(), discount);
        }
        return Money.of(total.currency(), "0");
    }

    @Override
    public String getName() {
        return "{STRATEGY_NAME}";
    }
}
```

### Step 3: Create Strategy Selector

Create in `domain/service/`:

```java
package {base}.domain.service;

import {base}.domain.model.entity.Order;
import {base}.domain.model.valueobject.Money;
import {base}.domain.port.inbound.{StrategyType};
import org.springframework.stereotype.Service;
import java.util.List;

@Service
public class {StrategyType}Selector {

    private final List<{StrategyType}> strategies;

    public {StrategyType}Selector(List<{StrategyType}> strategies) {
        this.strategies = strategies;
    }

    public {StrategyType} select(Order order) {
        // Select strategy based on order context
        return strategies.stream()
            .filter(s -> s.getName().equals(determineStrategyName(order)))
            .findFirst()
            .orElseThrow(() -> new IllegalArgumentException(
                "No strategy found for order: " + order.getId()
            ));
    }

    private String determineStrategyName(Order order) {
        // Business logic to determine which strategy to use
        // e.g., based on region, product type, customer tier
        return "{DEFAULT_STRATEGY_NAME}";
    }
}
```

### Step 4: Integrate into Use Case

Update the use case that needs the strategy:

```java
@Service
public class {UseCaseName}UseCaseImpl implements {UseCaseName}UseCase {

    private final {StrategyType}Selector strategySelector;

    // Constructor injection...

    @Override
    public Response execute(Request request) {
        Order order = // ... build order

        // Select and apply strategy
        {StrategyType} strategy = strategySelector.select(order);
        Money result = strategy.calculate(order);

        // Use the result
        order.apply{Result}(result);
        // ...
    }
}
```

### Step 5: Configuration-based Strategy (Alternative)

If strategy selection should be configurable:

```java
package {base}.domain.service.impl;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

@Component
public class {StrategyName} implements {StrategyType} {

    @Value("${strategies.{type}.{name}.enabled:true}")
    private boolean enabled;

    @Value("${strategies.{type}.{name}.rate:0.10}")
    private BigDecimal rate;

    @Override
    public Money calculate(Order order) {
        if (!enabled) {
            return Money.of(order.getTotal().currency(), "0");
        }
        // Use rate from configuration
        BigDecimal result = order.getTotal().amount().multiply(rate);
        return new Money(order.getTotal().currency(), result);
    }
}
```

### Step 6: Tests for the Strategy

Create in `src/test/java/{packagePath}/domain/service/impl/`:

```java
package {base}.domain.service.impl;

import {base}.domain.model.entity.Order;
import {base}.domain.model.valueobject.*;
import org.junit.jupiter.api.*;
import static org.assertj.core.api.Assertions.*;

class {StrategyName}Test {

    private {StrategyName} strategy;

    @BeforeEach
    void setUp() {
        strategy = new {StrategyName}();
    }

    @Test
    @DisplayName("should calculate correctly when condition is met")
    void shouldCalculateWhenConditionMet() {
        // Arrange
        var order = Order.create(/* total > threshold */);

        // Act
        var result = strategy.calculate(order);

        // Assert
        assertThat(result.amount()).isPositive();
    }

    @Test
    @DisplayName("should return zero when condition is not met")
    void shouldReturnZeroWhenConditionNotMet() {
        // Arrange
        var order = Order.create(/* total < threshold */);

        // Act
        var result = strategy.calculate(order);

        // Assert
        assertThat(result.amount()).isZero();
    }

    @Test
    @DisplayName("should have correct name")
    void shouldHaveCorrectName() {
        assertThat(strategy.getName()).isEqualTo("{STRATEGY_NAME}");
    }
}
```

### Step 7: Flyway Migration for Strategy Configuration (optional)

```sql
-- V{N}__create_strategy_config.sql
CREATE TABLE strategy_config (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    strategy_type VARCHAR(100) NOT NULL,
    strategy_name VARCHAR(100) NOT NULL,
    enabled BOOLEAN NOT NULL DEFAULT TRUE,
    config JSONB,
    UNIQUE(strategy_type, strategy_name)
);

INSERT INTO strategy_config (strategy_type, strategy_name, enabled, config)
VALUES ('TAX_CALCULATOR', '{strategy_name}', true, '{"rate": 0.10}');
```

## Output

Print:
- All files created/modified with paths
- The strategy selection logic
- All available strategies registered in the application

## Rules (from Constitution)

- Strategy interface MUST be in `domain/port/inbound/`.
- Strategy implementations MUST be in `domain/service/impl/`.
- Each strategy MUST be annotated with `@Component` for Spring DI.
- Strategy selection logic MUST be testable without Spring context.
- Strategy implementations MUST be stateless and thread-safe.
