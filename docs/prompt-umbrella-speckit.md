# Prompt: armar estructura umbrella (speckit + submodules + constitution en cascada)

Ya tenés un repo umbrella vacío. Parate dentro de ese repo y pegale este prompt completo a tu agente (Claude Code, Cursor, Copilot CLI, etc.).

---

## Contexto para el agente

Estoy parado dentro de un repo git ya inicializado y vacío, que va a funcionar como "umbrella" orquestador de un proyecto multi-repo con Spec Kit (speckit). La estructura final debe ser:

```
. (este repo, umbrella)
├── .specify/                          Spec Kit del proyecto completo
│   └── memory/constitution.md         Constitution GLOBAL
├── modulos/
│   ├── specs-lib/                     submodule → repo de specs, pineado a un tag
│   ├── <modulo-1>/                    submodule → repo de implementación
│   │   ├── specs/                     submodule → mismo repo de specs, mismo tag
│   │   └── .specify/memory/
│   │       ├── .agent-context
│   │       └── constitution.md        overrides LOCALES (opcional)
│   └── <modulo-N>/ ...
├── CONTRIBUTING.md                    proceso de cambio de spec
└── README.md
```

Reglas de fondo que la estructura debe garantizar (no las rompas en ningún paso):
- Las specs viven en un repo separado, versionado con tags semver (`spec-vMAJOR.MINOR.PATCH`).
- Ningún módulo sigue `main` del repo de specs: cada submodule queda pineado a un commit/tag fijo. Actualizar la spec de un módulo es SIEMPRE un acto explícito, nunca automático.
- La constitution se lee en cascada: primero la global (`modulos/<modulo>/specs/.specify/memory/constitution.md`), después la local del módulo si existe, que solo aporta overrides puntuales.
- Todo cambio de spec futuro se propone por PR en el repo de specs, se aprueba, se taggea, y recién ahí cada módulo decide cuándo actualizar su puntero.

**Regla de ejecución obligatoria: después de CADA paso numerado de abajo, hacé `git add` + `git commit` con un mensaje descriptivo de ESE paso únicamente (no acumules varios pasos en un commit), mostrame `git log --oneline -n <lo que corresponda>` y el árbol de archivos afectado, y esperá mi confirmación explícita antes de pasar al siguiente paso. No sigas de largo por tu cuenta.**

Antes de arrancar, preguntame lo que no puedas inferir del repo actual:
- Nombre y URL del repo de specs (si ya existe, o si hay que crearlo).
- Nombre y URL de cada módulo de implementación que agreguemos (empezar con al menos uno está bien, se pueden sumar más después repitiendo el Paso 3).

---

## Paso 1 — Spec Kit y constitution global en el umbrella

1. Inicializá Spec Kit en la raíz de este repo (`specify init` o el comando equivalente de tu CLI).
2. Corré (o guiame para correr) `/speckit.constitution` generando principios GLOBALES: calidad de código, estándares de testing transversales, criterios de arquitectura compartida entre módulos. Nada específico de un stack puntual todavía.
3. Verificá que quedó en `.specify/memory/constitution.md`.

→ Commit: `chore: init spec kit + constitution global`

## Paso 2 — Repo de specs como submodule pineado

1. Si el repo de specs no existe, creálo con esta estructura mínima antes de agregarlo:
   ```
   <repo-specs>/
   ├── .specify/memory/constitution.md   (mismo contenido que el global del Paso 1)
   ├── specs/
   ├── CHANGELOG.md
   └── README.md
   ```
   con un primer tag `spec-v1.0.0`.
2. Agregalo como submodule dentro del umbrella:
   ```
   git submodule add <url-repo-specs> modulos/specs-lib
   cd modulos/specs-lib
   git checkout spec-v1.0.0
   cd ../..
   ```
3. Confirmame en una línea que quedó pineado al tag y no a `main`.

→ Commit: `chore: agrega specs-lib como submodule pineado a spec-v1.0.0`

## Paso 3 — Agregar un módulo de implementación (repetir por cada módulo)

1. Agregá el módulo como submodule:
   ```
   git submodule add <url-repo-modulo> modulos/<nombre-modulo>
   ```
2. Dentro del módulo, agregá el submodule de specs pineado al mismo tag:
   ```
   cd modulos/<nombre-modulo>
   git submodule add <url-repo-specs> specs
   cd specs && git checkout spec-v1.0.0 && cd ..
   ```
3. Creá `.specify/memory/.agent-context` indicando qué carpeta de `specs/specs/` le corresponde a este módulo.
4. Creá `.specify/memory/constitution.md` SOLO si hay overrides reales (ej. framework de testing del lenguaje de este módulo). Si no hay overrides todavía, dejalo sin crear y decímelo.

→ Commit: `chore: agrega modulo <nombre-modulo> con specs pineado`

(Repetí este paso completo, con su propio commit, por cada módulo adicional.)

## Paso 4 — Documentar la cascada de constitution

1. En el `README.md` del umbrella, escribí explícitamente el orden de lectura de constitution que cualquier persona o agente debe seguir al implementar dentro de un módulo: primero la global del submodule de specs, después la local del módulo si existe.

→ Commit: `docs: documenta orden de lectura de constitution en cascada`

## Paso 5 — Documentar el flujo de cambio de spec

1. Creá `CONTRIBUTING.md` en la raíz con el proceso paso a paso para cuando haya que cambiar una spec ya aprobada:
   - PR en el repo de specs (nunca editar `main` directo).
   - Review y aprobación con branch protection.
   - Al mergear: nuevo tag semver + entrada en `CHANGELOG.md`.
   - Cada módulo actualiza su puntero de forma explícita cuando decide hacerlo (comando exacto de `git checkout <nuevo-tag>` dentro de `modulos/<modulo>/specs`), nunca automático.
   - Un módulo puede quedarse en una versión anterior mientras termina su implementación actual sin bloquear a nadie.

→ Commit: `docs: agrega proceso de cambio de spec en CONTRIBUTING.md`

## Paso 6 — Resumen final

1. Mostrame el árbol completo del repo con todos los submodules.
2. Mostrame `git log --oneline` completo de todos los commits hechos en esta sesión.
3. Decime si quedó algún paso manual pendiente de mi parte (crear repos remotos si no existían, dar permisos, etc.).

No hagas commit en este paso, es solo un resumen.

---

**Nota para vos (el agente):** si en algún paso falta un dato (URL de repo, nombre de módulo), preguntamelo antes de ejecutar el comando que lo necesita. No inventes URLs ni nombres.
