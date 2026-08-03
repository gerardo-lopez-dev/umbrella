# 06 — Contributing: el proceso de cambio de specs

> **Rama:** `aprender-05-contributing` · **Objetivo:** documentar el flujo por
> el que una spec cambia. Es el proceso que protege la fuente de verdad.

## Qué vas a aprender

- Por qué cambiar una spec es un acto **explícito, revisado y versionado**.
- La secuencia completa: PR → review → tag → CHANGELOG → punteros por módulo.

## Paso 1 — Rama

```sh
git checkout main && git pull
git checkout -b aprender-05-contributing
```

## Paso 2 — Escribe CONTRIBUTING.md

Contenido guía (compáralo con `git show a74bf2b:CONTRIBUTING.md`):

```markdown
# Spec change process

Specs are versioned and shared across modules. Changing an approved spec is
always an explicit, reviewed act — never an automatic update.

## Steps
1. **Open a PR in the specs repo.** Never edit `main` directly.
2. **Review and approval.** Changes require review and approval, enforced by
   branch protection on the specs repo.
3. **On merge:** create a new semver tag (`spec-vMAJOR.MINOR.PATCH`) and add an
   entry to the specs repo `CHANGELOG.md`.
4. **Each module updates its pointer explicitly, when it decides to.** Inside
   the module, pin the specs submodule to the new tag:

   ```sh
   cd modulos/<module>/specs
   git fetch origin
   git checkout spec-v<MAJOR>.<MINOR>.<PATCH>
   cd ../..
   git add specs
   git commit -m "chore: pin specs to spec-v<MAJOR>.<MINOR>.<PATCH>"
   ```

   Never update a module's specs pointer automatically as part of another
   change.

5. **Modules may lag behind.** A module can stay on an older spec version while
   it finishes current implementation work. This blocks no one.
```

## Paso 3 — Commit, PR, merge

```sh
git add CONTRIBUTING.md
git commit -m "docs: proceso de cambio de spec en CONTRIBUTING.md"

git push -u origin aprender-05-contributing
gh pr create --title "aprender-05-contributing: CONTRIBUTING" --body "Flujo de cambio de specs: PR -> review -> tag -> punteros por modulo."
gh pr merge --merge --delete-branch
```

## Verificación

- Sabes responder: ¿qué pasa si dos módulos necesitan specs distintas? ¿Quién
  puede editar `main` de specs? ¿Qué se taggea al mergear?

> **En este paso NO se toca el repo specs** (sigue en `spec-v1.0.0`). Solo se
> documenta el proceso.
