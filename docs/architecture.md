# Arquitectura de Trabajito

> Verificado directamente sobre el repositorio. Última revisión: **2026-09-18
> (tareas 052-060)**, cuando cartera, calificaciones y chat dejaron Firestore y
> se retiró Firebase de la app. Donde algo no se pudo verificar en esta máquina
> se dice explícitamente.

## 1. Arquitectura actual (lo que corre de verdad)

**Desde el 2026-09-18 la app habla solo con el backend propio.** La migración
de ADR-0009 terminó en el cliente: autenticación y perfil (tarea 020), trabajos
y postulaciones (026), cartera y calificaciones (052) y chat (053, ADR-0018).
`lib/` y `pubspec.yaml` ya no tienen Firebase ni Firestore (ADR-0019, tarea
060). Lo que resta de Firebase es solo `firestore.rules`,
`firestore.indexes.json` y el proyecto en la consola: la fase 3 lo borra.

```
┌───────────────────────────────────────────────┐
│              App Flutter (móvil)              │
│                                               │
│  funcionalidades/{autenticacion, perfil,      │
│    trabajos, postulaciones, chat, cartera,    │
│    calificaciones, inicio}/datos/*_service    │
└───────────────────────┬───────────────────────┘
                        │
       lib/nucleo/api/ApiClient
       HTTP + JWT + refresh token (el chat, con sondeo)
                        ▼
        ┌──────────────────────────────┐
        │  Backend propio              │
        │  Spring Boot + JWT           │
        │  PostgreSQL 16               │
        │                              │
        │  usuarios, sesiones, perfil, │
        │  trabajos, postulaciones,    │
        │  evidencias, chats, cartera, │
        │  calificaciones              │
        └──────────────────────────────┘
```

### Lo que ya pasa por el backend propio

**Tarea 020 (fase 2a):**

- **Registro, login, cierre de sesión y renovación de token.** JWT de acceso de
  15 min + refresh token rotativo y revocable (ADR-0010). Se guardan en el
  almacén seguro del dispositivo (`flutter_secure_storage`), no en claro.
- **Perfil**: leerlo, editarlo, el CV del trabajador (habilidades, experiencia,
  estudios) y la baja de cuenta.
- **Listado de trabajadores y ranking** (`GET /api/usuarios/ranking`).

**Tarea 026 (fase 2b-1):**

- **Trabajos**: el feed paginado, las publicaciones propias, los trabajos
  asignados, el detalle, publicar, y **todas las transiciones de la máquina de
  estados de ADR-0007** (reservar pago, iniciar, entregar, pedir correcciones,
  aceptar y pagar, cancelar, rechazar, reclamar a soporte).
- **Postulaciones**: postularse, retirarse, ver los postulantes de un trabajo y
  aceptar a uno —que en el servidor asigna el trabajo, rechaza al resto y crea
  el chat, todo en una transacción—.
- **Evidencias/avances** de un trabajo.

**Lo que la app perdió al migrar esas dos**, porque el backend no lo ofrece:
**editar** un trabajo publicado (no hay `PUT`/`PATCH`), **borrarlo** (no hay
`DELETE`; se cierra) y **reabrir** uno cerrado. Las pantallas lo dicen en vez
de fingirlo. Ver `docs/agent-reports/026-fase2b-publicaciones-y-postulaciones.md`.

**Firebase ya no se usa en la app** (ADR-0019, tarea 060): `firebase_core`,
`firebase_auth` y `cloud_firestore` salieron de `pubspec.yaml`, y con ellos
`Firebase.initializeApp()`, el plugin `google-services` de Android y
`android/app/google-services.json`. Quedan comentarios históricos sobre
Firestore en algunos archivos de `lib/`; son inofensivos.

### Chat: REST con sondeo (ADR-0018)

El chat usa `/api/chats/**` con **sondeo corto** mientras la pantalla está
abierta, y "deslizar para actualizar" en la lista. El WebSocket `/ws` sigue
construido y **autorizado** (el `CONNECT` exige JWT, tarea 030; el `SUBSCRIBE`
solo admite `/topic/chats/{uuid}` a participantes de ese chat, tarea 057), pero
la app no lo usa: STOMP queda como mejora futura de tiempo real. El acuerdo de
pago y tiempo lo valida el servidor en `reservar-pago` (tarea 055); ya no hay
costura con Firestore. **Sin verificar en vivo:** el sondeo y STOMP.

### Historia: por qué una cuenta nueva no veía datos de Firestore

Mientras duró la migración, el `uid` pasó de ser el de Firebase a ser el UUID
del backend, y las pantallas que seguían en Firestore no encontraban datos de
cuentas creadas contra el backend. Se cerró al migrar las tres últimas. Detalle
histórico en `docs/agent-reports/020-fase2a-auth-contra-el-backend.md`.

