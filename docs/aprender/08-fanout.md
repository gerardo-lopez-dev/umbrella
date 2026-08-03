# 08 — Fan-out: protección de main + extensión umbrella-fanout

> **Rama:** `aprender-07-fanout` · **Objetivo:** construir la automatización
> **propia** que envuelve la sección 4 del WORKFLOW (fan-out manual), más el
> script que protege `main` de los módulos. Es el paso más grande: cuatro
> unidades de trabajo, cuatro commits, un PR.

## Qué vas a aprender

- `gh api` para aplicar branch protection a `main` de un módulo.
- El contrato del fan-out (`fanout.sh`) y cómo **automatizar un procedimiento
  documentado** sin romperlo.
- Cómo una extensión de speckit expone un comando de agente y se engancha a los
  hooks `after_plan` / `after_tasks`.
- Cómo los **self-tests** definen "hecho" para un script.

> **Clave de respuestas para todo este paso:**
> `git show a74bf2b:.specify/scripts/bash/fanout.sh`,
> `git show a74bf2b:.specify/scripts/bash/module-bootstrap.sh`,
> `git show a74bf2b:.specify/scripts/bash/ci_jobs.py`,
> `git show a74bf2b:.specify/extensions/umbrella-fanout/extension.yml`.
> Escribe primero; usa el show solo si te atascas.

---

## Paso 1 — Rama

```sh
git checkout main && git pull
git checkout -b aprender-07-fanout
```

---

## Paso 2 — Parte A: protección de main (module-bootstrap)

El contrato: dado `modulos/<módulo>`, resuelve el repo GitHub desde su remote y
aplica protección a `main` con `gh api PUT`: 1 review requerida, CI checks
requeridos (auto-detectados), admins incluidos, sin force-push, sin deletions.
Idempotente (re-ejecutar re-aplica). Flags: `--dry-run`, `--ci job1,job2`.

Primero el detector de jobs CI (`ci_jobs.py` — pequeño, escríbelo tal cual y
entiéndelo):

```python
#!/usr/bin/env python3
"""Extract GitHub Actions job names from a repo's workflow files.

Usage: ci_jobs.py <repo-dir>   -> prints "job1,job2" (sorted, deduped)
Used by module-bootstrap.sh to auto-detect required status checks.
"""
import glob
import os
import re
import sys


def ci_jobs(repo_dir):
    jobs = []
    for f in glob.glob(os.path.join(repo_dir, ".github", "workflows", "*")):
        if not f.endswith((".yml", ".yaml")):
            continue
        try:
            text = open(f, encoding="utf-8").read()
        except OSError:
            continue
        m = re.search(r"^jobs:\s*\n((?:.*\n)*?)(?=^\S|\Z)", text, re.M)
        if m:
            jobs += re.findall(r"^\s{2}([a-zA-Z0-9_-]+):\s*$", m.group(1), re.M)
    return sorted(set(jobs))


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit("usage: ci_jobs.py <repo-dir>")
    print(",".join(ci_jobs(sys.argv[1])))
```

Ahora `module-bootstrap.sh`: argumaentos (`<module>` | `--dry-run` | `--ci`) →
fuentea `common.sh` → `get_repo_root` → resuelve el repo desde
`git config --get remote.origin.url` (con `sed`) → detecta jobs → construye el
payload JSON (mira la referencia para la forma exacta: `required_status_checks`
con `strict: true`, `required_pull_request_reviews` con 1 review, `enforce_admins`,
`allow_force_pushes: false`, `allow_deletions: false`) → `gh api -X PUT` al
endpoint `repos/<repo>/branches/main/protection`. Con `--dry-run` solo imprime.

El self-test `module-bootstrap-test.sh` define "hecho": crea un repo falso en
`/tmp/opencode`, con un `.github/workflows/ci.yml` con jobs `build` y `lint`,
y verifica: (1) `ci_jobs.py` parsea `build,lint`; (2) `--dry-run` resuelve
`owner/fake-service`; (3) `--ci build` hornea `"build"` en el payload;
(4) auto-detecta "required checks: build,lint".

**Commit A:**

```sh
git add .specify/scripts/bash/ci_jobs.py .specify/scripts/bash/module-bootstrap.sh .specify/scripts/bash/module-bootstrap-test.sh
git commit -m "chore: proteccion de main en modulos (module-bootstrap + self-test)"
```

