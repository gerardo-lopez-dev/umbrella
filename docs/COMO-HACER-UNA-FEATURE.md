# Cómo hacer una feature — receta paso a paso

> Guía **genérica y reutilizable** para implementar cualquier feature del ROADMAP
> en este proyecto multi-repo. Una feature es **UNA spec** (`NNN-slug`) que vive
> en el repo de specs y se implementa en 1..N módulos. Todo se ejecuta **desde la
> raíz del umbrella**, sin `cd` a ningún submodulo.
>
> Los comandos usan placeholders:
>
> | Placeholder | Significado | Ejemplo |
> |-------------|-------------|---------|
> | `NNN-slug` | Nombre de feature **y** de rama (igual en todos los repos) | `002-docker` |
> | `<module>` | Módulo afectado | `microservice-template` |
> | `<owner>` | Cuenta/organización de GitHub | `gerardo-lopez-dev` |
> | `spec-v<X.Y.Z>` | Tag semver nuevo del repo de specs | `spec-v1.0.2` |
>
> **Referencias**: reglas vinculantes en `AGENTS.md` · workflow completo en
> `docs/WORKFLOW.md` · ramas en `BRANCHING.md` · cambio de specs en
> `CONTRIBUTING.md`. Un ejemplo real ya ejecutado: `docs/posts/02-docker.md`.

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
- **Deliver** son PRs (uno por repo) + tag de specs + punteros en el umbrella.

---

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

## Fase 0 — Preparar el workspace

Materializa los submodulos y asegúrate de partir limpio:

```sh
git submodule update --init --recursive
git status                       # umbrella sin cambios pendientes
```

> Si un submodulo no está materializado, el wrapper no lo clona por ti: corre
> `git submodule update --init --recursive` primero.

---

## Fase 1 — Specify (la spec)

La spec vive en el repo `specs`, montado en `modulos/specs-lib`. Crea la feature
con el wrapper — **el wrapper crea la rama por ti**, desde `origin/main`, nunca
del tag pineado:

```
/speckit.umbrella.run specs specify NNN-slug
```

> Detrás de escena corre `bash .specify/scripts/bash/ensure-spec-branch.sh
> --feature NNN-slug` (crea la rama `NNN-slug` en `modulos/specs-lib` desde
> `origin/main`; idempotente; aborta si el working tree de specs-lib está sucio
> — resuélvelo con `git -C modulos/specs-lib status`). Luego delega en
> `/speckit.specify`.

Esto crea `modulos/specs-lib/specs/NNN-slug/spec.md`. Escribe las user stories,
requisitos funcionales (`FR-xxx`) y success criteria.

**Commit en specs:**

```sh
git -C modulos/specs-lib add specs/NNN-slug
git -C modulos/specs-lib commit -m "feat(specs): spec NNN-slug (<resumen>)"
```

---

## Fase 2 — Plan (afectados + plan.md)

```
/speckit.umbrella.run specs plan
```

Revisa que `plan.md` quede completo (Technical Context, Constitution Check) y
**registra los módulos afectados** — esto es lo que conduce el fan-out:

```markdown
## Affected Repositories

- <module> (<rol en la feature>)
```

**Commit:**

```sh
git -C modulos/specs-lib add specs/NNN-slug/plan.md
git -C modulos/specs-lib commit -m "feat(specs): plan NNN-slug (affected: <module>)"
```

---

## Fase 3 — Tasks (divididas por repo)

```
/speckit.umbrella.run specs tasks
```

Genera `tasks.md` (orquestación) y, para features multi-repo, un task file por
módulo bajo `specs/NNN-slug/tasks/<module>.md`. Cada task file lleva las tasks
de implementación de ese módulo (una por ítem de la feature).

**Commit:**

```sh
git -C modulos/specs-lib add specs/NNN-slug/tasks.md specs/NNN-slug/tasks
git -C modulos/specs-lib commit -m "feat(specs): tasks NNN-slug (por repo)"
```

---

## Fase 4 — Fan-out (la rama llega a los módulos)

El plan declara los módulos afectados → crea la rama `NNN-slug` en cada uno,
**siempre desde `origin/main`**. Manual (el contrato) o automatizado:

```sh
# manual (el contrato — WORKFLOW.md sección 4)
git -C modulos/<module> fetch origin
git -C modulos/<module> checkout -b NNN-slug origin/main

# automatizado con el script: SIEMPRE --dry-run primero
bash .specify/scripts/bash/fanout.sh --plan modulos/specs-lib/specs/NNN-slug/plan.md --dry-run
bash .specify/scripts/bash/fanout.sh --plan modulos/specs-lib/specs/NNN-slug/plan.md

# equivalente vía wrapper (misma extensión)
/speckit.umbrella.run umbrella fanout --dry-run
/speckit.umbrella.run umbrella fanout
```

Notas del contrato:

- Fan-out **solo** a los módulos que el plan marca como afectados.
- Mismo nombre de rama en todos los repos.
- Base = `main` por defecto (config `umbrella_fanout.base`).
- Si dice `SKIP (dirty working tree)`, resuelve el módulo sucio antes de seguir:
  `git -C modulos/<module> status`.

---

## Fase 5 — Implement (dentro de cada módulo)

Repite esta fase **por cada módulo afectado**.

```
/speckit.umbrella.run <module> implement
```

El agente lee, en orden:

1. `modulos/<module>/.specify/memory/.agent-context` — qué carpeta/task file de
   specs aplica y el orden de la cascada de constitution.
2. El task file del módulo en
   `modulos/<module>/specs/specs/NNN-slug/tasks/<module>.md`.
3. La **cascada de constitution**: global primero
   (`modulos/<module>/specs/.specify/memory/constitution.md`), overrides locales
   después (`modulos/<module>/.specify/memory/constitution.md`) si existen.

Y ejecuta las tasks escribiendo/editando archivos bajo `modulos/<module>/`
(builds y tests como subprocesos con el módulo como working dir, ej. `./mvnw
test`).

**Commit en el módulo:**

```sh
git -C modulos/<module> add -A
git -C modulos/<module> commit -m "feat: <qué implementa> (NNN-slug)"
```

> **Nota (multi-repo / multi-dev):** durante el desarrollo —antes de que exista
> el tag— el submodulo `specs/` del módulo está en el tag viejo, que aún no tiene
> el directorio de esta feature. Para que el módulo lea el task file, pon su
> submodulo de specs en la rama de la feature (`WORKFLOW.md` §3.1):
>
> ```sh
> git -C modulos/<module>/specs fetch origin
> git -C modulos/<module>/specs checkout NNN-slug
> ```
>
> Requiere que la rama de specs esté en `origin` (púsheada). Tras el deliver
> (Fase 7.3) el submodulo se re-pinea al tag nuevo. En el flujo de un solo
> módulo/dev, el agente suele resolver el task file desde `modulos/specs-lib`
> (que ya está en la rama de la feature) sin necesidad de este paso.

---

## Fase 6 — Verify

Por módulo:

```
/speckit.umbrella.run <module> verify
```

Debe contar tasks `- [ ]` vs `- [X]` en el task file del módulo, correr el
build/tests del módulo (ej. `./mvnw test`) y dar un veredicto **PASS** (o
FAIL/PARTIAL). Si algo falla, se arregla antes de seguir.

```sh
git -C modulos/<module> add -A
git -C modulos/<module> commit -m "test: verify PASS (tasks completas + tests)"
```

---

## Fase 7 — Deliver (PRs, tag, punteros)

Tres sub-fases. **Todos los merges los hace el humano (squash), nunca el agente.**

### 7.1 PR por módulo (implementación)

```sh
git -C modulos/<module> push -u origin NNN-slug
gh pr create --repo <owner>/<module> \
  --title "NNN-slug: <resumen>" \
  --body "Implementa <post/feature> del ROADMAP."
```

El agente se detiene aquí y avisa. **El humano mergea:**

```sh
gh pr merge --repo <owner>/<module> --squash --delete-branch
```

> `main` de los módulos está protegido y GitHub no deja aprobar tu propio PR. En
> un repo personal el dueño mergea; si hiciera falta, `--admin` es la salida
> pragmática de un dev solo (documenta en el PR que fuiste tú). Con más gente, el
> reviewer es otra persona.