### Sin conexión confirmada no se escribe (ADR-0013)

Desde la tarea 026, **toda acción que cree o modifique datos** pasa por una
comprobación única en `ApiClient.exigirSesionConfirmada`: si la sesión se
restauró del dispositivo y no se pudo confirmar contra el servidor
(`EstadoSesion.avisoSinConexion`), la petición **no sale** y el usuario recibe
un mensaje que dice explícitamente que no se ha enviado nada.

Está en un solo sitio a propósito. Firestore encolaba las escrituras sin
conexión y las sincronizaba después; contra HTTP ese encolado no existe, así
que sin esta regla la migración habría empeorado el comportamiento sin que se
notara. La instala `AuthService.vigilarEscriturasSinConexion()` desde
`main.dart`, y aprovecha el intento para **reconfirmar la sesión**: si la
conexión ya volvió, la acción continúa sola.

### El estado de sesión, ahora que no hay `authStateChanges()`

Firebase daba un `Stream<User?>` que avisaba solo. Su sustituto es
`lib/nucleo/sesion/sesion_usuario.dart`: un `ValueNotifier<EstadoSesion>` con tres
fases explícitas (`comprobando` / `sinSesion` / `conSesion`) que rellena
`AuthService`. `PantallaInicial` lo escucha para decidir entre la pantalla de
carga, el login y la pantalla principal.

Los `Stream` de Firestore se sustituyeron por carga puntual + "deslizar para
actualizar", salvo el chat, que usa sondeo corto (ADR-0018; antes se planeó
WebSocket, ahora es mejora futura).

### Módulos Flutter — **por funcionalidad desde la tarea 027 (ADR-0014)**

`lib/` se está reorganizando de "por tipo" (`models/`, `screens/`,
`services/`...) a "por funcionalidad". **La migración va a medias y a
propósito**: se movió `autenticacion` como piloto (parte A), **la base
compartida —`nucleo/api/` y `compartido/widgets/`— en la parte B-1**, y
**`trabajos`, `postulaciones`, `perfil` e `inicio` más los modelos en la
B-2** (2026-09-09); `chat`, `cartera` y `calificaciones` se movieron al
migrarse (052/053). `lib/screens/` y `lib/services/` **ya no existen**
(verificado 2026-09-18). Mira esta tabla antes de suponer dónde está algo.

