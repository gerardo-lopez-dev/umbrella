# umbrella

Orchestrating repo of a multi-repo project built with Spec Kit (speckit). It
does not hold implementation code: it pins shared specs and the implementation
modules (each in its own repo) as git submodules.

## Structure

```
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
│   ├── ROADMAP.md                     project roadmap
│   └── aprender/                      tutorial del curso (este repo)
└── .opencode/commands/                /speckit.* commands (incl. umbrella.run)
```

## Operating model — todo desde la raíz del umbrella

El umbrella es el **único** espacio de trabajo. Nunca `cd` a un submodulo ni
abras una sesión dentro de uno: los ficheros se referencian con rutas
relativas al umbrella (`modulos/...`), git de los submodulos se ejecuta con
`git -C modulos/<m>`, GitHub con `gh` resolviendo el repo desde el remote del
submodulo, y el contexto de speckit se resuelve via
`SPECIFY_FEATURE_DIRECTORY`. Punto de entrada único para todas las fases:

```
/speckit.umbrella.run <target> <phase>
```

| Target | Root on disk | Phases |
|--------|--------------|--------|
| `specs` | `modulos/specs-lib` | `specify`, `plan`, `tasks` |
| `umbrella` | `.` | `fanout` |
| `<module>` | `modulos/<module>` | `implement`, `verify` |

Los nombres de feature/rama siguen `NNN-slug` (`BRANCHING.md`); el asistente
los deriva del ROADMAP, no se escriben a mano.

## Cascada de constitution

Orden de lectura para quien implemente dentro de un modulo:

1. **Global primero**: `modulos/<module>/specs/.specify/memory/constitution.md`
   (el submodulo de specs, misma versión etiquetada para todos los modulos).
2. **Overrides locales después** (si existen):
   `modulos/<module>/.specify/memory/constitution.md`. Los locales solo añaden
   overrides puntuales; nunca contradicen la global.

Revisa `modulos/<module>/.specify/memory/.agent-context` para saber qué carpeta
de `specs/specs/` aplica a ese modulo.

## Submodule pinning

Todo submodulo `specs` queda anclado a una tag fija (nunca `main`). Actualizar
las specs de un modulo es siempre un acto explícito. Ver `CONTRIBUTING.md`
para el flujo de cambio de specs.

## Verified state

- Submodulos anclados a `spec-v1.0.1` (`modulos/specs-lib` y
  `modulos/microservice-template/specs`, mismo commit).
- `microservice-template` en `main`; su `main` está protegido (PR requerido,
  CI `build` requerida, strict, admins enforced, sin force-push/deletes).
- `specs` repo `main` también protegido (PR requerido, admins enforced, sin
  force-push/deletes — sin CI; specs no tiene).
- Protección sin aprobación obligatoria: setup solo-dev — el dueño squash-mergea
  su propio PR (`gh pr merge --squash --delete-branch`). Re-add 1 approval
  cuando haya reviewers.
- Self-checks PASS: `bash .specify/scripts/bash/{fanout-test,module-bootstrap-test,context-test,ensure-spec-branch-test}.sh`.
