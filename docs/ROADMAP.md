# E-Commerce Distribuido - Roadmap Completo

> Sistema de comercio electrónico distribuido basado en microservicios, arquitectura hexagonal, y patrones de diseño.
> Cada microservicio se ejecuta en su propio repo (polyrepo), clonado desde el template base.

---

## Arquitectura General del Sistema

```
                    ┌──────────────┐
                    │ API Gateway  │
                    │ (Spring Cloud│
                    │  Gateway)    │
                    └──────┬───────┘
                           │
          ┌────────────────┼────────────────────┐
          │                │                    │
    ┌─────┴─────┐   ┌─────┴─────┐      ┌──────┴──────┐
    │  Users    │   │ Products  │      │   Orders    │
    │  Service  │   │  Service  │      │   Service   │
    └─────┬─────┘   └─────┬─────┘      └──────┬──────┘
          │                │                    │
          │          ┌─────┴─────┐      ┌──────┴──────┐
          │          │ Inventory │      │  Payments   │
          │          │  Service  │      │   Service   │
          │          └─────┬─────┘      └──────┬──────┘
          │                │                    │
          │          ┌─────┴─────┐      ┌──────┴──────┐
          └──────────│   Cart    │      │Notifications│
                     │  Service  │      │   Service   │
                     └───────────┘      └─────────────┘

         ═══════════════════════════════════════════════
              Kafka / RabbitMQ (mensajería async)
         ═══════════════════════════════════════════════
```

### Microservicios (7 dominios)

| # | Microservicio | Puerto | Repo | Dominio |
|---|--------------|--------|------|---------|
| 1 | users-service | 8081 | users-service | Autenticación, perfiles, RBAC |
| 2 | products-service | 8082 | products-service | Catálogo, categorías, búsqueda |
| 3 | inventory-service | 8083 | inventory-service | Stock, reservas, alertas |
| 4 | cart-service | 8084 | cart-service | Carrito de compras |
| 5 | orders-service | 8085 | orders-service | Pedidos, ciclo de vida, Sagas |
| 6 | payments-service | 8086 | payments-service | Procesamiento de pagos |
| 7 | notifications-service | 8087 | notifications-service | Email, push, SMS |

### Estructura Hexagonal (común a todos los microservicios)

```
com.template.{domain}/
├── domain/
│   ├── model/
│   │   ├── entity/          # Entidades de dominio (puros, sin anotaciones JPA)
│   │   ├── valueobject/     # Value Objects (Money, Address, etc.)
│   │   └── event/           # Eventos de dominio
│   ├── port/
│   │   ├── inbound/         # Puertos de entrada (casos de uso)
│   │   └── outbound/        # Puertos de salida (repositorios, gateways)
│   └── service/
│       └── impl/            # Implementación de lógica de negocio
├── application/
│   ├── usecase/             # Casos de uso (implementan puertos inbound)
│   ├── dto/
│   │   ├── request/         # DTOs de entrada
│   │   └── response/        # DTOs de salida
│   └── mapper/              # Mappers entre DTOs y entidades
└── infrastructure/
    ├── config/              # Configuraciones de Spring
    ├── adapter/
    │   ├── inbound/
    │   │   ├── rest/        # Controllers REST (adaptadores de entrada)
    │   │   └── messaging/   # Consumers de mensajería (adaptadores de entrada)
    │   └── outbound/
    │       ├── persistence/ # Repositorios JPA (adaptadores de salida)
    │       ├── messaging/   # Producers de mensajería (adaptadores de salida)
    │       └── external/    # Clients de servicios externos (Feign, etc.)
    └── {Domain}Application.java
```

---

## PARTE 1: Template Base

> Estos posts aplican al template compartido que todos los microservicios clonarán.
> Se implementan UNA sola vez y benefit a todos los servicios.

---

### Post 01 - Spring Profiles y Configuración 12-Factor

**Tema:** Cómo configurar microservicios con perfiles y variables de entorno.
**Investigar:** 12-Factor App, profiles de Spring Boot, externalización de configuración.
**Implementar en template:**
- Revisar y mejorar los profiles existentes (local, dev, prod)
- Agregar profile `test` para tests de integración
- Agregar `application-{profile}.yaml` con configuraciones diferenciadas
- Documentar todas las variables de entorno en `.env.example`
- Agregar validación de variables de entorno al arranque
**Archivo clave:** `src/main/resources/application*.yaml`

---

### Post 02 - Docker Multi-Stage y Docker Compose

**Tema:** Builds optimizados y orquestación local de microservicios.
**Investigar:** Multi-stage builds, docker-compose v2, healthchecks, redes Docker.
**Implementar en template:**
- Optimizar el Dockerfile multi-stage (caché de dependencias)
- Agregar `docker-compose.yaml` con servicios base (PostgreSQL, Redis, Kafka)
- Configurar redes Docker para comunicación entre servicios
- Agregar volumenes para persistencia
- Agregar `.dockerignore` optimizado
**Archivos clave:** `Dockerfile`, `docker-compose.yml`, `.dockerignore`

---

### Post 03 - Actuator + Health Checks Personalizados

**Tema:** Monitoreo básico de salud de tus microservicios en producción.
**Investigar:** Spring Actuator, health indicators custom, métricas básicas.
**Implementar en template:**
- Configurar endpoints de Actuator por profile
- Crear HealthIndicator custom (ej: verificar conexión a BD)
- Configurar health checks en Docker Compose
- Exponer métricas básicas (uptime, memory, threads)
**Archivos clave:** `application*.yaml`, clase `HealthIndicator` custom

---

### Post 04 - GitHub Actions CI/CD Pipeline

**Tema:** Automatiza build, test y coverage en cada push.
**Investigar:** GitHub Actions, Maven workflows, caching, artifacts.
**Implementar en template:**
- Mejorar el workflow CI existente
- Agregar stages: lint → test → build → coverage → docker build
- Agregar badge de coverage en README
- Configurar branches protection rules
- Agregar dependabot para actualizaciones automáticas
**Archivos clave:** `.github/workflows/ci.yml`, `.github/dependabot.yml`

