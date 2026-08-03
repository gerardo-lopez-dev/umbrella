# Flujo de ejemplo — ROADMAP Parte 1 · Post 01

> **Feature:** *Spring Profiles y Configuración 12-Factor*
> **Repos afectados (Affected Repositories):** `microservice-template`
> **Rama de feature:** `001-spring-profiles`
> **Tag de specs al terminar:** `spec-v1.1.0`
> **Branching:** GitHub Flow — base siempre `main` (`BRANCHING.md`)
> Versión interactiva: [`flujo-ejemplo-post01.html`](./flujo-ejemplo-post01.html)

**Convención de ramas (GitHub Flow — `BRANCHING.md`):** `main` es la única
troncal y está protegida (1 review + CI `build` obligatorios). La rama feature
nace **siempre del último `origin/main`**, se mergea vía PR y se borra. Los tags
`spec-vX.Y.Z` son el punto de integración de specs, no una rama `develop`.

Este es el recorrido end-to-end de una feature por el workflow del umbrella
(`docs/WORKFLOW.md`). Cada paso indica **dónde** corre (qué target), **qué** se
hace y **cuál es el resultado esperado**.

> **Todo se ejecuta desde la raíz del umbrella.** Nunca hay que `cd` a specs o a
> un módulo: los archivos se tocan con paths del root (`modulos/...`), el git de
> submodules con `git -C modulos/<m>`, y el contexto speckit se resuelve con
> `SPECIFY_FEATURE_DIRECTORY=modulos/<target>/...`. Un solo comando para
> despachar fases: **`/speckit.umbrella.run <target> <phase>`**.

| Target | Dónde vive en el umbrella | Fases |
|--------|---------------------------|-------|
| `specs` | `modulos/specs-lib/` | `specify`, `plan`, `tasks` |
| `umbrella` | `.` | `fanout` (rama a los afectados) |
| `microservice-template` | `modulos/microservice-template/` | `implement`, `verify` |

```
repos implicados:

  umbrella/  ── orchestrates, no code
    ├── modulos/specs-lib/              specs (fuente de verdad) — mounted 2x
    └── modulos/microservice-template/  implementación del Post 01
```

---

## Paso 0 — Sincronizar el workspace

**Repo:** `umbrella` (root) · **Rol:** preparar los submodules

```sh
git submodule update --init --recursive
```

**Resultado:** los submodules están materializados y pineados:
`specs-lib` y `microservice-template/specs` en `spec-v1.0.0`,
`microservice-template` en su `main`.

---

## Paso 1 — Especificar (Specify)

**Target:** `specs` (`modulos/specs-lib`) · **Comando:** `/speckit.umbrella.run specs specify <feature>`

```sh
# desde la raíz del umbrella — target specs
/speckit.umbrella.run specs specify 001-spring-profiles
```

Equivale a trabajar en el repo de specs (sus archivos viven en `modulos/specs-lib/`).
Crea la rama `001-spring-profiles` en el repo de specs y el directorio de la
feature:

```
specs/001-spring-profiles/
└── spec.md        # user stories del Post 01 (profiles local/dev/prod/test, 12-factor, validación de env)
```

**Resultado:** feature ramificada en specs, `spec.md` con las historias de
usuario del Post 01.

---

## Paso 2 — Planificar (Plan)

**Target:** `specs` · **Comando:** `/speckit.umbrella.run specs plan`

```sh
# desde la raíz del umbrella
/speckit.umbrella.run specs plan
```

**Qué hace:** genera `research.md`, `plan.md`, `data-model.md`, `contracts/`.
En `plan.md` se registra el listado **Affected Repositories**:

```markdown
## Affected Repositories
- microservice-template
```

**Hook `after_plan`:** el hook de nuestra extensión `umbrella-fanout` (opcional)
te ofrece lanzar el fan-out ya. Lo lanzamos en el paso siguiente.

---

## Paso 3 — Fan-out de la rama (extensión o git manual)

**Target:** `umbrella` (rama a specs + módulos afectados) · **Comando:** `/speckit.umbrella.run umbrella fanout`

```sh
# desde la raíz del umbrella
/speckit.umbrella.run umbrella fanout --plan modulos/specs-lib/specs/001-spring-profiles/plan.md --dry-run
# si se ve bien, sin --dry-run
```

Equivale al git manual de `WORKFLOW.md` §4:

```sh
git -C modulos/specs-lib checkout -b 001-spring-profiles
git -C modulos/microservice-template fetch origin
git -C modulos/microservice-template checkout -b 001-spring-profiles origin/main
```

**¿De `main` o `develop`?** — la base es `main` por defecto (config
`umbrella_fanout.base`), y la rama feature nace del último `origin/main`
post-fetch (fallback: `main` local). La rama de specs se crea en el Paso 1
desde la troncal de specs (hoy `main`; no hay `develop`). Si algún módulo
tuviera una troncal `develop`, se fuerza con `--base`:

