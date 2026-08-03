# 01 — Conceptos: los 3 repos y el flujo

> Paso de **teoría**. No cambia nada en el repo. Léelo con calma; todo lo demás
> asume que entiendes esto.

## 1. Los repos y sus roles

| Repo | Rol | Contiene | Nota |
|------|-----|----------|------|
| `umbrella` | **Orquesta** | docs, reglas (`AGENTS.md`, `BRANCHING.md`, `CONTRIBUTING.md`), los módulos como submodulos | **Nunca** código de implementación |
| `specs` | **Fuente de verdad** | requirements, contracts, planes, constitution global | Versionado con tags `spec-vMAJOR.MINOR.PATCH` |
| `<módulo>` (ej. `microservice-template`) | **Implementa** | el código real de un servicio | Consume `specs` como submodulo pineado |

El umbrella existe para que **una sola sesión de trabajo** (una sola carpeta)
pueda orquestar la spec, los módulos y las ramas sin ir saltando de repo en
repo.

## 2. Por qué specs se monta DOS veces

El repo `specs` es un submodulo en dos lugares:

```
umbrella/
├── modulos/specs-lib/          ← referencia del umbrella a la spec
└── modulos/<módulo>/specs/     ← copia de trabajo dentro de cada módulo
```

Ambos apuntan al **mismo tag** (`spec-v1.0.0`). Esto significa que:

- La constitution global es **una sola copia física** (en el repo specs) y todos
  la ven igual, desde cualquier módulo.
- Cuando el código de un módulo se abre en GitHub, la spec viaja con él (el
  submodulo está dentro del módulo).

## 3. GitHub Flow + tags + pinning

- **GitHub Flow**: `main` es la única rama base y siempre debe estar buildable.
  Todo trabajo va en ramas cortas (`NNN-slug`) → PR → merge → borrar rama. No
  hay `develop` ni `release/*`.
- **`specs` se versiona con tags** `spec-vX.Y.Z`. Cada merge de spec = nuevo tag
  + entrada en `CHANGELOG.md`.
- **Ningún módulo sigue `main` de specs**: cada submodulo de specs queda
  **pineado a un tag fijo**. Mover el puntero es SIEMPRE un acto explícito.
  Un módulo puede quedarse en una versión anterior mientras termina su trabajo;
  no bloquea a nadie.

## 4. Constitution en cascada

Dentro de un módulo se lee la constitution en este orden:

1. **GLOBAL primero**: `modulos/<módulo>/specs/.specify/memory/constitution.md`
   (viene del submodulo de specs — misma versión para todos).
2. **LOCAL después** (solo si existe): `modulos/<módulo>/.specify/memory/constitution.md`
   — overrides puntuales (ej. el framework de testing del lenguaje). Nunca
   contradice la global.

## 5. Operating model: todo desde la raíz del umbrella

Regla de hierro: **nunca `cd` a un submodulo ni abras sesión dentro de uno**.
Todo se resuelve desde la raíz:

- Archivos con rutas relativas al umbrella: `modulos/...`.
- Git de un submodulo con `git -C modulos/<m> ...`.
- GitHub con `gh`, resolviendo el repo desde el remote del submodulo.
- El contexto speckit con `SPECIFY_FEATURE_DIRECTORY=modulos/<target>/...`.

## 6. El ciclo de vida de una feature

Una feature es **una spec** (por feature, no por módulo) en el repo specs, en
`specs/NNN-name/`. Si toca varios repos, solo se dividen las **tasks**:

```
specs/NNN-checkout-flow/
├── spec.md              ← UNA spec para todos los repos
├── plan.md              ← sección "Affected Repositories": backend, bff, ...
├── tasks.md             ← tasks de orquestación/compartidas
└── tasks/
    ├── backend.md       ← task file por repo
    └── bff.md
```

El ciclo completo (lo implementarás a mano en el paso 10):

1. **Specify** — crear `specs/NNN-name/` + `spec.md`.
2. **Plan** — generar plan + **Affected Repositories** (esto decide el fan-out).
3. **Fan out** — crear la rama de la feature en specs y en cada módulo afectado.
4. **Tasks** — generar `tasks.md` y los task files por repo.
5. **Implement** — en cada módulo, leer su `.agent-context` → su task file →
   la cascada de constitution → ejecutar sus tasks.
6. **Verify** — tasks marcadas, checklists verdes, tests del módulo pasan.
7. **Deliver** — PR por módulo, PR en specs, tag `spec-vX.Y.Z`, y cada módulo
   actualiza su puntero al tag cuando decide.

## 7. Auto-naming de ramas

Los nombres `NNN-slug` los **deriva el asistente del ROADMAP**, no se escriben a
mano. `NNN` = número del post, `slug` = título en kebab-case. Ej: Post 03
("Actuator + Health Checks") → `003-actuator-health-checks`. Un solo nombre de
rama por feature en **todos** los repos que toca, para que los PRs se alineen.

## Checklist de comprensión

- [ ] ¿Por qué specs se monta en 2 lugares?
- [ ] ¿Qué significa "pinear a un tag" y por qué no `main`?
- [ ] ¿Cuál es el orden de la cascada de constitution?
- [ ] ¿De dónde sale el nombre de una rama de feature?
- [ ] ¿En qué archivo se declaran los módulos afectados por una feature?

Cuando lo tengas claro, pasa al paso 02.