---

### Post 05 - Arquitectura Hexagonal: Estructura de Paquetes

**Tema:** Estructura de paquetes que aísla dominio de infraestructura.
**Investigar:** Hexagonal Architecture (Alistair Cockburn), puertos y adaptadores, Clean Architecture.
**Skill:** `/hexagonal.scaffold` — scaffolding completo de hexagonal
**Implementar en template:**
- Crear la estructura de paquetes base hexagonal
- Crear interfaces de ejemplo (puertos inbound/outbound)
- Crear adaptadores de ejemplo (rest controller, JPA repository)
- Crear caso de uso de ejemplo
- Documentar la convención de paquetes en README
**Nota:** Esta estructura se clonará para cada microservicio

---

### Post 06 - Flyway: Migraciones de Base de Datos

**Tema:** Versionado de esquemas de base de datos como código.
**Investigar:** Flyway, convenciones de naming, migraciones, rollbacks.
**Implementar en template:**
- Agregar dependencia de Flyway en `pom.xml`
- Crear primera migración (`V1__init_schema.sql`)
- Configurar Flyway por profile
- Agregar migración de ejemplo
- Mostrar cómo funciona el flyway: migrate
**Archivos clave:** `pom.xml`, `src/main/resources/db/migration/`

---

### Post 07 - Spring Data JPA + Repository Pattern

**Tema:** Capa de persistencia desacoplada del dominio.
**Investigar:** Spring Data JPA, Repository pattern, especificaciones, query methods.
**Skills:** `/hexagonal.add-entity` + `/hexagonal.add-usecase`
**Implementar en template:**
- Crear ejemplo de entidad de dominio pura (sin JPA)
- Crear adaptador de persistencia con JPA
- Crear repositorio con Spring Data
- Mostrar separación: entidad JPA vs entidad de dominio
**Archivos clave:** Paquetes `domain/model/entity`, `infrastructure/adapter/outbound/persistence`

---

### Post 08 - MapStruct + DTOs + Global Exception Handler

**Tema:** Capa de presentación limpia con manejo centralizado de errores.
**Investigar:** MapStruct, DTO pattern, `@ControllerAdvice`, `@RestControllerAdvice`.
**Implementar en template:**
- Agregar dependencia de MapStruct en `pom.xml`
- Crear DTOs de ejemplo (request/response)
- Crear mapper con MapStruct
- Crear `GlobalExceptionHandler` con respuestas estandarizadas
- Crear `ApiResponse<T>` wrapper para todas las respuestas
**Archivos clave:** `application/dto/`, `application/mapper/`, `infrastructure/config/`

---

### Post 09 - Spring Security + JWT

**Tema:** Autenticación stateless con tokens JWT.
**Investigar:** Spring Security, JWT (access + refresh tokens), flujo de autenticación.
**Implementar en template:**
- Agregar dependencias de Spring Security y JWT
- Crear filter chain de seguridad
- Crear `JwtTokenProvider`
- Crear endpoints de login y register
- Configurar seguridad por profile
**Archivos clave:** `infrastructure/config/SecurityConfig`, `infrastructure/adapter/inbound/rest/`

---

### Post 10 - RBAC: Roles y Permisos

**Tema:** Control de acceso por rol (ADMIN, CUSTOMER, VENDOR).
**Investigar:** RBAC, authorización por roles, SpEL security.
**Skill:** `/hexagonal.add-event` — para publicar eventos de cambio de rol
**Implementar en template:**
- Crear entidades Role y Permission
- Crear enums de roles
- Configurar endpoints por rol
- Crear anotación custom `@PreAuthorize` para permisos
- Agregar migración Flyway para roles iniciales
**Archivos clave:** `domain/model/entity/`, `infrastructure/config/SecurityConfig`

---

### Post 11 - SpringDoc OpenAPI (Swagger)

**Tema:** Documentación automática interactiva de tu API REST.
**Investigar:** springdoc-openapi, anotaciones OpenAPI, agrupación de endpoints.
**Implementar en template:**
- Agregar dependencia springdoc-openapi
- Configurar info de la API (título, versión, descripción)
- Agrupar endpoints por tag
- Agregar ejemplos de request/response
- Configurar por profile (habilitado solo en dev/local)
**Archivos clave:** `pom.xml`, `application.yaml`, `infrastructure/config/OpenApiConfig`

---

### Post 12 - Validación con Bean Validation

**Tema:** Reglas de negocio en DTOs con @Valid, custom validators.
**Investigar:** Bean Validation, constraints custom, validación en cascada.
**Implementar en template:**
- Crear DTOs con anotaciones de validación
- Crear validator custom (ej: `@StrongPassword`)
- Crear `@Validated` en controllers
- Mostrar validación anidada de DTOs
- Agregar mensajes de error i18n
**Archivos clave:** `application/dto/request/`, `infrastructure/config/`

---

### Post 13 - Flyway: Migraciones Avanzadas

**Tema:** Migraciones complejas, datos seed, y gestión de esquemas en producción.
**Investigar:** Flyway callbacks, repeatable migrations, baselines.
**Implementar en template:**
- Crear migración de datos seed
- Crear migración repeatable para vistas
- Configurar baseline para BD existentes
- Agregar Flyway callback para logging
- Mostrar flujo completo de migración
**Archivos clave:** `src/main/resources/db/migration/`, `application*.yaml`

---

### Post 14 - Testcontainers para Tests de Integración

**Tema:** Tests de integración con contenedores Docker reales.
**Investigar:** Testcontainers, JUnit 5 extensions, test profiles.
**Skill:** `/hexagonal.add-test` — scaffolding de tests por capa
**Implementar en template:**
- Agregar dependencias de Testcontainers
- Crear container de PostgreSQL para tests
- Crear test de integración de ejemplo
- Configurar `@Testcontainers` y `@Container`
- Mostrar diferencias entre unit test e integration test
**Archivos clave:** `src/test/java/`, `pom.xml`

