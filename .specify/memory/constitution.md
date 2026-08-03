<!--
Sync Impact Report
- Version change: none (template) -> 1.0.0
- Modified principles: n/a (first ratification)
- Added sections: Core Principles (I-V), Additional Constraints (Constitution cascade),
  Development Workflow, Governance
- Removed sections: n/a
- Templates requiring updates: all bundled templates left untouched (aligned)
- Follow-up TODOs: none
-->

# Umbrella Constitution

Constitution global del proyecto multi-repo (orquestado por `umbrella`). Aplica a
todos los módulos por igual. Los módulos pueden agregar overrides locales
puntuales (framework de testing del lenguaje, etc.) que NUNCA contradicen estos
principios.

## Core Principles

### I. Spec-First (NON-NEGOTIABLE)

Nada se implementa sin una spec aprobada. Toda especificación vive en el repo de
specs, versionada con tags `spec-vMAJOR.MINOR.PATCH`. Ningún módulo sigue `main`
del repo de specs: cada submodule queda pineado a un tag fijo. Actualizar la spec
de un módulo es SIEMPRE un acto explícito, nunca automático.

### II. Cambio de spec controlado por PR

Todo cambio de spec se propone por PR en el repo de specs (nunca editar `main`
directo), pasa review y aprobación con branch protection, y al mergear genera un
nuevo tag semver + entrada en `CHANGELOG.md`. Recién ahí cada módulo decide
cuándo actualizar su puntero. Un módulo puede quedarse en una versión anterior
mientras termina su implementación actual; no bloquea a nadie.

### III. Quality Before Quantity

Código simple, legible y deliberado. Se prefiere la solución más pequeña que
funciona (YAGNI); el código nunca se escribe "por si acaso". Toda complejidad
debe estar justificada y documentada. La deuda técnica es una excepción explícita,
nunca la norma.

### IV. Testing is Non-Negotiable

Todo código nuevo o modificado incluye pruebas. Se sigue la pirámide de testing:
la mayoría unitarias, las de integración donde hay contratos o bordes de sistema,
y las end-to-end donde el flujo lo justifica. Ningún cambio se mergea sin
verificación. Los detalles de framework por lenguaje son overrides locales, no
disminuyen la obligación.

### V. Arquitectura compartida con bordes claros

Los módulos comparten criterios de arquitectura: separación de dominio vs.
infraestructura, dependencias que apuntan hacia adentro (el dominio no depende de
la infraestructura), y contratos explícitos entre servicios. Los detalles
específicos de stack viven en la constitution local de cada módulo, no en esta.

## Additional Constraints

### Constitution cascade

La constitution se lee en cascada:
1. Primero la GLOBAL: `modulos/<modulo>/specs/.specify/memory/constitution.md`
   (este archivo, desde el submodule de specs, misma versión para todos).
2. Después la LOCAL del módulo si existe: `modulos/<modulo>/.specify/memory/constitution.md`
   — solo overrides puntuales, nunca contradice los principios globales.

## Development Workflow

- Feature = una spec por feature, no por módulo. Las tasks se dividen por repo
  (`specs/NNN-name/tasks/<repo>.md`) y el `.agent-context` de cada repo apunta a
  su task file.
- Antes de implementar dentro de un módulo, se lee la cascada de constitution y
  el `.agent-context` del módulo.
- Un commit por unidad lógica de trabajo, con mensaje descriptivo.
- El fan-out de branches entre módulos afectados es manual con git plano (o con
  la automatización propia cuando exista), nunca con herramientas de terceros.

## Governance

- Esta constitution es la fuente de verdad global; las constituciones locales la
  complementan, nunca la contradicen.
- Las enmiendas a principios globales siguen el mismo flujo que el cambio de
  spec: PR en el repo de specs → review → aprobación → nuevo tag `spec-vX.Y.Z` +
  `CHANGELOG.md` → cada módulo actualiza su puntero cuando decide.
- Versioning: MAJOR para cambios incompatibles de governance, MINOR para
  principios/secciones nuevas, PATCH para aclaraciones.
- Toda review debe verificar cumplimiento de estos principios.

**Version**: 1.0.0 | **Ratified**: 2026-08-03 | **Last Amended**: 2026-08-03
