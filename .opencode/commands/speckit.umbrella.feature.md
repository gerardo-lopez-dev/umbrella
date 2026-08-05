---
description: Orquesta una feature completa de punta a punta desde el umbrella. Un solo comando: doctor → specify → plan → tasks → fanout → implement → verify → deliver. Para en los gates humanos (aprobaciones y merges); reanudable.
mode: agent
model: opencode-go/deepseek-v4-pro
---

## User Input

```text
$ARGUMENTS
```

**MUST** consider the user input before proceeding. Expected shape:

```
/speckit.umbrella.feature <post>           # empezar o retomar una feature
/speckit.umbrella.feature <post> --resume  # retomar explícito
/speckit.umbrella.feature <post> --status  # solo observar: no ejecuta nada
```

`<post>` es el número del ROADMAP (ej. `03`, `Post 03`, `003-actuator`).

## Resolución del nombre feature

1. Lee `docs/ROADMAP.md`.
2. Deriva el nombre: `NNN` = número del post, `slug` = título del post en
   kebab-case. Ejemplo: `Post 03 - Actuator + Health Checks Personalizados` →
   `003-actuator`.
3. El nombre `NNN-slug` es el feature dir, el branch name y el nombre de rama
   en todos los repos. Repórtalo claramente al usuario.

## Preflight (siempre)

```sh
git submodule update --init --recursive
bash .specify/scripts/bash/doctor.sh --fetch
```

Si `doctor.sh` sale con FAIL:

- **FAIL por pin MISMATCH a mitad de deliver** (la feature ya tiene tag creado o
  un PR chore abierto del deliver en curso): no es bloqueante; salta directo a
  Fase 7. El MISMATCH es el estado esperado entre `tag` y el merge de los chore
  PRs.
- **Cualquier otro FAIL**: muéstrale al usuario qué falla y cómo resolverlo
  (commits pendientes, dirty trees, pins inconsistentes). No sigas hasta que
  pase.

## Observación de estado (reanudación)

Antes de cada fase, **observa** qué existe ya y solo corre lo que falta.
Usa `doctor.sh --feature <NNN-slug>` y revisa los artifacts
(`spec.md`/`plan.md`/`tasks.md` en `modulos/specs-lib/specs/<NNN-slug>/`,
ramas locales, PRs vía `gh`). Todo se infiere de git/gh, no hay ledger.

**WIP en un módulo (árbol sucio):** si un módulo está sucio y está en la rama
de la feature `<NNN-slug>`, el trabajo es WIP de una sesión anterior →
commitéalo en la rama con mensaje Conventional Commits
(`git -C modulos/<m> add -A && git -C modulos/<m> commit`) y continúa. Si está
sucio en otra rama, pregúntale al usuario cómo resolverlo.

Si la feature **ya tiene un tag** (se entregó), o las fases restantes son solo
deliver, ve directo a Fase 7.

## Gates humanos (tabla única de verdad)

| Gate | Fase | Qué apruebas | Cómo reanudas |
|------|------|-------------|---------------|
| **G1** | Specify | `modulos/specs-lib/specs/NNN-slug/spec.md` | "ok" / "aprobado" / "siguiente" |
| **G2** | Plan | Affected Repositories + Technical Context | "ok" / "aprobado" / "siguiente" |
| **G3** | Tasks | `tasks.md` y task files por módulo | "ok" / "aprobado" / "siguiente" |
| **G4** | Implement | Cambios implementados en el módulo | "ok" / "aprobado" / "siguiente" |
| **G5** | Verify | Fixes de verify (solo si hubo) | "ok" / "aprobado" / "siguiente" |
| **G6** | Deliver (prs) | Merge de PRs de feature (módulo + specs) | Merges squash del humano → "listo" / "hecho" / "mergeados" |
| **G7** | Deliver (pin) | Merge de PRs chore (módulo + umbrella) | Merges squash del humano → "listo" / "hecho" / "mergeados" |

## --status (solo observar)

Cuando el usuario pasa `--status`, no ejecutes ninguna fase. Solo:
1. Corre `doctor.sh --feature <NNN-slug>`.
2. Revisa los artifacts (`spec.md` / `plan.md` / `tasks.md`), ramas locales y
   PRs vía `gh`.
3. Imprime un mapa de fases marcando ✅ (completada), ⏳ (en progreso, con la
   siguiente acción concreta) y ⬜ (pendiente). Reporta sin cambiar nada y
   termina.

## Ciclo completo (fases que corres secuencialmente)

### Fase 1 — Specify

Si `spec.md` no existe: `/speckit.umbrella.run specs specify <NNN-slug>`.
El subagente `spec-writer` garantiza la rama (`ensure-spec-branch.sh`) y
escribe `spec.md` (ver `.opencode/commands/speckit.umbrella.run.md`).

**→ PUNTO DE PARADA G1** (tabla de gates): presenta los cambios al usuario (archivos
creados/editados). Pregunta: "¿Conforme con la spec? ¿Quieres cambios?".
- Si pide cambios → edítalos en el feature dir → vuelve a preguntar.
- Si confirma ("ok", "aprobado", "siguiente") → haz commit en specs-lib
  (`git -C modulos/specs-lib add ... && git -C modulos/specs-lib commit`)
  con mensaje Conventional Commits → avanza a Fase 2.

### Fase 2 — Plan

Si `plan.md` no existe: `/speckit.umbrella.run specs plan`.
El subagente `spec-writer` completa `plan.md` con Technical Context,
Constitution Check y **Affected Repositories** (módulos cuya implementación
cambiará — esto conduce el fan-out).

