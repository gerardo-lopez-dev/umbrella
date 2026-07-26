---
description: "Add tests for a feature: unit, integration, and architecture tests"
handoffs: ["hexagonal.add-entity", "hexagonal.add-usecase"]
---

# Add Tests (Hexagonal Layers)

You are adding tests following the test pyramid for hexagonal architecture.

## Inputs

The user provides:
- **Entity or use case to test** (e.g., `Order`, `CreateOrderUseCase`, `OrderController`)
- **Package base** (e.g., `com.template.orders`)
- **Test scenarios** (optional — if not provided, derive from the code)

## Instructions

1. **Load constitution** from `.specify/memory/constitution.md` — section IX (Testing by Layer) is authoritative.

2. **Detect existing test patterns** — look for existing test classes to follow conventions.

### Step 1: Domain Unit Tests

Create in `src/test/java/{packagePath}/domain/service/`:

```java
package {base}.domain.service;

import {base}.domain.model.entity.*;
import {base}.domain.model.valueobject.*;
import org.junit.jupiter.api.*;
import static org.assertj.core.api.Assertions.*;

class {Entity}Test {

    @Test
    @DisplayName("should create {entity} with valid data")
    void shouldCreateWithValidData() {
        // Arrange
        var value1 = "...";
        var value2 = 100;

        // Act
        var entity = {Entity}.create(value1, value2);

        // Assert
        assertThat(entity).isNotNull();
        assertThat(entity.getId()).isNotNull();
        assertThat(entity.getValue1()).isEqualTo(value1);
    }

    @Test
    @DisplayName("should throw exception when {field} is null")
    void shouldThrowWhenFieldIsNull() {
        // Arrange & Act & Assert
        assertThatThrownBy(() -> {Entity}.create(null, 100))
            .isInstanceOf(NullPointerException.class);
    }

    @Test
    @DisplayName("should transition status from {from} to {to}")
    void shouldTransitionStatus() {
        // Arrange
        var entity = {Entity}.create(...);

        // Act
        entity.{methodToTransition}();

        // Assert
        assertThat(entity.getStatus()).isEqualTo({Entity}Status.{TO_STATE});
    }

    @Test
    @DisplayName("should reject invalid status transition")
    void shouldRejectInvalidTransition() {
        // Arrange
        var entity = {Entity}.create(...);
        entity.{methodToTransition}();

        // Act & Assert
        assertThatThrownBy(() -> entity.{invalidTransition}())
            .isInstanceOf(InvalidStateTransitionException.class);
    }
}
```

**Rules**:
- NO `@SpringBootTest` — pure unit tests.
- Use AssertJ assertions (`assertThat`).
- Test method names: `should{ExpectedBehavior}When{Condition}`.
- Test display names: human-readable scenario descriptions.
- Cover: happy path, validation, state transitions, edge cases.

### Step 2: Use Case Unit Tests

Create in `src/test/java/{packagePath}/application/usecase/`:

```java
package {base}.application.usecase;

import {base}.domain.port.outbound.*;
import {base}.application.dto.request.*;
import {base}.application.mapper.*;
import org.junit.jupiter.api.*;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.*;
import org.mockito.junit.jupiter.MockitoExtension;
import static org.assertj.core.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class {UseCaseName}UseCaseImplTest {

    @Mock
    private {OutboundPort1} port1;

    @Mock
    private {OutboundPort2} port2;

    @Mock
    private {Entity}Mapper mapper;

    @InjectMocks
    private {UseCaseName}UseCaseImpl useCase;

    @Test
    @DisplayName("should execute successfully with valid request")
    void shouldExecuteSuccessfully() {
        // Arrange
        var request = new {UseCaseName}Request(...);
        var domainEntity = {Entity}.create(...);
        var jpaEntity = new {Entity}JpaEntity();
        var response = new {UseCaseName}Response(...);

        when(port1.save(any())).thenReturn(domainEntity);
        when(mapper.toDomain(any())).thenReturn(domainEntity);
        when(mapper.toJpa(any())).thenReturn(jpaEntity);
        when(mapper.toResponse(any())).thenReturn(response);

        // Act
        var result = useCase.execute(request);

        // Assert
        assertThat(result).isNotNull();
        verify(port1).save(any());
        verify(mapper).toResponse(any());
    }

    @Test
    @DisplayName("should propagate exception from outbound port")
    void shouldPropagateException() {
        // Arrange
        when(port1.save(any())).thenThrow(new RuntimeException("DB error"));

        // Act & Assert
        assertThatThrownBy(() -> useCase.execute(new {UseCaseName}Request(...)))
            .isInstanceOf(RuntimeException.class)
            .hasMessage("DB error");
    }
}
```

### Step 3: Integration Tests (Infrastructure)

Create in `src/test/java/{packagePath}/infrastructure/adapter/`:

```java
package {base}.infrastructure.adapter;

import {base}.infrastructure.adapter.outbound.persistence.*;
import org.junit.jupiter.api.*;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.jdbc.AutoConfigureTestDatabase;
import org.springframework.boot.test.autoconfigure.orm.jpa.DataJpaTest;
import org.springframework.test.context.ActiveProfiles;
import static org.assertj.core.api.Assertions.*;

@DataJpaTest
@ActiveProfiles("local")
@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE)
class {Entity}RepositoryTest {

    @Autowired
    private {Entity}JpaRepository repository;

    @Test
    @DisplayName("should save and retrieve {entity}")
    void shouldSaveAndRetrieve() {
        // Arrange
        var entity = new {Entity}JpaEntity();
        // set fields...

        // Act
        var saved = repository.save(entity);
        var found = repository.findById(saved.getId());

        // Assert
        assertThat(found).isPresent();
        assertThat(found.get().getField()).isEqualTo(entity.getField());
    }

    @Test
    @DisplayName("should return empty when {entity} not found")
    void shouldReturnEmptyWhenNotFound() {
        // Act
        var found = repository.findById(UUID.randomUUID());

        // Assert
        assertThat(found).isEmpty();
    }
}
```

### Step 4: Controller Integration Tests

Create in `src/test/java/{packagePath}/infrastructure/adapter/inbound/rest/`:

```java
package {base}.infrastructure.adapter.inbound.rest;

import {base}.domain.port.inbound.*;
import {base}.application.dto.request.*;
import {base}.application.dto.response.*;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.*;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.bean.MockBean;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@WebMvcTest({Entity}Controller.class)
class {Entity}ControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @MockBean
    private {UseCaseName}UseCase useCase;

    @Autowired
    private ObjectMapper objectMapper;

    @Test
    @DisplayName("should return 201 when creating {entity}")
    void shouldReturn201WhenCreating() throws Exception {
        // Arrange
        var request = new {UseCaseName}Request(...);
        var response = new {UseCaseName}Response(...);
        when(useCase.execute(any())).thenReturn(response);

        // Act & Assert
        mockMvc.perform(post("/api/v1/{resources}")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(request)))
            .andExpect(status().isCreated())
            .andExpect(jsonPath("$.id").value(response.id().toString()));
    }

    @Test
    @DisplayName("should return 400 when request is invalid")
    void shouldReturn400WhenInvalid() throws Exception {
        // Act & Assert
        mockMvc.perform(post("/api/v1/{resources}")
                .contentType(MediaType.APPLICATION_JSON)
                .content("{}"))
            .andExpect(status().isBadRequest());
    }
}
```

### Step 5: Architecture Tests

Create in `src/test/java/{packagePath}/architecture/`:

```java
package {base}.architecture;

import com.tngtech.archunit.core.importer.ClassFileImporter;
import com.tngtech.archunit.lang.ArchRule;
import org.junit.jupiter.api.Test;
import static com.tngtech.archunit.lang.syntax.ArchRuleDefinition.*;

class HexagonalArchitectureTest {

    private final var classes = new ClassFileImporter()
        .importPackages("{base}");

    @Test
    @DisplayName("domain layer must not depend on infrastructure")
    void domainMustNotDependOnInfrastructure() {
        ArchRule rule = noClasses()
            .that().resideInAPackage("..domain..")
            .should().dependOnClassesThat()
            .resideInAPackage("..infrastructure..");

        rule.check(classes);
    }

    @Test
    @DisplayName("domain layer must not depend on Spring framework")
    void domainMustNotDependOnSpring() {
        ArchRule rule = noClasses()
            .that().resideInAPackage("..domain..")
            .should().dependOnClassesThat()
            .resideInAPackage("org.springframework..");

        rule.check(classes);
    }

    @Test
    @DisplayName("controllers must not depend on repositories")
    void controllersMustNotDependOnRepositories() {
        ArchRule rule = noClasses()
            .that().resideInAPackage("..adapter.inbound.rest..")
            .should().dependOnClassesThat()
            .resideInAPackage("..adapter.outbound.persistence..");

        rule.check(classes);
    }

    @Test
    @DisplayName("use cases must follow naming convention")
    void useCasesMustFollowNaming() {
        ArchRule rule = classes()
            .that().haveSimpleNameEndingWith("UseCase")
            .should().beInterfaces();

        rule.check(classes);
    }
}
```

**Dependencies needed in `pom.xml`**:

```xml
<dependency>
    <groupId>com.tngtech.archunit</groupId>
    <artifactId>archunit-junit5</artifactId>
    <version>1.3.0</version>
    <scope>test</scope>
</dependency>
```

### Step 6: Test Configuration

Create `src/test/resources/application-local.yaml`:

```yaml
spring:
  datasource:
    url: jdbc:h2:mem:testdb;DB_CLOSE_DELAY=-1
    driver-class-name: org.h2.Driver
    username: sa
    password:
  jpa:
    hibernate:
      ddl-auto: create-drop
```

## Output

Print:
- All test files created with paths
- Summary: unit tests, integration tests, architecture tests
- Command to run: `./mvnw test`

## Rules (from Constitution)

- Domain tests: NO Spring context, pure unit tests.
- Use case tests: Mockito mocks for outbound ports, no Spring.
- Infrastructure tests: `@DataJpaTest` or `@WebMvcTest` with Testcontainers.
- Architecture tests: ArchUnit rules enforcing hexagonal boundaries.
- All tests MUST use Arrange-Act-Assert pattern.
- Test method names MUST describe the scenario.
- Coverage target: 80% minimum.
