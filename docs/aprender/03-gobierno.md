# 03 — Gobierno: AGENTS.md + BRANCHING.md

> **Rama:** `aprender-02-gobierno` · **Objetivo:** las reglas que hacen que todo
> el mundo (humanos y agentes) trabaje igual: el flujo de ramas y las reglas
> vinculantes para agentes.

## Qué vas a aprender

- Qué es `AGENTS.md` y por qué un agente lo lee antes de tocar nada.
- La convención GitHub Flow documentada para este proyecto (`BRANCHING.md`).
- Que la **protección de `main`** en los módulos se aplica con un script
  (lo construimos en el paso 08; aquí solo documentas la convención).

## Paso 1 — Rama

```sh
git checkout main && git pull
git checkout -b aprender-02-gobierno
```

## Paso 2 — BRANCHING.md

Documenta las reglas de GitHub Flow **de este proyecto**. Contenido guía
(escíbelo tú y compara con `git show a74bf2b:BRANCHING.md`):

- **Reglas (todos los repos)**: `main` única troncal, nunca commiteo directo;
  toda change = rama corta → PR → merge → borrar; ramas `NNN-slug` derivadas por
  el asistente del ROADMAP (nunca escritas a mano); un nombre de rama por
  feature en todos los repos que toca; rama siempre nacida de `main` (lo
  garantiza `fanout.sh`).
- **Per-repo nuances**: qué significa `main` en `specs` (spec liberada, merge =
  nuevo tag), en `<módulo>` (estado buildable), en `umbrella` (estado de
  orquestación; no usa ramas de feature).
- **Tags**: solo `specs` se versiona (`spec-vX.Y.Z`); los módulos pinan a tags.
- **Enforcement**: protección de `main` (1 review + CI requerido, admins
  incluidos, sin force-push ni deletions) aplicada con
  `.specify/scripts/bash/module-bootstrap.sh`.

## Paso 3 — AGENTS.md

Reglas **vinculantes** para cualquier agente que trabaje aquí. El original
tenía: repos y su montaje, el modelo operativo (una sola sesión desde la raíz,
`git -C`, `gh`, nunca `cd`), el orden de lectura de constitution en cascada, el
flujo de cambio de specs, y el pinning de submodulos. Escríbelo y compara:

```sh
git show a74bf2b:AGENTS.md
```

Incluye como mínimo:

```markdown
# AGENTS.md

Reglas vinculantes para agentes que trabajan en este repo.

## Reglas
1. El umbrella es la única sesión de trabajo: NUNCA `cd` a un submodulo.
2. Rutas relativas al umbrella (`modulos/...`), git de submodulo con
   `git -C`, GitHub con `gh` (repo resuelto del remote del submodulo).
3. Constitution en cascada: global primero
   (`modulos/<m>/specs/.specify/memory/constitution.md`), local después
   (`modulos/<m>/.specify/memory/constitution.md`).
4. Submodulos de specs SIEMPRE pineados a tags, nunca a `main`. Actualizar
   punteros es un acto explícito (ver CONTRIBUTING.md).
5. Feature = una spec por feature; las tasks se dividen por repo y el
   `.agent-context` de cada módulo apunta a su task file.
```

## Paso 4 — Commits (dos unidades lógicas, dos commits)

```sh
git add BRANCHING.md
git commit -m "docs: convencion GitHub Flow (BRANCHING.md)"

git add AGENTS.md
git commit -m "docs: reglas vinculantes para agentes (AGENTS.md)"
```

## Paso 5 — PR y merge

```sh
git push -u origin aprender-02-gobierno
gh pr create --title "aprender-02-gobierno: AGENTS + BRANCHING" --body "Reglas vinculantes + convencion de ramas GitHub Flow."
gh pr merge --merge --delete-branch
```

## Verificación

- `git log --oneline -3` muestra tus dos commits.
- Sabes responder: ¿por qué el agente no debe `cd`? ¿Qué se protege y con qué
  script? ¿Qué significa "nunca editar main directo en specs"?
