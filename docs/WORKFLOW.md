# Workflow — Spec-Driven Development entre módulos

Cómo el umbrella + el repo de specs + los repos de módulos trabajan juntos, de
punta a punta. Las reglas vinculantes (pinning, cascada, flujo de cambio de
specs) viven en `AGENTS.md` y `CONTRIBUTING.md`; este documento es el
procedimiento ejecutable.

> **Para implementar una feature nueva, usa el orquestador:**
> `/speckit.umbrella.feature <post>` (ver `docs/COMO-HACER-UNA-FEATURE.md`).
> Este documento describe el procedimiento interno paso a paso y sirve de
> referencia/fallback.

> **Decisiones:**
> - **Convención de ramas:** GitHub Flow en todos los repos — `main` como única
>   troncal, ramas de feature de vida corta mergeadas vía PR y borradas tras el
>   merge. Sin `develop`/`release`/`hotfix`. Ver `BRANCHING.md`.
> - **Sin preset/extensión de speckit de terceros.** Las herramientas de la
>   comunidad (`multi-repo-sync` extension, `multi-repo-branching` preset)
>   existen pero no están probadas para este setup y añaden automatización
>   frágil ante upgrades.
> - **La automatización la construimos nosotros.** El fan-out de ramas es manual
>   con git plano (sección 4) por defecto; cuando necesite automatización, la
>   escribimos como extensión propia de speckit (sección 4.1) — dueña, testeada y
>   mantenida por nosotros. Nunca se añade una dependencia de terceros para esto.

---

## 1. Roles de los repos

| Repo | Rol |
|------|-----|
| `umbrella` | Orquesta. Contiene docs, reglas (`AGENTS.md`, `CONTRIBUTING.md`) y los submodulos de módulos. Sin implementación. |
| `specs` | Fuente de verdad. Requisitos, contratos, planes, constitution global. Versionado con tags `spec-vMAJOR.MINOR.PATCH`. |
| `<module>` | Implementación. Consume `specs` como submodulo git pineado en `modulos/<module>/specs`. |

El repo `specs` se monta **dos veces**: en `modulos/specs-lib` (referencia del
umbrella) y en `modulos/<module>/specs` (copia de trabajo de cada módulo).
Ambos pineados al mismo tag.

## 1.1 Operating model — todo desde la raíz del umbrella

El umbrella es la **única** sesión de trabajo. Nunca `cd` a un submodulo ni
abras una sesión dentro de uno; toda fase se ejecuta desde la raíz del umbrella:

- **Ficheros** con rutas relativas al umbrella (`modulos/specs-lib/...`,
  `modulos/<module>/...`).
- **Git de submodulo** con `git -C modulos/<m> ...`.
- **GitHub** con `gh`, repo resuelto del remote del submodulo.
- **Contexto de speckit** vía `SPECIFY_FEATURE_DIRECTORY=modulos/<target>/...`
  (override soportado por `get_feature_paths`); `SPECIFY_INIT_DIR` solo cuando
  el target tiene su propio `.specify/feature.json`.

Punto de entrada único: `/speckit.umbrella.run <target> <phase>`.

| Target | Root on disk | Phases |
|--------|--------------|--------|
| `specs` | `modulos/specs-lib` | `specify`, `plan`, `tasks` |
| `umbrella` | `.` | `fanout` (rama a los módulos afectados) |
| `<module>` | `modulos/<module>` | `implement`, `verify` |

Ejemplo: `/speckit.umbrella.run microservice-template implement` implementa las
tasks del módulo (desde su `.agent-context` → su task file en las specs montadas
en el módulo) sin salir de la raíz del umbrella.

El orquestador `/speckit.umbrella.feature <post>` corre todas las fases en
secuencia y se detiene solo en los gates humanos (aprobación de spec, plan,
tasks, implementación, verify-fixes, merges de PRs). Usa `deliver.sh` para la
Fase 7.

---

## 2. Getting started: configurar el umbrella (paso a paso)

Un commit por paso, con confirmación explícita entre pasos. **No te saltes
pasos.**

### Prerrequisitos

