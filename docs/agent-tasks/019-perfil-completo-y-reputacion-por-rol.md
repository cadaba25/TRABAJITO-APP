---
id: 019
titulo: "El backend no guarda el perfil del trabajador (bloquea la fase 2), y la reputación debe separarse por rol"
estado: en-progreso
agente: "backend-agent"
creada: 2026-08-27
rama: "feature/perfil-completo-backend"
---

## Por qué esta tarea existe

**Bloquea la fase 2 de la migración.** Lo encontró `flutter-agent` al cerrar
la fase 1 y lo confirmó el `tech-lead` comparando ambos modelos: la entidad
`Usuario` del backend **no tiene** la mayoría de los campos que el registro
de Flutter recoge. Migrar el perfil hoy **perdería datos visibles para el
usuario** — justo los que llena el formulario de 5 pasos.

### Qué falta exactamente (verificado, no supuesto)

El backend **sí** tiene: `correo`, `passwordHash`, `nombres`, `apellidos`,
`dni`, `telefono`, `rol`, `fotoUrl`, `presentacion`, `departamento`,
`ciudad`, `tipoEmpleador`, `nombreEmpresa`, `rtn`, `sectorEmpresa`,
`tamanoEmpresa`, `sitioWeb`, `saldo`, `trabajosCompletados`,
`calificacionPromedio`, `totalCalificaciones`.

**Falta** (lo tiene Flutter y se perdería):

| Campo | De dónde sale |
|---|---|
| `telefonoEmergencia` | registro trabajador, paso 2 |
| `fechaNacimiento` | registro, paso 2 (además valida ≥18 años) |
| `genero` | registro, paso 2 |
| `viveEnHonduras`, `codigoPostal`, `pais` | registro, paso 2 |
| `urlCV` | registro, paso 3 |
| `habilidades` | perfil del trabajador (se muestra y se filtra por ellas) |
| `experiencia` (lista) | registro, paso 4 — empresa, puesto, fechas, descripción |
| `estudios` (lista) | registro, paso 5 — nivel, centro, fechas |
| `registroCompleto` | controla si el registro terminó |
| `cargoContacto`, `descripcionEmpresa` | registro de empleador |
| `estado` (activo/suspendido) | comprobar si equivale al `activo` que ya existe |

`experiencia` y `estudios` son **listas**: en Firestore van embebidas como
mapas; en PostgreSQL lo natural son dos tablas con FK a `usuarios`. Decide y
justifica.

## Además: dos decisiones de producto del dueño (2026-08-26)

Se meten aquí porque tocan **la misma entidad y la misma migración de
esquema**, y hacerlas después costaría repetir el trabajo:

### 1. Dos reputaciones separadas, una por rol

> *"dos diferentes para cada rol"*

Hoy hay un solo `calificacionPromedio` / `totalCalificaciones`. Ser buen
trabajador y ser buen contratista son cosas distintas y se califican aparte.
Hay que desdoblarlos y que cada `Calificacion` sepa **a qué rol** califica.
Comprueba si la entidad `Calificacion` ya tiene algo tipo `rolCalificado`
(el modelo de Firestore sí lo tiene) y reutilízalo si existe.

`CalificacionService` debe actualizar el promedio **del rol correcto**.

### 2. Nadie puede postularse a su propio trabajo

> *"bloquea los postulamientos a propios trabajos"*

Hoy `PostulacionService` **no lo comprueba**. Con el doble rol (tarea 012)
sería trivial de hacer. Rechazar con 409 y mensaje claro.

## Contexto relevante

- `lib/models/usuario.dart` — el modelo completo que hay que soportar.
- `lib/screens/registro/registro_trabajador_screen.dart` y
  `registro_empleador_screen.dart` — de dónde salen los datos.
- `docs/database.md` — **está desactualizado en esto**: no menciona la
  diferencia. Actualízalo.
- `docs/decisions.md` ADR-0006 (bloqueo pesimista y orden global de bloqueo:
  respétalo si tocas algo que mueva dinero), ADR-0007, ADR-0010.
- `docs/agent-tasks/012-doble-perfil-trabajador-contratista.md` — el contexto
  del doble rol.

## Criterios de aceptación

- [ ] La entidad `Usuario` (o tablas relacionadas) soporta **todos** los
      campos de la tabla de arriba, y los DTO de perfil los exponen.
- [ ] `experiencia` y `estudios` se pueden crear, leer y editar por API.
- [ ] Reputación separada por rol, con `CalificacionService` actualizando la
      correcta. Verificado con una calificación real de cada tipo.
- [ ] Postularse al propio trabajo → **409** con mensaje claro. Con test.
- [ ] `mvn test` pasa (hoy 85) + tests nuevos.
- [ ] `backend/scripts/prueba-flujo-negocio.sh` sigue en **0 fallos
      inesperados** (hoy 175 OK / 0 / 0).
- [ ] `docs/database.md` y `docs/api.md` actualizados.
- [ ] Si el cambio de esquema es grande, valora si ya toca meter Flyway —
      pero **no lo metas en esta tarea**: propónlo. El esquema lo genera
      Hibernate con `ddl-auto=update`, que **no altera constraints
      existentes** (ya causó dos incidentes: ver `RestriccionSaldoNoNegativo`
      y `RestriccionEstadoTrabajo`). Si añades constraints, sigue ese patrón.

## Fuera de alcance

- `lib/**` (Flutter): la fase 2 consume esto después.
- El **cambio de rol** en sí (activar el segundo rol, alternar): eso es la
  tarea 012 completa y necesita más decisiones. Aquí solo se separa la
  reputación y se bloquea la autopostulación.
- Refresh tokens, rate limiting: ya hechos (tarea 015).

## Notas del agente que la ejecuta

(vacío — en progreso)
