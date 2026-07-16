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
| `usuarios` | perfil, ranking, baja de cuenta |
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
cp .env.example .env          # ajusta credenciales/secreto si quieres
docker compose up -d db        # PostgreSQL en localhost:5432
```

### 3. Correr el backend
```bash
# con perfil dev (crea una cuenta admin de prueba):
SPRING_PROFILES_ACTIVE=dev mvn spring-boot:run
```
o desde el IDE ejecutando `TrabajitoApplication`.

### 4. Probar
- Swagger UI: http://localhost:8080/swagger-ui.html
- Admin de prueba (solo perfil `dev`): `admin@trabajito.local` / `Admin1234`

Flujo típico en Swagger:
1. `POST /api/auth/registro` → copia el `token`.
2. Botón **Authorize** (arriba a la derecha) → pega el token.
3. Ya puedes llamar al resto de endpoints autenticado.

## Mapa de la API

### Autenticación — `/api/auth` (público)
| Método | Ruta | Descripción |
|--------|------|-------------|
| POST | `/registro` | crea cuenta, devuelve token + usuario |
| POST | `/login` | inicia sesión, devuelve token + usuario |
| GET | `/yo` | usuario autenticado (valida el token) |

### Usuarios — `/api/usuarios`
| GET `/{id}` | perfil público |
| PUT `/me` | editar perfil propio |
| GET `/ranking` | ranking de trabajadores |
| DELETE `/me` | baja de la cuenta propia |

### Trabajos — `/api/trabajos`
| GET `/` | feed paginado (`?pagina=0&tamano=20`) |
| GET `/{id}` | detalle |
| GET `/mios` | mis publicaciones (empleador) |
| GET `/asignados` | trabajos asignados a mí (trabajador) |
| POST `/` | publicar |
| POST `/{id}/reservar-pago` | confirmar acuerdo + depositar en garantía |
| POST `/{id}/iniciar` | trabajador inicia |
| POST `/{id}/terminar` | trabajador marca terminado |
| POST `/{id}/solicitar-correccion` | empleador pide correcciones |
| POST `/{id}/aceptar` | empleador acepta y libera el pago |
| POST `/{id}/cancelar` | empleador cancela (reembolso) |
| POST `/{id}/rechazar` | trabajador rechaza (sin escrow) |

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
| GET `/usuario/{id}` | reseñas recibidas |

### Notificaciones — `/api/notificaciones`
| GET `/` · `/no-leidas` · POST `/{id}/leida` | in-app |

### Reportes — `/api/reportes` · Admin — `/api/admin` (rol ADMIN)
| POST `/api/reportes` | crear reporte |
| GET `/api/admin/estadisticas` · `/reportes` | panel |
| POST `/api/admin/reportes/{id}/resolver` | resolver reporte |
| POST `/api/admin/usuarios/{id}/suspender` · `/reactivar` | moderación |

### Archivos — `/api/archivos`
| POST `/` (multipart `archivo`) | sube y devuelve `{ "url": "/uploads/..." }` |

## Seguridad

- Contraseñas con **BCrypt** (nunca en texto plano).
- **JWT** en cada request: header `Authorization: Bearer <token>`.
- Autorización por rol (`@EnableMethodSecurity`) y por dueño/participante en los
  servicios. **El cliente nunca decide permisos.**
- CORS configurable por `CORS_ORIGINS`.

## Pendientes (TODO)

- Validar el JWT en el **handshake/CONNECT del WebSocket** (hoy el envío por REST
  ya valida; el socket solo difunde).
- **Pasarela de pago real** (Tigo Money / tarjeta) en el módulo `pagos`; hoy la
  recarga es un prototipo.
- **FCM** para push real (`NotificacionService.enviarPush`).
- **Flyway/Liquibase** para migraciones (hoy `ddl-auto=update` para desarrollo).
- **Almacenamiento de objetos** (S3/MinIO) en vez de disco local para archivos.
- Auto-liberación del escrow por tiempo, y flujo de disputa que congela fondos.

## Producción (resumen)

Ubuntu + Nginx (reverse proxy con HTTPS/Let's Encrypt sobre un dominio) →
Spring Boot (jar o Docker) → PostgreSQL con backups automáticos. Ver
`docker-compose.yml` y `Dockerfile`. Para un servidor casero: IP pública o DDNS,
puertos abiertos y la máquina encendida 24/7.