- CLI `specify` instalado (verificado: v0.14.2). Comprueba con `specify --version`.
- `gh` autenticado (`gh auth status`) — para crear/inspeccionar repos.
- Git + claves SSH configuradas (`ssh -T git@github.com`).
- Repos GitHub que posees: `umbrella` (este) ya existe. Hay que decidir el
  nombre del repo de specs (propuesto: `specs`) y el primer repo de módulo
  (propuesto: `microservice-template`).

### Paso 0 — Recoge los datos de los repos

Pregunta/confirma antes de ejecutar cualquier cosa que los necesite (nunca
inventes URLs):
- Nombre + URL del repo de specs (`gerardo-lopez-dev/specs`?).
- Nombre + URL del primer repo de módulo (`gerardo-lopez-dev/microservice-template`?).
- Tag al que pinear todo: `spec-v1.0.0`.

### Paso 1 — Spec Kit + constitution global

```sh
specify init --here --integration opencode
```

Genera `.specify/memory/constitution.md` en el umbrella con los principios
GLOBALES (calidad de código, estándares de testing cross-module, criterios de
arquitectura compartida — nada de stack específico aún).
→ Commit: `chore: init spec kit + constitution global`

### Paso 2 — Crea el repo de specs

Si no existe, créalo con:

```
<specs>/
├── .specify/memory/constitution.md   (mismo contenido que la global del paso 1)
├── specs/
├── CHANGELOG.md
└── README.md
```

Tag `spec-v1.0.0` y push.

### Paso 3 — Pinear specs-lib

```sh
git submodule add <url-repo-specs> modulos/specs-lib
git -C modulos/specs-lib checkout spec-v1.0.0
git add .gitmodules modulos/specs-lib && git commit -m "chore: agrega specs-lib pineado a spec-v1.0.0"
```

Confirma en una línea que está pineado al tag, no a `main`.

### Paso 4 — Añadir el primer módulo (repetir por módulo)

```sh
git submodule add <url-repo-module> modulos/<module>
git -C modulos/<module> submodule add <url-repo-specs> specs
git -C modulos/<module>/specs checkout spec-v1.0.0
```

Después crea `.specify/memory/.agent-context` dentro del módulo, apuntando a la
carpeta `specs/specs/` que le aplica. Crea un `constitution.md` local SOLO si
hay overrides reales (ej. el framework de testing del lenguaje); si no,
omítelo.
→ Commit: `chore: agrega modulo <module> con specs pineado`

Aplica la convención de branch protection al `main` del módulo nuevo (GitHub
Flow, `BRANCHING.md`) — idempotente, auto-detecta los checks de CI:

```sh
bash .specify/scripts/bash/module-bootstrap.sh <module> --dry-run   # revisar antes
bash .specify/scripts/bash/module-bootstrap.sh <module>             # aplicar
```
→ Commit: `chore: configura branch protection de <module> (main)`

### Paso 5 — Documenta la cascada de constitution

En el `README.md` del umbrella, escribe el orden de lectura para quien
implemente dentro de un módulo: global primero
(`modulos/<module>/specs/.specify/memory/...`), overrides locales después
(`modulos/<module>/.specify/memory/...`) si existen.
→ Commit: `docs: documenta orden de lectura de constitution en cascada`

### Paso 6 — Proceso de cambio de specs

`CONTRIBUTING.md` en la raíz documenta el flujo de cambio de spec (PR → review →
tag + CHANGELOG → cada módulo actualiza su puntero cuando decide).
→ Commit: `docs: agrega proceso de cambio de spec en CONTRIBUTING.md`

### Paso 7 — Automatización propia (extensión in-house)

Construir nuestra propia extensión de speckit que envuelva el fan-out manual de
la sección 4 — nunca una de terceros. Ver la sección 4.1 para el plan completo
de construcción.
→ Un commit por unidad de trabajo de la extensión.

### Paso 8 — Verificar

- Mostrar el árbol completo del repo con todos los submodulos.
- Mostrar `git log --oneline` de los commits de esta sesión.
- Listar lo que queda pendiente en ti (repos remotos creados, permisos).
  ✅ La branch protection del `main` del repo specs está aplicada (1 review,
  admins enforced, sin force-push/deletions).

Sin commit en este paso: es un resumen.

### Dónde viven spec.md / plan.md / tasks.md

Las features se escriben en el **repo de specs** (el proyecto speckit). Una
feature es un directorio bajo `specs/`:

```
<specs>/
├── .specify/memory/constitution.md
├── specs/
│   └── 001-users-domain/
│       ├── spec.md              ← la spec de la feature
│       ├── data-model.md
│       ├── contracts/api.yaml
│       ├── plan.md              ← incluye Affected Repositories (fan-out)
│       ├── tasks.md             ← tasks compartidas/orquestación
│       └── tasks/
│           ├── users-service.md ← task file por módulo
│           └── ...
├── CHANGELOG.md
└── README.md
```

Se monta en dos sitios:

- Referencia del umbrella: `modulos/specs-lib/specs/001-users-domain/`.
- Cada módulo: `modulos/<module>/specs/specs/001-users-domain/`. El
  `.specify/memory/.agent-context` del módulo apunta a su task file, ej.
  `specs/specs/001-users-domain/tasks/users-service.md`.

`/speckit.specify`, `/speckit.plan`, `/speckit.tasks`, `/speckit.verify` corren
en el **repo de specs**. `/speckit.implement` corre dentro de cada módulo.

### Una feature, muchos repos (backend + bff + frontend)

La spec es por **feature**, no por módulo. Una feature transversal mantiene UNA
spec y solo divide las tasks:

```
specs/NNN-checkout-flow/
├── spec.md              ← UNA spec para las tres capas
├── plan.md              ← Affected Repositories: backend, bff, frontend
├── tasks.md             ← tasks compartidas/orquestación
└── tasks/
    ├── backend.md       ← task file del repo backend
    ├── bff.md           ← task file del repo BFF
    └── frontend.md      ← task file del repo frontend
```

`/speckit.specify` y `/speckit.plan` corren una vez por feature. El fan-out
(sección 4) crea la rama en cada repo afectado; el `.agent-context` de cada repo
apunta a su propio task file; todos los repos implementan en paralelo contra la
misma spec y la misma constitution.

### Mapeo al ROADMAP

`docs/ROADMAP.md` es el backlog de contenido; el umbrella es la maquinaria de
entrega. Componen:

- Cada Post (o grupo lógico) se convierte en una feature del repo de specs:
  `specs/NNN-<post-slug>/`.
- Los **módulos afectados** por post deciden el fan-out:
  - Posts 01–17 → `microservice-template` (base compartida del template).
  - Fase A (18–21) → `users-service`, Fase B → `products-service`, … Fase G →
    `notifications-service` (según la tabla de servicios del ROADMAP).
- Las fases transversales (Sagas, CQRS/ES, Observabilidad, Producción) tocan
  varios módulos → se registran en `plan.md` como repos afectados.
- La implementación por módulo usa las skills del ROADMAP
  (`/hexagonal.scaffold`, `/hexagonal.add-entity`, `/orders.add-state`, …).
  Esas 13 skills son entregables del ROADMAP y deben crearse antes del primer
  uso; son lo que `/speckit.implement` ejecuta dentro de un módulo.

---

## 3. Ciclo de vida de una feature

1. **Init** — `specify init --here --integration opencode` (hecho en el
   bootstrap; por proyecto si el repo de specs es su propio proyecto speckit).
2. **Specify** — `/speckit.umbrella.run specs specify` crea el directorio de la
   feature (`specs/NNN-name/` + `spec.md`). La creación de rama ocurre en el
   fan-out (paso 4); el nombre `NNN-slug` lo deriva el asistente del post del
   ROADMAP (BRANCHING.md) — nunca se teclea.
3. **Plan** — `/speckit.plan` genera `spec.md`, `data-model.md`, contratos y
   `plan.md`. En `plan.md` registra una lista **Affected Repositories**: todo
   módulo cuya implementación va a cambiar.
4. **Fan-out de ramas (git manual)** — ver sección 4.
5. **Tasks** — `/speckit.tasks` genera `tasks.md` (compartidas/orquestación) y,
   para features multi-repo, task files por módulo bajo `specs/NNN-name/tasks/`.
   El `.specify/memory/.agent-context` de cada módulo apunta a su task file.
6. **Implementar por módulo** — en `modulos/<module>`, ejecutar
   `/speckit.implement`. El agente lee la cascada de constitution (global desde
   `specs/.specify/...`, luego overrides locales) y ejecuta solo las tasks de su
   propio task file.
