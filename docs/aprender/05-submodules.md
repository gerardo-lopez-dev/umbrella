# 05 — Submodulos: specs-lib y el primer módulo (pineados)

> **Rama:** `aprender-04-submodules` · **Objetivo:** montar el repo `specs` y el
> primer módulo (`microservice-template`) como submodulos, **pineados a tags**,
> y dejar el `.agent-context` del módulo apuntando a su spec.

## Qué vas a aprender

- `git submodule add` y el archivo `.gitmodules`.
- **Pinear a un tag** (nunca quedarse en `main` de specs).
- Materializar los submodulos anidados de un módulo (`--recursive`).
- El `.agent-context`: cómo un módulo declara qué spec le aplica.

## Paso 1 — Rama

```sh
git checkout main && git pull
git checkout -b aprender-04-submodules
```

## Paso 2 — Verifica los repos remotos (no se tocan, se consultan)

```sh
git ls-remote git@github.com:gerardo-lopez-dev/specs.git 'refs/tags/*'
git ls-remote git@github.com:gerardo-lopez-dev/microservice-template.git 'refs/heads/main'
```

Debes ver el tag `spec-v1.0.0` (≈ commit `8643569…`) y `main` del template.

## Paso 3 — Monta specs-lib (la referencia del umbrella)

```sh
git submodule add git@github.com:gerardo-lopez-dev/specs.git modulos/specs-lib
git -C modulos/specs-lib checkout spec-v1.0.0
```

Esto crea `.gitmodules` y registra el submodulo. El checkout del tag lo deja en
estado **detached** (sin rama) — es exactamente lo que queremos: nadie edita la
spec en el umbrella, solo se lee.

## Paso 4 — Monta el primer módulo

```sh
git submodule add git@github.com:gerardo-lopez-dev/microservice-template.git modulos/microservice-template
```

El template **trae su propio submodulo `specs`** (registrado en su
`.gitmodules`). Materialízalo y pínealo:

```sh
git -C modulos/microservice-template submodule update --init --recursive
git -C modulos/microservice-template/specs checkout spec-v1.0.0
```

> **Pregunta para ti:** ¿por qué el template tiene un submodulo `specs` dentro?
> (Respuesta: el código del módulo debe viajar con su spec; si abres el repo en
> GitHub, la spec va incluida.)

## Paso 5 — `.agent-context` del módulo

Crea `modulos/microservice-template/.specify/memory/.agent-context`. Es lo que
lee un agente para saber **qué folder de specs le aplica** y en qué orden leer
la constitution:

```markdown
# Agent Context — microservice-template

This module is the base microservice template (Spring Boot 4.1 / Java 21 /
PostgreSQL, Docker multi-stage, CI/CD). Every other microservice in the project
is generated from it.

- **Applies specs from**: `specs/specs/` (the specs submodule). The folder that
  applies to this module is the template/infrastructure feature(s) — e.g.
  `specs/specs/*/tasks/microservice-template.md`.
- **Constitution cascade**: read the global constitution first at
  `specs/.specify/memory/constitution.md`, then the local one at
  `.specify/memory/constitution.md` if it exists (currently none — no local
  overrides).
- **Specs submodule is pinned to a tag** (`spec-v1.0.0`). Never move it to a new
  tag on your own; propose spec changes through the specs repo PR flow.
```

> **Regla:** la constitution **local** del módulo solo se crea si hay overrides
> reales (ej. el framework de testing del lenguaje). El template no tiene → no
> crees `constitution.md` local.

## Paso 6 — Documenta la cascada en el README

El `AGENTS.md` del paso 03 ya documenta la cascada. Refuerza lo mismo en el
`README.md` (sección **Constitution cascade**), describiendo el orden: global
primero (`modulos/<m>/specs/.specify/memory/constitution.md`), local después
(`modulos/<m>/.specify/memory/constitution.md`).

## Paso 7 — Commits (tres unidades lógicas)

```sh
git add .gitmodules modulos/specs-lib
git commit -m "chore: agrega specs-lib pineado a spec-v1.0.0"

git add modulos/microservice-template
git commit -m "chore: agrega modulo microservice-template con specs pineado"

git add README.md
git commit -m "docs: documenta orden de lectura de constitution en cascada"
```

## Paso 8 — PR y merge

```sh
git push -u origin aprender-04-submodules
gh pr create --title "aprender-04-submodules: specs-lib + primer modulo" --body "Submodulos pineados a spec-v1.0.0 + .agent-context del template."
gh pr merge --merge --delete-branch
```

## Verificación

- `git submodule status` muestra los 3 submodulos (specs-lib, microservice-template,
  y `modulos/microservice-template/specs`) todos en `spec-v1.0.0`.
- `git -C modulos/specs-lib describe --tags` → `spec-v1.0.0`.
- `git -C modulos/microservice-template/specs describe --tags` → `spec-v1.0.0`.
- `modulos/microservice-template/.specify/memory/.agent-context` existe y
  menciona la cascada y el pin.

**Respuestas:** `git show 7607247` (módulo) y `git show 827b8bb` (specs-lib).