---

### Post 15 - WireMock para Mock de Servicios Externos

**Tema:** Mock de servicios externos para tests aislados.
**Investigar:** WireMock, stub recording, simular errores y timeouts.
**Implementar en template:**
- Agregar dependencia de WireMock
- Crear stub de servicio externo
- Crear test que use WireMock
- Mostrar simulación de escenarios (éxito, error, timeout)
- Integrar con Testcontainers para suite de tests completa
**Archivos clave:** `src/test/java/`, `pom.xml`

---

### Post 16 - ArchUnit: Tests de Arquitectura

**Tema:** Tests de arquitectura que verifican reglas de diseño.
**Investigar:** ArchUnit, reglas de arquitectura, convenciones de paquetes.
**Implementar en template:**
- Agregar dependencia de ArchUnit
- Crear reglas: dominio no depende de infraestructura
- Crear reglas: controllers no acceden directamente a repositorios
- Crear reglas: naming conventions
- Crear reglas: dependencias禁止 circular
**Archivos clave:** `src/test/java/`, `pom.xml`

---

### Post 17 - Test Pyramid: Estrategia Completa de Testing

**Tema:** Unit → Integration → E2E, métricas y estrategia.
**Investigar:** Test pyramid, test categories, coverage metrics.
**Implementar en template:**
- Organizar tests por categoría (unit, integration, e2e)
- Configurar Maven profiles para ejecutar por categoría
- Configurar JaCoCo con umbrales de coverage
- Crear documentación de la estrategia de testing
- Mostrar cómo ejecutar cada tipo de test
**Archivos clave:** `pom.xml`, `.github/workflows/ci.yml`, README

---

## PARTE 2: Microservicios por Dominio

> Cada microservicio se crea clonando el template base.
> Se indica la fase de investigación e implementación para cada uno.

---

## Fase A: Users Service

> Primer microservicio. Establece los patrones que seguirán los demás.

### Post 18 - Users Service: Diseño del Dominio

**Tema:** Modelado del dominio de usuarios con arquitectura hexagonal.
**Investigar:** Domain-Driven Design basics, entidades vs value objects, agregados.
**Skill:** `/hexagonal.scaffold users 8081` — scaffold del primer microservicio
**Implementar en `users-service`:**
- Clonar template base
- Crear estructura hexagonal completa
- Definir entidades: `User`, `Role`
- Definir value objects: `Email`, `Password`, `UserProfile`
- Definir eventos: `UserRegisteredEvent`, `UserUpdatedEvent`
- Definir puertos inbound: `RegisterUserUseCase`, `GetUserProfileUseCase`
- Definir puertos outbound: `UserRepository`, `PasswordEncoder`
**Repo:** `users-service` (clonado desde template)

---

### Post 19 - Users Service: Register y Login con JWT

**Tema:** Flujo completo de autenticación con arquitectura hexagonal.
**Investigar:** JWT best practices, refresh tokens, token rotation.
**Implementar en `users-service`:**
- Implementar caso de uso `RegisterUserUseCase`
- Implementar caso de uso `LoginUseCase`
- Implementar caso de uso `RefreshTokenUseCase`
- Crear endpoints REST: POST /auth/register, POST /auth/login, POST /auth/refresh
- Implementar `PostgreSQLUserRepository` (adaptador outbound)
- Implementar `BCryptPasswordEncoder` (adaptador outbound)
- Publicar evento `UserRegisteredEvent` al registrar
**Claves:** Separa lógica de negocio del controller, el caso de uso no conoce Spring

---

### Post 20 - Users Service: RBAC Completo

**Tematicas:** Control de acceso por roles, permisos granulares.
**Investigar:** RBAC vs ABAC, principle of least privilege.
**Implementar en `users-service`:**
- Crear casos de uso: `AssignRoleUseCase`, `RevokeRoleUseCase`
- Crear endpoint: POST /users/{id}/roles, DELETE /users/{id}/roles
- Crear endpoint: GET /users/{id}/permissions
- Implementar filtro JWT que extrae roles del token
- Configurar endpoints protegidos por rol
- Agregar migración Flyway para roles y permisos iniciales
**Claves:** Los roles se codifican en el JWT, no se consultan en cada request

---

### Post 21 - Users Service: Tests y Documentación

**Tema:** Testing completo del microservicio de usuarios.
**Implementar en `users-service`:**
- Tests unitarios de casos de uso (con mocks)
- Tests de integración con Testcontainers (PostgreSQL)
- Tests de arquitectura con ArchUnit
- Tests de security (login fallido, token expirado, roles)
- Documentación Swagger completa
- Verificar que el dominio puro no tiene dependencias de Spring
**Claves:** Cobertura mínima del 80%, todos los tests deben pasar en CI

---

## Fase B: Products Service

### Post 22 - Products Service: Diseño del Dominio

**Tematicas:** Catálogo de productos, categorías, búsqueda.
**Investigar:** Product catalog patterns, categorization, search strategies.
**Implementar en `products-service`:**
- Clonar template base
- Crear entidades: `Product`, `Category`
- Definir value objects: `Money`, `Dimensions`, `ProductStatus`
- Definir eventos: `ProductCreatedEvent`, `ProductUpdatedEvent`, `ProductDeactivatedEvent`
- Definir puertos: `CreateProductUseCase`, `SearchProductsUseCase`, `GetProductUseCase`
- Definir puertos outbound: `ProductRepository`, `CategoryRepository`
**Claves:** Product es un agregado raíz, Category es un entity separado

---

### Post 23 - Products Service: CRUD con Paginación y Búsqueda