7. **Verify** — `/speckit.verify` por módulo y para la feature.
8. **Deliver** —
   - PR por módulo (implementación) → merge.
   - PR en el repo de specs (check de tasks, actualización de contratos) → merge.
   - Tag del repo de specs (`spec-vX.Y.Z`) + entrada en `CHANGELOG.md`.
   - Cada módulo actualiza explícitamente su puntero `specs/` al tag nuevo cuando
     decide (sección 5). Nunca automático.

## 3.1 Workflow multi-desarrollador

El repo de specs es el único punto de coordinación compartido. Cada
desarrollador monta el mismo repo de specs (como submodulo), así que **las specs
son el único estado mutable que todos tocan** — las reglas de ramas y review de
abajo son lo que evita que N desarrolladores se pisen.

Modelo de ramas en el repo de specs:

- `main` contiene las specs aprobadas; los tags `spec-vX.Y.Z` marcan versiones
  liberadas.
- Cada feature tiene su rama en el repo de specs (ej. `001-auth-backend`),
  creada por el fan-out (sección 4) y nombrada por el asistente siguiendo
  `NNN-slug` (BRANCHING.md).
- Si varios devs trabajan en la misma feature, ramifican de la rama de feature
  con ramas de trabajo por dueño (`001-auth-backend`, `001-auth-api`) y hacen PR
  de vuelta a la rama de feature.
- El **Affected Repositories** de `plan.md` les dice a todos qué módulos
  coordinan en la feature.

El día de cada desarrollador:

1. Sincroniza el workspace: `git submodule update --init --recursive`.
2. Su rama de feature existe en el repo de specs (o la crea).
3. Hace fan-out de la rama a los módulos afectados (sección 4).
4. En su módulo, hace checkout de la rama de feature en el submodulo `specs/`
   del módulo para trabajar contra la spec de la feature.
5. `/speckit.implement` en el módulo: lee `.agent-context` → su task file →
   cascada de constitution → implementa.
6. `/speckit.verify`.
7. Abre PRs: uno por módulo; en el repo de specs, un PR de la rama de feature a
   `main`. Al mergear, tag `spec-vX.Y.Z` y actualiza `CHANGELOG.md`.

Por qué esto evita conflictos:

- Las features viven en su propio directorio (`specs/NNN-name/`); dos devs
  editando features distintas tocan ficheros distintos.
- La branch protection del repo de specs es la puerta: nada llega a `main` sin
  review.
- Los módulos nunca editan una spec pineada en sitio — trabajan en una rama de
  feature dentro del submodulo, y solo absorben una spec nueva moviendo su
  puntero a un tag liberado (sección 5).

Coordinación en módulos compartidos:

- Dos devs en el mismo módulo trabajan desde task files separados bajo
  `specs/NNN-name/tasks/` (uno por módulo) — un único task file por módulo
  mantiene la responsabilidad inequívoca.
- La rama propia del módulo es el workspace compartido; los cambios llegan por
  el flujo de PR normal del módulo antes de tocar la spec compartida.

## 4. Branch fan-out (git manual — nuestro)

Cuando `plan.md` lista los módulos afectados, crea la rama de feature en el repo
de specs y en cada módulo afectado:

```sh
# raíz del umbrella — asegúrate de que los submodulos estén presentes
git submodule update --init --recursive

# repo de specs (vía la referencia del umbrella)
git -C modulos/specs-lib fetch origin
git -C modulos/specs-lib checkout -b <feature-branch>

# cada módulo afectado — siempre nace del origin/main más reciente (base = main)
for m in users products orders; do
  git -C modulos/$m fetch origin
  git -C modulos/$m checkout -b <feature-branch> origin/main
done
```

Notas del contrato:

- Un módulo puede quedarse en su propia rama si la feature no lo toca — haz
  fan-out solo de lo que el plan marca como afectado.
- `git submodule update --init --recursive` también materializa el submodulo
  `specs/` de cada módulo antes de empezar.
- Mismo nombre de rama en todos los repos para que los PRs se alineen. Distintos
  repos, un mismo nombre.
- La base es `main` por defecto (config `umbrella_fanout.base`). Un módulo con
  otra troncal fuerza `--base` vía `fanout.sh`.

