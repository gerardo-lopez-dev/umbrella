# Cómo hacer una feature — flujo automatizado con paradas humanas

> Guía **genérica y reutilizable** para implementar cualquier feature del ROADMAP
> en este proyecto multi-repo. Una feature es **UNA spec** (`NNN-slug`) que vive
> en el repo de specs y se implementa en 1..N módulos. Todo se ejecuta **desde la
> raíz del umbrella**, sin `cd` a ningún submodulo.
>
> Comandos con placeholders:
>
> | Placeholder | Significado | Ejemplo |
> |-------------|-------------|---------|
> | `NNN-slug` | Nombre de feature **y** de rama (igual en todos los repos) | `002-docker` |
> | `<module>` | Módulo afectado | `microservice-template` |
> | `spec-v<X.Y.Z>` | Tag semver nuevo del repo de specs | `spec-v1.0.3` |
>
> **Referencias**: reglas vinculantes en `AGENTS.md` · workflow completo en
> `docs/WORKFLOW.md` · ramas en `BRANCHING.md` · cambio de specs en
> `CONTRIBUTING.md` · estado del proyecto en `doctor.sh`.

---

## El ciclo en una línea

```
specify → plan → tasks → fanout → implement → verify → deliver
```

- Las fases de **spec** (`specify`, `plan`, `tasks`) corren contra el repo de
  specs (`target = specs`).
- El **fanout** corre contra el umbrella (`target = umbrella`).
- Las fases de **implementación** (`implement`, `verify`) corren contra cada
  módulo (`target = <module>`).
- **Deliver** lo automatiza `deliver.sh` (PRs → tag → punteros → cierre).

## Reglas de oro (operating model — no negociables)

1. **El umbrella es la única sesión de trabajo.** Nunca `cd` a un submodulo ni
   abras una sesión dentro de uno.
2. **Ficheros** con rutas relativas al umbrella (`modulos/...`).
3. **Git de submodulo** con `git -C modulos/<m> ...`.
4. **GitHub** con `gh`, resolviendo el repo del remote del submodulo.
5. **Punto de entrada único**: `/speckit.umbrella.run <target> <phase>`.
6. **Nombres `NNN-slug`**: `NNN` = número de post del ROADMAP, `slug` el título
   en kebab-case. El nombre lo **deriva el asistente** del ROADMAP, no se teclea.
   **Mismo nombre de rama en todos los repos** que toca la feature.
7. **Los PRs los mergea el HUMANO (squash), nunca el agente** (`AGENTS.md`
   regla 6). El agente crea y sube el PR y avisa; el dueño ejecuta
   `gh pr merge <n> --squash --delete-branch`.

| Target | Root en disco | Fases |
|--------|---------------|-------|
| `specs` | `modulos/specs-lib` | `specify`, `plan`, `tasks` |
| `umbrella` | `.` | `fanout` |
| `<module>` | `modulos/<module>` | `implement`, `verify` |

---

## Puntos de parada (los tuyos)

El flujo corre solo entre paradas. Los gates humanos (ver tabla canónica en `.opencode/commands/speckit.umbrella.feature.md`):

| # | Cuándo | Qué haces |
|---|--------|-----------|
| **G1** | Tras `specify` | Revisas/apruebas `spec.md` (la spec es la fuente de verdad) |
| **G2** | Tras `plan` | Apruebas los **affected repos** y el technical context (conduce el fan-out) |
| **G3** | Tras `tasks` | Apruebas `tasks.md` y task files por módulo |
| **G4** | Tras `implement` | Apruebas la implementación del módulo |
| **G5** | Tras `verify` (si hubo fixes) | Apruebas los fixes |
| **G6** | `deliver.sh` crea los PRs | Squash-mergeas el PR del módulo + el PR de specs (`gh pr merge --squash --delete-branch`) |
| **G7** | `deliver.sh` crea los PRs chore | Squash-mergeas los PRs chore de módulo + umbrella

Todo lo demás (`tasks`, `fanout`, `implement`, `verify`, `prs`, `tag`, `pin`,
`close`) lo corre el agente. La versión del tag (`--bump patch|minor|major`,
patch por defecto) se confirma en el primer run de `deliver.sh`.

---

## Fase 0 — Preflight

Materializa submodulos y comprueba que todo está sano (reemplaza la Fase 0
manual y la "Verificación final"):

```sh
git submodule update --init --recursive
bash .specify/scripts/bash/doctor.sh --fetch
```

`doctor.sh` verifica materialización, árboles limpios, pins a tag y consistencia
entre `specs-lib` y los `specs` de cada módulo. Salida no cero → resuelve antes
de seguir. Estado de una feature: `doctor.sh --feature <NNN-slug>`.

---

## Fase 1 — Specify (la spec)

La spec vive en el repo `specs`, montado en `modulos/specs-lib`. El wrapper
crea la rama por ti desde `origin/main`, nunca del tag pineado:

```
/speckit.umbrella.run specs specify NNN-slug
```

