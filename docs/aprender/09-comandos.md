# 09 — El wrapper: `/speckit.umbrella.run`

> **Rama:** `aprender-08-comandos` · **Objetivo:** el **único punto de entrada**
> del umbrella: un comando de agente que corre cualquier fase contra cualquier
> target (`specs`, `umbrella` o un módulo) **sin salir de la raíz**.

## Qué vas a aprender

- Cómo un comando de opencode (`.opencode/commands/*.md`) le dice a un agente
  qué hacer.
- El mapeo target → fase → contexto speckit, y por qué `SPECIFY_FEATURE_DIRECTORY`
  es la palanca que lo hace todo funcionar desde la raíz.

## Paso 1 — Rama

```sh
git checkout main && git pull
git checkout -b aprender-08-comandos
```

## Paso 2 — Escribe `.opencode/commands/speckit.umbrella.run.md`

El comando recibe `$ARGUMENTS` con la forma `/speckit.umbrella.run <target> <phase> [args]`
y delega en los comandos estándar que ya generó `specify init` (`/speckit.specify`,
`/speckit.plan`, `/speckit.tasks`, `/speckit.implement`, `/speckit.verify`).

Debe contener:

1. **Operating model (binding)**: el umbrella es la única sesión; nunca `cd`; la
   tabla target → root en disco → contexto speckit:

   | Target | Root on disk | Speckit context |
   |--------|--------------|-----------------|
   | `specs` | `modulos/specs-lib` | `SPECIFY_FEATURE_DIRECTORY=modulos/specs-lib/specs/NNN-name` |
   | `umbrella` | `.` | umbrella's `.specify/feature.json` |
   | `<module>` | `modulos/<module>` | module-mounted specs at `modulos/<module>/specs/specs/NNN-name` |

2. **Outline** — para cada fase:
   - `specify [<feature>]` → crear la feature en specs. El nombre sigue `NNN-slug`
     y lo **deriva del ROADMAP** (ej. "Post 01" → `001-spring-profiles`), nunca se
     teclea. Se setea `SPECIFY_FEATURE_DIRECTORY=modulos/specs-lib/specs/<feature>`.
   - `plan` / `tasks` → corren contra specs con la misma variable. En `plan.md` se
     registran los **Affected Repositories** (esto conduce el fan-out).
   - `fanout` → delega en `/speckit.umbrella-fanout.fanout`.
   - `implement` → en el módulo: leer `.agent-context` → leer el task file del
     módulo (`modulos/<m>/specs/specs/NNN-name/tasks/<m>.md`) → leer la cascada
     de constitution → implementar los tasks escribiendo archivos bajo
     `modulos/<m>/` (builds/tests como subprocesos con working dir del módulo).
   - `verify` → por módulo: correr build/tests y revisar su task file; por
     feature: revisar `tasks.md` y `checklists/` en la feature dir. Verdicto
     PASS/FAIL/PARTIAL.

3. **Regla de oro**: si un helper de speckit necesita el root del propio target
   (uno con su propio `.specify/feature.json`), setea `SPECIFY_INIT_DIR=modulos/<target>`;
   si no, basta `SPECIFY_FEATURE_DIRECTORY` + rutas relativas al umbrella.

Cierra con un **Completion Report** (target, fase, feature dir, archivos
cambiados, qué falta — PRs, tag) y el **Done When** (fase corrió contra el
target correcto sin `cd`; feature dir resuelta y reportada; módulos respetaron
`.agent-context` y la cascada).

Compara al terminar con `git show a74bf2b:.opencode/commands/speckit.umbrella.run.md`.

## Paso 3 — Commit, PR, merge

```sh
git add .opencode/commands/speckit.umbrella.run.md
git commit -m "feat(speckit): wrapper umbrella.run — todo desde la raiz del umbrella"

git push -u origin aprender-08-comandos
gh pr create --title "aprender-08-comandos: wrapper umbrella.run" --body "Unico punto de entrada: /speckit.umbrella.run <target> <phase> desde la raiz."
gh pr merge --merge --delete-branch
```

## Verificación

- Explicas por qué `SPECIFY_FEATURE_DIRECTORY` + `git -C` + `gh` hacen
  innecesario el `cd`.
- Sabes qué fase usa cada target (specs: specify/plan/tasks; umbrella: fanout;
  módulo: implement/verify).
