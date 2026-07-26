---
description: "Add Resilience4j circuit breaker and retry to an adapter"
handoffs: ["hexagonal.add-test", "shared.add-feign-client"]
---

# Add Circuit Breaker (Shared)

You are adding Resilience4j circuit breaker, retry, and rate limiting to an outbound adapter.

## Inputs

The user provides:
- **Adapter to protect** (e.g., `ProductFeignClient`, `PaymentGateway`)
- **Failure threshold** (e.g., 50% error rate opens the circuit)
- **Retry count** (e.g., 3 retries with exponential backoff)
- **Timeout** (e.g., 5s timeout)
- **Package base** (e.g., `com.template.cart`)

## Instructions

1. **Load constitution** from `.specify/memory/constitution.md`.

### Step 1: Add Dependencies to pom.xml

```xml
<dependency>
    <groupId>io.github.resilience4j</groupId>
    <artifactId>resilience4j-spring-boot3</artifactId>
</dependency>

<dependency>
    <groupId>io.github.resilience4j</groupId>
    <artifactId>resilience4j-reactor</artifactId>
</dependency>
```

### Step 2: Configuration

Add to `application.yaml`:

```yaml
resilience4j:
  circuitbreaker:
    instances:
      {adapter-name}:
        register-health-indicator: true
        sliding-window-size: 10
        minimum-number-of-calls: 5
        failure-rate-threshold: 50
        wait-duration-in-open-state: 30s
        permitted-number-of-calls-in-half-open-state: 3
        automatic-transition-from-open-to-half-open-enabled: true
        event-consumer-buffer-size: 100

  retry:
    instances:
      {adapter-name}:
        max-attempts: 3
        wait-duration: 1s
        enable-exponential-backoff: true
        exponential-backoff-multiplier: 2
        retry-exceptions:
          - java.io.IOException
          - java.util.concurrent.TimeoutException
          - org.springframework.web.client.HttpServerErrorException
        ignore-exceptions:
          - com.template.common.exception.BusinessException

  timelimiter:
    instances:
      {adapter-name}:
        timeout-duration: 5s
        cancel-running-future: true

  ratelimiter:
    instances:
      {adapter-name}:
        limit-for-period: 100
        limit-refresh-period: 1s
        timeout-duration: 0
```

### Step 3: Annotate the Adapter

Update the Feign client or adapter:

```java
package {base}.infrastructure.adapter.outbound.external;

import io.github.resilience4j.circuitbreaker.annotation.CircuitBreaker;
import io.github.resilience4j.retry.annotation.Retry;
import io.github.resilience4j.timelimiter.annotation.TimeLimiter;
import io.github.resilience4j.ratelimiter.annotation.RateLimiter;
import org.springframework.stereotype.Component;

@Component
public class {Adapter}ResilientAdapter implements {TargetService}Gateway {

    private final {TargetService}FeignClient feignClient;
    private final {TargetService}Fallback fallback;

    public {Adapter}ResilientAdapter({TargetService}FeignClient feignClient, {TargetService}Fallback fallback) {
        this.feignClient = feignClient;
        this.fallback = fallback;
    }

    @Override
    @CircuitBreaker(name = "{adapter-name}", fallbackMethod = "fallbackGetById")
    @Retry(name = "{adapter-name}", fallbackMethod = "fallbackGetById")
    @TimeLimiter(name = "{adapter-name}")
    public {ResourceDto} getById(UUID id) {
        return feignClient.getById(id);
    }

    public {ResourceDto} fallbackGetById(UUID id, Throwable throwable) {
        return fallback.getById(id);
    }

    @Override
    @CircuitBreaker(name = "{adapter-name}", fallbackMethod = "fallbackValidate")
    @Retry(name = "{adapter-name}", fallbackMethod = "fallbackValidate")
    @RateLimiter(name = "{adapter-name}")
    public ValidationResult validate(ValidationRequest request) {
        return feignClient.validate(request);
    }

    public ValidationResult fallbackValidate(ValidationRequest request, Throwable throwable) {
        return fallback.validate(request);
    }
}
```

### Step 4: Fallback Class

Create in `infrastructure/adapter/outbound/external/`:

```java
package {base}.infrastructure.adapter.outbound.external;

import {base}.application.dto.response.*;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;
import java.util.UUID;

@Component
public class {TargetService}Fallback {

    private static final Logger log = LoggerFactory.getLogger({TargetService}Fallback.class);

    public {ResourceDto} getById(UUID id) {
        log.warn("Fallback triggered for getById({}) — returning default", id);
        return {ResourceDto}.fallback(id);
    }

    public ValidationResult validate(ValidationRequest request) {
        log.warn("Fallback triggered for validate — returning safe default");
        return new ValidationResult(true, "Service unavailable — validation deferred");
    }
}
```

### Step 5: Custom Feign Decoder (Optional)

Create in `infrastructure/config/`:

```java
package {base}.infrastructure.config;

import feign.Response;
import feign.codec.ErrorDecoder;
import org.springframework.stereotype.Component;

@Component
public class FeignErrorDecoder implements ErrorDecoder {

    private final ErrorDecoder defaultDecoder = new Default();

    @Override
    public Exception decode(String methodKey, Response response) {
        switch (response.status()) {
            case 400 -> throw new BadRequestException("Bad request to " + methodKey);
            case 404 -> throw new ResourceNotFoundException("Resource not found: " + methodKey);
            case 429 -> throw new RateLimitExceededException("Rate limit exceeded for " + methodKey);
            case 500, 502, 503 -> throw new ServiceUnavailableException(
                "Service unavailable: " + methodKey + " (status: " + response.status() + ")"
            );
            default -> return defaultDecoder.decode(methodKey, response);
        }
    }
}
```

### Step 6: Custom Exceptions

Create in `domain/exception/`:

```java
package {base}.domain.exception;

public class ResourceNotFoundException extends RuntimeException {
    public ResourceNotFoundException(String message) {
        super(message);
    }
}

public class ServiceUnavailableException extends RuntimeException {
    public ServiceUnavailableException(String message) {
        super(message);
    }
}

public class RateLimitExceededException extends RuntimeException {
    public RateLimitExceededException(String message) {
        super(message);
    }
}
```

### Step 7: Actuator Health Indicator

Create in `infrastructure/config/`:

```java
package {base}.infrastructure.config;

import io.github.resilience4j.circuitbreaker.CircuitBreakerRegistry;
import io.github.resilience4j.circuitbreaker.CircuitBreaker;
import org.springframework.boot.actuate.health.Health;
import org.springframework.boot.actuate.health.HealthIndicator;
import org.springframework.stereotype.Component;

@Component
public class CircuitBreakerHealthIndicator implements HealthIndicator {

    private final CircuitBreakerRegistry registry;

    public CircuitBreakerHealthIndicator(CircuitBreakerRegistry registry) {
        this.registry = registry;
    }

    @Override
    public Health health() {
        CircuitBreaker cb = registry.circuitBreaker("{adapter-name}");

        return switch (cb.getState()) {
            case CLOSED -> Health.up()
                .withDetail("circuitbreaker", "CLOSED")
                .withDetail("failureRate", cb.getMetrics().getFailureRate() + "%")
                .withDetail("calls", cb.getMetrics().getNumberOfSuccessfulCalls() + " successful, " +
                    cb.getMetrics().getNumberOfFailedCalls() + " failed")
                .build();
            case OPEN -> Health.down()
                .withDetail("circuitbreaker", "OPEN")
                .withDetail("failureRate", cb.getMetrics().getFailureRate() + "%")
                .withDetail("waitDuration", cb.getMetrics().getNumberOfNotPermittedCalls() + " not permitted")
                .build();
            case HALF_OPEN -> Health.status("DEGRADED")
                .withDetail("circuitbreaker", "HALF_OPEN")
                .withDetail("failureRate", cb.getMetrics().getFailureRate() + "%")
                .build();
        };
    }
}
```

### Step 8: Metrics Configuration

Add to `application.yaml`:

```yaml
management:
  endpoints:
    web:
      exposure:
        include: health,info,prometheus
  metrics:
    tags:
      application: ${spring.application.name}
    distribution:
      percentiles-histogram:
        http.server.requests: true
      percentiles:
        http.server.requests: 0.5, 0.75, 0.95, 0.99
```

### Step 9: Tests

```java
package {base}.infrastructure.adapter.outbound.external;

import io.github.resilience4j.circuitbreaker.CircuitBreaker;
import io.github.resilience4j.circuitbreaker.CircuitBreakerRegistry;
import org.junit.jupiter.api.*;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.*;
import org.mockito.junit.jupiter.MockitoExtension;
import static org.assertj.core.api.Assertions.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class {Adapter}ResilientAdapterTest {

    @Mock private {TargetService}FeignClient feignClient;
    @Mock private {TargetService}Fallback fallback;
    @InjectMocks private {Adapter}ResilientAdapter adapter;

    @Test
    @DisplayName("should return result when service is healthy")
    void shouldReturnResultWhenHealthy() {
        // Arrange
        var id = UUID.randomUUID();
        var dto = new {ResourceDto}(id, "Product");
        when(feignClient.getById(id)).thenReturn(dto);

        // Act
        var result = adapter.getById(id);

        // Assert
        assertThat(result).isNotNull();
        verify(feignClient).getById(id);
        verify(fallback, never()).getById(any());
    }

    @Test
    @DisplayName("should use fallback when service fails")
    void shouldUseFallbackOnFailure() {
        // Arrange
        var id = UUID.randomUUID();
        when(feignClient.getById(id)).thenThrow(new RuntimeException("Service down"));
        when(fallback.getById(id)).thenReturn({ResourceDto}.fallback(id));

        // Act
        var result = adapter.getById(id);

        // Assert
        assertThat(result).isNotNull();
        verify(fallback).getById(id);
    }
}
```

## Output

Print:
- All files created/modified with paths
- The resilience chain: Call → RateLimiter → TimeLimiter → CircuitBreaker → Retry → Fallback
- Dashboard URL for monitoring circuit breaker state

## Rules (from Constitution)

- Every outbound adapter calling external services MUST have circuit breaker.
- Fallbacks MUST return safe defaults, never throw exceptions.
- Circuit breaker state MUST be exposed via Actuator health endpoint.
- Retry MUST use exponential backoff to avoid thundering herd.
- Timeouts MUST be configured per adapter (default 5s).