**→ PUNTO DE PARADA G2** (tabla de gates): presenta los cambios al usuario. Pregunta:
"¿Conforme con el plan y los affected repos? ¿Quieres cambios?".
- Si pide cambios → edítalos en el feature dir → vuelve a preguntar.
- Si confirma ("ok", "aprobado", "siguiente") → haz commit en specs-lib
  con Conventional Commits → avanza a Fase 3.

### Fase 3 — Tasks

Si `tasks.md` y `tasks/<module>.md` no existen:
`/speckit.umbrella.run specs tasks`.
El subagente `spec-writer` genera `tasks.md` + task files por módulo.

**→ PUNTO DE PARADA G3** (tabla de gates): presenta los cambios al usuario. Pregunta:
"¿Conforme con las tasks? ¿Quieres cambios?".
- Si pide cambios → edítalos en el feature dir → vuelve a preguntar.
- Si confirma ("ok", "aprobado", "siguiente") → haz commit en specs-lib
  con Conventional Commits → avanza a Fase 4 (fanout).

### Fase 4 — Fan-out

Si la rama `NNN-slug` no existe en los módulos afectados:
`/speckit.umbrella.run umbrella fanout --dry-run` primero,
luego `/speckit.umbrella.run umbrella fanout`.
El wrapper delega en `fanout.sh` (desde origin/main, solo módulos afectados,
skippea árboles sucios).

### Fase 5 — Implement

Por cada módulo afectado:
`/speckit.umbrella.run <module> implement`.
El agente lee `.agent-context` → cascada de constitution → task file del
módulo (con fallback a `modulos/specs-lib` si el submódulo specs del módulo
aún no tiene la feature) → implementa las tasks en la rama
`NNN-slug` del módulo.

No avances al siguiente módulo sin que todas las tasks del actual estén
implementadas.

**→ PUNTO DE PARADA G4 (por módulo)**: presenta los cambios del módulo.
Pregunta: "¿Conforme con la implementación de <módulo>? ¿Quieres cambios?".
- Si pide cambios → edítalos → vuelve a preguntar.
- Si confirma ("ok", "aprobado", "siguiente") → haz commit en el módulo
  (`git -C modulos/<module> add -A && git -C modulos/<module> commit`)
  con Conventional Commits → avanza al siguiente módulo o a Fase 6.

### Fase 6 — Verify

Por cada módulo afectado:
`/speckit.umbrella.run <module> verify`.
El subagente `reviewer` cuenta tasks `- [ ]` vs `- [X]`, corre build/tests
(`./mvnw test` o equivalente) y reporta PASS/FAIL/PARTIAL.

Si algún módulo sale FAIL o PARTIAL → arregla los hallazgos y
re-ejecuta verify hasta PASS. No sigas a deliver sin PASS en todos los
módulos.

**→ PUNTO DE PARADA G5**: si hiciste fixes de verify, presenta los cambios.
Pregunta: "¿Conforme con los fixes de verify? ¿Quieres cambios?".
- Si pide cambios → edítalos → vuelve a preguntar.
- Si confirma → haz commit en el módulo.

### Fase 7 — Deliver

Todo va con `deliver.sh <NNN-slug>`. Siempre `--dry-run` primero, luego
ejecución real.

1. **PRs** — `deliver.sh <NNN-slug> prs --dry-run` → revisa →
   `deliver.sh <NNN-slug> prs`. Esto pushea las ramas de los módulos + specs,
   crea los PRs, marca las tasks `[X]` y mete la entrada CHANGELOG.

    **→ PUNTO DE PARADA G6**: el script imprime las URLs de los PRs y el
   comando de merge. **Espera** a que el usuario confirme que mergeó (no
   merges tú). Solo cuando el usuario diga "listo", "hecho", "mergeados" o
   similar, continúa.

2. **Tag + Pin** — `deliver.sh <NNN-slug> --resume --dry-run` → revisa →
   `deliver.sh <NNN-slug> --resume`. Crea el tag `spec-vX.Y.Z`, las ramas
   `chore-spec-vX.Y.Z` por módulo y en el umbrella, y los PRs chore.

    **→ PUNTO DE PARADA G7**: el script imprime los PRs chore y el comando
    de merge. **Espera** confirmación del usuario igual que en G6.

3. **Close** — `deliver.sh <NNN-slug> --resume --dry-run` → revisa →
   `deliver.sh <NNN-slug> --resume`. Verifica los merges, corre
   `doctor --fetch` y limpia las ramas locales huérfanas.

   La feature queda cerrada. El script reporta "listo".

## Opciones extra de deliver.sh

Si el usuario quiere controlar la versión del tag (por defecto el script usa
`--bump patch`), dile que puede añadirlo:

```
bash .specify/scripts/bash/deliver.sh <NNN-slug> prs --bump minor
bash .specify/scripts/bash/deliver.sh <NNN-slug> prs --version spec-v1.1.0
```

## Completion Report

Al final, reporta: feature entregada, tag creado, PRs mergeados, punteros del
umbrella actualizados, `doctor --fetch` PASS. Un resumen en 3 líneas.

## Done When

- [ ] Feature dir `specs/<NNN-slug>/` completo (spec, plan, tasks)
- [ ] Cada módulo afectado implementado, verificado (PASS) y mergeado
- [ ] PR de specs mergeado + tag `spec-vX.Y.Z` creado
- [ ] PRs chore de módulo mergeados (suben specs al nuevo tag)
- [ ] PR chore del umbrella mergeado (specs-lib al tag, módulo a origin/main)
- [ ] `doctor --fetch` PASS
- [ ] Feature cerrada y ramas locales limpias