| Carpeta | Contiene |
|---|---|
| `lib/nucleo/api/` | La capa HTTP única, partida en cuatro desde la B-1: `api_client.dart` (la fachada, con `instancia`/`fijarInstancia`), `transporte_http.dart` (una ida y vuelta: URL, cabeceras, tiempo límite y traducción de errores de ADR-0008), `gestor_sesion.dart` (**los tres candados de la renovación**, el almacén de sesión y la petición autenticada) y `guardia_escrituras.dart` (ADR-0013). Más `configuracion_api`, `sesion_api`, `almacen_sesion`, `pagina_api` y `api_excepciones` |
| `lib/nucleo/tema/` | `AppColores`, `AppTema` (claro/oscuro), `notificadorTema` (el `ValueNotifier` global del modo de tema) y `colores_por_tema.dart` (`colorTextoFuerte`/`Suave`/`Superficie`/`Borde`: la parte del tema que depende del `BuildContext`) |
| `lib/nucleo/textos/` | `AppTextos` y `MensajesError` |
| `lib/nucleo/dominio/` | Vocabulario del negocio compartido: `EstadosTrabajo`/`EstadosPostulacion`/`TiposMensaje`, `MapeoEnumApi` (enums del backend ↔ minúsculas de la app), `RolesApi`+`ValoresDefecto`, `CamposUsuario`, `ReglasCuenta` (lo que el servidor exige y el formulario debe pedir igual) |
| `lib/nucleo/sesion/` | `SesionUsuario`, el `ValueNotifier<EstadoSesion>` que sustituye a `authStateChanges()` |
| `lib/nucleo/inyeccion/` | `proveedoresDeLaApp()`: **la raíz de composición**, el único sitio donde se construyen los servicios. Registra `AuthService`, `PerfilService`, `PublicacionService`, `PostulacionService`, `CarteraService`, `CalificacionService` y `ChatService` |
| `lib/nucleo/movimiento/` | **Desde la tarea 028 (ADR-0015).** El vocabulario de movimiento único: `app_movimiento.dart` (`AppMovimiento`, `Duration`/`Curve` con nombre — `microFeedback`/`chico`/`medio`/`panel`, `entrada`/`panelCurva`/`estandar`/`exito`) y `movimiento_accesible.dart` (`duracionMov`/`curvaMov`/`prefiereMenosMovimiento`, que colapsan a `Duration.zero`/fundido simple con `MediaQuery.disableAnimations`). Ningún otro archivo declara un `Duration`/`Curve` de animación a mano; todo widget animado pasa por aquí |
| `lib/compartido/datos/` | Catálogos: departamentos y ciudades de Honduras, sectores y tamaños de empresa |
| `lib/compartido/modelos/` | **Los 7 modelos + `json_utiles.dart` desde la B-2.** Transversales (p. ej. `Publicacion` la usan trabajos, postulaciones y chat). Ya no quedan `desdeFirestore()`/`aFirestore()` en los modelos (solo se mencionan en `json_utiles.dart`); se usan `desdeJson()`/`aJson()`. Modelos en esta carpeta: Usuario, Publicacion (trabajo), Postulacion, Calificacion, Evidencia, Tarjeta (Chat y MovimientoCartera viven ahora en sus funcionalidades) |
| `lib/compartido/widgets/` | Componentes reusables, **uno por archivo** desde la B-1: `custom_textfield` (`CustomTextField`), `custom_dropdown`, `indicador_pasos`, `botones_si_no`, `indicador_fuerza_contrasena`, `mostrar_snackbar`, `ejecutar_con_carga` (¡lleva un candado **global** anti doble-toque!), más `entrada_etiquetas`, `estrellas`, `resenas` y `logo_trabajito`. **Desde la tarea 028**: `pulsa_con_escala` (`PulsaConEscala`, feedback al tacto de ADR-0015), `cambio_de_estado` (`CambioDeEstado`, fundido entre estados de lista) y `estado_exito` (`EstadoExito`, el check tras publicar/postularse) |
| `lib/funcionalidades/autenticacion/` | `datos/auth_service.dart` (sesión, registro, baja de cuenta) y `pantallas/` (login, bienvenida y los dos registros) |
| `lib/funcionalidades/perfil/` | `datos/perfil_service.dart` (recargar/editar el perfil propio, CV del trabajador, perfil ajeno, `listarTrabajadores` — salió de `AuthService` en la B-2) y `pantallas/` (perfil_tab, editar_perfil, ranking_tab, trabajadores_tab, configuracion, detalle_trabajador) |
| `lib/funcionalidades/trabajos/` | `datos/publicacion_service.dart` y `pantallas/` (trabajos_tab, detalle_trabajo, publicar, editar, mis_publicaciones) |
| `lib/funcionalidades/postulaciones/` | `datos/postulacion_service.dart` y `pantallas/` (mis_postulaciones, postulantes, postularse_sheet) |
| `lib/funcionalidades/inicio/` | `pantallas/inicio_screen.dart`: el `Scaffold` post-login con las 5 pestañas y el badge de no leídos |
| `lib/funcionalidades/chat/`, `cartera/`, `calificaciones/` | `datos/{chat,cartera,calificacion}_service.dart` (sobre la API REST; `chat/` también tiene `datos/chat.dart`, `pantallas/{chats_tab,chat_screen}` y `widgets/` con el panel de negociación; `cartera/` trae `movimiento_cartera.dart`, `cartera_screen` y `dialogos_cartera`; `calificaciones/` trae `calificar_sheet`) |

**Las dos reglas que hacen que esto no se deshaga** (reglas 14-16 de
`CLAUDE.md`):

- **Ningún archivo Dart pasa de 300 líneas** sin justificarlo en el reporte de
  su tarea. Las excepciones vivas están anotadas en
  `docs/agent-reports/027-estructura-por-funcionalidad-y-di.md`, en
  `docs/agent-reports/027b1-base-compartida.md` y —para las 6 que la B-2 mueve
  tal cual y parte en un PR aparte (B-2b): `trabajos_tab`, `perfil_tab`,
  `publicacion_service`, `editar_perfil_screen`, `mis_publicaciones_screen`,
  `postulantes_screen`— en `docs/agent-tasks/027-estructura-por-funcionalidad-y-di.md`
  (decisión 2 del plan B-2). `auth_service.dart` bajó de 487 a 350 al salir
  `PerfilService`, y sigue sobre el techo por sus docstrings de ADR-0013 y de
  la renovación de sesión.
- **Las pantallas no construyen sus servicios**: los reciben con
  `context.read<T>()` desde `proveedoresDeLaApp()`. `final _s = MiService();`
  dentro de un `State` es exactamente lo que dejó sin test a 12 de las 14
  pantallas.

