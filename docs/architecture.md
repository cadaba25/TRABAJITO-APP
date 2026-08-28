# Arquitectura de Trabajito

> Verificado directamente sobre el repositorio. Última revisión: **2026-08-27
> (tarea 020)**, cuando la app dejó de autenticarse contra Firebase. Donde algo
> no se pudo verificar en esta máquina se dice explícitamente.

## 1. Arquitectura actual (lo que corre de verdad)

**Desde el 2026-08-27 la app está partida en dos a propósito.** La migración de
ADR-0009 va servicio por servicio, y el primero (autenticación y perfil) ya
habla con el backend propio; los otros cinco siguen en Firestore hasta que les
toque. Esto **no es una arquitectura híbrida de destino**: es el estado
intermedio de una migración en curso. El destino sigue siendo Firebase = cero.

```
┌───────────────────────────────────────────────┐
│              App Flutter (móvil)              │
│                                               │
│  lib/services/auth_service.dart ───┐          │
│  (sesión, perfil, CV, trabajadores)│          │
│                                    │          │
│  lib/services/{publicacion,        │          │
│   postulacion, chat, calificacion, │          │
│   cartera}_service.dart ───────────┼───┐      │
└────────────────────────────────────┼───┼──────┘
                                     │   │
       lib/services/api/ApiClient    │   │  SDK de Firebase (directo)
       HTTP + JWT + refresh token    │   │
                                     ▼   ▼
        ┌──────────────────────┐   ┌──────────────────────┐
        │  Backend propio      │   │  Cloud Firestore     │
        │  Spring Boot + JWT   │   │  publicaciones,      │
        │  PostgreSQL 16       │   │  postulaciones,      │
        │                      │   │  chats, calificacio- │
        │  usuarios, sesiones, │   │  nes, tarjetas       │
        │  perfil, CV          │   │                      │
        └──────────────────────┘   └──────────────────────┘
                                    (Firebase Auth: YA NO SE USA)
```

### Lo que ya pasa por el backend propio (tarea 020, fase 2a)

- **Registro, login, cierre de sesión y renovación de token.** JWT de acceso de
  15 min + refresh token rotativo y revocable (ADR-0010). Se guardan en el
  almacén seguro del dispositivo (`flutter_secure_storage`), no en claro.
- **Perfil**: leerlo, editarlo, el CV del trabajador (habilidades, experiencia,
  estudios) y la baja de cuenta.
- **Listado de trabajadores y ranking** (`GET /api/usuarios/ranking`).

**Firebase Authentication ya no se usa**: ningún archivo de `lib/` importa
`firebase_auth`. El paquete sigue en `pubspec.yaml` porque quitarlo es la
fase 3, cuando ya no quede nada de Firebase.

### Lo que sigue en Firestore

`publicacion_service`, `postulacion_service`, `chat_service`,
`calificacion_service` y `cartera_service`, con sus pantallas. La autorización
de esa parte sigue viviendo en `firestore.rules`.

### La consecuencia de haber migrado la autenticación primero

El identificador de usuario pasó de ser el `uid` de Firebase a ser el **UUID
del backend**, y ese UUID no existe en Firestore. Además, `firestore.rules`
exige `request.auth != null` en todas las colecciones, y ya no hay sesión de
Firebase Auth que lo satisfaga. Por tanto, **una cuenta creada contra el
backend no encuentra datos en las pantallas que siguen en Firestore**.

Es inherente al orden de migración que fijó la épica 014 (sin token del backend
no se puede migrar nada más), no un descuido, y no afecta a nadie hoy porque
los datos de Firebase son de prueba y se descartan (ADR-0009). Se cierra cuando
termine la fase 2b. Detalle en
`docs/agent-reports/020-fase2a-auth-contra-el-backend.md`.

### El estado de sesión, ahora que no hay `authStateChanges()`

Firebase daba un `Stream<User?>` que avisaba solo. Su sustituto es
`lib/services/sesion_usuario.dart`: un `ValueNotifier<EstadoSesion>` con tres
fases explícitas (`comprobando` / `sinSesion` / `conSesion`) que rellena
`AuthService`. `PantallaInicial` lo escucha para decidir entre la pantalla de
carga, el login y la pantalla principal.

Los `Stream` de Firestore que desaparecen **no se sustituyen por sondeo**: la
decisión del `tech-lead` para la fase 2 es carga puntual + "deslizar para
actualizar", salvo el chat, que necesitará WebSocket.

### Módulos Flutter (por carpeta, no por capa técnica)

| Carpeta | Contiene |
|---|---|
| `lib/screens/` | Pantallas de flujo raíz: login, bienvenida/elección de rol, registro (trabajador/empleador) |
| `lib/screens/tabs/` | Las 5 pestañas de navegación inferior post-login: Trabajos, Trabajadores, Ranking, Chats, Perfil |
| `lib/screens/*_screen.dart` (resto) | Pantallas de detalle/flujo: detalle de trabajo, detalle de trabajador, publicar trabajo, editar trabajo/perfil, postulantes, mis postulaciones, mis publicaciones, cartera, configuración, chat |
| `lib/models/` | Modelos de datos. Conviven `desdeFirestore()`/`aFirestore()` y `desdeJson()`/`aJson()` mientras dure la migración: Usuario, Publicacion (trabajo), Postulacion, Chat, Calificacion, Evidencia, Tarjeta |
| `lib/services/api/` | La capa HTTP única: `ApiClient` (cabecera `Authorization`, renovación serializada del token, traducción de errores de ADR-0008), configuración de URL base, rutas, excepciones y almacén seguro de la sesión |
| `lib/services/` | Un servicio por dominio. `auth_service` habla HTTP; los otros cinco, Firestore |
| `lib/services/sesion_usuario.dart` | El estado de sesión en memoria, sustituto de `authStateChanges()` |
| `lib/widgets/` | Componentes reusables (campos de formulario, estrellas, etiquetas, reseñas, logo) |
| `lib/utils/constantes.dart` | Colores, textos, nombres de colecciones de Firestore, traducción de enums de la API, reglas de cuenta que impone el servidor, catálogo de departamentos/ciudades de Honduras, tema claro/oscuro |

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
