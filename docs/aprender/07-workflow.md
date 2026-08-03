# 07 — WORKFLOW: el ciclo de feature documentado

> **Rama:** `aprender-06-workflow` · **Objetivo:** escribir
> `docs/WORKFLOW.md`, el documento que define **cómo funciona el flujo de punta
> a punta**. Es el corazón del proyecto. Este paso lo escribes con calma.

## Qué vas a aprender

- Las 7 secciones del workflow real y qué decide cada una.
- El ciclo: specify → plan → fanout → tasks → implement → verify → deliver.
- La **sección 4 (fan-out manual con git puro)** — es el contrato que el paso 08
  automatizará.

## Paso 1 — Rama

```sh
git checkout main && git pull
git checkout -b aprender-06-workflow
```

## Paso 2 — Escribe docs/WORKFLOW.md

El documento tiene **7 secciones**. Escribe cada una con tus palabras y
compárala con `git show a74bf2b:docs/WORKFLOW.md` (430 líneas: no la copies, usa
la guía de abajo y completa con la referencia).

### 1. Roles de los repos

Tabla: `umbrella` (orquesta, sin implementación), `specs` (fuente de verdad,
tags `spec-vX.Y.Z`), `<módulo>` (implementa, consume specs como submodulo
pineado). Explica que specs se monta **dos veces**: `modulos/specs-lib`
(referencia) y `modulos/<módulo>/specs` (copia de trabajo), mismo tag.

**1.1 Operating model — todo desde la raíz**: el umbrella es la única sesión;
nunca `cd`; rutas relativas; `git -C modulos/<m>`; `gh` con repo resuelto del
remote; contexto speckit vía `SPECIFY_FEATURE_DIRECTORY`. Incluye la tabla de
targets:

| Target | Root on disk | Phases |
|--------|--------------|--------|
| `specs` | `modulos/specs-lib` | `specify`, `plan`, `tasks` |
| `umbrella` | `.` | `fanout` |
| `<module>` | `modulos/<module>` | `implement`, `verify` |

### 2. Getting started (configurar el umbrella paso a paso)

El bootstrap completo en 8 pasos (prerrequisitos, init de spec kit, crear specs
repo + tag, pin specs-lib, añadir primer módulo + protección, cascada,
CONTRIBUTING, extensión propia, verificación). Tú ya hiciste casi todo en pasos
anteriores — este documento lo **registra** como procedimiento reproducible.
Incluye dónde viven spec/plan/tasks (`specs/NNN-name/…`) y la estructura de una
feature multi-repo (un `spec.md`, tasks divididas en `tasks/<repo>.md`).
Cierra con el mapeo al ROADMAP: cada Post → feature `specs/NNN-<slug>/` y a qué
módulos afecta.

### 3. Feature lifecycle

Los 8 pasos del ciclo (specify → plan → fanout → tasks → implement → verify →
deliver) con su referencia a los comandos `/speckit.*`.

**3.1 Multi-developer workflow**: specs repo = único punto de coordinación
compartido. Rama por feature en specs, sub-branches por dueño si varios devs,
`plan.md` (Affected Repositories) dice qué módulos coordinan. Cada dev: sincroniza
submodulos → fan-out → task file propio → implementa → verify → PRs (uno por
módulo + uno en specs). Explica **por qué esto evita conflictos** (features en
carpetas separadas, protección de main, punteros inmutables).

### 4. Branch fan-out (manual git — el contrato)

```sh
git submodule update --init --recursive

# specs repo (via the umbrella reference)
git -C modulos/specs-lib fetch origin
git -C modulos/specs-lib checkout -b <feature-branch>

# each affected module — always born from the latest origin/main (base = main)
for m in users products orders; do
  git -C modulos/$m fetch origin
  git -C modulos/$m checkout -b <feature-branch> origin/main
done
```

Notas del contrato (léelas y escríbelas con tus palabras): fan-out **solo** a
los módulos que el plan marca como afectados; mismo nombre de rama en todos los
repos; base = `main` por defecto; nunca se toca un repo no afectado.

**4.1 Own automation (in-house)**: declara que la sección 4 es el contrato y que
la automatización es **propia** (nunca una extensión de terceros). Describe el
plan de construcción de la extensión `umbrella-fanout` (scaffold → hooks
`after_plan`/`after_tasks` → config en init-options → safety → verify). El paso
08 la construye; aquí la documento.

### 5. Spec change / pointer update

El flujo del CONTRIBUTING (PR → review → tag + CHANGELOG → cada módulo mueve su
puntero cuando decide). Un módulo puede quedarse en un tag viejo; no bloquea a
nadie.

### 6. Constitution cascade and discovery

La cascada (global primero, local después) + `.agent-context` por repo (apunta
al task file que le toca). El umbrella no necesita `.agent-context`: solo
orquesta.

### 7. Flexibility

Reglas que mantienen el sistema flexible: módulo pinea el tag que quiera;
constituciones locales y task files son opcionales; añadir/quitar módulos =
repetir el paso 4 de la sección 2; si el fan-out manual es cuello de botella →
automatización propia, nunca de terceros.

## Paso 3 — Commit, PR, merge

```sh
git add docs/WORKFLOW.md
git commit -m "docs: WORKFLOW (ciclo de feature + operating model + fan-out)"

git push -u origin aprender-06-workflow
gh pr create --title "aprender-06-workflow: WORKFLOW" --body "El flujo completo: roles, ciclo de feature, fan-out manual (contrato) y flexibilidad."
gh pr merge --merge --delete-branch
```

## Verificación

- Relees `docs/WORKFLOW.md` y puedes explicar el ciclo de una feature sin mirar
  el documento.
- Sabes dónde está el **contrato** del fan-out (sección 4) — lo necesitas en el
  siguiente paso.