### 7.2 PR en specs + tag

En el repo de specs: marca las tasks del task file como `[X]` y añade la entrada
al `CHANGELOG.md`. Luego commit, push y PR:

```sh
git -C modulos/specs-lib add -A
git -C modulos/specs-lib commit -m "feat(specs): tasks NNN-slug completadas + changelog vX.Y.Z"
git -C modulos/specs-lib push -u origin NNN-slug
gh pr create --repo <owner>/specs \
  --title "NNN-slug: spec + tasks" \
  --body "Spec, plan y tasks de NNN-slug. Tasks del módulo completadas."
```

**El humano mergea (squash):**

```sh
gh pr merge --repo <owner>/specs --squash --delete-branch
```

Y crea el tag (ya sobre `main` actualizado):

```sh
git -C modulos/specs-lib checkout main && git -C modulos/specs-lib pull
git -C modulos/specs-lib tag -a spec-v<X.Y.Z> -m "spec-v<X.Y.Z>: NNN-slug <resumen>"
git -C modulos/specs-lib push origin spec-v<X.Y.Z>
```

> El número de versión sigue semver: PATCH por feature añadida/compatible,
> MINOR/MAJOR si cambia alcance o contratos. El tag nuevo es el punto que los
> módulos pinearán.

### 7.3 Punteros en el umbrella (acto explícito)

El umbrella absorbe la nueva spec: actualiza `modulos/specs-lib` y
`modulos/<module>/specs` al tag nuevo, en una rama del umbrella con su PR
(el umbrella solo registra punteros + docs):

```sh
git checkout main && git pull
git checkout -b chore-spec-v<X.Y.Z>

git -C modulos/specs-lib fetch origin
git -C modulos/specs-lib checkout spec-v<X.Y.Z>
git -C modulos/<module>/specs fetch origin
git -C modulos/<module>/specs checkout spec-v<X.Y.Z>

git add modulos && git commit -m "chore: pin specs a spec-v<X.Y.Z> (NNN-slug)"

git push -u origin chore-spec-v<X.Y.Z>
gh pr create --title "chore: pin specs a spec-v<X.Y.Z>" --body "Absorbe NNN-slug en specs-lib y el módulo."
```

**El humano mergea (squash):**

```sh
gh pr merge --squash --delete-branch
```

> Actualizar el puntero de specs de un módulo es **siempre un acto explícito**
> (`CONTRIBUTING.md`): nunca automático, nunca como parte de otro cambio. Un
> módulo puede quedarse en un tag anterior mientras termina su trabajo; no
> bloquea a nadie.

---

## Verificación final

Antes de dar la feature por cerrada:

- [ ] `git submodule status` — `modulos/specs-lib` y
      `modulos/<module>/specs` en `spec-v<X.Y.Z>` (mismo commit).
- [ ] Self-tests en verde:
      ```sh
      bash .specify/scripts/bash/fanout-test.sh
      bash .specify/scripts/bash/module-bootstrap-test.sh
      bash .specify/scripts/bash/context-test.sh
      bash .specify/scripts/bash/ensure-spec-branch-test.sh
      ```
- [ ] El `CHANGELOG.md` de specs tiene la entrada `spec-v<X.Y.Z>`.
- [ ] El build/tests del módulo pasa (`./mvnw test` o equivalente).
- [ ] El README del umbrella documenta el estado verificado (submodulos
      pineados, self-tests).

**Commit de cierre en el umbrella** (si actualizaste el README):

```sh
git add README.md
git commit -m "docs: verifica y documenta estado del proyecto (NNN-slug)"
```

---

## Y después

Cada post del ROADMAP se implementa igual: **una feature por post, una rama
`NNN-slug`, un PR por repo**, y solo la Fase 7 (PR specs → tag → punteros) toca
el versionado. Cuando la base compartida esté completa y toque un nuevo servicio
(ej. `users-service`), se clona el template base y se repite el mismo ciclo —
añadiendo el módulo nuevo con branch protection vía
`bash .specify/scripts/bash/module-bootstrap.sh <module>`.
