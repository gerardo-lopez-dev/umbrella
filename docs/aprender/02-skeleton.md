# 02 — Skeleton: estructura + README.md

> **Rama:** `aprender-01-skeleton` · **Objetivo:** darle forma al repo y
> documentar qué es. El README describe el **estado objetivo** (la estructura a
> la que llegarás al final del curso), así que lo escribes completo desde ya.

## Qué vas a aprender

- La estructura de directorios que tendrá el umbrella al terminar.
- Escribir un README que es la **entrada** de cualquiera que toque el proyecto
  (incluido un agente).

## Paso 1 — Crea la rama

```sh
git checkout main && git pull
git checkout -b aprender-01-skeleton
```

## Paso 2 — Escribe el README.md

Piensa en qué necesita saber alguien nuevo: qué es el repo, su estructura, el
modelo operativo, la cascada de constitution, el pinning de submodulos. El
README original lo tenía todo; escríbelo **con tus palabras** y luego compáralo
con la referencia:

```sh
git show a74bf2b:README.md
```

Estructura sugerida (secciones del original):

```markdown
# umbrella

Orchestrating repo of a multi-repo project built with Spec Kit (speckit). It
does not hold implementation code: it pins shared specs and the implementation
modules (each in its own repo) as git submodules.

## Structure

    . (this repo, umbrella)
    ├── .specify/                          Spec Kit for the whole project
    │   ├── memory/constitution.md         GLOBAL constitution
    │   ├── init-options.json              speckit config (feature numbering, fan-out)
    │   ├── extensions.yml                 hooks → umbrella-fanout extension
    │   └── scripts/bash/                  fanout.sh, module-bootstrap.sh + self-checks
    ├── modulos/
    │   ├── specs-lib/                     submodule → specs repo, pinned to a tag
    │   └── <module>/                      submodule → implementation repo
    │       ├── specs/                     submodule → same specs repo, same tag
    │       └── .specify/memory/
    │           ├── .agent-context
    │           └── constitution.md        LOCAL overrides (optional)
    ├── AGENTS.md                          binding rules for agents
    ├── BRANCHING.md                       GitHub Flow convention + branch protection
    ├── CONTRIBUTING.md                    spec change process
    ├── docs/
    │   ├── WORKFLOW.md                    end-to-end workflow
    │   └── ROADMAP.md                     project roadmap
    └── .opencode/commands/                /speckit.* commands (incl. umbrella.run)
```

Después, las secciones **Operating model** (todo desde la raíz del umbrella),
**Constitution cascade**, **Submodule pinning** y **Verified state**. Las
escribes ahora aunque las piezas aún no existan: documentan el objetivo.
No copies del original: escríbelo, compara, ajusta.

## Paso 3 — Commit

```sh
git add README.md
git commit -m "docs: bootstrap README (estructura + operating model + cascada)"
```

## Paso 4 — PR y merge

```sh
git push -u origin aprender-01-skeleton
gh pr create --title "aprender-01-skeleton: README" --body "Estructura objetivo del umbrella + modelo operativo."
gh pr merge --merge --delete-branch   # (repo sin branch protection, merge normal)
```

> **Nota:** el umbrella no protege su propio `main` (nada se mergea sin CI que
> lo justifique); la protección se aplica en los **módulos** (paso 03). De todos
> modos practicas el flujo de PR aquí.

## Verificación

- `git log --oneline -1` → tu commit de docs en `main`.
- El repo solo tiene `README.md` y `docs/`.

**Respuesta:** `git show a74bf2b:README.md` (compáralo, no lo copies).
