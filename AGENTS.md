# AGENTS.md

Reglas vinculantes para agentes que trabajan en este repo. Si eres un agente,
léelas antes de tocar nada.

## Qué es este repo

`umbrella` es el repo orquestador de un proyecto multi-repo construido con Spec
Kit (speckit). No contiene código de implementación: pinear shared specs y los
módulos de implementación (cada uno en su propio repo) como git submodules.

La estructura objetivo:

```
. (this repo, umbrella)
├── .specify/                          Spec Kit para todo el proyecto
│   └── memory/constitution.md         GLOBAL constitution
├── modulos/
│   ├── specs-lib/                     submodule → specs repo, pineado a un tag
│   ├── <module-1>/                    submodule → repo de implementación
│   │   ├── specs/                     submodule → mismo specs repo, mismo tag
│   │   └── .specify/memory/
│   │       ├── .agent-context
│   │       └── constitution.md        LOCAL overrides (opcional)
│   └── <module-N>/ ...
├── CONTRIBUTING.md                    proceso de cambio de specs
└── README.md
```

## Reglas

1. El umbrella es la única sesión de trabajo: NUNCA `cd` a un submodulo.
2. Rutas relativas al umbrella (`modulos/...`), git de submodulo con `git -C`,
   GitHub con `gh` (repo resuelto del remote del submodulo).
3. Constitution en cascada: global primero
   (`modulos/<m>/specs/.specify/memory/constitution.md`), local después
   (`modulos/<m>/.specify/memory/constitution.md`).
4. Submodulos de specs SIEMPRE pineados a tags, nunca a `main`. Actualizar
   punteros es un acto explícito (ver CONTRIBUTING.md).
5. Feature = una spec por feature; las tasks se dividen por repo y el
   `.agent-context` de cada módulo apunta a su task file.
6. **PRs siempre squash-merge, y el merge lo hace el humano.** El agente crea y
   sube el PR pero NUNCA lo mergea: entrega el PR y avisa al usuario para que lo
   mergee él (`gh pr merge <n> --squash --delete-branch`).

## Reglas vinculantes del original (no negociables)

Estas reglas del proyecto no se rompen. No las incumplas.

1. **Las specs viven en un repo separado**, versionadas con tags semver
   `spec-vMAJOR.MINOR.PATCH`.
2. **Ningún módulo sigue `main` del repo de specs.** Todo submodulo está
   pineado a un commit/tag fijo. Actualizar las specs de un módulo es SIEMPRE
   un acto explícito, nunca automático.
3. **La constitution se lee en cascada.** Al implementar dentro de un módulo,
   lee primero la global (`modulos/<module>/specs/.specify/memory/constitution.md`),
   luego la local del módulo (`modulos/<module>/.specify/memory/constitution.md`)
   si existe — el archivo local solo añade overrides puntuales.
4. **Los cambios de specs siempre pasan por el proceso de `CONTRIBUTING.md`**:
   PR en el repo specs (nunca editar `main` directo) → review y aprobación →
   tag nuevo + entrada en `CHANGELOG.md` → cada módulo actualiza su puntero de
   forma explícita cuando lo decide. Un módulo puede quedarse en una versión
   anterior mientras termina su trabajo actual; no bloquea a nadie.

## Trabajando en un módulo

- Antes de implementar en `modulos/<module>`, lee la cascada de constitution
  (global primero, luego overrides locales).
- Revisa `modulos/<module>/.specify/memory/.agent-context` para saber qué
  carpeta de `specs/specs/` aplica a ese módulo.
- Nunca muevas un submodulo de specs a un tag nuevo por tu cuenta. Propón el
  cambio de spec primero por el flujo de PR del repo specs.

## Referencias

- `CONTRIBUTING.md` — proceso de cambio de specs.
- `BRANCHING.md` — convención de ramas (GitHub Flow, todos los repos).
- `docs/WORKFLOW.md` — workflow end-to-end (bootstrap, ciclo de vida de
  features, fan-out manual de ramas entre módulos).
- `docs/ROADMAP.md` — roadmap del proyecto.