**Tematicas:** API REST completa con paginación, filtros y búsqueda.
**Investigar:** Spring Data Specifications, paginación, sorting, filtros dinámicos.
**Implementar en `products-service`:**
- Implementar casos de uso CRUD
- Implementar búsqueda con filtros (categoría, precio, estado)
- Implementar paginación con `Pageable`
- Implementar adaptador JPA con Specifications
- Crear endpoints: GET /products (con filtros), POST /products, PUT /products/{id}, DELETE /products/{id}
- Crear endpoint: GET /categories
**Claves:** El controller nunca recibe entidades de dominio, solo DTOs

---

### Post 24 - Products Service: Caché con Redis

**Tematicas:** Caché de primer nivel para datos de alto acceso.
**Investigar:** Spring Cache, Redis, cache eviction strategies, TTL.
**Implementar en `products-service`:**
- Agregar dependencias de Redis
- Configurar Redis por profile
- Agregar `@Cacheable` en casos de uso de lectura
- Agregar `@CacheEvict` en operaciones de escritura
- Configurar TTL por tipo de dato
- Crear `RedisConfig` personalizado
**Claves:** La caché es transparente para el dominio, se configura en infraestructura

---

## Fase C: Inventory Service

### Post 25 - Inventory Service: Diseño del Dominio

**Tematicas:** Gestión de stock, reservas, alertas de bajo stock.
**Investigar:** Inventory management patterns, stock reservation, concurrency control.
**Implementar en `inventory-service`:**
- Clonar template base
- Crear entidad: `InventoryItem`
- Definir value objects: `StockQuantity`, `ReservationId`
- Definir eventos: `StockReservedEvent`, `StockReleasedEvent`, `LowStockAlertEvent`
- Definir puertos: `ReserveStockUseCase`, `ReleaseStockUseCase`, `CheckAvailabilityUseCase`
- Definir puertos outbound: `InventoryRepository`
**Claves:** La reserva de stock es transaccional, debe ser idempotente

---

### Post 26 - Inventory Service: Reserva de Stock con Concurrency Control

**Tematicas:** Control de concurrencia en actualizaciones de stock.
**Investigar:** Optimistic locking, pessimistic locking, SELECT FOR UPDATE.
**Implementar en `inventory-service`:**
- Implementar reserva de stock con `@Version` (optimistic locking)
- Implementar liberación de stock
- Implementar verificación de disponibilidad
- Crear endpoint: POST /inventory/reserve, DELETE /inventory/reserve/{id}
- Crear endpoint: GET /inventory/{productId}/available
- Manejar conflictos de concurrencia con HTTP 409
**Claves:** Un producto no puede venderse si no hay stock, la reserva tiene TTL

---

## Fase D: Cart Service

### Post 27 - Cart Service: Diseño del Dominio

**Tematicas:** Carrito de compras, gestión temporal, sincronización.
**Investigar:** Shopping cart patterns, session management, cart persistence.
**Implementar en `cart-service`:**
- Clonar template base
- Crear entidad: `Cart`, `CartItem`
- Definir value objects: `CartId`, `Quantity`
- Definir eventos: `ItemAddedEvent`, `ItemRemovedEvent`, `CartCheckedOutEvent`
- Definir puertos: `AddItemUseCase`, `RemoveItemUseCase`, `GetCartUseCase`, `CheckoutUseCase`
- Definir puertos outbound: `CartRepository`, `ProductGateway` (para validar precio)
**Claves:** El carrito referencia productos de otro servicio, nunca almacena precios directamente

---

### Post 28 - Cart Service: Comunicación Síncrona con OpenFeign

**Tematicas:** Llamadas declarativas HTTP entre microservicios.
**Investigar:** OpenFeign, fallbacks, timeout configuration, service discovery.
**Skill:** `/shared.add-feign-client products` — cliente Feign para products-service
**Implementar en `cart-service`:**
- Agregar dependencia de OpenFeign
- Crear `ProductFeignClient` (puerto outbound para products-service)
- Crear adaptador que implemente el puerto usando Feign
- Configurar timeouts y retry
- Implementar fallback con Circuit Breaker (preview)
- Crear endpoint: GET /cart/{userId}, POST /cart/{userId}/items, DELETE /cart/{userId}/items/{productId}
**Claves:** El CartService nunca llama directamente al repositorio de Products, usa el puerto

---

### Post 29 - Cart Service: Resiliencia con Resilience4j

**Tematicas:** Circuit Breaker, Retry, Rate Limiter contra fallos en cascada.
**Investigar:** Resilience4j, patrones de resiliencia, fallback strategies.
**Skill:** `/shared.add-circuit-breaker productFeignClient` — resiliencia en adaptador
**Implementar en `cart-service`:**
- Agregar dependencias de Resilience4j
- Configurar Circuit Breaker para llamadas a products-service
- Configurar Retry con backoff exponencial
- Configurar TimeLimiter para timeouts
- Crear fallback method (retornar caché o mensaje amigable)
- Agregar métricas de circuit breaker en Actuator
**Claves:** Si products-service cae, el cart debe degradarse gracefully, no fallar completamente

---

## Fase E: Orders Service (El más complejo)

### Post 30 - Orders Service: Diseño del Dominio Complejo

**Tematicas:** Entidad central del e-commerce, ciclo de vida complejo.
**Investigar:** Order aggregate design, domain events, Saga pattern intro.
**Implementar en `orders-service`:**
- Clonar template base
- Crear entidad: `Order`, `OrderItem`, `OrderStatus`
- Definir value objects: `OrderId`, `Money`, `Address`, `OrderStatus` (enum con transiciones válidas)
- Definir eventos: `OrderCreatedEvent`, `OrderPaidEvent`, `OrderShippedEvent`, `OrderCancelledEvent`
- Definir puertos: `CreateOrderUseCase`, `PayOrderUseCase`, `ShipOrderUseCase`, `CancelOrderUseCase`
- Definir puertos outbound: `OrderRepository`, `PaymentGateway`, `InventoryGateway`, `NotificationGateway`
**Claves:** Order es el agregado raíz más importante, su ciclo de vida define el negocio

---

