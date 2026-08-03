# 10 — Ejercicio end-to-end: una feature completa + verificación final

> **Rama (curso):** `aprender-09-e2e` — pero ojo: esta vez el trabajo real vive
> en los repos `specs` y `microservice-template`, no en el umbrella. **Objetivo:**
> recorrer el ciclo completo (specify → plan → fanout → tasks → implement →
> verify → deliver) con una feature real del ROADMAP, usando ramas, commits y
> PRs. Es el examen final del curso.

## La feature

**Post 03 del ROADMAP — Actuator + Health Checks Personalizados.**
El template ya trae la dependencia `spring-boot-starter-actuator`; lo que falta
es lo del post:

- Un `HealthIndicator` custom que verifique la conexión a la BD.
- Exponer `/actuator/health` en **todos** los profiles.
- Exponer el **resto** de endpoints de Actuator solo en `dev`/`local`.
- Un test unitario del `HealthIndicator`.

Convención de rama real: `003-actuator-health-checks` (NNN = post 03, slug =
título). El mismo nombre en specs y en el módulo.

> **Antes de empezar**, vuelve a leer `01-conceptos.md` sección 6. Todo lo que
> sigue es ese ciclo, ejecutado.

---

## Fase 1 — Specify (la spec)

La spec vive en el repo `specs`, montado en `modulos/specs-lib`. Primero creas
la rama de la feature **dentro del submodulo** (desde la raíz, con `git -C`):

```sh
git submodule update --init --recursive
git -C modulos/specs-lib fetch origin
git -C modulos/specs-lib checkout -b 003-actuator-health-checks origin/main
```

Ahora crea la feature con el wrapper (deriva el nombre de rama del ROADMAP —
no lo escribes tú):

```
/speckit.umbrella.run specs specify 003-actuator-health-checks
```

Esto crea `modulos/specs-lib/specs/003-actuator-health-checks/spec.md`.
Escribe 2 user stories mínimas:

```markdown
# 003 — Actuator Health Checks

## User Stories
- Como operador, quiero ver en `/actuator/health` el estado del servicio y de
  su conexión a BD, para detectar fallos tempranos.
- Como operador, quiero que los endpoints de Actuator expuestos dependan del
  profile (health siempre; el resto solo en dev/local).
```

**Commit en specs:**

```sh
git -C modulos/specs-lib add specs/003-actuator-health-checks
git -C modulos/specs-lib commit -m "feat(specs): spec Post 03 (actuator health checks)"
```

---

## Fase 2 — Plan (afectados + plan.md)

```
/speckit.umbrella.run specs plan
```

Revisa que `plan.md` quede completo y **registra los módulos afectados** (esto
conduce el fan-out):

```markdown
## Affected Repositories

- microservice-template (template base, Parte 1)
```

**Commit:**

```sh
git -C modulos/specs-lib add specs/003-actuator-health-checks/plan.md
git -C modulos/specs-lib commit -m "feat(specs): plan Post 03 (affected: microservice-template)"
```

---

## Fase 3 — Tasks (divididas por repo)

```
/speckit.umbrella.run specs tasks
```

Genera `tasks.md` + `tasks/microservice-template.md`. El task file del módulo
debe quedar con 4 tasks (una por ítem de la feature). Marca el task file de
orquestación de modo que quede claro que `microservice-template` es quien
implementa.

**Commit:**

```sh
git -C modulos/specs-lib add specs/003-actuator-health-checks/tasks.md specs/003-actuator-health-checks/tasks
git -C modulos/specs-lib commit -m "feat(specs): tasks Post 03 (por repo)"
```

---

## Fase 4 — Fan out (la rama llega al módulo)

El plan declara `microservice-template` como afectado → fan-out manual (sección
4 del WORKFLOW) o vía la extensión del paso 08:

```sh
# manual (el contrato)
git -C modulos/microservice-template fetch origin
git -C modulos/microservice-template checkout -b 003-actuator-health-checks origin/main

# o automatizado (extension del paso 08): siempre --dry-run primero
/speckit.umbrella.run umbrella fanout --dry-run
/speckit.umbrella.run umbrella fanout
```

> Si la extensión dice `SKIP (dirty working tree)`, resuelve el módulo sucio
> antes de seguir: `git -C modulos/microservice-template status`.

---

## Fase 5 — Implement (dentro del módulo)

```
/speckit.umbrella.run microservice-template implement
```

El agente lee `.agent-context` → su task file → cascada de constitution → ejecuta
las tasks bajo `modulos/microservice-template/`. Si lo haces a mano, esto es:

1. **HealthIndicator custom** — nueva clase en
   `infrastructure/config/DatabaseHealthIndicator.java` que implementa
   `HealthIndicator` y devuelve `UP`/`DOWN` según la conexión a la BD
   (puedes usar `JdbcTemplate` o `DataSource` y `getConnection().isValid(1)`).
