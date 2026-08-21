---
id: 005
tarea: docs/agent-tasks/005-backend-en-servidor-ubuntu.md
agente: "devops-agent"
fecha: 2026-08-20
---

## Objetivo (copiado de la tarea)

Primera fase del camino para dejar de depender de Firebase (ver ADR-0002,
todavía abierto). Antes de tocar una sola línea de Flutter, el backend
Spring Boot tiene que correr de verdad en un servidor tipo producción y
responder peticiones HTTP reales — no solo compilar y pasar tests unitarios
en la máquina de desarrollo.

## Cambios realizados

1. **`backend/docker-compose.yml`** — el servicio `api` pasó de estar comentado
   a estar activo y completo:
   - `DB_URL: jdbc:postgresql://db:5432/...` — dentro de la red de Docker el
     host de la BD es el **nombre del servicio**, no `localhost`.
   - `depends_on: db: condition: service_healthy` — Spring Boot no arranca
     hasta que PostgreSQL acepta conexiones.
   - `JWT_SECRET` como variable **requerida** (sintaxis `${VAR:?mensaje}`), sin
     valor por defecto.
   - `UPLOADS_DIR: /app/uploads`, coincidiendo con el volumen `trabajito_uploads`
     (antes el default `./uploads` resolvía a `/app/uploads` por accidente, al
     ser `WORKDIR /app`; ahora es explícito).
   - Healthcheck de `api` contra `GET /v3/api-docs` (ruta pública según
     `SecurityConfig`), con `start_period: 60s`.
   - Puertos parametrizados: `API_PORT_BIND` (default `8080`) y `DB_PORT_BIND`
     (default `127.0.0.1:5432`). `pgadmin` también pasó a `127.0.0.1:5050`.
2. **`backend/.env.example`** — documenta las variables nuevas
   (`API_PORT_BIND`, `DB_PORT_BIND`, `JPA_DDL_AUTO`, `SPRING_PROFILES_ACTIVE`) y
   aclara que `DB_URL` solo aplica fuera de Docker.
3. **`backend/README.md`** — nueva sección "Cómo correr TODO el stack en
   Docker" + tabla de las variables que consume compose.
4. **`docs/development.md`** — nueva sección "Levantar el backend en un
   servidor (todo en Docker)": pasos, verificación con `curl`, puertos,
   operación y limitaciones conocidas.
5. **`docs/agent-context/repo-snapshot.md`** — actualizado: el backend ya se
   ejecutó fuera de la máquina del desarrollador.

**No** se tocó `lib/**` ni `backend/src/main/java/**`. No hizo falta ningún
cambio de código de aplicación: `application.yml` ya leía todo por variables de
entorno con defaults de `localhost`, y basta con sobreescribirlas desde compose.

## Archivos modificados

- `backend/docker-compose.yml`
- `backend/.env.example`
- `backend/README.md`
- `docs/development.md`
- `docs/agent-context/repo-snapshot.md`
- `docs/agent-tasks/005-backend-en-servidor-ubuntu.md`
- `docs/agent-reports/005-backend-en-servidor-ubuntu.md` (este archivo)

Creado **solo en el servidor, nunca en Git**: `backend/.env`.

## Decisiones tomadas

**`JWT_SECRET` obligatorio en vez de tener default.** El default anterior
(`cambia-esto-en-produccion`) permitía arrancar el backend con un secreto que
cualquiera conoce — es decir, con tokens falsificables. Ahora compose se niega
a interpolar y aborta. **Efecto secundario deliberado:** sin `backend/.env`
falla incluso `docker compose up -d db` (compose valida el archivo entero, no
solo el servicio que se pide). Se aceptó porque `cp .env.example .env` ya era
el primer paso documentado, el error es explícito y accionable, y el modo de
fallo alternativo — arrancar en silencio con un secreto público — es peor.
Documentado en `backend/README.md` y `docs/development.md`.

**`db` y `pgadmin` dejan de publicarse en `0.0.0.0`.** El backend llega a la BD
por la red interna de Docker; el puerto publicado solo sirve para conectar un
IDE o `psql` desde el propio host. Publicarlo en todas las interfaces de un
servidor es exposición gratuita. Queda parametrizable por si alguien lo necesita.

**`API_PORT_BIND` sí queda en `0.0.0.0` por defecto.** En una VM con NAT, el
port forwarding del hipervisor apunta a la IP de la guest (10.0.2.15), no a su
loopback: bindear a `127.0.0.1` rompería el reenvío.