### Post 31 - Patrón State: Ciclo de Vida del Pedido

**Tematicas:** Gestión de estados con transiciones válidas e inválidas.
**Investigar:** State pattern GoF, state machines, transiciones de estado.
**Skill:** `/orders.add-state` — agrega transición de estado al pedido
**Implementar en `orders-service`:**
- Implementar patrón State para `OrderStatus`
- Crear interfaces: `OrderState` con métodos `pay()`, `ship()`, `cancel()`
- Crear implementaciones: `CreatedState`, `PaidState`, `ShippedState`, `DeliveredState`, `CancelledState`
- Cada estado define qué transiciones son válidas
- Las transiciones inválidas lanzan `InvalidOrderStateException`
- Crear tests que verifiquen todas las transiciones
**Claves:** Un pedido CREADO no puede enviarse sin pagar, uno CANCELADO no puede pagarse

---

### Post 32 - Patrón Strategy: Impuestos y Descuentos

**Tematicas:** Algoritmos intercambiables de cálculo.
**Investigar:** Strategy pattern GoF, tax calculation rules, discount strategies.
**Skill:** `/orders.add-strategy` — agrega estrategia de cálculo
**Implementar en `orders-service`:**
- Crear interfaz `TaxCalculator` (puerto inbound)
- Crear implementaciones: `StandardTaxCalculator`, `ReducedTaxCalculator`, `NoTaxCalculator`
- Crear interfaz `DiscountStrategy` (puerto inbound)
- Crear implementaciones: `PercentageDiscount`, `FixedAmountDiscount`, `BuyXGetYFreeDiscount`
- Inyectar estrategias según contexto (región, tipo de producto)
- Configurar estrategias por perfil
**Claves:** Las estrategias se eligen en tiempo de ejecución, no en compilación

---

### Post 33 - Orders Service: API REST Completa

**Tematicas:** Endpoints del Order Service con documentación completa.
**Implementar en `orders-service`:**
- POST /orders (crear pedido)
- GET /orders/{id} (consultar pedido)
- GET /orders?userId=X&status=Y (listar con filtros)
- POST /orders/{id}/pay (pagar pedido)
- POST /orders/{id}/ship (enviar pedido)
- POST /orders/{id}/cancel (cancelar pedido)
- Configurar Swagger con tags y ejemplos
- Agregar validación con Bean Validation
- Crear respuesta estándar `ApiResponse<T>`
**Claves:** El controller delega TODO al caso de uso, nunca contiene lógica de negocio

---

## Fase F: Payments Service

### Post 34 - Payments Service: Diseño del Dominio

**Tematicas:** Procesamiento de pagos, integración con pasarelas.
**Investigar:** Payment processing patterns, idempotency, PCI compliance basics.
**Implementar en `payments-service`:**
- Clonar template base
- Crear entidad: `Payment`
- Definir value objects: `PaymentId`, `PaymentMethod`, `PaymentStatus`, `Money`
- Definir eventos: `PaymentCompletedEvent`, `PaymentFailedEvent`, `PaymentRefundedEvent`
- Definir puertos: `ProcessPaymentUseCase`, `RefundPaymentUseCase`, `GetPaymentStatusUseCase`
- Definir puertos outbound: `PaymentRepository`, `PaymentGateway` (pasarela externa)
**Claves:** Los pagos deben ser idempotentes, un pago duplicado no debe cobrar dos veces

---

### Post 35 - Payments Service: Idempotencia en APIs

**Tematicas:** Procesamiento seguro de requests duplicados.
**Investigar:** Idempotency keys, deduplication strategies, exactly-once semantics.
**Skill:** `/payments.idempotent` — interceptor de idempotencia con Redis
**Implementar en `payments-service`:**
- Crear interceptor de idempotencia (`IdempotencyInterceptor`)
- Generar idempotency key por request
- Almacenar respuestas previas en Redis
- Retornar respuesta缓存 si la key ya fue procesada
- Crear endpoint: POST /payments (con idempotency key en header)
- Crear endpoint: GET /payments/{id}
**Claves:** El client envía un `X-Idempotency-Key` header, el server garantiza exactly-once

---

### Post 36 - Payments Service: Integration Test Completo

**Tematicas:** Tests end-to-end del flujo de pago.
**Implementar en `payments-service`:**
- Tests unitarios de casos de uso con mocks
- Tests de integración con Testcontainers (PostgreSQL + Redis)
- Tests de integración con WireMock (mock de pasarela de pagos)
- Test de idempotencia (enviar mismo request dos veces)
- Test de concurrencia (mismo pago desde dos threads)
- Test de arquitectura con ArchUnit
**Claves:** Cada escenario de pago debe tener su test (éxito, fallo, timeout, duplicado)

---

## Fase G: Notifications Service

### Post 37 - Notifications Service: Diseño del Dominio

**Tematicas:** Sistema de notificaciones multi-canal.
**Investigar:** Notification patterns, template engine, channel abstraction.
**Implementar en `notifications-service`:**
- Clonar template base
- Crear entidad: `Notification`
- Definir value objects: `NotificationType`, `NotificationChannel`, `NotificationStatus`
- Definir eventos: `NotificationSentEvent`, `NotificationFailedEvent`
- Definir puertos: `SendNotificationUseCase`, `ScheduleNotificationUseCase`
- Definir puertos outbound: `NotificationRepository`, `EmailSender`, `PushSender`, `SmsSender`
**Claves:** Cada canal es un adaptador separado, el dominio no conoce el canal específico

---

### Post 38 - Notifications Service: Consumo de Eventos con Kafka

