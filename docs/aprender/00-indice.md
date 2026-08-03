# 00 — Índice y reglas del curso

> Meta de este curso: **reconstruir el umbrella con tus manos**, entendiendo cada
> pieza, en pasos pequeños. Cada paso es una rama → commits → PR → merge. Cuando
> termines, tendrás el mismo umbrella que había antes (commit `a74bf2b`), pero
> entendido.

## Por qué estamos aquí

El umbrella anterior estaba completo (spec kit, extensión umbrella-fanout,
scripts, submodulos pineados) pero se construyó **por ti, no por nosotros**. No
aprendiste el flujo. Se borró todo excepto `docs/ROADMAP.md`. Los repos remotos
(`gerardo-lopez-dev/specs`, `gerardo-lopez-dev/microservice-template`) **no se
tocaron**: siguen en GitHub con sus tags y su historia.

## El flujo completo en una página

```
                    repo specs (source of truth)
   specs/NNN-name/{spec,plan,tasks}.md   ← features
            │  se monta como submodule en 2 lugares:
            ▼
  umbrella (orquesta) ──modulos/specs-lib──► specs (referencia, tag fijo)
     │ modulos/<módulo>/specs ──────────────► specs (copia de trabajo, mismo tag)
     ▼
  modulos/<módulo> (implementa) ← clonado desde microservice-template

Ciclo de una feature (una spec, varios repos):
  specify → plan → fanout → tasks → implement → verify → deliver
  ───────   ────   ──────   ─────   ──────────   ──────   ───────
  escribir  plan +  crear     dividir  ejecutar    tests +  PR por repo,
  la spec   módulos   la rama  tasks    tasks en   checklist tag specs,
  (specs)   afectados  en c/   por repo   cada repo  specs    pin punteros
             (plan.md)  repo              (módulo)  aprobado
```

## Reglas de oro (se aplican a TODOS los pasos)

1. **GitHub Flow en todos los repos**: `main` siempre buildable. Nada se
   commitea directo a `main`. Todo cambio = rama → PR → merge → borrar rama.
2. **Una rama por paso** de este curso, nombre `aprender-NN-slug`
   (ej. `aprender-01-skeleton`). Se usa ese prefijo porque estos pasos son
   meta-trabajo del umbrella, **no** features del ROADMAP. Cuando el umbrella
   esté listo, las features reales usarán `NNN-slug` (NNN = número del post del
   ROADMAP, ej. `003-actuator-health-checks`).
3. **Un commit por unidad lógica** con mensaje descriptivo (tipo + descripción
   corta, ej. `chore(speckit): bootstrap spec kit`).
4. **Comprobar lo que se hace** antes de abrir el PR: `git status`, `git diff`,
   y en los pasos con scripts, sus self-tests.
5. **PR con body breve** explicando qué y por qué. Merge (no squash) y borrar
   la rama.

## Los pasos

| Paso | Rama (sugerida) | Qué construyes | Commit real de referencia |
|------|-----------------|----------------|---------------------------|
| `01-conceptos.md` | — (teoría, sin cambios) | Repos, GitHub Flow, tags, cascada | — |
| `02-skeleton.md` | `aprender-01-skeleton` | Estructura + `README.md` | `a74bf2b:README.md` |
| `03-gobierno.md` | `aprender-02-gobierno` | `AGENTS.md` + `BRANCHING.md` | `a74bf2b:AGENTS.md`, `BRANCHING.md` |
| `04-spec-kit.md` | `aprender-03-spec-kit` | `specify init`, constitution global, `init-options.json` | `97a26f6` |
| `05-submodules.md` | `aprender-04-submodules` | `modulos/specs-lib` + `modulos/microservice-template` pineados + `.agent-context` | `827b8bb`, `7607247` |
| `06-contributing.md` | `aprender-05-contributing` | `CONTRIBUTING.md` | `a74bf2b:CONTRIBUTING.md` |
| `07-workflow.md` | `aprender-06-workflow` | `docs/WORKFLOW.md` | `a74bf2b:docs/WORKFLOW.md` |
| `08-fanout.md` | `aprender-07-fanout` | fanout manual + extensión `umbrella-fanout` + scripts + self-tests | `5fcbae0`, `504ed15` |
| `09-comandos.md` | `aprender-08-comandos` | wrapper `/speckit.umbrella.run` | `a74bf2b:.opencode/commands/speckit.umbrella.run.md` |
| `10-ejercicio-e2e.md` | `aprender-09-e2e` | Feature completa de punta a punta (Post 03) + verificación final | `a74bf2b` |

## La clave de respuestas

Todo lo que se borró sigue en la historia de git. La respuesta exacta de
cualquier archivo está en:

```sh
git show a74bf2b:<ruta-del-archivo>
```

Por ejemplo: `git show a74bf2b:AGENTS.md`, `git show a74bf2b:.specify/scripts/bash/fanout.sh`.

**Cómo usarla (importante):** primero escribe cada archivo con tus palabras
siguiendo lo que pide el paso. Usa `git show` solo si te atascas o para
**verificar** al final que no te falta nada. Copiar-pegar sin entender no
aprende.

## Prerrequisitos (verificados en el entorno)

- `git` instalado y con SSH configurado: `ssh -T git@github.com`
- `gh` CLI autenticado: `gh auth status` (cuenta `gerardo-lopez-dev`)
- `specify` CLI: `specify --version` → `0.14.2`
- Repos en GitHub (ya existen, no se tocan):
  - `gerardo-lopez-dev/umbrella` (este)
  - `gerardo-lopez-dev/specs` (con tag `spec-v1.0.0`)
  - `gerardo-lopez-dev/microservice-template` (con su submodule `specs` pineado)

## Cuándo terminaste

Cuando el paso `10` cierre, tu `git log` del umbrella debe contar la misma
historia que la original (`97a26f6` → `a74bf2b`) y los self-tests de fanout
deben pasar. No hay prisa: cada paso tiene su PR y su merge.
