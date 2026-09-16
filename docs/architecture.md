# Arquitectura de Trabajito

> Verificado directamente sobre el repositorio. Última revisión: **2026-09-04
> (tarea 026)**, cuando trabajos y postulaciones dejaron Firestore. Donde algo
> no se pudo verificar en esta máquina se dice explícitamente.

## 1. Arquitectura actual (lo que corre de verdad)

**Desde el 2026-08-27 la app está partida en dos a propósito.** La migración de
ADR-0009 va servicio por servicio. Ya hablan con el backend propio la
autenticación y el perfil (tarea 020) y, desde el **2026-09-04**, los trabajos
y las postulaciones (tarea 026). Siguen en Firestore los **tres** que quedan.
Esto **no es una arquitectura híbrida de destino**: es el estado intermedio de
una migración en curso. El destino sigue siendo Firebase = cero.

```
┌───────────────────────────────────────────────┐
│              App Flutter (móvil)              │
│                                               │
│  funcionalidades/autenticacion/    ┐          │
│    datos/auth_service.dart ────────┤          │
│  funcionalidades/perfil/           │          │
│    datos/perfil_service.dart ──────┤          │
│  funcionalidades/trabajos/         │          │
│    datos/publicacion_service.dart  │          │
│  funcionalidades/postulaciones/    │          │
│    datos/postulacion_service.dart  │          │
│                                    │          │
│  lib/services/{chat, calificacion, │          │
│   cartera}_service.dart ───────────┼───┐      │
└────────────────────────────────────┼───┼──────┘
                                     │   │
       lib/nucleo/api/ApiClient      │   │  SDK de Firebase (directo)
       HTTP + JWT + refresh token    │   │
                                     ▼   ▼
        ┌──────────────────────┐   ┌──────────────────────┐
        │  Backend propio      │   │  Cloud Firestore     │
        │  Spring Boot + JWT   │   │  chats, calificacio- │
        │  PostgreSQL 16       │   │  nes, tarjetas       │
        │                      │   │                      │
        │  usuarios, sesiones, │   │  (publicaciones y    │
        │  perfil, CV,         │   │   postulaciones ya   │
        │  trabajos, postula-  │   │   no se leen)        │
        │  ciones, evidencias  │   │                      │
        └──────────────────────┘   └──────────────────────┘
                                    (Firebase Auth: YA NO SE USA)
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

**Firebase Authentication ya no se usa**: ningún archivo de `lib/` importa
`firebase_auth`. El paquete sigue en `pubspec.yaml` porque quitarlo es la
fase 3, cuando ya no quede nada de Firebase.

### Lo que sigue en Firestore

`chat_service`, `calificacion_service` y `cartera_service`, con sus pantallas
(chat, calificar, cartera) y el contador de no leídos de `InicioScreen`. La
autorización de esa parte sigue viviendo en `firestore.rules`.

**Un cruce que hay que tener presente hasta que se cierre la fase 2b:** el
acuerdo de pago y tiempo que exige `POST /api/trabajos/{id}/reservar-pago` se
sigue leyendo del **chat de Firestore** (`DetalleTrabajoScreen._reservarPago`).
Es la única costura que queda entre las dos mitades.

### La consecuencia de haber migrado la autenticación primero

El identificador de usuario pasó de ser el `uid` de Firebase a ser el **UUID
del backend**, y ese UUID no existe en Firestore. Además, `firestore.rules`
exige `request.auth != null` en todas las colecciones, y ya no hay sesión de
Firebase Auth que lo satisfaga. Por tanto, **una cuenta creada contra el
backend no encuentra datos en las pantallas que siguen en Firestore** —hoy, las
tres que quedan—.

Es inherente al orden de migración que fijó la épica 014 (sin token del backend
no se puede migrar nada más), no un descuido, y no afecta a nadie hoy porque
los datos de Firebase son de prueba y se descartan (ADR-0009). Se cierra cuando
termine la fase 2b. Detalle en
`docs/agent-reports/020-fase2a-auth-contra-el-backend.md`.

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

Los `Stream` de Firestore que desaparecen **no se sustituyen por sondeo**: la
decisión del `tech-lead` para la fase 2 es carga puntual + "deslizar para
actualizar", salvo el chat, que necesitará WebSocket.

### Módulos Flutter — **por funcionalidad desde la tarea 027 (ADR-0014)**

`lib/` se está reorganizando de "por tipo" (`models/`, `screens/`,
`services/`...) a "por funcionalidad". **La migración va a medias y a
propósito**: se movió `autenticacion` como piloto (parte A), **la base
compartida —`nucleo/api/` y `compartido/widgets/`— en la parte B-1**, y
**`trabajos`, `postulaciones`, `perfil` e `inicio` más los modelos en la
B-2** (2026-09-09). Lo único que sigue "por tipo" es `lib/screens/` (4
archivos) y `lib/services/` (4), todos dependientes de Firestore, que se
mueven al migrarse en la fase 2b-2. Mira esta tabla antes de suponer dónde
está algo.

| Carpeta | Contiene |
|---|---|
| `lib/nucleo/api/` | La capa HTTP única, partida en cuatro desde la B-1: `api_client.dart` (la fachada, con `instancia`/`fijarInstancia`), `transporte_http.dart` (una ida y vuelta: URL, cabeceras, tiempo límite y traducción de errores de ADR-0008), `gestor_sesion.dart` (**los tres candados de la renovación**, el almacén de sesión y la petición autenticada) y `guardia_escrituras.dart` (ADR-0013). Más `configuracion_api`, `sesion_api`, `almacen_sesion`, `pagina_api` y `api_excepciones` |
| `lib/nucleo/tema/` | `AppColores`, `AppTema` (claro/oscuro), `notificadorTema` (el `ValueNotifier` global del modo de tema) y `colores_por_tema.dart` (`colorTextoFuerte`/`Suave`/`Superficie`/`Borde`: la parte del tema que depende del `BuildContext`) |
| `lib/nucleo/textos/` | `AppTextos` y `MensajesError` |
| `lib/nucleo/dominio/` | Vocabulario del negocio compartido: `EstadosTrabajo`/`EstadosPostulacion`/`TiposMensaje`, `MapeoEnumApi` (enums del backend ↔ minúsculas de la app), `RolesApi`+`ValoresDefecto`, `CamposUsuario`, `ReglasCuenta` (lo que el servidor exige y el formulario debe pedir igual) |
| `lib/nucleo/sesion/` | `SesionUsuario`, el `ValueNotifier<EstadoSesion>` que sustituye a `authStateChanges()` |
| `lib/nucleo/inyeccion/` | `proveedoresDeLaApp()`: **la raíz de composición**, el único sitio donde se construyen los servicios. Registra `AuthService`, `PerfilService`, `PublicacionService` y `PostulacionService` |
| `lib/compartido/datos/` | Catálogos: departamentos y ciudades de Honduras, sectores y tamaños de empresa |
| `lib/compartido/modelos/` | **Los 7 modelos + `json_utiles.dart` desde la B-2.** Transversales (p. ej. `Publicacion` la usan trabajos, postulaciones y chat). Conviven `desdeFirestore()`/`aFirestore()` y `desdeJson()`/`aJson()` mientras dure la migración: Usuario, Publicacion (trabajo), Postulacion, Chat, Calificacion, Evidencia, Tarjeta |
| `lib/compartido/widgets/` | Componentes reusables, **uno por archivo** desde la B-1: `custom_textfield` (`CustomTextField`), `custom_dropdown`, `indicador_pasos`, `botones_si_no`, `indicador_fuerza_contrasena`, `mostrar_snackbar`, `ejecutar_con_carga` (¡lleva un candado **global** anti doble-toque!), más `entrada_etiquetas`, `estrellas`, `resenas` y `logo_trabajito` |
| `lib/funcionalidades/autenticacion/` | `datos/auth_service.dart` (sesión, registro, baja de cuenta) y `pantallas/` (login, bienvenida y los dos registros) |
| `lib/funcionalidades/perfil/` | `datos/perfil_service.dart` (recargar/editar el perfil propio, CV del trabajador, perfil ajeno, `listarTrabajadores` — salió de `AuthService` en la B-2) y `pantallas/` (perfil_tab, editar_perfil, ranking_tab, trabajadores_tab, configuracion, detalle_trabajador) |
| `lib/funcionalidades/trabajos/` | `datos/publicacion_service.dart` y `pantallas/` (trabajos_tab, detalle_trabajo, publicar, editar, mis_publicaciones) |
| `lib/funcionalidades/postulaciones/` | `datos/postulacion_service.dart` y `pantallas/` (mis_postulaciones, postulantes, postularse_sheet) |
| `lib/funcionalidades/inicio/` | `pantallas/inicio_screen.dart`: el `Scaffold` post-login con las 5 pestañas y el badge de no leídos |
| `lib/screens/` | **Lo que queda por tipo.** Solo `calificar_sheet`, `cartera_screen`, `chat_screen` y `tabs/chats_tab` — todos dependen de Firestore. Se mueven al migrarse (fase 2b-2) |
| `lib/services/` | Solo `chat_service`, `calificacion_service`, `cartera_service` (Firestore). `firestore_colecciones.dart` vive aquí **a propósito**: muere con ellos en la fase 3 |

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
WebSocket (STOMP) para chat en tiempo real, **todavía sin probar**. Ver
`docs/api.md` para el mapa de endpoints y `docs/database.md` para el modelo de
datos.

**Desde la tarea 020 ya no es "código sin consumidor":** los módulos `auth` y
`usuarios` los usa la app de verdad. Los demás siguen esperando su fase.

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
| 2b | Migrar los otros cinco servicios | pendiente |
| 3 | Pantallas que el backend ya soporta, y quitar Firebase de `pubspec.yaml`, `firestore.rules` y `google-services.json` | pendiente |
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