**No se agregó `spring-boot-starter-actuator`** para el healthcheck. Habría
sido una dependencia nueva en `pom.xml` (dominio de `backend-agent`) por algo
que `/v3/api-docs` ya resuelve: es público y solo responde cuando el contexto
de Spring terminó de arrancar.

## Problemas encontrados

Menos de los esperados. Lo relevante:

1. **`localhost` vs `db`** — el riesgo anticipado en la tarea. `application.yml`
   tiene `${DB_URL:jdbc:postgresql://localhost:5432/trabajito}`, que dentro del
   contenedor apuntaría al propio contenedor. Resuelto por configuración
   (compose fija `DB_URL`), sin tocar código Java.
2. **WARNs de Hibernate al arrancar** — `constraint "uq_calificacion_trabajo_autor"
   of relation "calificaciones" does not exist, skipping` y 3 similares. **No es
   un error**: con `ddl-auto=update` sobre una BD vacía, Hibernate intenta
   borrar constraints antes de crearlas. El esquema quedó correcto (11 tablas).
   Desaparecerán cuando se pase a Flyway/Liquibase.
3. **El build tarda** (~5 min la primera vez: imagen de Maven + dependencias).
   El build de Maven en sí fueron 14 s. Se corrió en background con el log en
   un archivo para no chocar con timeouts.
4. **`sudo` pide contraseña en la VM** — no hizo falta: Docker ya era usable sin
   `sudo` y no se instaló ningún paquete del sistema.

## Tests ejecutados

Todo lo de abajo se corrió **en el servidor** (`TrabajitoTestServer`, Ubuntu
Server 26.04) vía SSH, contra los contenedores reales.

### Build y arranque

```
$ docker compose build api
[INFO] BUILD SUCCESS    (Maven dentro de Docker, 14.1 s)
 => exporting to image  ->  trabajito-api:local  (365MB)

$ docker compose up -d
 Container trabajito-db  Healthy
 Container trabajito-api  Started

$ docker compose ps --format "{{.Service}} {{.Status}}"
api Up 28 seconds (healthy)
db Up 39 seconds (healthy)
```

### Logs de arranque (extracto real)

```
INFO ... o.s.b.w.embedded.tomcat.TomcatWebServer : Tomcat initialized with port 8080 (http)
INFO ... com.zaxxer.hikari.pool.HikariPool       : HikariPool-1 - Added connection org.postgresql.jdbc.PgConnection@2804b13f
INFO ... com.zaxxer.hikari.HikariDataSource      : HikariPool-1 - Start completed.
INFO ... j.LocalContainerEntityManagerFactoryBean: Initialized JPA EntityManagerFactory for persistence unit 'default'
INFO ... o.s.b.w.embedded.tomcat.TomcatWebServer : Tomcat started on port 8080 (http) with context path '/'
INFO ... com.trabajito.TrabajitoApplication      : Started TrabajitoApplication in 18.34 seconds (process running for 20.022)
```

El driver es `org.postgresql.jdbc.PgConnection` → **es PostgreSQL real, no H2**.

### Esquema creado por Hibernate

```
$ docker compose exec -T db psql -U trabajito -d trabajito -c "\dt"
 public | calificaciones      | table | trabajito
 public | chat_rooms          | table | trabajito
 public | evidencias          | table | trabajito
 public | mensajes            | table | trabajito
 public | movimientos_cartera | table | trabajito
 public | notificaciones      | table | trabajito
 public | postulaciones       | table | trabajito
 public | propuestas          | table | trabajito
 public | reportes            | table | trabajito
 public | trabajos            | table | trabajito
 public | usuarios            | table | trabajito
(11 rows)
```

### 1) POST /api/auth/registro → 200

Petición (cuerpo abreviado en una línea por legibilidad; se envió tal cual):

```
$ curl -s -i -X POST http://localhost:8080/api/auth/registro \
    -H "Content-Type: application/json" \
    -d {"correo":"prueba.devops@trabajito.local","password":"Prueba1234","nombres":"Prueba","apellidos":"DevOps","dni":"0801199012345","telefono":"99887766","rol":"TRABAJADOR","departamento":"Francisco Morazan","ciudad":"Tegucigalpa"}
```

Respuesta real:

```
HTTP/1.1 200
X-Content-Type-Options: nosniff
X-Frame-Options: DENY
Cache-Control: no-cache, no-store, max-age=0, must-revalidate
Content-Type: application/json

{"token":"eyJhbGciOiJIUzUxMiJ9.eyJzdWIiOiI1NTYzMGQ1MS1iYjgyLTRhYWItYmRhYi00OTIxNThjZDA2NTUiLCJjb3JyZW8iOiJwcnVlYmEuZGV2b3BzQHRyYWJhaml0by5sb2NhbCIsInJvbCI6IlRSQUJBSkFET1IiLCJpYXQiOjE3ODcyNzM5MzksImV4cCI6MTc4Nzg3ODczOX0.FAX-oq6LSklSypqC_bLjHX5BZwo7qBPyIsWlC8HpkU_PX1bSvFH3W7YNbkispnR9x2WYN5n02Du6fn7CMxfF5w",
 "usuario":{"id":"55630d51-bb82-4aab-bdab-492158cd0655",
 "correo":"prueba.devops@trabajito.local","nombres":"Prueba","apellidos":"DevOps",
 "nombreCompleto":"Prueba DevOps","dni":"0801199012345","telefono":"99887766",
 "rol":"TRABAJADOR","fotoUrl":null,"presentacion":null,
 "departamento":"Francisco Morazan","ciudad":"Tegucigalpa",
 "trabajosCompletados":0,"trabajosPublicados":0,"pagosConfirmados":0,
 "calificacionPromedio":0,"totalCalificaciones":0,"saldo":0,
 "tipoEmpleador":null,"nombreEmpresa":null,"sectorEmpresa":null,
 "tamanoEmpresa":null,"sitioWeb":null}}
```

(El token es de una cuenta de prueba desechable en una VM local; el
`JWT_SECRET` que lo firma nunca salió del servidor.)

### 2) POST /api/auth/login → 200

```
$ curl -s -X POST http://localhost:8080/api/auth/login \
    -H "Content-Type: application/json" \
    -d {"correo":"prueba.devops@trabajito.local","password":"Prueba1234"}

{"token":"eyJhbGciOiJIUzUxMiJ9.eyJzdWIiOiI1NTYzMGQ1MS1iYjgyLTRhYWItYmRhYi00OTIxNThjZDA2NTUiLCJjb3JyZW8iOiJwcnVlYmEuZGV2b3BzQHRyYWJhaml0by5sb2NhbCIsInJvbCI6IlRSQUJBSkFET1IiLCJpYXQiOjE3ODcyNzM5NTAsImV4cCI6MTc4Nzg3ODc1MH0.zrf6vX54t1SHtvHrsHFONvO3NAI-GRcBtzrOSGNYSSLeEcHb0guHobleOKL4HZ9PCb4vBy9dTMbQhMwXkaHwiQ",
 "usuario":{"id":"55630d51-bb82-4aab-bdab-492158cd0655", ... "saldo":0.00, ...}}
HTTP_CODE:200
```

Mismo `id` de usuario que en el registro → el dato se **persistió** en Postgres.

### 3) GET /api/auth/yo con el JWT → 200

```
$ curl -s http://localhost:8080/api/auth/yo -H "Authorization: Bearer $TOKEN"

{"id":"55630d51-bb82-4aab-bdab-492158cd0655","correo":"prueba.devops@trabajito.local",
 "nombres":"Prueba","apellidos":"DevOps","nombreCompleto":"Prueba DevOps",
 "dni":"0801199012345","telefono":"99887766","rol":"TRABAJADOR","fotoUrl":null,
 "presentacion":null,"departamento":"Francisco Morazan","ciudad":"Tegucigalpa",
 "trabajosCompletados":0,"trabajosPublicados":0,"pagosConfirmados":0,
 "calificacionPromedio":0.00,"totalCalificaciones":0,"saldo":0.00,
 "tipoEmpleador":null,"nombreEmpresa":null,"sectorEmpresa":null,
 "tamanoEmpresa":null,"sitioWeb":null}
HTTP_CODE:200
```

### 4) Casos negativos y una ruta protegida real

```
GET  /api/auth/yo   SIN token                      -> HTTP 401
GET  /api/trabajos  CON token                      -> HTTP 200
     {"content":[],"pageable":{"pageNumber":0,"pageSize":20,...},"totalElements":0,...}
POST /api/auth/login con password incorrecta       -> HTTP 401
     {"error":"Unauthorized","message":"Correo o contraseña incorrectos",
      "timestamp":"2026-08-21T00:59:10.930654094Z","status":401}
GET  /swagger-ui.html                              -> HTTP 302 (redirección normal de springdoc)
```

