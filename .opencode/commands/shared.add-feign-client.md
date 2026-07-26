---
description: "Add a Feign client for synchronous inter-service communication"
handoffs: ["shared.add-circuit-breaker", "hexagonal.add-test"]
---

# Add Feign Client (Shared)

You are adding an OpenFeign client for synchronous communication between microservices.

## Inputs

The user provides:
- **Target service** (e.g., `products-service`, `users-service`)
- **Operations** (e.g., `getProduct`, `validateStock`, `getUser`)
- **Package base** (e.g., `com.template.cart`)

## Instructions

1. **Load constitution** from `.specify/memory/constitution.md` — section VI (Microservice Conventions) applies.

### Step 1: Feign Client Interface

Create in `infrastructure/adapter/outbound/external/`:

```java
package {base}.infrastructure.adapter.outbound.external;

import {base}.domain.port.outbound.{TargetService}Gateway;
import {base}.application.dto.response.*;
import org.springframework.cloud.openfeign.FeignClient;
import org.springframework.web.bind.annotation.*;

@FeignClient(
    name = "${feign.clients.{target-service}.name:{target-service}}",
    url = "${feign.clients.{target-service}.url:http://localhost:8082}",
    fallbackFactory = {TargetService}FallbackFactory.class
)
public interface {TargetService}FeignClient extends {TargetService}Gateway {

    @GetMapping("/api/v1/{resources}/{id}")
    {ResourceDto} getById(@PathVariable("id") UUID id);

    @PostMapping("/api/v1/{resources}/validate")
    ValidationResult validate(@RequestBody ValidationRequest request);

    @GetMapping("/api/v1/{resources}")
    Page<{ResourceDto>> search(
        @RequestParam("query") String query,
        @RequestParam(value = "page", defaultValue = "0") int page,
        @RequestParam(value = "size", defaultValue = "20") int size
    );
}
```

**Note**: The Feign client extends the outbound port interface — this ensures the adapter implements the port contract.

### Step 2: Outbound Port (Gateway)

Create in `domain/port/outbound/`:

```java
package {base}.domain.port.outbound;

import {base}.application.dto.response.*;
import org.springframework.data.domain.Page;
import java.util.UUID;

public interface {TargetService}Gateway {
    {ResourceDto} getById(UUID id);
    ValidationResult validate(ValidationRequest request);
    Page<{ResourceDto}> search(String query, int page, int size);
}
```

### Step 3: Fallback Factory (Resilience)

Create in `infrastructure/adapter/outbound/external/`:

```java
package {base}.infrastructure.adapter.outbound.external;

import {base}.application.dto.response.*;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.cloud.openfeign.FallbackFactory;
import org.springframework.data.domain.Page;
import org.springframework.stereotype.Component;
import java.util.UUID;

@Component
public class {TargetService}FallbackFactory implements FallbackFactory<{TargetService}FeignClient> {

    private static final Logger log = LoggerFactory.getLogger({TargetService}FallbackFactory.class);

    @Override
    public {TargetService}FeignClient create(Throwable cause) {
        log.error("Fallback triggered for {target-service} due to: {}", cause.getMessage());

        return new {TargetService}FeignClient() {
            @Override
            public {ResourceDto} getById(UUID id) {
                log.warn("Using fallback for getById: {}", id);
                // Return cached data or default value
                return {ResourceDto}.fallback(id);
            }

            @Override
            public ValidationResult validate(ValidationRequest request) {
                log.warn("Using fallback for validate: {}", request);
                // Assume valid to allow degraded operation
                return new ValidationResult(true, "Service unavailable — validation skipped");
            }

            @Override
            public Page<{ResourceDto}> search(String query, int page, int size) {
                log.warn("Using fallback for search: {}", query);
                // Return empty page
                return Page.empty();
            }
        };
    }
}
```

### Step 4: Feign Configuration

Create in `infrastructure/config/`:

```java
package {base}.infrastructure.config;

import feign.Logger;
import feign.Request;
import feign.Response;
import org.springframework.cloud.openfeign.EnableFeignClients;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import java.util.concurrent.TimeUnit;

@Configuration
@EnableFeignClients(basePackages = "{base}.infrastructure.adapter.outbound.external")
public class FeignConfig {

    @Bean
    public Logger.Level feignLoggerLevel() {
        return Logger.Level.BASIC; // NONE, BASIC, HEADERS, FULL
    }

    @Bean
    public Request.Options requestOptions() {
        // connectTimeout: 5s, readTimeout: 10s
        return new Request.Options(5, TimeUnit.SECONDS, 10, TimeUnit.SECONDS, true);
    }
}
```

