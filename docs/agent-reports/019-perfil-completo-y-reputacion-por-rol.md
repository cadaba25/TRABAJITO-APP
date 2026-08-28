---
id: 019
tarea: docs/agent-tasks/019-perfil-completo-y-reputacion-por-rol.md
agente: "backend-agent"
fecha: 2026-08-27
---

## Objetivo (copiado de la tarea)

> **Bloquea la fase 2 de la migración.** La entidad `Usuario` del backend **no
> tiene** la mayoría de los campos que el registro de Flutter recoge. Migrar el
> perfil hoy **perdería datos visibles para el usuario** — justo los que llena el
> formulario de 5 pasos.

Y, en el mismo cambio, dos decisiones de producto del dueño (2026-08-26):
*"dos [reputaciones] diferentes para cada rol"* y *"bloquea los postulamientos a
propios trabajos"*.

## Cambios realizados

### 1. El perfil completo (lo que bloqueaba la fase 2)

`usuarios` gana **14 columnas** y aparecen **3 tablas nuevas**:

| Qué faltaba | Dónde está ahora |
|---|---|
| `telefonoEmergencia`, `genero`, `codigoPostal`, `pais`, `viveEnHonduras`, `urlCV`, `registroCompleto`, `cargoContacto`, `descripcionEmpresa` | columnas de `usuarios` |
| `fechaNacimiento` | columna `date` de `usuarios`, con **edad mínima de 18 exigida por el servidor** |
| `habilidades` | tabla `habilidades` (una fila por etiqueta, FK a `usuarios`, índice para filtrar el feed) |
| `experiencia` | tabla `experiencias` (una fila por puesto, FK a `usuarios`) |
| `estudios` | tabla `estudios` (una fila por estudio, FK a `usuarios`) |
| `estado` (activo/suspendido) | **no hacía falta columna**: es el booleano `activo` que ya existía, que ahora sí se expone |
| `fechaRegistro` | **no hacía falta columna**: es `creadoEn` de `BaseEntity`, que ahora sí se expone |
| `rtn` (existía, no se exponía ni se podía editar) | expuesto en la vista del dueño y editable en `PUT /me` |

Endpoints nuevos (todos bajo `/api/usuarios/me`, autorización resuelta en el
servicio): `GET /me`, `PUT /me/habilidades`, `POST|PUT|DELETE /me/experiencia`
y `.../me/estudios`. `GET /api/auth/yo` pasa a devolver el perfil **completo**.

### 2. Dos reputaciones, una por rol

`Usuario` gana `calificacionComoTrabajador`/`totalCalificacionesComoTrabajador`
y `calificacionComoEmpleador`/`totalCalificacionesComoEmpleador`; `Calificacion`
gana `rolCalificado`. `CalificacionService` decide dónde suma por el papel que
tenía **el receptor en ese trabajo**, no por su rol de cuenta (importa para el
doble perfil de la tarea 012). La media global se conserva.

### 3. Nadie se postula a su propio trabajo → 409

### 4. Hallazgo lateral arreglado: el perfil ajeno filtraba datos personales

`GET /api/usuarios/{id}` devolvía el **saldo** de cualquier usuario a cualquier
cuenta autenticada, además de su correo y DNI. Añadir ahí el perfil completo sin
tocar nada habría sumado teléfono de emergencia, fecha de nacimiento y género al
mismo agujero. `UsuarioResponse` pasa a tener **dos vistas** (dueño / pública).

## Archivos modificados

Backend — código nuevo:

- `backend/src/main/java/com/trabajito/modules/usuarios/Experiencia.java`
- `backend/src/main/java/com/trabajito/modules/usuarios/Estudio.java`
- `backend/src/main/java/com/trabajito/modules/usuarios/Habilidad.java`
- `.../usuarios/ExperienciaRepository.java`, `EstudioRepository.java`, `HabilidadRepository.java`
- `backend/src/main/java/com/trabajito/modules/usuarios/PerfilService.java`
- `.../usuarios/dto/ExperienciaRequest.java`, `ExperienciaResponse.java`, `EstudioRequest.java`, `EstudioResponse.java`, `HabilidadesRequest.java`
- `backend/src/main/java/com/trabajito/common/enums/RolCalificado.java`
- `backend/src/main/java/com/trabajito/modules/calificaciones/dto/CalificacionResponse.java`
- `backend/src/main/java/com/trabajito/config/RellenoPerfilYReputacion.java`

Backend — modificado:

- `.../modules/usuarios/Usuario.java` (14 columnas), `UsuarioService.java`,
  `UsuarioController.java`, `dto/UsuarioResponse.java`, `dto/ActualizarPerfilRequest.java`
- `.../modules/calificaciones/Calificacion.java`, `CalificacionService.java`,
  `CalificacionController.java`, `CalificacionRepository.java`
- `.../modules/postulaciones/PostulacionService.java` (400 → 409)
- `.../modules/auth/AuthController.java` (`/yo` devuelve el perfil completo)

Tests:

- `backend/src/test/java/com/trabajito/modules/usuarios/PerfilCompletoHttpTest.java` (nuevo, 10)
- `backend/src/test/java/com/trabajito/modules/calificaciones/CalificacionServiceTest.java` (nuevo, 5)
- `backend/src/test/java/com/trabajito/modules/postulaciones/PostulacionServiceTest.java` (nuevo, 3)
- `backend/scripts/prueba-flujo-negocio.sh` (+32 comprobaciones)

Docs: `docs/decisions.md` (ADR-0011), `docs/api.md`, `docs/database.md`,
`backend/README.md`, `docs/agent-context/repo-snapshot.md`,
`docs/agent-tasks/019-...md`.

## Decisiones tomadas

Todas razonadas en **ADR-0011**. Lo que más conviene saber sin abrirlo:

1. **Tres tablas con FK, no JSON embebido.** El feed tiene que poder filtrar por
   habilidad (con una cadena separada por comas eso es un `LIKE` sin índice), y
   editar el CV no debe reescribir la fila del usuario, que lleva el `saldo` y
   depende de `@DynamicUpdate` para no pisar una recarga concurrente (ADR-0006).
   Son las **primeras tres claves ajenas reales** del esquema.
2. **Sin colecciones en `Usuario`.** La relación se declara solo en el hijo
   (`@ManyToOne`), para no arrastrar cargas perezosas a los caminos que bloquean
   la fila del usuario con `SELECT ... FOR UPDATE`. Descarté `@ElementCollection`
   por eso mismo: `EAGER` habría entrado en las transacciones de dinero y `LAZY`
   habría reventado al serializar (`open-in-view: false`).
3. **Fechas: texto para el CV, `LocalDate` para nacimiento.** `MM/AAAA` son
   fechas parciales; convertirlas obligaría a inventar un día. La de nacimiento
   sí es fecha porque de ella depende una regla: **18 años**, que hasta hoy solo
   comprobaba la pantalla de Flutter (o sea, no se comprobaba). Entra
   `dd/MM/yyyy` o ISO, **sale siempre ISO**.
4. **Columnas nuevas sin `NOT NULL`, con `@ColumnDefault`.** PostgreSQL rechaza
   `ADD COLUMN ... NOT NULL` sin `DEFAULT` sobre una tabla con filas, y con
   `ddl-auto=update` el fallo se traga en un WARN: la columna no existiría y todo
   `SELECT` de usuarios reventaría. Verificado en el servidor: las 14 columnas se
   crearon **con** su default y sin dejar un solo NULL en las 131 filas.
5. **Se conserva `calificacionPromedio`.** Quitarla habría borrado la reputación
   visible de quien ya tenía reseñas.
6. **Dos vistas de usuario** (dueño/pública) en vez de una sola.

**Desviación respecto a la tarea, con motivo:** el enunciado decía que
`PostulacionService` "no lo comprueba". Sí lo comprobaba desde el esqueleto
(`03541dc`); lo que fallaba era el código, `400`. Se cambió a `409` y se
actualizó el script de regresión, que exigía `400` (queda anotado en su
cabecera: si vuelve a salir 400, es regresión).

## Problemas encontrados

- **La trampa de `ddl-auto=update` volvió a aparecer, y esta vez con datos.** No
  solo no altera constraints: tampoco puede añadir columnas obligatorias a una
  tabla poblada, y no sabe rellenar `calificaciones.rol_calificado`, cuyo valor
  correcto depende de cada fila. De ahí `RellenoPerfilYReputacion`, hermano de
  `RestriccionSaldoNoNegativo` y `RestriccionEstadoTrabajo`. **Van tres parches
  de arranque haciendo de sistema de migraciones**: la propuesta de meter Flyway
  está en ADR-0011 y en `backend/README.md`, pero **no se implementó** aquí.
- **Los tests no habrían visto nada de eso.** H2 con `create-drop` regenera el
  esquema entero; el problema solo existe contra una base que ya tiene filas. Por
  eso todo se verificó además contra el PostgreSQL del servidor.
- **El perfil público filtraba el saldo** desde antes de esta tarea (ver arriba).
- El `Usuario` que viaja en el `UsuarioPrincipal` del token está detached, así
  que `/api/auth/yo` no podía limitarse a serializarlo: ahora relee el perfil
  dentro de una transacción de solo lectura.

## Tests ejecutados

**Unitarios (máquina de desarrollo, Windows):**

```
export JAVA_HOME="C:\Program Files\Android\Android Studio\jbr"
export PATH="$PATH:/c/Users/enigm/tools/apache-maven-3.9.16/bin"
cd backend && mvn test -Dtest='!IntegridadCarteraConcurrenteTest' -DfailIfNoSpecifiedTests=false
```

→ **BUILD SUCCESS, `Tests run: 103, Failures: 0, Errors: 0, Skipped: 0`**
(antes 85; +18). Reparto de los nuevos: `PerfilCompletoHttpTest` 10 (MockMvc+H2),
`CalificacionServiceTest` 5, `PostulacionServiceTest` 3.
`IntegridadCarteraConcurrenteTest` sigue excluido (Testcontainers no corre en
Windows) — **no se ejecutó**, igual que antes de esta tarea.