La cadena JWT completa funciona de punta a punta: emisión, validación y rechazo.

### 5) Contraseña hasheada en la BD

```
$ docker compose exec -T db psql -U trabajito -d trabajito \
    -c "SELECT correo, rol, left(password_hash,7) AS prefijo, length(password_hash) AS largo FROM usuarios;"

            correo             |    rol     | prefijo | largo
-------------------------------+------------+---------+-------
 prueba.devops@trabajito.local | TRABAJADOR | $2a$10$ |    60
```

BCrypt, 60 caracteres. La columna se llama `password_hash`; no existe ninguna
columna con la contraseña en claro.

### 6) Persistencia tras reinicio

```
$ docker compose restart api
api healthy tras restart
$ curl ... POST /api/auth/login                    -> HTTP 200
```

### 7) El secreto real está en uso (y el guardia funciona)

```
$ docker compose exec -T api sh -c "printf %s ${#JWT_SECRET}"
JWT_SECRET largo=64 ; es_placeholder=NO

$ docker compose --env-file /dev/null config -q
error while interpolating services.api.environment.JWT_SECRET: required
variable JWT_SECRET is missing a value: falta JWT_SECRET; copia .env.example
a .env y genera uno con openssl rand -base64 48
```

### 8) Volumen de uploads y recursos

```
$ docker compose exec -T api sh -c "ls -ld /app/uploads && touch /app/uploads/.probe"
drwxr-xr-x 2 root root 4096 Aug 21 00:58 /app/uploads
ESCRITURA_OK

$ docker stats --no-stream
trabajito-api CPU=10.18% MEM=280.9MiB / 4.806GiB
trabajito-db  CPU=0.11%  MEM=42.44MiB / 4.806GiB
```

Holgado para los 4.8 GB de la VM.

### El `.env` no se filtró

```
$ cd ~/trabajito && git status --short
(vacío)
```

### Lo que NO se probó (explícitamente)

- **WebSocket/STOMP (`/ws`)**: no se probó ninguna conexión de chat en tiempo
  real. Solo se vio arrancar el broker (`SimpleBrokerMessageHandler: Started.`).
- **Subida real de archivos** por `POST /api/archivos`: solo se comprobó que el
  volumen es escribible desde el contenedor.
- **El resto de módulos de negocio** (trabajos, postulaciones, pagos/escrow,
  calificaciones): solo se llamó `GET /api/trabajos` (lista vacía). No se
  ejecutó ningún flujo de negocio completo contra Postgres.
- **Acceso desde fuera de la VM**: el puerto 8080 no está reenviado en
  VirtualBox. Todo se probó con `curl` desde el propio servidor.
- **`mvn test`** no se re-ejecutó aquí; el build de la imagen usa `-DskipTests`
  a propósito. Los 22/22 de la tarea 003 siguen siendo la referencia.
- **Reinicio del host**: no se reinició la VM, así que `restart: unless-stopped`
  se validó solo a nivel de `docker compose restart`, no de arranque en frío.

## Pendientes

Candidatos a tareas nuevas:

1. **Reenviar el puerto 8080 en VirtualBox** (acción del usuario, no de un
   agente) para poder probar la API desde Windows. Requiere apagar la VM:
   `VBoxManage modifyvm "<nombre-vm>" --natpf1 "api,tcp,127.0.0.1,8080,,8080"`.
2. **Ejercitar un flujo de negocio completo** contra Postgres real (publicar
   trabajo → postularse → aceptar → escrow → completar → calificar). Es el
   siguiente paso lógico y es trabajo de `qa-agent` + `backend-agent`.
3. **Flyway/Liquibase** y `JPA_DDL_AUTO=validate`. Con `update` no hay control
   de versiones del esquema ni rollback. Ya estaba en los TODO del backend.
4. **Probar el WebSocket** del chat contra el servidor.
5. **Backups de PostgreSQL** (`pg_dump` programado + rotación).
6. **Reverse proxy con HTTPS** cuando esto deje de ser una VM de pruebas.
7. **Que el `.env` del servidor sobreviva** — hoy solo existe en esa VM. Si se
   recrea, se invalidan los tokens ya emitidos (cambia el `JWT_SECRET`). Definir
   dónde vive el secreto de verdad antes de cualquier despliegue serio.
8. **Decidir ADR-0002** (migrar o no de Firestore). Esta tarea aportó el dato
   que faltaba: el backend **sí** funciona en un servidor. La decisión sigue
   siendo del `tech-lead` + usuario, no de esta tarea.