**Tematicas:** Consumo de eventos de otros microservicios.
**Investigar:** Kafka consumers, consumer groups, offset management, dead letter queues.
**Skill:** `/notifications.add-consumer OrderPaidEvent` — consumer de eventos
**Implementar en `notifications-service`:**
- Agregar dependencias de Kafka
- Crear consumers para eventos de otros servicios
- Escuchar: `UserRegisteredEvent`, `OrderPaidEvent`, `OrderShippedEvent`, `PaymentCompletedEvent`
- Crear caso de uso: enviar email de bienvenida al registrarse
- Crear caso de uso: enviar confirmación de pago
- Crear caso de uso: enviar notificación de envío
- Configurar dead letter queue para mensajes fallidos
**Claves:** El consumer traduce evento de dominio → caso de uso → envío por canal

---

### Post 39 - Kafka vs RabbitMQ: Estudio Comparativo

**Tematicas:** Cuándo usar Kafka vs RabbitMQ en un sistema distribuido.
**Investigar:** Arquitectura de Kafka, arquitectura de RabbitMQ, use cases, trade-offs.
**Implementar (estudio):**
- Crear branch con implementación en Kafka
- Crear branch con implementación en RabbitMQ
- Comparar: throughput, latencia, durabilidad, consumo de recursos
- Documentar cuándo usar cada uno
- Crear tabla comparativa completa
- Mostrar configuración de ambos en el mismo microservicio
**Claves:** Kafka es mejor para event sourcing y streaming, RabbitMQ para tareas y colas simples

---

### Post 40 - RabbitMQ: Implementación Alternativa

**Tematicas:** Implementación del mismo dominio con RabbitMQ.
**Investigar:** RabbitMQ exchanges, routing keys, queues, acknowledgments.
**Implementar en `notifications-service` (branch alternativo):**
- Configurar RabbitMQ en Docker Compose
- Crear exchanges y queues para cada evento
- Implementar producers y consumers con RabbitMQ
- Comparar código con la implementación de Kafka
- Mostrar configuración de retry y dead letter en RabbitMQ
**Claves:** El puerto outbound de mensajería es el mismo, solo cambia el adaptador

---

## Fase H: Transacciones Distribuidas

### Post 41 - Saga Pattern: Orquestación

**Tematicas:** Coordinar transacciones entre servicios con un orquestador.
**Investigar:** Saga pattern, orchestration vs choreography, compensation actions.
**Skill:** `/orders.create-saga` — saga con pasos y compensaciones
**Implementar en `orders-service`:**
- Crear `OrderSaga` orquestador
- Definir flujo: Create Order → Reserve Inventory → Process Payment → Confirm Order
- Implementar acciones compensatorias: si pago falla → liberar stock → cancelar pedido
- Crear estado de la saga: PENDING, INVENTORY_RESERVED, PAYMENT_PROCESSED, COMPLETED, COMPENSATING, FAILED
- Persistir estado de la saga en BD
- Crear timeouts para cada paso
**Claves:** El orquestador es una clase de dominio, no un controller, gestiona el flujo completo

---

### Post 42 - Saga Pattern: Coreografía

**Tematicas:** Decoupling total con eventos reactivos entre servicios.
**Investigar:** Choreography-based saga, event-driven architecture, eventual consistency.
**Implementar (alternativa a Post 41):**
- Cada servicio publica eventos cuando completa su paso
- Orders publica `OrderCreatedEvent`
- Inventory escucha y reserva stock, publica `StockReservedEvent`
- Payments escucha y cobra, publica `PaymentCompletedEvent`
- Orders escucha y confirma el pedido
- Implementar compensación via eventos `StockReleaseRequestedEvent`
**Claves:** No hay orquestador central, cada servicio reacciona a eventos, más desacoplado pero más difícil de rastrear

---

### Post 43 - Transactional Outbox Pattern

**Tematicas:** Publicación confiable de eventos tras transacción local.
**Investigar:** Outbox pattern, polling publisher, CDC (Change Data Capture).
**Implementar en `orders-service`:**
- Crear tabla `outbox_events` en la misma BD del servicio
- En el caso de uso, escribir el evento en la tabla dentro de la misma transacción
- Crear un poller que lea eventos pendientes y los publique en Kafka
- Marcar eventos como publicados
- Configurar polling interval
- Mostrar cómo garantiza delivery at-least-once
**Claves:** El evento se escribe en la BD y se publica async, nunca se pierde un evento

---

## Fase I: CQRS y Event Sourcing

### Post 44 - CQRS: Separar Lectura y Escritura

**Tematicas:** Optimizar consultas masivas separando modelos.
**Investigar:** CQRS pattern, read models vs write models, projected views.
**Skill:** `/orders.add-cqrs` — modelo de lectura separado
**Implementar en `orders-service`:**
- Crear modelo de escritura: `Order` entity con JPA (PostgreSQL)
- Crear modelo de lectura: `OrderReadModel` proyectado desde eventos
- Crear caso de uso de escritura: `CreateOrderUseCase`
- Crear caso de uso de lectura: `GetOrderSummaryUseCase`
- Crear projector que escuche eventos y actualice el read model
- Los reads van a una tabla optimizada para consultas
**Claves:** El write model prioriza integridad, el read model prioriza velocidad de consulta

---

### Post 45 - Event Sourcing: Almacenar Eventos Inmutables

**Tematicas:** Cada cambio como evento, reconstrucción de estado.
**Investigar:** Event sourcing, event store, snapshots, replay.
**Implementar en `orders-service`:**
- Crear tabla `order_events` (event store)
- Cada operación guarda un evento inmutable: `OrderCreated`, `OrderPaid`, `OrderShipped`
- Crear función `rebuild()` que reconstruye el estado desde eventos
- Implementar snapshots cada N eventos para optimizar reconstrucción
- Crear endpoint: GET /orders/{id}/history (historial completo de cambios)
**Claves:** El estado actual es una función de todos los eventos pasados, nunca se borra nada

---

### Post 46 - Vistas Materializadas para Búsquedas

