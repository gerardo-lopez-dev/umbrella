---
description: "Add idempotency interceptor to a payment endpoint"
handoffs: ["hexagonal.add-test", "hexagonal.add-usecase"]
---

# Add Idempotent Endpoint (Payments)

You are adding idempotency to a payment endpoint to prevent duplicate processing.

## Inputs

The user provides:
- **Endpoint** (e.g., `POST /api/v1/payments`)
- **Idempotency key source** (header `X-Idempotency-Key`)
- **Cache store** (Redis)
- **Package base** (e.g., `com.template.payments`)

## Instructions

1. **Load constitution** from `.specify/memory/constitution.md`.

### Step 1: Idempotency Key Entity

Create in `domain/model/entity/`:

```java
package {base}.domain.model.entity;

import java.time.Instant;
import java.util.UUID;

public class IdempotencyRecord {
    private final UUID id;
    private final String idempotencyKey;
    private final String requestHash;
    private final String responsePayload;
    private final int statusCode;
    private final Instant createdAt;
    private final Instant expiresAt;

    // Constructor, getters...

    public boolean isExpired() {
        return Instant.now().isAfter(expiresAt);
    }
}
```

### Step 2: Idempotency Repository (Outbound Port)

Create in `domain/port/outbound/`:

```java
package {base}.domain.port.outbound;

import {base}.domain.model.entity.IdempotencyRecord;
import java.util.Optional;

public interface IdempotencyRepository {
    Optional<IdempotencyRecord> findByKey(String idempotencyKey);
    IdempotencyRecord save(IdempotencyRecord record);
    void deleteExpired();
}
```

### Step 3: Redis-backed Implementation

Create in `infrastructure/adapter/outbound/persistence/`:

```java
package {base}.infrastructure.adapter.outbound.persistence;

import {base}.domain.model.entity.IdempotencyRecord;
import {base}.domain.port.outbound.IdempotencyRepository;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Repository;
import java.time.Duration;
import java.time.Instant;
import java.util.Optional;

@Repository
public class RedisIdempotencyRepository implements IdempotencyRepository {

    private static final String KEY_PREFIX = "idempotency:";
    private static final Duration TTL = Duration.ofHours(24);

    private final StringRedisTemplate redisTemplate;
    private final ObjectMapper objectMapper;

    public RedisIdempotencyRepository(StringRedisTemplate redisTemplate, ObjectMapper objectMapper) {
        this.redisTemplate = redisTemplate;
        this.objectMapper = objectMapper;
    }

    @Override
    public Optional<IdempotencyRecord> findByKey(String idempotencyKey) {
        String json = redisTemplate.opsForValue().get(KEY_PREFIX + idempotencyKey);
        if (json == null) return Optional.empty();
        try {
            IdempotencyRecord record = objectMapper.readValue(json, IdempotencyRecord.class);
            if (record.isExpired()) {
                redisTemplate.delete(KEY_PREFIX + idempotencyKey);
                return Optional.empty();
            }
            return Optional.of(record);
        } catch (Exception e) {
            return Optional.empty();
        }
    }

    @Override
    public IdempotencyRecord save(IdempotencyRecord record) {
        try {
            String json = objectMapper.writeValueAsString(record);
            redisTemplate.opsForValue().set(KEY_PREFIX + record.getIdempotencyKey(), json, TTL);
            return record;
        } catch (Exception e) {
            throw new RuntimeException("Failed to save idempotency record", e);
        }
    }

    @Override
    public void deleteExpired() {
        // Redis handles TTL automatically
    }
}
```

### Step 4: Idempotency Interceptor

Create in `infrastructure/config/`:

```java
package {base}.infrastructure.config;

import {base}.domain.port.outbound.IdempotencyRepository;
import {base}.domain.model.entity.IdempotencyRecord;
import jakarta.servlet.http.*;
import org.springframework.stereotype.Component;
import org.springframework.web.servlet.HandlerInterceptor;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.Optional;
import java.util.UUID;

@Component
public class IdempotencyInterceptor implements HandlerInterceptor {

    private final IdempotencyRepository idempotencyRepository;

    public IdempotencyInterceptor(IdempotencyRepository idempotencyRepository) {
        this.idempotencyRepository = idempotencyRepository;
    }

    @Override
    public boolean preHandle(HttpServletRequest request, HttpServletResponse response, Object handler) {
        String idempotencyKey = request.getHeader("X-Idempotency-Key");
        if (idempotencyKey == null || idempotencyKey.isBlank()) {
            return true; // No idempotency key — proceed normally
        }

        // Check if we've seen this key before
        Optional<IdempotencyRecord> existing = idempotencyRepository.findByKey(idempotencyKey);
        if (existing.isPresent()) {
            // Return cached response
            IdempotencyRecord record = existing.get();
            response.setStatus(record.getStatusCode());
            response.setContentType("application/json");
            response.getWriter().write(record.getResponsePayload());
            response.setHeader("X-Idempotent-Replay", "true");
            return false; // Don't proceed to controller
        }

        // Store key in request attribute for the response wrapper
        request.setAttribute("idempotencyKey", idempotencyKey);
        return true;
    }
}
```

### Step 5: Response Wrapper for Idempotent Storage

Create in `infrastructure/config/`:

```java
package {base}.infrastructure.config;

import {base}.domain.port.outbound.IdempotencyRepository;
import {base}.domain.model.entity.IdempotencyRecord;
import jakarta.servlet.*;
import jakarta.servlet.http.*;
import org.springframework.core.annotation.Order;
import org.springframework.stereotype.Component;
import java.io.*;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.UUID;

@Component
@Order(2)
public class IdempotentResponseFilter implements Filter {

    private final IdempotencyRepository idempotencyRepository;

    public IdempotentResponseFilter(IdempotencyRepository idempotencyRepository) {
        this.idempotencyRepository = idempotencyRepository;
    }

    @Override
    public void doFilter(ServletRequest request, ServletResponse response, FilterChain chain)
            throws IOException, ServletException {

        HttpServletRequest httpRequest = (HttpServletRequest) request;
        HttpServletResponse httpResponse = (HttpServletResponse) response;

        String idempotencyKey = (String) httpRequest.getAttribute("idempotencyKey");
        if (idempotencyKey == null) {
            chain.doFilter(request, response);
            return;
        }

        // Wrap response to capture output
        CachedBodyHttpServletResponse cachedResponse = new CachedBodyHttpServletResponse(httpResponse);
        chain.doFilter(request, cachedResponse);

        // Store the response for future idempotent replays
        if (cachedResponse.getStatus() >= 200 && cachedResponse.getStatus() < 300) {
            String responseBody = cachedResponse.getCachedBody();
            IdempotencyRecord record = new IdempotencyRecord(
                UUID.randomUUID(),
                idempotencyKey,
                computeHash(httpRequest),
                responseBody,
                cachedResponse.getStatus(),
                Instant.now(),
                Instant.now().plus(24, ChronoUnit.HOURS)
            );
            idempotencyRepository.save(record);
        }
    }

    private String computeHash(HttpServletRequest request) {
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            byte[] hash = digest.digest(
                (request.getMethod() + request.getRequestURI() + getRequestBody(request))
                    .getBytes(StandardCharsets.UTF_8)
            );
            return bytesToHex(hash);
        } catch (Exception e) {
            return "";
        }
    }

    private String getRequestBody(HttpServletRequest request) {
        // Read request body if available
        return "";
    }

    private String bytesToHex(byte[] bytes) {
        StringBuilder sb = new StringBuilder();
        for (byte b : bytes) {
            sb.append(String.format("%02x", b));
        }
        return sb.toString();
    }
}
```

### Step 6: Register Interceptor

Update `infrastructure/config/WebConfig.java`:

```java
package {base}.infrastructure.config;

import org.springframework.context.annotation.Configuration;
import org.springframework.web.servlet.config.annotation.*;

@Configuration
public class WebConfig implements WebMvcConfigurer {

    private final IdempotencyInterceptor idempotencyInterceptor;

    public WebConfig(IdempotencyInterceptor idempotencyInterceptor) {
        this.idempotencyInterceptor = idempotencyInterceptor;
    }

    @Override
    public void addInterceptors(InterceptorRegistry registry) {
        registry.addInterceptor(idempotencyInterceptor)
            .addPathPatterns("/api/v1/payments")
            .addPathPatterns("/api/v1/payments/**");
    }
}
```

### Step 7: Flyway Migration

```sql
-- V{N}__create_idempotency_records.sql
CREATE TABLE idempotency_records (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    idempotency_key VARCHAR(255) NOT NULL UNIQUE,
    request_hash VARCHAR(64) NOT NULL,
    response_payload TEXT NOT NULL,
    status_code INT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL
);

CREATE INDEX idx_idempotency_key ON idempotency_records(idempotency_key);
CREATE INDEX idx_idempotency_expires ON idempotency_records(expires_at);
```

### Step 8: Tests

```java
package {base}.infrastructure.config;

import {base}.domain.port.outbound.IdempotencyRepository;
import {base}.domain.model.entity.IdempotencyRecord;
import org.junit.jupiter.api.*;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.*;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;
import static org.assertj.core.api.Assertions.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class IdempotencyInterceptorTest {

    @Mock private IdempotencyRepository idempotencyRepository;
    @InjectMocks private IdempotencyInterceptor interceptor;

    @Test
    @DisplayName("should return cached response when idempotency key exists")
    void shouldReturnCachedResponse() throws Exception {
        // Arrange
        var request = new MockHttpServletRequest("POST", "/api/v1/payments");
        request.addHeader("X-Idempotency-Key", "test-key-123");
        var response = new MockHttpServletResponse();

        var record = new IdempotencyRecord(
            UUID.randomUUID(), "test-key-123", "hash",
            "{\"id\":\"123\"}", 201, Instant.now(), Instant.now().plusHours(24)
        );
        when(idempotencyRepository.findByKey("test-key-123")).thenReturn(Optional.of(record));

        // Act
        boolean result = interceptor.preHandle(request, response, new Object());

        // Assert
        assertThat(result).isFalse();
        assertThat(response.getStatus()).isEqualTo(201);
        assertThat(response.getContentAsString()).contains("\"id\":\"123\"");
    }

    @Test
    @DisplayName("should proceed when no idempotency key")
    void shouldProceedWithoutKey() throws Exception {
        // Arrange
        var request = new MockHttpServletRequest("POST", "/api/v1/payments");
        var response = new MockHttpServletResponse();

        // Act
        boolean result = interceptor.preHandle(request, response, new Object());

        // Assert
        assertThat(result).isTrue();
    }
}
```

## Output

Print:
- All files created with paths
- The idempotency flow: Request → Check Cache → Miss → Process → Cache Response
- Redis TTL configuration

## Rules (from Constitution)

- Idempotency keys MUST be provided by the client via `X-Idempotency-Key` header.
- Cached responses MUST expire (24h default).
- Idempotent replay MUST set `X-Idempotent-Replay: true` header.
- Only successful responses (2xx) are cached.
- Request hash MUST include method + URI + body.