### Step 5: Application Configuration

Add to `application.yaml`:

```yaml
feign:
  clients:
    {target-service}:
      name: ${TARGET_SERVICE_NAME:{target-service}}
      url: ${TARGET_SERVICE_URL:http://localhost:8082}
  circuitbreaker:
    enabled: true
  httpclient:
    hc5:
      enabled: true
  compression:
    request:
      enabled: true
      mime-types: application/json
    response:
      enabled: true
```

### Step 6: Add Dependency to pom.xml

```xml
<dependency>
    <groupId>org.springframework.cloud</groupId>
    <artifactId>spring-cloud-starter-openfeign</artifactId>
</dependency>

<dependency>
    <groupId>org.springframework.cloud</groupId>
    <artifactId>spring-cloud-starter-circuitbreaker-resilience4j</artifactId>
</dependency>
```

### Step 7: Add Dependency Management

```xml
<dependencyManagement>
    <dependencies>
        <dependency>
            <groupId>org.springframework.cloud</groupId>
            <artifactId>spring-cloud-dependencies</artifactId>
            <version>2024.0.1</version>
            <type>pom</type>
            <scope>import</scope>
        </dependency>
    </dependencies>
</dependencyManagement>
```

### Step 8: Tests

```java
package {base}.infrastructure.adapter.outbound.external;

import {base}.application.dto.response.*;
import org.junit.jupiter.api.*;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.*;
import org.mockito.junit.jupiter.MockitoExtension;
import static org.assertj.core.api.Assertions.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class {TargetService}FeignClientTest {

    @Mock private {TargetService}FeignClient feignClient;
    @InjectMocks private SomeUseCase useCase;

    @Test
    @DisplayName("should return product when service is available")
    void shouldReturnProductWhenAvailable() {
        // Arrange
        var productId = UUID.randomUUID();
        var product = new {ResourceDto}(productId, "Product A", Money.of("USD", "99.99"));
        when(feignClient.getById(productId)).thenReturn(product);

        // Act
        var result = useCase.execute(productId);

        // Assert
        assertThat(result).isNotNull();
        verify(feignClient).getById(productId);
    }

    @Test
    @DisplayName("should use fallback when service is unavailable")
    void shouldUseFallbackWhenUnavailable() {
        // Arrange
        var productId = UUID.randomUUID();
        when(feignClient.getById(productId)).thenThrow(new RuntimeException("Service down"));

        // Act & Assert
        assertThrows(RuntimeException.class, () -> useCase.execute(productId));
    }
}
```

### Step 9: Integration Test with WireMock

```java
package {base}.infrastructure.adapter.outbound.external;

import com.github.tomakehamcrest.wiremock.client.WireMock;
import org.junit.jupiter.api.*;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.cloud.contract.wiremock.AutoConfigureWireMock;
import org.springframework.test.context.ActiveProfiles;
import static com.github.tomakehamcrest.wiremock.client.WireMock.*;
import static org.assertj.core.api.Assertions.*;

@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@AutoConfigureWireMock(port = 8082)
@ActiveProfiles("test")
class {TargetService}FeignIntegrationTest {

    @Autowired
    private {TargetService}FeignClient feignClient;

    @Test
    @DisplayName("should call external service and return result")
    void shouldCallExternalService() {
        // Arrange
        stubFor(get(urlPathEqualTo("/api/v1/products/123"))
            .willReturn(ok()
                .withHeader("Content-Type", "application/json")
                .withBody("{\"id\":\"123\",\"name\":\"Product A\"}")));

        // Act
        var result = feignClient.getById(UUID.fromString("123"));

        // Assert
        assertThat(result).isNotNull();
        verify(getRequestedFor(urlPathEqualTo("/api/v1/products/123")));
    }
}
```

## Output

Print:
- All files created with paths
- The communication flow: UseCase → Port → FeignClient → External Service
- Fallback behavior when service is down

## Rules (from Constitution)

- Feign clients MUST extend outbound port interfaces (hexagonal compliance).
- Fallbacks MUST be implemented for all Feign clients.
- Timeouts MUST be configured (connect: 5s, read: 10s).
- Feign clients MUST NOT be used for async communication (use Kafka/RabbitMQ).
- Inter-service communication MUST go through the port, never direct Feign injection.
