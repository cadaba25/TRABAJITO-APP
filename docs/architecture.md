# Arquitectura de Trabajito

> Verificado directamente sobre el repositorio el 2026-08-19. Donde algo no
> se pudo verificar en esta máquina (por ejemplo, compilar el backend porque
> no hay `mvn`/`java` instalados aquí), se dice explícitamente.

## 1. Arquitectura actual (lo que corre de verdad)

```
┌─────────────────────────┐
│   App Flutter (móvil)   │
│  lib/screens, services  │
└────────────┬─────────────┘
             │ SDK de Firebase (directo, sin capa intermedia propia)
             ▼
┌─────────────────────────┐
│   Firebase Auth          │  ← login, registro, sesión
│   Cloud Firestore         │  ← todos los datos: usuarios, publicaciones,
│                            │    postulaciones, chats, calificaciones,
│                            │    tarjetas, evidencias
└─────────────────────────┘
```

- El cliente Flutter llama a Firebase directamente desde cada `*_service.dart`
  en `lib/services/`. No existe una capa de API propia en producción.
- La autorización de quién puede leer/escribir qué vive en
  `firestore.rules` (reglas declarativas de Firebase), no en un backend.
- `pubspec.yaml` no declara ningún paquete HTTP (`http`, `dio`, etc.) — es la
  prueba definitiva de que hoy no hay ningún consumo de API REST propia.

### Módulos Flutter (por carpeta, no por capa técnica)

| Carpeta | Contiene |
|---|---|
| `lib/screens/` | Pantallas de flujo raíz: login, bienvenida/elección de rol, registro (trabajador/empleador) |
| `lib/screens/tabs/` | Las 5 pestañas de navegación inferior post-login: Trabajos, Trabajadores, Ranking, Chats, Perfil |
| `lib/screens/*_screen.dart` (resto) | Pantallas de detalle/flujo: detalle de trabajo, detalle de trabajador, publicar trabajo, editar trabajo/perfil, postulantes, mis postulaciones, mis publicaciones, cartera, configuración, chat |
| `lib/models/` | Modelos de datos con `desdeFirestore()`/`aFirestore()`: Usuario, Publicacion (trabajo), Postulacion, Chat, Calificacion, Evidencia, Tarjeta |
| `lib/services/` | Un servicio por dominio, cada uno hablando directo con Firestore: auth, publicacion, postulacion, chat, calificacion, cartera |
| `lib/widgets/` | Componentes reusables (campos de formulario, estrellas, etiquetas, reseñas, logo) |
| `lib/utils/constantes.dart` | Colores, textos, nombres de colecciones de Firestore, catálogo de departamentos/ciudades de Honduras, tema claro/oscuro |

### Backend Spring Boot (`backend/`) — existe, no está en producción

Esqueleto completo por capas (`Controller → Service → Repository → PostgreSQL`
vía JPA/Hibernate), organizado por módulo en
`backend/src/main/java/com/trabajito/modules/<módulo>/`:

`auth`, `usuarios`, `trabajos`, `postulaciones`, `chats`, `evidencias`,
`pagos`, `calificaciones`, `notificaciones`, `reportes`, `admin`, `archivos`.

Seguridad con Spring Security + JWT (`backend/src/main/java/com/trabajito/security/`).
WebSocket (STOMP) para chat en tiempo real. Ver `docs/api.md` para el mapa de
endpoints y `docs/database.md` para el modelo de datos que asume.

**Nada de esto está conectado al cliente Flutter todavía.** Es trabajo real
y sustancial (implementado en 2026-07-16), pero es un objetivo de migración,
no la arquitectura en producción. Ver ADR-0002 en `docs/decisions.md`.

## 2. Arquitectura objetivo (la que describió el dueño del proyecto)

Flutter → API REST propia (Spring Boot) → PostgreSQL, con Redis como cache y
JWT + refresh tokens para auth, todo sobre Docker.

**Esto implica migrar fuera de Firebase**, no sumar Spring Boot al lado de
Firebase. Es una decisión de producto/arquitectura grande (reescribir cada
`*_service.dart` de Flutter para hablar HTTP en vez de Firestore SDK, migrar
datos, decidir qué pasa con `firestore.rules`) que **no se ha tomado
formalmente todavía** — solo se construyó el esqueleto del lado backend.
Ningún agente debe asumir que esta migración está en marcha ni empezarla sin
que el usuario la apruebe explícitamente como una tarea planificada por el
`tech-lead`.

Redis tampoco existe en el repo en ninguna forma (ni en `pom.xml`, ni en
`docker-compose.yml`). Es puramente aspiracional por ahora.

## 3. Límites entre agentes (para evitar pisarse)

| Si tu cambio toca... | Dominio | Coordina con |
|---|---|---|
| `lib/**` (excepto llamadas nuevas a una API) | `flutter-agent` | — |
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