## 4.1 Automatización propia (extensión in-house) — plan de construcción

Los comandos de la sección 4 son el **contrato**. Nuestra extensión los
envuelve, siguiendo el diseño basado en hooks (verificado contra
`multi-repo-sync`) pero escrito, testeado y mantenido por nosotros.

1. **Scaffold del paquete** bajo `.specify/extensions/umbrella-fanout/`
   (manifest de extensión + comandos namespaced, para que `specify self upgrade`
   nunca toque nuestros ficheros).
2. **Hooks**:
   - `after_plan` → descubrir los módulos afectados de la lista **Affected
     Repositories** del plan.
   - `after_tasks` → crear la rama correspondiente en cada módulo afectado
     (`/speckit.umbrella-fanout.fanout`).
   Registrados en `.specify/extensions.yml` (ambos opcionales, prioridad 10).
3. **Config** en `.specify/init-options.json` (`umbrella_fanout`: `base`,
   `switch`, `skip_branches`, `exclude`) con defaults de `type: submodule`.
4. **Safety**: `--dry-run`, conmutación best-effort (nunca pisar un working tree
   sucio — ficheros untracked incluidos), re-ejecución idempotente. Implementado
   en `.specify/scripts/bash/fanout.sh`.
5. **Verify**: probarla en una feature desechable; comparar contra los comandos
   manuales de la sección 4; dejar la sección 4 como fallback documentado.

El comando para el agente es `/speckit.umbrella-fanout.fanout` (envuelve
`fanout.sh`); corre tras plan/tasks vía los hooks, o manualmente cuando quieras.
Para reinstalar tras editar el código de la extensión, ejecuta
`specify extension add .specify/extensions/umbrella-fanout --dev` desde una
ubicación temporal — pero la copia commiteada en
`.specify/extensions/umbrella-fanout/` es la fuente canónica, y la sección 4 es
siempre el fallback.

---

## 5. Cambio de spec / actualización de puntero

Una spec cambia vía `CONTRIBUTING.md`: PR en el repo de specs → review y
aprobación → merge → tag `spec-vX.Y.Z` + entrada en `CHANGELOG.md`. Después cada
módulo decide de forma independiente cuándo moverse:

```sh
git -C modulos/<module>/specs fetch origin
git -C modulos/<module>/specs checkout spec-v<X>.<Y>.<Z>
git -C modulos/<module> add specs
git -C modulos/<module> commit -m "chore: pin specs to spec-v<X>.<Y>.<Z>"
```

Un módulo puede quedarse en un tag anterior mientras termina su trabajo actual.
No bloquea a nadie.

## 6. Cascada de constitution y discovery

La constitution global vive **una vez** en el repo de specs
(`.specify/memory/constitution.md`). Todo repo ve el mismo fichero porque todo
repo monta el mismo submodulo de specs — backend, bff y frontend leen la misma
constitution global idéntica en el mismo tag pineado.

Al trabajar dentro de un módulo, lee en este orden:

1. Global: `modulos/<module>/specs/.specify/memory/constitution.md` (del
   submodulo de specs — mismo contenido para todo repo).
2. Overrides locales (si el fichero existe):
   `modulos/<module>/.specify/memory/constitution.md`.

El fichero local solo añade overrides puntuales (ej. el framework de testing
del lenguaje del módulo). Nunca redefine principios globales.

El discovery (`.agent-context`) vive por repo:

- `modulos/<module>/.specify/memory/.agent-context` — dentro del repo del
  módulo. Apunta a la carpeta/task file de specs que le aplica, ej.
  `specs/specs/NNN-checkout-flow/tasks/frontend.md`.
- Es lo que `/speckit.implement` lee para saber qué task file es dueño del repo.
- El umbrella en sí no necesita uno; solo orquesta.

## 7. Flexibilidad

- Un módulo puede pinear cualquier tag de spec; elige cuándo avanzar.
- Las constituciones locales y los task files son opcionales por módulo.
- Los módulos se añaden/quitan repitiendo el paso 4 de la sección 2; nada más
  cambia.
- Si el fan-out manual se convierte en cuello de botella, automatizamos con
  nuestra propia extensión (sección 4.1) — nunca una de terceros.