---

## Paso 3 — Parte B: el motor del fan-out (fanout.sh)

El contrato de la sección 4 del WORKFLOW, automatizado. `fanout.sh` debe:

- **Args**: `--dry-run`, `-b|--branch <name>`, `--base <branch>`, `--plan <file>`,
  `-m|--module <name>` (repetible), `--switch <y|n>`, `-h`.
- **Config** de `init-options.json` (bloque `umbrella_fanout`): `type`, `switch`,
  `base`, `skip_branches`, `exclude` (usa `python3` para leer el JSON).
- **Rama**: `--branch` gana; si no, la rama actual de `modulos/specs-lib`; si no
  hay, error.
- **Módulos**: `-m` gana; si no, la sección **Affected Repositories** del
  `--plan` (regex del estilo `^#.*Affected Repositories` + items `- <name>`).
- **Seguridad**: nunca tocar `skip_branches`; saltar módulos en `exclude`; saltar
  si no hay repo git; saltar si la rama ya existe (idempotente); **saltar si el
  working tree está sucio**; `--dry-run` solo imprime.
- **Acción**: `git fetch origin` → `checkout -b <branch>` desde `origin/<base>`
  (base default `main`) → reportar `created`/`exists`/`skipped`/`failed`.

El self-test `fanout-test.sh` define "hecho": construye un umbrella de juguete en
`/tmp/opencode`, con `specs-lib` en la rama `001-checkout`, un módulo limpio
(`microservice-template`), uno sucio (`products-service` con un archivo
untracked) y un `plan.md` con Affected Repositories. Verifica:
1. Crea la rama en el módulo limpio.
2. Salta el módulo sucio (`SKIP`).
3. Re-ejecutar reporta `exists` (idempotente).
4. `--branch main` sale por `Skipped` (skip_branches).
5. Sin módulos afectados → no toca ningún módulo.
6. `--dry-run` no crea ramas.
7. `--base develop -m bff-service` crea la rama desde `develop` y lo reporta.

**Commit B:**

```sh
git add .specify/scripts/bash/fanout.sh .specify/scripts/bash/fanout-test.sh
git commit -m "feat(fanout): fanout.sh (base main por defecto + flag --base) + self-test"
```

---

## Paso 4 — Parte C: la extensión umbrella-fanout + `speckit.verify`

La extensión expone el comando de agente `speckit.umbrella-fanout.fanout` y se
engancha a los hooks `after_plan` y `after_tasks`. Escribe:

**`.specify/extensions/umbrella-fanout/extension.yml`** (es el manifiesto; así
era el original):

```yaml
schema_version: "1.0"
extension:
  id: umbrella-fanout
  name: Umbrella Fanout
  version: 0.1.0
  description: In-house branch fan-out across module submodules (docs/WORKFLOW.md 4.1)
  category: workflow
  effect: read-write
requires:
  speckit_version: ">=0.14.0"
provides:
  commands:
    - name: speckit.umbrella-fanout.fanout
      file: commands/fanout.md
hooks:
  after_plan:
    - command: speckit.umbrella-fanout.fanout
      optional: true
      priority: 10
      description: Fan out the feature branch to the modules listed in plan.md's Affected Repositories
  after_tasks:
    - command: speckit.umbrella-fanout.fanout
      optional: true
      priority: 10
      description: Fan out the feature branch to the modules listed in plan.md's Affected Repositories
```

**`.specify/extensions/umbrella-fanout/commands/fanout.md`** — el comando que
lee el agente. Debe decir: resolver config → resolver rama (`--branch` o la rama
de `modulos/specs-lib`) → resolver módulos (`-m` o Affected Repositories del
`plan.md`) → correr `fanout.sh --dry-run` primero y luego real → reportar por
módulo (`created`/`exists`/`skipped`/`failed`), sin forzar checkouts sobre
working trees sucios. (Referencia: `git show a74bf2b:.specify/extensions/umbrella-fanout/commands/fanout.md`.)

**Registra la extensión.** Comportamiento verificado de `specify extension add`:
**copia** la extensión al destino `.specify/extensions/<id>/` y falla si la
fuente ES ese destino. Por eso se autorra la extensión en una copia temporal y
se instala desde ahí:

```sh
# (1) arma la extensión en una carpeta temporal, p. ej. /tmp/umbrella-fanout
#     con extension.yml + commands/fanout.md

# (2) desde la raíz del umbrella, instala DESDE la copia temporal
specify extension add /tmp/umbrella-fanout --dev

# (3) la copia instalada (canónica y commiteable) queda en:
#     .specify/extensions/umbrella-fanout/
```

Esto crea `.specify/extensions.yml` (`installed:`, `auto_execute_hooks: true`),
el `.registry` y copia el comando a `.opencode/commands/speckit.umbrella-fanout.fanout.md`.
**Los hooks no se autopopulan**: escríbelos a mano en `.specify/extensions.yml`
(compáralo con `git show a74bf2b:.specify/extensions.yml`):

```yaml
installed:
- umbrella-fanout
settings:
  auto_execute_hooks: true
hooks:
  after_plan:
  - extension: umbrella-fanout
    command: speckit.umbrella-fanout.fanout
    enabled: true
    optional: true
    priority: 10
    prompt: Execute speckit.umbrella-fanout.fanout?
    description: Fan out the feature branch to the modules listed in plan.md's Affected Repositories
    condition: null
  after_tasks:
  - extension: umbrella-fanout
    command: speckit.umbrella-fanout.fanout
    enabled: true
    optional: true
    priority: 10
    prompt: Execute speckit.umbrella-fanout.fanout?
    description: Fan out the feature branch to the modules listed in plan.md's Affected Repositories
    condition: null
```

**El comando `speckit.verify`** (no viene de `specify init`; es nuestro). Es el
verificador del ciclo: lee las rutas con `check-prerequisites.sh --paths-only`,
cuenta `- [ ]`/`- [X]` del `tasks.md`, cuenta los checklists de
`FEATURE_DIR/checklists/`, detecta el comando de test del módulo (`pom.xml` →
`./mvnw test`, `package.json` → `npm test`, …) y lo corre, relee la spec y los
contracts para detectar drift, y emite verdicto **PASS / FAIL / PARTIAL** con la
evidencia (comandos y salidas exactas). Referencia:
`git show a74bf2b:.opencode/commands/speckit.verify.md`. Escribelo como parte
de este commit:

**Commit C:**

```sh
git add .specify/extensions .specify/extensions.yml .specify/extensions/.registry .opencode/commands/speckit.umbrella-fanout.fanout.md .opencode/commands/speckit.verify.md
git commit -m "feat(speckit): extension umbrella-fanout + comando speckit.verify + hooks"
```

---

## Paso 5 — Parte D: self-test de contexto

`context-test.sh` verifica el corazón del operating model: que el contexto
speckit se resuelve **desde la raíz del umbrella** sin `cd`. Arma un tree falso
y comprueba que `SPECIFY_FEATURE_DIRECTORY=modulos/specs-lib/specs/NNN-fake`
hace que `check-prerequisites.sh --paths-only` devuelva `REPO_ROOT` = el umbrella
y `FEATURE_DIR` dentro de `modulos/specs-lib`; y que `SPECIFY_INIT_DIR` redirige
`REPO_ROOT` al target con su propio `.specify/feature.json`. (Referencia:
`git show a74bf2b:.specify/scripts/bash/context-test.sh`.)

**Commit D:**

```sh
git add .specify/scripts/bash/context-test.sh
git commit -m "test(fanout): self-test de contexto (todo desde la raiz)"
```

---

## Paso 6 — Verifica y PR

```sh
bash .specify/scripts/bash/fanout-test.sh
bash .specify/scripts/bash/module-bootstrap-test.sh
bash .specify/scripts/bash/context-test.sh
# las tres deben imprimir "...: PASS"

git push -u origin aprender-07-fanout
gh pr create --title "aprender-07-fanout: proteccion de main + extension fanout" --body "module-bootstrap, fanout.sh + self-tests, extension umbrella-fanout (hooks after_plan/after_tasks)."
gh pr merge --merge --delete-branch
```

## Verificación

- Los 3 self-tests pasan.
- `specify` reconoce la extensión (`.specify/extensions.yml` con los hooks).
- Puedes explicar por qué el fan-out **nunca** fuerza un checkout sobre un tree
  sucio.

> **Ojo real:** `module-bootstrap.sh` aplica protección a GitHub. No lo corras
> contra `microservice-template` "en seco" sin `--dry-run` primero — el template
> ya tiene `main` protegido (es idempotente, pero practica con `--dry-run`).