`ApiClient` es la excepción declarada: no se registra en `provider` porque ya
tiene `ApiClient.fijarInstancia()`, que usan unos 60 tests de la capa HTTP.
Dos formas de sustituir lo mismo es peor que una. **Partirlo en cuatro (B-1) no
cambió ni esa API ni la renovación**: `ApiClient` sigue siendo la única puerta,
ahora delegando en tres colaboradores.

### Backend Spring Boot (`backend/`) — ya tiene consumidor

Esqueleto completo por capas (`Controller → Service → Repository → PostgreSQL`
vía JPA/Hibernate), organizado por módulo en
`backend/src/main/java/com/trabajito/modules/<módulo>/`:

`auth`, `usuarios`, `trabajos`, `postulaciones`, `chats`, `evidencias`,
`pagos`, `calificaciones`, `notificaciones`, `reportes`, `admin`, `archivos`.

Seguridad con Spring Security + JWT (`backend/src/main/java/com/trabajito/security/`).
WebSocket (STOMP) en `/ws`, autorizado (CONNECT y SUBSCRIBE) pero **sin uso
desde la app y sin probar en vivo**: el chat va por REST con sondeo. Ver
`docs/api.md` para el mapa de endpoints y `docs/database.md` para el modelo de
datos.

**Ya no es "código sin consumidor":** la app usa de verdad `auth`, `usuarios`,
`trabajos`, `postulaciones`, `evidencias`, `chats`, `pagos` (cartera) y
`calificaciones`. Sin consumidor siguen `notificaciones`, `reportes`, `admin` y
`archivos` (por verificar módulo a módulo).

## 2. Arquitectura objetivo

Flutter → API REST propia (Spring Boot) → PostgreSQL, con JWT + refresh tokens
para auth, todo sobre Docker. **Decidido y en marcha** desde el 2026-08-26
(ADR-0009, que reemplaza al ADR-0002, que dejaba la decisión abierta). El plan
por fases vive en `docs/agent-tasks/014-migracion-de-firebase-al-backend.md`:

| Fase | Qué | Estado |
|---|---|---|
| 0 | Cerrar el contrato de autenticación (refresh tokens, login exigente) | hecho (015) |
| 1 | Cimientos del cliente HTTP y modelos con JSON | hecho (018) |
| 2a | Migrar `auth_service` | **hecho (020)** |
| 2b | Migrar los otros cinco servicios | **hecho** (026, 052, 053) |
| 3 | Pantallas que el backend ya soporta, y borrar `firestore.rules`, `firestore.indexes.json` y el proyecto Firebase | **parcial**: `pubspec.yaml`, `google-services.json` y la inicialización ya salieron (060, ADR-0019); quedan las reglas y el proyecto |
| 4 | Flyway, HTTPS, backups, CI, pasarela de pago real | pendiente |

Redis, que estaba en el stack objetivo original, **no existe en el repo** en
ninguna forma (ni en `pom.xml`, ni en `docker-compose.yml`). Sigue siendo
aspiracional.

## 3. Límites entre agentes (para evitar pisarse)

| Si tu cambio toca... | Dominio | Coordina con |
|---|---|---|
| `lib/**` | `flutter-agent` | `backend-agent` si necesita un endpoint que no existe o cambiar un contrato; `security-agent` si toca la sesión o el almacén del token |
| `backend/src/main/java/**` | `backend-agent` | `security-agent` si toca `security/` o `auth/`; avisar a `flutter-agent` si cambia un contrato de endpoint ya consumido |
| `backend/src/main/resources/**` (schema, `application.yml`) | `backend-agent` | ver "cuándo se separa Database Agent" abajo |
| `firestore.rules`, `firestore.indexes.json` | `flutter-agent` o `security-agent` (según si es funcional o de seguridad) | `security-agent` siempre revisa antes de mergear |
| `.github/workflows/**`, `backend/Dockerfile`, `backend/docker-compose.yml` | `devops-agent` | — |
| `docs/**` | Cualquier agente puede proponer el cambio; `docs-agent` lo consolida | — |

### Cuándo separar un Database Agent dedicado

Hoy la base de datos (PostgreSQL) se maneja con `ddl-auto=update` de
Hibernate — el esquema se genera desde las entidades JPA, no hay migraciones
versionadas. Mientras eso sea cierto, el trabajo de "base de datos" es
indistinguible del trabajo de backend. Se justifica separar un agente de
Database dedicado cuando ocurra cualquiera de estas dos cosas (lo que pase
primero):

1. Se introduce Flyway o Liquibase (migraciones versionadas) — mencionado
   como pendiente en `backend/README.md`.
2. El número de tablas/relaciones crece lo suficiente como para que el
   diseño de índices y optimización de queries sea un trabajo full-time
   aparte del CRUD de cada módulo.

Hasta entonces, `backend-agent` cubre ambos.