```sh
.specify/scripts/bash/fanout.sh --branch 001-spring-profiles --base develop -m microservice-template
```

**Resultado:** la rama `001-spring-profiles` existe en **specs** y en
**microservice-template**, cada una con su base correcta. Solo en los repos
afectados — no en todos.

---

## Paso 4 — Tasks

**Target:** `specs` · **Comando:** `/speckit.umbrella.run specs tasks`

```sh
# desde la raíz del umbrella
/speckit.umbrella.run specs tasks
```

**Qué hace:** genera `tasks.md` (compartidas) y el archivo por módulo:

```
specs/001-spring-profiles/
├── tasks.md                        # orquestación / compartidas
└── tasks/
    └── microservice-template.md    # tareas que implementará el template
```

**Hook `after_tasks`:** vuelve a ofrecer el fan-out (idempotente — la rama ya
existe, no hace nada destructivo).

---

## Paso 5 — Implementar

**Target:** `microservice-template` · **Comando:** `/speckit.umbrella.run microservice-template implement`

```sh
# desde la raíz del umbrella
/speckit.umbrella.run microservice-template implement
```

Preparación (git del submodule desde el umbrella — ya lo hizo el fan-out):

```sh
git -C modulos/microservice-template checkout 001-spring-profiles
git -C modulos/microservice-template/specs checkout 001-spring-profiles
```

**Qué hace:** lee `.specify/memory/.agent-context` → su task file
(`tasks/microservice-template.md`) → constitution en cascada (global primero,
overrides locales si existen) → implementa las tareas del Post 01.

**Resultado esperado (del Post 01):**
- `src/main/resources/application-{local,dev,prod,test}.yaml`
- `.env.example` documentado
- validación de variables de entorno al arranque

---

## Paso 6 — Verificar

**Target:** `microservice-template` (módulo) + `specs` (feature) · **Comando:** `/speckit.umbrella.run microservice-template verify`

```sh
# desde la raíz del umbrella
/speckit.umbrella.run microservice-template verify
```

**Qué hace:** verifica el task file del módulo, corre su build/tests
(`./mvnw test` en `modulos/microservice-template`), y que la implementación
coincide con `spec.md`/contracts de la feature.

**Resultado:** veredicto PASS / FAIL / PARTIAL con evidencia.

---

## Paso 7 — Entregar (Deliver)

**Targets:** todos (git/gh desde el umbrella) · **Rol:** cerrar la feature y publicar el nuevo tag

1. **PR en `microservice-template`** — la implementación de la rama
   `001-spring-profiles` → `main`. Obligatorio por la branch protection
   (1 review + CI `build`); se borra la rama al mergear.
2. **PR en `specs`** — feature branch `001-spring-profiles` → `main`
   (tasks checkeadas, contracts actualizados) → merge.
3. **Tag + CHANGELOG** en specs:

   ```sh
   git -C modulos/specs-lib tag spec-v1.1.0
   # + entrada en CHANGELOG.md
   ```

4. **Cada módulo decide** cuándo mover su pointer (nunca automático):

   ```sh
   git -C modulos/microservice-template/specs checkout spec-v1.1.0
   git -C modulos/microservice-template add specs
   git -C modulos/microservice-template commit -m "chore: pin specs to spec-v1.1.0"
   ```

**Resultado:** el template base queda con el Post 01 implementado y specs en
`spec-v1.1.0`. El siguiente post (02 · Docker) repite el mismo ciclo.

> **Módulos nuevos:** al agregar un microservicio, su `main` se protege igual
> con `.specify/scripts/bash/module-bootstrap.sh <module>` (1 review + CI
> autodetectada). Convención en `BRANCHING.md`.

---

## Resumen del ciclo (una feature = un ciclo)

| Paso | Comando (desde el umbrella) | Target | Resultado |
|------|----------------------------|--------|-----------|
| 0 | `git submodule update --init --recursive` | umbrella | submodules listos |
| 1 | `/speckit.umbrella.run specs specify 001-spring-profiles` | specs | rama + `spec.md` |
| 2 | `/speckit.umbrella.run specs plan` | specs | `plan.md` + Affected Repositories |
| 3 | `/speckit.umbrella.run umbrella fanout` | specs + template | rama en los repos afectados (base `main`) |
| 4 | `/speckit.umbrella.run specs tasks` | specs | `tasks/` por módulo |
| 5 | `/speckit.umbrella.run microservice-template implement` | módulo | código del Post 01 |
| 6 | `/speckit.umbrella.run microservice-template verify` | módulo + specs | PASS/FAIL |
| 7 | PRs obligatorios + tag `spec-v1.1.0` + pointer update | todos | feature cerrada |

**Regla de oro:** todo se ejecuta desde la raíz del umbrella (nunca `cd`);
fan-out solo a los repos que toca la feature; base siempre `main`; PR obligatorio
en `main` (branch protection); el pointer de specs de cada módulo se actualiza
explícitamente, nunca en automático.