**Tematicas:** Consultas optimizadas alimentadas por eventos.
**Investigar:** Materialized views, read-optimized stores, denormalization.
**Implementar en `orders-service`:**
- Crear vistas materializadas en PostgreSQL para consultas frecuentes
- Proyectar datos de eventos en vistas: resumen de pedidos, métricas por usuario
- Crear refresh strategy (on-event o periódica)
- Crear endpoints optimizados: GET /orders/summary/{userId}, GET /orders/stats
- Mostrar rendimiento: query con CQRS vs query tradicional
**Claves:** Las vistas se actualizan cuando llegan eventos, no cuando se consulta

---

## Fase J: Observabilidad

### Post 47 - Micrometer + Prometheus

**Tematicas:** Métricas custom de negocio y técnicas.
**Investigar:** Micrometer, Prometheus, metric types (counter, gauge, histogram).
**Implementar en el template base (aplica a todos):**
- Agregar dependencias de Micrometer + Prometheus
- Configurar endpoint `/actuator/prometheus`
- Crear métricas custom: `orders_created_total`, `payments_processed_total`, `inventory_reservations_total`
- Crear métricas de tiempo: `order_processing_duration`
- Configurar Docker Compose con Prometheus
- Crear dashboard básico en Grafana
**Claves:** Cada microservicio expone sus métricas, Prometheus las recolecta, Grafana las visualiza

---

### Post 48 - OpenTelemetry: Distributed Tracing

**Tematicas:** Trazabilidad end-to-end entre microservicios.
**Investigar:** OpenTelemetry, traces, spans, context propagation.
**Implementar en el template base:**
- Agregar dependencias de OpenTelemetry
- Configurar exportación a Jaeger
- Inyectar trace ID en headers HTTP
- Propagar contexto entre servicios (Feign + Kafka)
- Crear span custom en casos de uso
- Configurar Jaeger en Docker Compose
**Claves:** Un solo trace ID permite rastrear una request desde el Gateway hasta el último servicio

---

### Post 49 - ELK Stack: Logs Centralizados

**Tematicas:** Agregación y búsqueda de logs distribuidos.
**Investigar:** ELK Stack, Filebeat, Logstash pipelines, Kibana dashboards.
**Implementar en el template base:**
- Agregar dependencia de logstash-logback-encoder
- Configurar logs en formato JSON estructurado
- Agregar campos custom: `service_name`, `trace_id`, `user_id`
- Configurar Docker Compose con Elasticsearch + Logstash + Kibana + Filebeat
- Crear pipeline en Logstash para enriquecimiento de logs
- Crear index patterns en Kibana
**Claves:** Todos los servicios loguean en JSON, Filebeat los envía, Logstash los procesa, Kibana los visualiza

---

### Post 50 - Structured Logging: Logs que se pueden buscar

**Tematicas:** Logs estructurados para consumo de herramientas.
**Investigar:** Structured logging, correlation IDs, MDC.
**Implementar en el template base:**
- Configurar Logback con layout JSON
- Agregar correlation ID a cada request via MDC
- Inyectar `trace_id`, `span_id`, `service_name` en cada log
- Crear helper class para logs de negocio
- Mostrar diferencia: log plano vs log estructurado
- Crear queries en Kibana para buscar por trace_id
**Claves:** Un log plano es inútil en producción, un log estructurado te permite buscar en milisegundos

---

## Fase K: Deploy y Producción

### Post 51 - Helm Charts para Kubernetes

**Tematicas:** Empaquetado y despliegue parametrizado en K8s.
**Investigar:** Helm, charts, values.yaml, templates, secrets management.
**Implementar en cada microservicio:**
- Crear Helm chart base (reutilizable)
- Parametrizar: imagen, replicas, resources, env vars
- Configurar ConfigMap y Secrets
- Configurar HPA (Horizontal Pod Autoscaler)
- Configurar ingress routes
- Crear values-dev.yaml y values-prod.yaml
**Claves:** Un solo chart sirve para todos los microservicios, solo cambian los values

---

### Post 52 - SonarQube: Análisis de Código Estático

**Tematicas:** Quality gates, deuda técnica, bugs y vulnerabilidades.
**Investigar:** SonarQube, quality profiles, sonarqube maven plugin.
**Implementar en el template base:**
- Agregar plugin de SonarQube en pom.xml
- Configurar SonarQube en Docker Compose
- Configurar quality gate (cobertura > 80%, 0 bugs, 0 vulnerabilities)
- Integrar con GitHub Actions (análisis en cada PR)
- Crear dashboard de métricas de código
**Claves:** El quality gate bloquea el merge si el código no cumple estándares

---

### Post 53 - Feature Flags

**Tematicas:** Habilitar/deshabilitar features sin redeploy.
**Investigar:** Feature toggle patterns, LaunchDarkly, Togglz.
**Implementar en el template base:**
- Agregar Togglz (feature flags para Java)
- Crear feature flags de ejemplo
- Configurar flags por profile
- Crear endpoint para cambiar flags en runtime
- Mostrar uso en código: `if (featureManager.isActive(Feature.NEW_CHECKOUT))`
**Claves:** Las feature flags permiten deploy continuo sin riesgo

---

### Post 54 - Blue/Green y Canary Deployments

**Tematicas:** Despliegues sin downtime con switch de tráfico.
**Investigar:** Blue/green, canary, rolling updates, traffic shifting.
**Implementar (estudio + configuración):**
- Configurar deployment blue/green en K8s
- Configurar canary con Istio o nginx-ingress
- Crear scripts de switch de tráfico
- Crear métricas de comparación entre versiones
- Documentar rollback strategy
**Claves:** Canary permite lanzar la nueva versión al 5% del tráfico y validar antes de escalar

---

## Resumen del Progreso

