# Trabajito — Backend (Spring Boot + PostgreSQL)

API REST + WebSocket que actúa como **el cerebro** de Trabajito. El cliente
Flutter solo muestra información y envía solicitudes; **toda la validación,
autorización y el manejo de dinero viven aquí**.

> Estado: **esqueleto completo**. La estructura, seguridad, entidades y el flujo
> principal (auth, trabajos, postulaciones, chat, pagos/escrow, calificaciones)
> están implementados. Quedan pendientes marcados con `TODO` (push FCM real,
> pasarela de pago, validación del socket, etc.).

## Stack

- **Java 17** + **Spring Boot 3.3**
- **PostgreSQL 16**
- **Spring Security 6** + **JWT** (BCrypt para contraseñas)
- **WebSocket (STOMP)** para el chat en tiempo real
- **springdoc-openapi** (Swagger UI) para probar la API
- **Docker Compose** para levantar la base de datos con un comando

## Arquitectura por capas

```
Controller  →  Service  →  Repository  →  PostgreSQL
(HTTP/JSON)    (lógica)     (JPA)
```

Cada módulo vive en `src/main/java/com/trabajito/modules/<modulo>`:

| Módulo | Responsabilidad |
|--------|-----------------|
| `auth` | registro, login, emisión de JWT |
| `usuarios` | perfil completo (con habilidades, experiencia y estudios), ranking, baja de cuenta |
| `trabajos` | ciclo de vida del trabajo (máquina de estados) |
| `postulaciones` | postularse, aceptar, retirar |
| `chats` | mensajería en tiempo real + negociación pago/tiempo |
| `evidencias` | avances/evidencias del trabajo |
| `pagos` | cartera y escrow (retener/liberar/reembolsar) |
| `calificaciones` | calificaciones bidireccionales |
| `notificaciones` | notificaciones in-app (+ gancho FCM) |
| `reportes` | denuncias de usuarios |
| `admin` | panel de administración (rol ADMIN) |
| `archivos` | subida de fotos/evidencias a disco local |

## Cómo correr en local

### 1. Requisitos
- Docker (para PostgreSQL) — o un PostgreSQL propio en `localhost:5432`.
- JDK 17 y Maven (o abre el proyecto en IntelliJ IDEA, que trae ambos).

### 2. Levantar la base de datos
```bash
cd backend
cp .env.example .env           # OBLIGATORIO: docker compose lee este archivo
docker compose up -d db        # PostgreSQL en localhost:5432
```

> `docker-compose.yml` declara `JWT_SECRET` como variable **requerida**. Sin un
> `.env` presente, cualquier comando de compose (incluso `up -d db`) falla con
> un mensaje que explica qué falta. Es a propósito: evita que el backend llegue
> a arrancar alguna vez firmando tokens con el secreto de ejemplo.

### 3. Correr el backend
```bash
mvn spring-boot:run
```
o desde el IDE ejecutando `TrabajitoApplication`.

