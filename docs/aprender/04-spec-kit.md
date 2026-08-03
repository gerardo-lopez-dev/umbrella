# 04 — Spec Kit: `specify init` + constitution global + config

> **Rama:** `aprender-03-spec-kit` · **Objetivo:** instalar Spec Kit (speckit)
> en el umbrella y escribir la **constitution global**, que es la base de
> governance del proyecto entero.

## Qué vas a aprender

- Qué genera `specify init` y qué es de speckit (se regenera) vs. qué es
  **nuestro** (se escribe a mano).
- A escribir una constitution global y su `init-options.json` con el bloque
  `umbrella_fanout`.

## Paso 1 — Rama

```sh
git checkout main && git pull
git checkout -b aprender-03-spec-kit
```

## Paso 2 — `specify init`

```sh
specify init --here --integration opencode
```

Esto genera la **parte estándar de speckit** (no la escribes a mano):

- `.specify/scripts/bash/{common,check-prerequisites,create-new-feature,setup-plan,setup-tasks}.sh`
- `.specify/templates/*` (spec, plan, tasks, checklist, constitution)
- `.specify/workflows/speckit/*`
- `.specify/integration.json`, `.specify/integrations/*`
- `.opencode/commands/speckit.{analyze,checklist,clarify,constitution,converge,implement,plan,specify,tasks,taskstoissues}.md`
  (los comandos estándar del ciclo de feature; **`speckit.verify` NO viene aquí**,
  se escribe a mano en el paso 08)

Ábrelos por encima y dime con tus palabras qué hace
`.specify/scripts/bash/check-prerequisites.sh` (pista: `--paths-only` imprime
`REPO_ROOT`, `BRANCH`, `FEATURE_DIR`, `FEATURE_SPEC`, `IMPL_PLAN`, `TASKS`;
sin `--paths-only`, valida que existan el feature dir y el plan).

> **Concepto clave:** speckit resuelve "dónde estoy" con `REPO_ROOT` y "sobre
> qué feature trabajo" con `FEATURE_DIR`. Ese mecanismo es lo que luego
> reutiliza el umbrella para apuntar a `modulos/<target>` desde la raíz.

## Paso 3 — Constitution global

Escribe `.specify/memory/constitution.md`. Es el governance del proyecto
multi-repo completo: **Spec-First** (nada se implementa sin spec aprobada,
versionada con tags), **cambio de spec por PR**, **calidad sobre cantidad**,
**testing obligatorio**, **arquitectura con bordes claros** (dominio no depende
de infraestructura), y las secciones de **cascada**, **workflow de desarrollo**
y **governance** (cómo se enmienda ella misma). Estructura mínima:

```markdown
# Umbrella Constitution

Constitution global del proyecto multi-repo (orquestado por `umbrella`). Aplica
a todos los módulos por igual. Los módulos pueden agregar overrides locales
puntuales que NUNCA contradicen estos principios.

## Core Principles
### I. Spec-First (NON-NEGOTIABLE)
### II. Cambio de spec controlado por PR
### III. Quality Before Quantity
### IV. Testing is Non-Negotiable
### V. Arquitectura compartida con bordes claros

## Additional Constraints
### Constitution cascade
1. GLOBAL primero: `modulos/<modulo>/specs/.specify/memory/constitution.md`
2. LOCAL después: `modulos/<modulo>/.specify/memory/constitution.md` (si existe)

## Development Workflow
## Governance

**Version**: 1.0.0 | **Ratified**: <fecha> | **Last Amended**: <fecha>
```

Escríbela completa con tus palabras; la referencia (idéntica a lo que estaba en
`specs`) está en `git show a74bf2b:.specify/memory/constitution.md`.

## Paso 4 — `init-options.json` con el bloque `umbrella_fanout`

Abre el `init-options.json` que generó `specify init` y agrégale el bloque de
configuración del fan-out (lo usará el `fanout.sh` del paso 08):

```json
{
  "ai": "opencode",
  "feature_numbering": "sequential",
  "here": true,
  "integration": "opencode",
  "script": "sh",
  "speckit_version": "0.14.2",
  "umbrella_fanout": {
    "type": "submodule",
    "switch": true,
    "base": "main",
    "skip_branches": ["main", "master"],
    "exclude": []
  }
}
```

Comprende cada clave: `switch` = crear y hacer checkout de la rama en el
módulo; `base` = rama base de la que nacen las ramas de feature; `skip_branches`
= nombres que jamás se fan-outtean; `exclude` = módulos a saltar.

## Paso 5 — Commits

```sh
git add .specify .opencode
git commit -m "chore(speckit): init spec kit + config umbrella_fanout"

git add .specify/memory/constitution.md
git commit -m "chore(speckit): constitution global v1.0.0"
```

> Si `specify init` dejó algún archivo que no entiendes, investiga antes de
> commitear. Todo lo que commitas debe tener un propósito.

## Paso 6 — PR y merge

```sh
git push -u origin aprender-03-spec-kit
gh pr create --title "aprender-03-spec-kit: init + constitution global" --body "Spec Kit 0.14.2 + constitution global v1.0.0 + bloque umbrella_fanout en init-options."
gh pr merge --merge --delete-branch
```

## Verificación

- `specify --version` sigue en `0.14.2`.
- `bash .specify/scripts/bash/check-prerequisites.sh --paths-only` imprime las
  rutas sin error.
- Tu constitution tiene las 5 secciones de Core Principles.

**Respuestas:** `git show a74bf2b:.specify/memory/constitution.md`,
`git show a74bf2b:.specify/init-options.json`.