**Integración contra el servidor real (VM Ubuntu, PostgreSQL 16):**

```
cd ~/trabajito && COMPOSE_DIR=$HOME/trabajito/backend bash backend/scripts/prueba-flujo-negocio.sh
```

→ **207 OK / 0 fallos conocidos / 0 inesperados** (antes 175/0/0; +32
comprobaciones). El cuadre contable sigue pasando para los 7 usuarios.

**Esquema real, tras desplegar la rama:**

- Las 14 columnas nuevas existen **con su `DEFAULT`**; `0` NULLs en las 131 filas
  de `usuarios`.
- `habilidades`, `experiencias` y `estudios` creadas con sus índices y sus FK
  (`fk_habilidades_usuario`, etc.).
- Log de arranque: `Reputación por rol: 20 calificación(es) antiguas
  clasificadas.` y `Reputación por rol recalculada: 10 usuario(s) con reseñas
  como trabajador, 10 como contratista.` En BD: 10 `TRABAJADOR` + 10 `EMPLEADOR`,
  ninguna sin clasificar.

**Peticiones reales (evidencia pedida en el encargo).** Contra
`http://localhost:8080` en el servidor:

- Perfil de trabajador completo guardado y recuperado: `GET /api/auth/yo` devuelve
  `telefonoEmergencia`, `fechaNacimiento: "1995-03-15"` (entró `15/03/1995`),
  `genero`, `codigoPostal`, `pais`, `viveEnHonduras`, `urlCV`,
  `registroCompleto: true`, `creadoEn`, `habilidades: ["Electricidad","Plomeria"]`,
  `experiencia[0].empresa: "Constructora del Valle"` y
  `estudios[0].centro: "UNAH-VS"`.
- Reputación por rol, con una calificación real de cada tipo: el trabajador queda
  en `calificacion_como_trabajador = 5.00` / `calificacion_como_empleador = 0.00`;
  el empleador, en `4.00` / `0.00` al revés. `rol_calificado` guardado como
  `TRABAJADOR` y `EMPLEADOR` respectivamente.
- Autopostulación: `HTTP 409` con
  `{"status":409,"error":"Conflict","message":"No puedes postularte a tu propio trabajo"}`.
- Privacidad: el perfil ajeno muestra el CV pero devuelve `null` en `correo`,
  `dni`, `telefonoEmergencia`, `fechaNacimiento` y `saldo`.

**No se probó:** nada en un emulador/dispositivo Flutter (fuera de alcance, y la
app sigue en Firestore), ni el WebSocket, ni la concurrencia sobre las tablas
nuevas.

## Pendientes

1. **Flyway/Liquibase — propuesto, no hecho** (ADR-0011). Es el pendiente más
   urgente del backend: tres componentes de arranque hacen ya de migraciones y el
   último toca datos. Debería entrar **antes** de que la fase 2 ponga datos
   reales de usuarios en esa base. Tarea propia, con su ADR.
2. **Revisión de `security-agent`**: esta tarea cambia qué datos personales
   devuelve `GET /api/usuarios/{id}` (a mejor, pero es una decisión de
   exposición). No toca `security/` ni `SecurityConfig`.
3. **Para `flutter-agent`, de cara a la fase 2** (contrato en `docs/api.md`):
   - `fechaNacimiento` llega en **ISO**; el modelo la trata como texto y la
     pantalla la enseñaría como `1995-03-15`. Hay que formatear al mostrar.
   - `habilidades`/`experiencia`/`estudios` llegan **`null`** en login y registro
     (no vacías): usar `GET /api/auth/yo` para el perfil completo.
   - El perfil de otra persona **no trae** correo, DNI ni teléfonos: las
     pantallas que los pinten hoy desde Firestore tendrán que dejar de hacerlo.
   - Editar el CV es por sub-recurso (`/me/experiencia/{id}`), no reenviando el
     usuario entero.
4. **Sigue faltando para la fase 2** (heredado de la tarea 018, fuera del alcance
   de esta): entidad/endpoints de **tarjetas**; los campos desnormalizados
   `tituloTrabajo`/`empleadorId` en `Postulacion` y `autorNombre` en
   `Calificacion`; y un **contador de no leídos por chat**.
5. **Sin cobertura todavía**: `PagoService` directo, los controllers de negocio y
   la capa de seguridad (`JwtAuthFilter`). Las tablas nuevas no tienen test de
   concurrencia (no manejan dinero, pero `PUT /me/habilidades` borra e inserta:
   dos peticiones simultáneas del mismo usuario podrían chocar con
   `uq_habilidad_usuario` y devolver 500 en vez de 409 — no reproducido).
6. **El ranking** sigue ordenando por `trabajosCompletados`. Ahora que existe
   reputación por rol, habría que decidir si el ranking usa
   `calificacionComoTrabajador`; es decisión de producto, no de backend.