Detrás de escena: `ensure-spec-branch.sh --feature NNN-slug` (idempotente,
aborta si el working tree de specs-lib está sucio) + delegación al subagente
`spec-writer`, que scaffolding y escribe `spec.md` (no commitea: el agente primario lo hace tras G1).

**→ PUNTO DE PARADA G1**: revisa `modulos/specs-lib/specs/NNN-slug/spec.md`.

---

## Fase 2 — Plan (afectados + plan.md)

```
/speckit.umbrella.run specs plan
```

El subagente `spec-writer` completa `plan.md` (Technical Context, Constitution
Check) y registra los módulos afectados — lo que conduce el fan-out:

```markdown
## Affected Repositories

- <module> (<rol en la feature>)
```

**→ PUNTO DE PARADA G2**: aprueba los affected repos y el technical context.

---

## Fase 3 — Tasks (divididas por repo)

```
/speckit.umbrella.run specs tasks
```

Genera `tasks.md` (orquestación) y, para features multi-repo, un task file por
módulo bajo `specs/NNN-slug/tasks/<module>.md`. El agente primario commitea tras G3.

---

## Fase 4 — Fan-out (la rama llega a los módulos)

```
/speckit.umbrella.run umbrella fanout
```

Crea la rama `NNN-slug` en cada módulo afectado desde `origin/main` (config
`umbrella_fanout.base`). Solo los módulos del plan. `--dry-run` primero; si un
módulo está sucio lo salta y lo reporta.

---

## Fase 5 — Implement (dentro de cada módulo)

Repite por cada módulo afectado:

```
/speckit.umbrella.run <module> implement
```

El agente lee `.agent-context`, la cascada de constitution (global primero,
overrides locales después) y el task file del módulo. **Resolución del task
file**: si el submódulo `specs/` del módulo (tag viejo) no tiene aún la
feature, se lee desde `modulos/specs-lib/specs/NNN-slug/tasks/<module>.md`.

---

## Fase 6 — Verify

Por módulo:

```
/speckit.umbrella.run <module> verify
```

Cuenta tasks `- [ ]` vs `- [X]` en el task file, corre build/tests y da
veredicto **PASS** (o FAIL/PARTIAL). Si algo falla, se arregla antes de seguir.

---

## Fase 7 — Deliver (automatizada)

**El agente** corre la Fase 7 con un solo comando, idempotente y reanudable:

```sh
# primer run: crea PRs (módulo(s) + specs), marca tasks [X], entrada CHANGELOG
bash .specify/scripts/bash/deliver.sh NNN-slug prs --dry-run   # plan primero
bash .specify/scripts/bash/deliver.sh NNN-slug prs

# tras tus merges, el agente retoma con:
bash .specify/scripts/bash/deliver.sh NNN-slug --resume --dry-run
bash .specify/scripts/bash/deliver.sh NNN-slug --resume
```

Qué hace cada etapa (todo automático, cada una para en el merge que toca):

| Etapa | Qué hace | Tu parada |
|-------|----------|-----------|
| `prs` | push ramas de módulos + `gh pr create` por módulo y para specs; marca tasks `[X]`; entrada CHANGELOG con la versión propuesta | **G6**: mergea módulo + specs |
| `tag` | verifica que todos los PRs de feature están MERGED, crea `spec-v<X.Y.Z>` sobre `main` de specs y lo pushea | — |
| `pin` | rama `chore-spec-v<X.Y.Z>` por módulo (sube SU specs al tag) y rama `chore-spec-v<X.Y.Z>` en el umbrella (specs-lib al tag, módulo a `origin/main`) | **G7**: mergea chores de módulo + umbrella |
| `close` | verifica el merge del umbrella, corre `doctor.sh --fetch`, limpia ramas locales huérfanas | — |

> El número de versión sigue semver: PATCH por feature compatible (default),
> MINOR/MAJOR con `--bump minor|major`. El tag nuevo es el punto que los
> módulos pinean. Actualizar el puntero de specs de un módulo sigue siendo un
> **acto explícito** (`CONTRIBUTING.md`): nunca automático, siempre en su rama
> chore con su PR.

---

## Verificación final

```sh
bash .specify/scripts/bash/doctor.sh --fetch        # todo sano (0 = PASS)
bash .specify/scripts/bash/doctor-test.sh           # self-check del doctor
bash .specify/scripts/bash/deliver-test.sh          # self-check del deliver
```

El README del umbrella referencia `doctor.sh` como fuente de verdad del estado
verificado — no se escribe a mano.

---

## Y después

Cada post del ROADMAP se implementa igual: **una feature por post, una rama
`NNN-slug`, un PR por repo**, y solo la Fase 7 (PR specs → tag → punteros) toca
el versionado. Cuando la base compartida esté completa y toque un nuevo
servicio (ej. `users-service`), se clona el template base y se repite el mismo
ciclo — añadiendo el módulo nuevo con branch protection vía
`bash .specify/scripts/bash/module-bootstrap.sh <module>`.