2. **Exposición por profile** — en `application-*.yaml`:
   - `health` expuesto siempre;
   - el resto de endpoints (`info`, `metrics`, …) solo en `dev`/`local`.
3. **Test unitario** del indicador (mockea la fuente de datos; `UP` y `DOWN`).

**Commit en el módulo:**

```sh
git -C modulos/microservice-template add -A
git -C modulos/microservice-template commit -m "feat: custom health indicator + actuator por profile (Post 03)"
```

---

## Fase 6 — Verify (tasks, checklist, tests)

```
/speckit.umbrella.run microservice-template verify
```

Debe: contar tasks `- [ ]` vs `- [X]` en el task file del módulo, correr los
tests (`./mvnw test`) y dar un verdicto **PASS**. Si un test falla, se arregla
antes de seguir.

```sh
git -C modulos/microservice-template add -A
git -C modulos/microservice-template commit -m "test: verify PASS (tasks completas + mvnw test)"
```

---

## Fase 7 — Deliver (PRs, tag, punteros)

### 7.1 PR en el módulo (implementación)

```sh
git -C modulos/microservice-template push -u origin 003-actuator-health-checks
gh pr create --repo gerardo-lopez-dev/microservice-template \
  --title "003-actuator-health-checks: health checks custom" \
  --body "Implementa Post 03 del ROADMAP."
```

**Merge de tu propio PR:** `main` de los módulos está protegido (1 review,
admins incluidos) y GitHub **no deja aprobar tu propio PR**. Para un repo
personal, el dueño mergea con admin:

```sh
gh pr merge --repo gerardo-lopez-dev/microservice-template --admin --merge --delete-branch
```

> En un proyecto con más gente, el reviewer es otra persona. `--admin` es la
> salida pragmática para un dev solo — documenta en el PR que fuiste tú quien
> mergeo.

### 7.2 PR en specs + tag

En el repo specs: marca las tasks del task file como `[X]`, actualiza
`CHANGELOG.md` con la entrada de la versión, merge y taggea:

```sh
git -C modulos/specs-lib add -A
git -C modulos/specs-lib commit -m "feat(specs): tasks Post 03 completadas + changelog v1.0.1"
git -C modulos/specs-lib push -u origin 003-actuator-health-checks
gh pr create --repo gerardo-lopez-dev/specs \
  --title "003-actuator-health-checks: spec + tasks" \
  --body "Spec, plan y tasks del Post 03. Tasks del modulo completadas."
gh pr merge --repo gerardo-lopez-dev/specs --admin --merge --delete-branch

git -C modulos/specs-lib checkout main && git -C modulos/specs-lib pull
git -C modulos/specs-lib tag -a spec-v1.0.1 -m "spec-v1.0.1: Post 03 actuator health checks"
git -C modulos/specs-lib push origin spec-v1.0.1
```

### 7.3 Punteros en el umbrella (acto explícito)

Ahora el umbrella absorbe la nueva spec: actualiza `modulos/specs-lib` y
`modulos/microservice-template/specs` al tag nuevo, en una rama del umbrella con
su PR (umbrella registra punteros + docs):

```sh
git checkout main && git pull
git checkout -b chore-spec-v1.0.1

git -C modulos/specs-lib fetch origin
git -C modulos/specs-lib checkout spec-v1.0.1
git -C modulos/microservice-template/specs fetch origin
git -C modulos/microservice-template/specs checkout spec-v1.0.1

git add modulos && git commit -m "chore: pin specs a spec-v1.0.1 (Post 03)"

git push -u origin chore-spec-v1.0.1
gh pr create --title "chore: pin specs a spec-v1.0.1" --body "Absorbe Post 03 en specs-lib y el modulo."
gh pr merge --merge --delete-branch
```

---

## Verificación final del curso (el "estado verificado")

Antes de dar el curso por terminado:

- [ ] `git submodule status` — todos los submodulos en `spec-v1.0.1`.
- [ ] Self-tests en verde:
  ```sh
  bash .specify/scripts/bash/fanout-test.sh
  bash .specify/scripts/bash/module-bootstrap-test.sh
  bash .specify/scripts/bash/context-test.sh
  ```
- [ ] `git log --oneline` del umbrella cuenta la misma historia que la original
      (`97a26f6` → `a74bf2b`, más tus pasos del curso y el pin a v1.0.1).
- [ ] El README documenta el estado verificado (actualiza la sección
      "Verified state": submodulos pineados, main protegido, self-tests).
- [ ] Puedes explicar el ciclo completo de una feature **sin mirar los docs**.

**Commit de cierre en el umbrella:**

```sh
git add README.md
git commit -m "docs: verifica y documenta estado del proyecto"
```

---

## Y después del curso

El umbrella está reconstruido y entendido. A partir de aquí, cada post del
ROADMAP se implementa exactamente igual que este ejercicio: una feature por
post, una rama `NNN-slug`, un PR por repo. No hace falta memorizar cada script:
el contrato y los self-tests definen el "hecho" mejor que cualquier recuerdo.
