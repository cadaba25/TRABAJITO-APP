# Estrategia de Git

Adaptada al repositorio real: la rama por defecto se llama **`master`**
(no `main` — no se renombra, es un cambio disruptivo sin beneficio real, ver
razones abajo) y no existía ninguna rama de integración hasta que se creó
`develop` como parte de este sistema (2026-08-19).

## Ramas

```
master              ← rama por defecto del repo, protegida. NUNCA commits directos.
└── develop         ← rama de integración, protegida. NUNCA commits directos.
    ├── feature/<área>-<slug>   ← trabajo nuevo (ej. feature/flutter-jobs-search)
    ├── fix/<slug>              ← corrección de un bug
    ├── chore/<slug>            ← infraestructura, tooling, docs, dependencias
    └── docs/<slug>             ← solo si el cambio es documentación pura
```

- **`master`** es lo que corre/está listo. Solo recibe merges desde `develop`
  cuando `develop` llega a un hito estable (no en cada PR).
- **`develop`** es donde conviven en curso las tareas de los distintos
  agentes. Todo PR de `feature/`, `fix/`, `chore/`, `docs/` apunta aquí.
- No se pre-crean ramas `feature/*` vacías para cada dominio (auth, jobs,
  chat...) como en el ejemplo genérico — se crean bajo demanda cuando arranca
  una tarea real en `docs/agent-tasks/`, con el nombre de esa tarea.

### Por qué no renombrar `master` → `main`

El usuario pidió una estructura "similar a" `main`/`develop`, no
literalmente. Renombrar la rama por defecto de un repo ya en GitHub requiere
tocar la configuración del repo, puede romper el workflow de
`.github/workflows/claude.yml` (que dispara sobre eventos del repo) y no
aporta ninguna funcionalidad nueva. Se mantiene `master` cumpliendo
exactamente el rol de "main".

## Cuándo hacer qué

| Acción | Cuándo |
|---|---|
| Crear una rama | Al empezar una tarea de `docs/agent-tasks/` que implica código. Nómbrala `feature/<área>-<slug-de-la-tarea>` |
| Hacer commit | Commits pequeños y descriptivos, en español, en el estilo ya usado en el historial (ej. "Agregar registro de empleadores", "Fix: botones que se quedaban cargando"). Un commit no debe mezclar dominios (Flutter + backend en el mismo commit, evitarlo salvo que la tarea sea intrínsecamente cross-stack) |
| Abrir Pull Request | Al terminar la tarea Y cumplir el checklist de `docs/development.md` (compila, tests pasan o se documenta por qué no se pudo verificar) |
| Pedir revisión | Todo PR hacia `develop` pasa por `security-agent` si tocó auth/datos/dinero, y por `qa-agent` si tocó lógica con cobertura de tests. El reporte de la tarea (`docs/agent-reports/`) debe estar completo antes de pedir merge |
| Hacer merge | Un humano (el usuario) aprueba y mergea. Ningún agente se auto-mergea un PR |
| `develop` → `master` | Cuando `tech-lead` y el usuario acuerdan que `develop` está en un estado estable/desplegable — no automático, no por cada feature |

## Reglas duras (no negociables)

- **Nunca** `git push --force` (ni siquiera `--force-with-lease` sin
  pedírselo primero al usuario).
- **Nunca** commit directo a `master` ni `develop`.
- **Nunca** commitear `backend/.env`, `google-services.json` con credenciales
  de un proyecto Firebase distinto al del equipo, ni ningún secreto. Antes de
  cada commit, revisa `git status` y el diff de lo que vas a subir.
- Si dos tareas activas en `docs/agent-tasks/` tocan el mismo archivo o
  módulo, el agente que lo detecta segundo para y avisa al `tech-lead` —no
  intenta resolverlo por su cuenta ni fuerza un merge.

## Primer caso de uso de este flujo: este mismo sistema

Este conjunto de documentos y agentes se está entregando en la rama
`chore/setup-multi-agent-system`, creada desde `develop`, para dar el
ejemplo desde el primer cambio.
