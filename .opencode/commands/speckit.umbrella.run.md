---
description: Run any umbrella workflow phase against a target repo (specs or a module) from the umbrella root. Never cd.
---

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

Expected shape: `/speckit.umbrella.run <target> <phase> [args]`

- `<target>` — where to work: `specs` | `umbrella` | a module name (e.g. `microservice-template`).
- `<phase>` — what to run: `specify` | `plan` | `tasks` | `implement` | `verify` | `fanout`.
- `[args]` — extra arguments passed through to the underlying phase. `specify`
  takes an optional feature name; if omitted, you derive it (see below).

## Operating model (binding)

El umbrella es la **única** sesión de trabajo. Nunca `cd` fuera de la raíz del
umbrella; nunca abras una sesión nueva dentro de un submodulo. Todos los paths
de abajo son relativos al umbrella; las operaciones git de submodulo usan
`git -C`; las de GitHub usan `gh` con el repo resuelto del remote del submodulo.

Tabla de targets:

| Target | Root on disk | Speckit context |
|--------|--------------|-----------------|
| `specs` | `modulos/specs-lib` | `SPECIFY_FEATURE_DIRECTORY=modulos/specs-lib/specs/NNN-name` |
| `umbrella` | `.` | umbrella's `.specify/feature.json` |
| `<module>` | `modulos/<module>` | module-mounted specs at `modulos/<module>/specs/specs/NNN-name` |

## Outline

1. **Resuelve el target** con la tabla de arriba. Target desconocido → STOP y
   pregunta. El feature dir `NNN-name` sale de `.specify/feature.json`, de
   `SPECIFY_FEATURE_DIRECTORY`, o de la feature más reciente bajo
   `modulos/specs-lib/specs/` — resuélvelo una vez y reutilízalo.

2. **Despacha la fase** (todos los comandos corren desde la raíz del umbrella):

   - **`specify [<feature>]`** → crear la feature en el repo de specs. El nombre
     sigue la convención `NNN-slug` (`BRANCHING.md`): `NNN` del número de post
     del ROADMAP, `slug` el título en kebab-case. Si no se da, derívalo del item
     del ROADMAP al que apunta el usuario (ej. "Post 01" →
     `001-spring-profiles`) y repórtalo. **Antes de crear la feature, garantiza
     la rama de specs** ejecutando
     `bash .specify/scripts/bash/ensure-spec-branch.sh --feature <feature>`
     (crea la rama en `modulos/specs-lib` desde `origin/main` — nunca del tag
     pineado; idempotente; aborta si el working tree está sucio, repórtalo al
     usuario para que lo resuelva). Luego setea
     `SPECIFY_FEATURE_DIRECTORY=modulos/specs-lib/specs/<feature>` para que los
     scripts speckit del umbrella resuelvan el feature dir correcto; sigue el
     comando `/speckit.specify` para el resto.
   - **`plan` / `tasks`** → corren contra el repo de specs con el mismo
     `SPECIFY_FEATURE_DIRECTORY`. Registra los **Affected Repositories** en
     `plan.md` (esto conduce el fan-out).
   - **`fanout`** → delega en `/speckit.umbrella-fanout.fanout` (base `main` por
     config, solo módulos afectados, `--dry-run` primero).
   - **`implement`** → trabajar en `<module>`:
     1. Lee `modulos/<module>/.specify/memory/.agent-context` (qué carpeta de
        specs aplica, orden de la cascada de constitution).
     2. Lee el task file del módulo en
        `modulos/<module>/specs/specs/NNN-name/tasks/<module>.md`.
     3. Lee la cascada de constitution: global primero
        (`modulos/<module>/specs/.specify/memory/constitution.md`), luego local
        (`modulos/<module>/.specify/memory/constitution.md`) si existe.
     4. Implementa las tasks del módulo escribiendo/editando archivos bajo
        `modulos/<module>/`. Corre builds/tests como subprocesos con el módulo
        como working dir (ej. `./mvnw test` dentro de `modulos/<module>`).
   - **`verify`** → a nivel módulo: corre el build/tests de
     `modulos/<module>`, revisa el task file del módulo; a nivel feature: revisa
     `tasks.md` y `checklists/` en el feature dir de specs (vía
     `SPECIFY_FEATURE_DIRECTORY` si hace falta). Reporta PASS/FAIL/PARTIAL.

3. **Nunca `cd`.** Si un helper de speckit necesita el root propio del target
   (un target con su propio `.specify/feature.json`), setea
   `SPECIFY_INIT_DIR=modulos/<target>` — si no, basta con
   `SPECIFY_FEATURE_DIRECTORY` + rutas relativas al umbrella.

## Completion Report

Reporta: target usado, fase corrida, feature dir, archivos cambiados (con rutas
relativas al umbrella) y lo que el usuario debe hacer después (ej. PRs, tag).

## Done When

- [ ] La fase corrió contra el target pedido con archivos bajo `modulos/<target>` (o specs) — sin `cd`, sin sesión nueva
- [ ] El feature dir `NNN-name` se resolvió y reportó consistentemente entre pasos
- [ ] Las fases de módulo respetaron `.agent-context` y la cascada de constitution
- [ ] Resumen reportado al usuario
