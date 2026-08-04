# 02 — Post 02 del ROADMAP: Docker Multi-Stage y Docker Compose

> **Rama:** `002-docker` — **Objetivo:** recorrer el ciclo completo
> (specify → plan → tasks → fanout → implement → verify → deliver) de una
> feature real del ROADMAP, con **todos** los comandos ejecutados desde la raíz
> del umbrella. Nunca `cd` a un submodulo: ficheros con rutas relativas al
> umbrella, git de submodulo con `git -C`, GitHub con `gh`.

> Si no lo has hecho aún, lee antes `docs/aprender/10-ejercicio-e2e.md`: este
> documento es el mismo ciclo, aplicado al Post 02.

---

## La feature

**Post 02 del ROADMAP — Docker Multi-Stage y Docker Compose.** El template ya
trae `Dockerfile`, `docker-compose.yml` y `.dockerignore` (commits anteriores);
lo que pide el post es **verificar y refinar** estos 5 ítems:

- Optimizar el `Dockerfile` multi-stage (caché de dependencias).
- `docker-compose.yml` con los servicios base: PostgreSQL, Redis, Kafka.
- Redes Docker para comunicación entre servicios.
- Volúmenes para persistencia.
- `.dockerignore` optimizado.

Convención de rama real: `002-docker` (NNN = post 02, slug = título). El mismo
nombre en specs y en el módulo.

---

## Fase 1 — Specify (la spec)

La spec vive en el repo `specs`, montado en `modulos/specs-lib`. Materializa el
submodulo (esto sí es manual: el wrapper no clona) y crea la feature con el
wrapper — **el wrapper crea la rama por ti**, desde `origin/main`, nunca del tag
pineado:

```sh
git submodule update --init --recursive
```

```
/speckit.umbrella.run specs specify 002-docker
```

> Detrás de escena, `specify` corre
> `bash .specify/scripts/bash/ensure-spec-branch.sh --feature 002-docker`
> antes de `/speckit.specify`: crea la rama `002-docker` en `modulos/specs-lib`
> desde `origin/main` (idempotente; aborta si el working tree de specs-lib está
> sucio — resuélvelo con `git -C modulos/specs-lib status`). El nombre de rama lo
> deriva del ROADMAP, no lo escribes tú.

Esto crea (o usa) `modulos/specs-lib/specs/002-docker/spec.md`. Escribe 2 user
stories mínimas:

```markdown
# 002 — Docker Multi-Stage y Docker Compose

## User Stories
- Como operador, quiero que el servicio se empaquete con un Dockerfile
  multi-stage que cachee dependencias, para builds rápidos e imágenes pequeñas.
- Como desarrollador, quiero levantar el stack completo (app + PostgreSQL +
  Redis + Kafka) con un solo `docker compose up`, con redes aisladas y
  volúmenes de persistencia.
```

**Commit en specs:**

```sh
git -C modulos/specs-lib add specs/002-docker
git -C modulos/specs-lib commit -m "feat(specs): spec Post 02 (docker multi-stage + compose)"
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
git -C modulos/specs-lib add specs/002-docker/plan.md
git -C modulos/specs-lib commit -m "feat(specs): plan Post 02 (affected: microservice-template)"
```

---

## Fase 3 — Tasks (divididas por repo)

```
/speckit.umbrella.run specs tasks
```

Genera `tasks.md` + `tasks/microservice-template.md`. El task file del módulo
debe quedar con 5 tasks (una por ítem de la feature):

1. Optimizar `Dockerfile` multi-stage: caché de dependencias
   (`dependency:go-offline` antes de `COPY src/`), stage runtime con usuario no
   root, imagen final JRE.
2. `docker-compose.yml` con servicios base: `app`, `postgres`, `redis`, `kafka`
   con healthchecks y `depends_on: condition: service_healthy`.
3. Redes Docker: red bridge dedicada (`microservice-net`) para todos los
   servicios.
4. Volúmenes de persistencia (`pgdata` para PostgreSQL, y volumen para datos de
   Kafka si procede).
5. `.dockerignore` optimizado (excluir `.git`, `target/`, `*.md`, IDE, `.env`).

**Commit:**

```sh
git -C modulos/specs-lib add specs/002-docker/tasks.md specs/002-docker/tasks
git -C modulos/specs-lib commit -m "feat(specs): tasks Post 02 (por repo)"
```

---

## Fase 4 — Fan out (la rama llega al módulo)

El plan declara `microservice-template` como afectado → fan-out manual (sección
4 del WORKFLOW) o vía la extensión:

```sh
# manual (el contrato)
git -C modulos/microservice-template fetch origin
git -C modulos/microservice-template checkout -b 002-docker origin/main

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
las tasks bajo `modulos/microservice-template/`. Como el template ya trae los 3
ficheros, esto es **refinarlos y validarlos**:

1. **Dockerfile multi-stage** — verifica el orden de caché: `.mvn/`, `mvnw` y
   `pom.xml` copiados y resueltos con `dependency:go-offline` **antes** de
   `COPY src/`, para que un cambio de código no rompa la caché de dependencias.
   Stage runtime con JRE, usuario no root, `EXPOSE 8080`.
2. **docker-compose.yml** — confirma los servicios base (PostgreSQL, Redis,
   Kafka) con healthchecks y `app` arrancando solo cuando están sanos.
3. **Redes** — todos los servicios en la red bridge `microservice-net`.
4. **Volúmenes** — `pgdata` para PostgreSQL (y el de Kafka si aplica); nada en
   `tmpfs` que pierda datos.
5. **.dockerignore** — excluye `.git`, `.github`, `target/`, `*.md`, `.env.*`
   (excepto `.env.example`), IDEs y ficheros temporales.

**Commit en el módulo:**

```sh
git -C modulos/microservice-template add -A
git -C modulos/microservice-template commit -m "feat: refina docker multistage + compose base (Post 02)"
```

---

## Fase 6 — Verify (tasks, checklist, tests)

```
/speckit.umbrella.run microservice-template verify
```

Debe: contar tasks `- [ ]` vs `- [X]` en el task file del módulo, correr los
tests (`./mvnw test`) y dar un verdicto **PASS**. Además, valida el compose sin
levantar nada:

```sh
docker compose -f modulos/microservice-template/docker-compose.yml config -q && echo "compose OK"
```

Si un test falla, se arregla antes de seguir.

```sh
git -C modulos/microservice-template add -A
git -C modulos/microservice-template commit -m "test: verify PASS (tasks completas + mvnw test + compose config)"
```

---

## Fase 7 — Deliver (PRs, tag, punteros)

### 7.1 PR en el módulo (implementación)

```sh
git -C modulos/microservice-template push -u origin 002-docker
gh pr create --repo gerardo-lopez-dev/microservice-template \
  --title "002-docker: docker multistage + compose base" \
  --body "Implementa Post 02 del ROADMAP."
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
git -C modulos/specs-lib commit -m "feat(specs): tasks Post 02 completadas + changelog v1.0.2"
git -C modulos/specs-lib push -u origin 002-docker
gh pr create --repo gerardo-lopez-dev/specs \
  --title "002-docker: spec + tasks" \
  --body "Spec, plan y tasks del Post 02. Tasks del modulo completadas."
gh pr merge --repo gerardo-lopez-dev/specs --admin --merge --delete-branch

git -C modulos/specs-lib checkout main && git -C modulos/specs-lib pull
git -C modulos/specs-lib tag -a spec-v1.0.2 -m "spec-v1.0.2: Post 02 docker multistage + compose"
git -C modulos/specs-lib push origin spec-v1.0.2
```

### 7.3 Punteros en el umbrella (acto explícito)

Ahora el umbrella absorbe la nueva spec: actualiza `modulos/specs-lib` y
`modulos/microservice-template/specs` al tag nuevo, en una rama del umbrella con
su PR (umbrella registra punteros + docs):

```sh
git checkout main && git pull
git checkout -b chore-spec-v1.0.2

git -C modulos/specs-lib fetch origin
git -C modulos/specs-lib checkout spec-v1.0.2
git -C modulos/microservice-template/specs fetch origin
git -C modulos/microservice-template/specs checkout spec-v1.0.2

git add modulos && git commit -m "chore: pin specs a spec-v1.0.2 (Post 02)"

git push -u origin chore-spec-v1.0.2
gh pr create --title "chore: pin specs a spec-v1.0.2" --body "Absorbe Post 02 en specs-lib y el modulo."
gh pr merge --merge --delete-branch
```

---

## Verificación final

- [ ] `git submodule status` — `modulos/specs-lib` y
      `modulos/microservice-template/specs` en `spec-v1.0.2`.
- [ ] Self-tests en verde:
  ```sh
  bash .specify/scripts/bash/fanout-test.sh
  bash .specify/scripts/bash/module-bootstrap-test.sh
  bash .specify/scripts/bash/context-test.sh
  bash .specify/scripts/bash/ensure-spec-branch-test.sh
  ```
- [ ] `docker compose config -q` sobre el compose del módulo da OK.
- [ ] El CHANGELOG de specs tiene la entrada `spec-v1.0.2`.
- [ ] README del umbrella documenta el estado verificado (submodulos pineados,
      self-tests).

**Commit de cierre en el umbrella:**

```sh
git add README.md
git commit -m "docs: verifica y documenta estado del proyecto (Post 02)"
```

---

## Y después

Cada post del ROADMAP se implementa igual que este: una feature por post, una
rama `NNN-slug`, un PR por repo, y solo la fase 7 (PR specs → tag → punteros)
toca el versionado. Si la parte 1 está completa (posts 01–17), el siguiente
módulo (`users-service`, Post 18) repite el mismo ciclo clonando el template
base.
