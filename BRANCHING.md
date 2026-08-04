# Branching convention — GitHub Flow (all repos)

Cada repo del proyecto (umbrella, specs, cada módulo) sigue **GitHub Flow**:
`main` es la única troncal y siempre está en estado desplegable/buildable; el
trabajo ocurre en ramas de feature de vida corta que se mergean a `main` vía PR
y se borran tras el merge. Sin `develop`, sin `release/*`, sin `hotfix/*`.

> Por qué: el repo `specs` ya juega el rol de "stage de integración" mediante
> sus tags `spec-vX.Y.Z`, así que una rama `develop` lo duplicaría. Una troncal
> por repo mantiene simple el fan-out del umbrella (las ramas de feature siempre
> nacen de `main`) y deja a Dependabot/CI apuntando a una sola rama.

## Reglas (todos los repos)

1. `main` es la única troncal. Nunca se commitea directo a ella.
2. Todo cambio es una rama de feature de vida corta → PR → merge a `main` →
   borrar la rama.
3. **Una rama hija pasa a `main` SIEMPRE por PR + `squash and merge`.** Nunca
   directo, nunca merge commit, nunca rebase. `main` queda limpio: un commit por
   PR. Comando: `gh pr merge <n> --squash --delete-branch`. Aplica a todos los
   repos (umbrella, specs, cada módulo).
4. Los nombres de rama usan el tag de feature: `NNN-slug` (ej.
   `001-spring-profiles`). El nombre lo **decide el asistente**, no se teclea:
   `NNN` del número de post del ROADMAP, `slug` el título del feature en
   kebab-case.
5. Un solo nombre de rama por feature en todos los repos que toca (mismo
   nombre, varios repos — los PRs se alinean).
6. Una rama de feature siempre nace del `main` actual del repo donde vive —
   garantizado por `fanout.sh`, cuya base por defecto es `main` (config
   `umbrella_fanout.base`, resuelta a `origin/main` tras el fetch).

## Nuances por repo

| Repo | Qué significa `main` | Extra |
|------|----------------------|-------|
| `specs` | El conjunto de specs liberado. | Nunca editar `main` directo (per `CONTRIBUTING.md`); mergear un feature = nuevo tag `spec-vX.Y.Z` + entrada en `CHANGELOG.md`. Los features viven en `specs/NNN-slug/`. |
| `<module>` | Un estado buildable y testeado. | Consume `specs` como submodulo pineado a un tag; mover el puntero es un acto explícito (`main` nunca sigue el `main` de specs). |
| `umbrella` | Estado de orquestación (docs, config, punteros de submodulos). | Sin ramas de feature: el "feature" vive en specs + módulos; el umbrella solo registra los punteros nuevos y las actualizaciones de docs. |

## Tags

- `specs` se versiona con tags `spec-vMAJOR.MINOR.PATCH`. Los módulos pinan a
  tags, nunca al `main` de specs.
- Los demás repos no son tag-driven.

## Enforcement (protección de rama en `main`)

El `main` de cada módulo está protegido: PR requerido (sin aprobación
obligatoria — setup solo-dev, el dueño squash-mergea su propio PR), CI requerido
(auto-detectado de `.github/workflows/`), admins incluidos, sin force-push, sin
deletions. Se aplica al añadir un módulo nuevo:

```sh
bash .specify/scripts/bash/module-bootstrap.sh <module> --dry-run   # revisar antes
bash .specify/scripts/bash/module-bootstrap.sh <module>             # aplicar (idempotente)
```

## Referencias

- Workflow y fan-out: `docs/WORKFLOW.md` (secciones 4 / 4.1).
- Proceso de cambio de specs: `CONTRIBUTING.md`.
- Ejemplo end-to-end: `docs/flujo-ejemplo-post01.html`.