| Fase | Posts | Microservicio | Concepts | Skills |
|------|-------|--------------|----------|--------|
| Parte 1 | 01-17 | Template base | Profiles, Docker, Actuator, CI/CD, Hexagonal, Flyway, JPA, DTOs, Security, JWT, RBAC, Swagger, Validación, Testing | `hexagonal.scaffold`, `hexagonal.add-entity`, `hexagonal.add-usecase`, `hexagonal.add-event`, `hexagonal.add-test` |
| A | 18-21 | Users Service | DDD, Auth, JWT, RBAC | `hexagonal.scaffold` (clonar) |
| B | 22-24 | Products Service | Catálogo, Búsqueda, Redis | `hexagonal.add-entity`, `hexagonal.add-usecase` |
| C | 25-26 | Inventory Service | Stock, Concurrency | `hexagonal.add-entity`, `hexagonal.add-event` |
| D | 27-29 | Cart Service | OpenFeign, Resilience4j | `shared.add-feign-client`, `shared.add-circuit-breaker` |
| E | 30-33 | Orders Service | State, Strategy, API completa | `orders.add-state`, `orders.add-strategy` |
| F | 34-36 | Payments Service | Idempotencia, WireMock | `payments.idempotent` |
| G | 37-40 | Notifications Service | Kafka, RabbitMQ, comparativa | `notifications.add-consumer` |
| H | 41-43 | Transacciones | Sagas, Outbox | `orders.create-saga` |
| I | 44-46 | CQRS/ES | Event Sourcing, Vistas Materializadas | `orders.add-cqrs` |
| J | 47-50 | Observabilidad | Micrometer, Prometheus, OpenTelemetry, ELK | — |
| K | 51-54 | Producción | Helm, SonarQube, Feature Flags, Deploy | — |

**Total: 54 posts de LinkedIn + 13 skills de OpenCode**

---

## Orden de Ejecución Recomendado

```
1.  Parte 1 (Posts 01-17)  → Primero: establece la base sólida
2.  Users Service (18-21)  → Segundo: primer microservicio funcional
3.  Products (22-24)       → Tercero: dominio de catálogo
4.  Inventory (25-26)      → Cuarto: stock y concurrencia
5.  Cart (27-29)           → Quinto: comunicación sync entre servicios
6.  Orders (30-33)         → Sexto: el dominio más complejo
7.  Payments (34-36)       → Séptimo: pagos e idempotencia
8.  Notifications (37-40)  → Octavo: mensajería async (Kafka + RabbitMQ)
9.  Sagas (41-43)          → Noveno: transacciones distribuidas
10. CQRS/ES (44-46)        → Décimo: patrones avanzados
11. Observabilidad (47-50) → Onceavo: ver lo que pasa en producción
12. Producción (51-54)     → Último: deploy y operaciones
```

---

## Skills Reference

### Template-Level Skills (se crean en Parte 1, se reutilizan en todos los microservicios)

| Skill | Post | Descripción | Uso |
|-------|------|-------------|-----|
| `/hexagonal.scaffold` | Post 05 | Scaffolding completo de hexagonal para un nuevo microservicio | `/hexagonal.scaffold orders 8085` |
| `/hexagonal.add-entity` | Post 07 | Agrega entidad con todas las capas (domain → port → use case → adapter → controller) | `/hexagonal.add-entity Order` |
| `/hexagonal.add-usecase` | Post 07 | Agrega caso de uso con puerto inbound, implementación, endpoint REST | `/hexagonal.add-usecase CreateOrder POST /api/v1/orders` |
| `/hexagonal.add-event` | Post 10 | Agrega evento de dominio + outbox producer + consumer | `/hexagonal.add-event OrderCreatedEvent Order` |
| `/hexagonal.add-test` | Post 14-16 | Scaffolds tests por capa: unit, integration (testcontainers), architecture (archunit) | `/hexagonal.add-test Order` |

### Domain-Level Skills (se crean en la fase específica del dominio)

| Skill | Fase | Post | Descripción | Uso |
|-------|------|------|-------------|-----|
| `/orders.add-state` | E | 31 | Agrega transición de estado al patrón State del pedido | `/orders.add-state PAID SHIPPED ship()` |
| `/orders.add-strategy` | E | 32 | Agrega estrategia de cálculo (impuesto, descuento) | `/orders.add-strategy TaxCalculator ReducedTax` |
| `/orders.create-saga` | H | 41 | Crea saga orquestada con pasos y compensaciones | `/orders.create-saga OrderProcessing` |
| `/orders.add-cqrs` | I | 44 | Agrega modelo de lectura separado del de escritura | `/orders.add-cqrs Order OrderSummary` |
| `/payments.idempotent` | F | 35 | Agrega idempotency interceptor a un endpoint | `/payments.idempotent POST /api/v1/payments` |
| `/notifications.add-consumer` | G | 38 | Agrega consumer de eventos (Kafka o RabbitMQ) | `/notifications.add-consumer OrderPaidEvent kafka` |
| `/shared.add-feign-client` | D | 28 | Agrega cliente Feign para comunicación sync | `/shared.add-feign-client products-service` |
| `/shared.add-circuit-breaker` | D | 29 | Agrega Resilience4j a un adaptador outbound | `/shared.add-circuit-breaker productFeignClient` |

### Flujo de Uso

```
1. Clonar template base
2. /speckit.constitution           → Constitution actualizada
3. /hexagonal.scaffold orders 8085 → Estructura hexagonal
4. /hexagonal.add-entity Order     → Entidad con todas las capas
5. /hexagonal.add-usecase CreateOrder POST /api/v1/orders → Caso de uso + endpoint
6. /hexagonal.add-event OrderCreatedEvent Order → Evento + outbox + consumer
7. /hexagonal.add-test Order       → Tests unitarios, integration, architecture
8. ... (repetir 4-7 para cada entidad/caso de uso)
9. /orders.add-state PAID SHIPPED  → Patrón State
10. /orders.create-saga OrderProcessing → Saga con compensaciones
11. /orders.add-cqrs Order Summary → CQRS
12. /shared.add-feign-client products → Feign client
13. /shared.add-circuit-breaker productFeignClient → Resilience4j
```

---

*Documento generado como guía de implementación para el E-Commerce Distribuido.*
*Cada post implica: investigación → implementación → publicación en LinkedIn.*
*Cada skill se ejecuta con OpenCode para acelerar la implementación.*