### 4. Probar
- Swagger UI: http://localhost:8080/swagger-ui.html
- Por defecto **no existe ninguna cuenta ADMIN** (ya no hay admin semilla con
  contraseña fija). Ver [Cómo se crea un ADMIN](#cómo-se-crea-un-admin).

Flujo típico en Swagger:
1. `POST /api/auth/registro` → copia el `token`.
2. Botón **Authorize** (arriba a la derecha) → pega el token.
3. Ya puedes llamar al resto de endpoints autenticado.

## Cómo correr TODO el stack en Docker

Con esto no hace falta Java ni Maven en la máquina: el `Dockerfile` es
multi-etapa y compila dentro de Docker.

```bash
cd backend
cp .env.example .env
# secreto real, no el placeholder:
sed -i "s|^JWT_SECRET=.*|JWT_SECRET=$(openssl rand -base64 48)|" .env
chmod 600 .env

docker compose build api     # la primera vez tarda: baja Maven + dependencias
docker compose up -d         # levanta db + api
docker compose ps            # ambos deben quedar "healthy"
docker compose logs -f api
```

Procedimiento paso a paso en un servidor Ubuntu (y qué se verificó realmente
ahí) en [`../docs/development.md`](../docs/development.md).

### Variables que consume `docker-compose.yml`

| Variable | Por defecto | Para qué |
|---|---|---|
| `DB_NAME` / `DB_USER` / `DB_PASSWORD` | `trabajito` | credenciales de PostgreSQL |
| `JWT_SECRET` | **sin valor — obligatoria** | firma de los JWT (`openssl rand -base64 48`) |
| `JWT_EXPIRATION_MS` | `604800000` (7 días) | vida del token |
| `JPA_DDL_AUTO` | `update` | estrategia de esquema de Hibernate |
| `CORS_ORIGINS` | `*` | orígenes permitidos |
| `SPRING_PROFILES_ACTIVE` | vacío | perfil de Spring (ya no crea ningún usuario) |
| `ADMIN_INICIAL_CORREO` | vacío | correo del ADMIN inicial (ver más abajo) |
| `ADMIN_INICIAL_PASSWORD` | vacío | su contraseña, mínimo 12 caracteres |
| `API_PORT_BIND` | `8080` | dónde se publica la API en el host |
| `DB_PORT_BIND` | `127.0.0.1:5432` | dónde se publica PostgreSQL en el host |

`DB_URL` del `.env` **solo** aplica cuando corres el backend fuera de Docker.
Dentro de compose el host de la BD es el servicio `db` (no `localhost`), y ese
valor lo fija `docker-compose.yml`.

## Mapa de la API

### Respuestas de error (ADR-0008)

Cualquier error, venga del controller o de la cadena de filtros de seguridad,
responde el mismo cuerpo:

```json
{"timestamp":"...","status":400,"error":"Bad Request","message":"Datos inválidos",
 "fields":{"trabajoId":"Indica el trabajo al que te postulas"}}
```

`400` validación/JSON/tipo · `401` sin token, token inválido, credenciales
incorrectas **o cuenta suspendida** · `403` autenticado sin permiso · `404`
ruta o recurso inexistente · `405` método no permitido (con cabecera `Allow`)
· `409` estado incompatible o choque con la BD · `415` `Content-Type` no
soportado · `500` fallo no previsto (mensaje genérico; el detalle, con
stacktrace, solo en el log del servidor).

Todo se declara en `common/exception/GlobalExceptionHandler` (errores dentro
del DispatcherServlet) y `common/exception/ManejadoresSeguridadHttp` (401/403
de la cadena de filtros); el cuerpo lo construye `RespuestaError`. Si añades
un endpoint: lanza `ApiException`, pon `@Valid` en el `@RequestBody` y no
inventes otro formato de error. Detalle y códigos en `docs/api.md`.

### Autenticación — `/api/auth` (público)
| Método | Ruta | Descripción |
|--------|------|-------------|
| POST | `/registro` | crea cuenta, devuelve token + usuario. `rol` solo admite `TRABAJADOR` o `EMPLEADOR` |
| POST | `/login` | inicia sesión, devuelve token + usuario |
| GET | `/yo` | usuario autenticado (valida el token) |

### Usuarios — `/api/usuarios`
| GET `/{id}` | perfil público de otra persona: **con** su CV, **sin** correo, DNI, teléfonos, fecha de nacimiento, género, código postal, RTN ni saldo |
| GET `/me` | perfil propio completo |
| PUT `/me` | editar perfil propio (23 campos; si mandas `habilidades` reemplaza la lista entera). Devuelve el perfil completo ya guardado |
| GET `/ranking` | ranking de trabajadores (vista pública, sin CV) |
| DELETE `/me` | baja de la cuenta propia |
| PUT `/me/habilidades` | reemplaza la lista de habilidades (máx. 30) |
| POST `/me/experiencia` | añade un puesto al historial laboral → **201** (máx. 30) |
| PUT · DELETE `/me/experiencia/{id}` | edita / borra un puesto **propio** (ajeno → 403) |
| POST `/me/estudios` | añade un estudio → **201** (máx. 30) |
| PUT · DELETE `/me/estudios/{id}` | edita / borra un estudio **propio** (ajeno → 403) |

**El perfil completo (tarea 019, ADR-0011).** `habilidades`, `experiencia` y
`estudios` viven en tres tablas propias con FK a `usuarios`, no dentro de la
fila del usuario. `fechaNacimiento` entra en `dd/MM/yyyy` o ISO, sale en ISO, y
el servidor **exige 18 años cumplidos**. Las fechas de experiencia y estudios
son texto (`MM/AAAA`: son fechas parciales). En `/api/auth/login` y
`/api/auth/registro` las tres listas llegan como `null` = "no viene en esta
respuesta"; el perfil entero está en `GET /api/auth/yo`, `GET /api/usuarios/me`
y `GET /api/usuarios/{id}`.

### Trabajos — `/api/trabajos`
| GET `/` | feed paginado (`?pagina=0&tamano=20`) |
| GET `/{id}` | detalle |
| GET `/mios` | mis publicaciones (empleador) |
| GET `/asignados` | trabajos asignados a mí (trabajador) |
| POST `/` | publicar |
| POST `/{id}/reservar-pago` | confirmar acuerdo + depositar en garantía |
| POST `/{id}/iniciar` | trabajador inicia |
| POST `/{id}/terminar` | trabajador entrega — **exige al menos una evidencia suya**, si no `409` (ADR-0007) |
| POST `/{id}/solicitar-correccion` | empleador pide correcciones (para re-entregar hace falta una evidencia nueva) |
| POST `/{id}/aceptar` | empleador acepta y libera el pago |
| POST `/{id}/cancelar` | empleador cancela — body `{"reabrir":true\|false}` **obligatorio**; solo desde `ACTIVO`/`ASIGNADO`/`ACORDADO`, después `409` |
| POST `/{id}/rechazar` | trabajador rechaza — solo desde `ASIGNADO` y sin escrow, después `409` |
| POST `/{id}/reclamar` | cualquiera de las dos partes lleva el problema a soporte: `EN_DISPUTA`, escrow congelado (body `{"motivo":"...","descripcion":"..."}`, motivo obligatorio) |

**Reglas de cancelación y entrega (ADR-0007, tarea 010).** Una vez el trabajo
inicia (`EN_PROGRESO`), **ninguna** de las dos partes puede cancelar: la única
salida es `POST /{id}/reclamar`, que deja el dinero congelado hasta que un
`ADMIN` resuelve. La tabla completa de transiciones está en `docs/decisions.md`
→ ADR-0007.

### Postulaciones — `/api/postulaciones`
| POST `/` | postularse |
| GET `/?trabajoId=` | postulantes de un trabajo (dueño) |
| GET `/mias` | mis postulaciones (trabajador) |
| POST `/{id}/aceptar` | empleador acepta → asigna + crea chat |
| DELETE `/{id}` | retirar postulación |

### Evidencias — `/api/trabajos/{trabajoId}/evidencias`
| GET `/` | ver avances |
| POST `/` | agregar avance (trabajador, en progreso) |

### Chats — `/api/chats`
| GET `/` | mis chats |
| GET `/{id}` · `/{id}/mensajes` | detalle / mensajes |
| POST `/{id}/mensajes` | enviar (se difunde por WebSocket) |
| POST `/{id}/leido` | marcar leídos |
| POST `/{id}/proponer-pago` · `/aceptar-pago` | negociación de pago |
| POST `/{id}/proponer-tiempo` · `/aceptar-tiempo` | negociación de tiempo |

**Tiempo real:** el cliente se conecta a `ws://host:8080/ws` (SockJS/STOMP) y se
suscribe a `/topic/chats/{chatId}` para recibir mensajes al instante.

### Cartera — `/api/cartera`
| POST `/recargar` | recargar saldo (prototipo) |
| GET `/movimientos` | historial de la cartera |

### Calificaciones — `/api/calificaciones`
| POST `/` | calificar (1–5) |
| GET `/usuario/{id}` | reseñas recibidas (`?rol=TRABAJADOR|EMPLEADOR` filtra por papel) |

**Dos reputaciones, una por rol (tarea 019, ADR-0011).** Cada calificación suma
en `calificacionComoTrabajador` o en `calificacionComoEmpleador` según el papel
que tenía **el receptor en ese trabajo** (`Calificacion.rolCalificado`), nunca
según su rol de cuenta. `calificacionPromedio` se conserva como media global.

### Notificaciones — `/api/notificaciones`
| GET `/` · `/no-leidas` · POST `/{id}/leida` | in-app |

### Reportes — `/api/reportes` · Admin — `/api/admin` (rol ADMIN)
| POST `/api/reportes` | crear reporte |
| GET `/api/admin/estadisticas` · `/reportes` | panel |
| POST `/api/admin/reportes/{id}/resolver` | resolver reporte |
| GET `/api/admin/trabajos/en-disputa` | cola de trabajos con el escrow congelado |
| POST `/api/admin/trabajos/{id}/resolver-disputa` | descongela el dinero: body `{"aFavorDe":"TRABAJADOR"\|"EMPLEADOR","resolucion":"..."}` (ADR-0007) |
| POST `/api/admin/usuarios/{id}/suspender` · `/reactivar` | moderación |

> **Ojo operativo:** desde ADR-0007 hay dinero que **solo** un `ADMIN` puede
> desbloquear. Un despliegue sin ningún ADMIN (que es el valor por defecto,
> ver ADR-0005) deja los trabajos en disputa congelados para siempre.

### Archivos — `/api/archivos`
| POST `/` (multipart `archivo`) | sube y devuelve `{ "url": "/uploads/..." }` |

## Seguridad

- Contraseñas con **BCrypt** (nunca en texto plano).
- **JWT** en cada request: header `Authorization: Bearer <token>`.
- Autorización por rol (`@EnableMethodSecurity`) y por dueño/participante en los
  servicios. **El cliente nunca decide permisos.**
- CORS configurable por `CORS_ORIGINS`.
- **Sin token es 401, no 403.** La cadena de filtros responde `401` con cuerpo
  JSON cuando no hay credenciales válidas, y `403` solo cuando el usuario está
  autenticado pero no tiene permiso (`ManejadoresSeguridadHttp`, ADR-0008).
- **El login no dice por qué falla.** Contraseña incorrecta y cuenta
  suspendida (`activo=false`) devuelven el mismo `401` con el mismo mensaje;
  si respondieran distinto, cualquiera podría averiguar desde un endpoint
  público qué cuentas existen y cuáles están sancionadas. El motivo real queda
  en el log del servidor (`AuthService`, nivel WARN).
- **El rol no se acepta del cliente.** `POST /api/auth/registro` es público y
  solo puede crear `TRABAJADOR` o `EMPLEADOR`: su DTO usa el enum `RolPublico`,
  que no incluye `ADMIN`. Cualquier otro valor (`ADMIN`, `SUPERJEFE`, ...)
  responde **400** y no crea usuario. Las autoridades de Spring Security salen
  de la fila de BD (`UsuarioPrincipal` → `usuario.getRol()`), no del claim del
  token, así que la única forma de ser ADMIN es tener `rol='ADMIN'` en la BD.
  Ver ADR-0005 en `docs/decisions.md`.

### Cómo se crea un ADMIN

No hay ningún endpoint para crear ni promover administradores, y **no existe
ninguna cuenta ADMIN por defecto**. Vías soportadas:

**1. Administrador inicial (arranque en frío).** Define las dos variables en
`backend/.env` (o en el entorno del proceso) y arranca el backend:

```bash
ADMIN_INICIAL_CORREO=admin@tudominio.hn
ADMIN_INICIAL_PASSWORD=<mínimo 12 caracteres, no la dejes en un .env compartido>
```

`AdminInicialSeeder` crea esa cuenta con rol `ADMIN` solo si el correo aún no
existe. Si falta cualquiera de las dos variables no hace nada; si la contraseña
tiene menos de 12 caracteres, loguea un `ERROR` y tampoco la crea. **No promueve
cuentas ya existentes** a propósito: promover en silencio a alguien que se
registró solo sería la misma escalada de privilegios por otra puerta. Tras el
primer acceso, cambia la contraseña y quita la variable del `.env`.

**2. Promover una cuenta existente (operación manual y auditable).** Con acceso
a la BD:

```sql
UPDATE usuarios SET rol = 'ADMIN' WHERE correo = 'persona@tudominio.hn';
-- para revocar:
UPDATE usuarios SET rol = 'EMPLEADOR' WHERE correo = 'persona@tudominio.hn';
```

Quien tiene acceso a la BD ya podía hacer cualquier cosa, así que esto no añade
riesgo nuevo, y deja rastro en el historial de operación en vez de en un
endpoint que cualquiera pueda alcanzar.

## Pendientes (TODO)

- Validar el JWT en el **handshake/CONNECT del WebSocket** (hoy el envío por REST
  ya valida; el socket solo difunde).
- **Pasarela de pago real** (Tigo Money / tarjeta) en el módulo `pagos`; hoy la
  recarga es un prototipo.
- **FCM** para push real (`NotificacionService.enviarPush`).
- **Flyway/Liquibase** para migraciones (hoy `ddl-auto=update` para desarrollo).
  **Ya son tres los componentes de arranque que hacen de sistema de migraciones**
  (`RestriccionSaldoNoNegativo`, `RestriccionEstadoTrabajo` y, desde la tarea
  019, `RellenoPerfilYReputacion`, que además toca *datos* y no solo
  constraints). Propuesto como tarea propia en ADR-0011: debería entrar antes de
  que la fase 2 de ADR-0009 ponga datos reales de usuarios en esta base.
- **Almacenamiento de objetos** (S3/MinIO) en vez de disco local para archivos.
- Auto-liberación del escrow por tiempo, y flujo de disputa que congela fondos.

## Producción (resumen)

Ubuntu + Nginx (reverse proxy con HTTPS/Let's Encrypt sobre un dominio) →
Spring Boot (jar o Docker) → PostgreSQL con backups automáticos. Ver
`docker-compose.yml` y `Dockerfile`. Para un servidor casero: IP pública o DDNS,
puertos abiertos y la máquina encendida 24/7.
