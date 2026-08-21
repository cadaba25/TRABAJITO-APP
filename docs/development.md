# Desarrollo local

## Flutter (frontend — lo único que corre en producción hoy)

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

Requiere el `google-services.json` de Android (ya está commiteado en
`android/app/`) y, si se agrega soporte iOS, un `GoogleService-Info.plist`
que **hoy no existe en el repo**.
### Estado conocido al 2026-08-20

- `flutter analyze`: sin errores en `lib/`. Hay warnings/info menores
  (mayormente `withOpacity` deprecado, `use_build_context_synchronously`,
  un import y un campo sin usar) — no bloquean, pero cualquier agente que
  toque uno de esos archivos debería limpiarlo de paso.
- `flutter test`: **pasa** (4 tests). El fallo histórico de
  `test/widget_test.dart` (referenciaba una clase `MyApp` inexistente) se
  arregló en la tarea 001 — ver `docs/agent-reports/001-fix-widget-test.md`.
## Backend (Spring Boot — no conectado a la app, ver `docs/architecture.md`)

Instrucciones completas en [`backend/README.md`](../backend/README.md).
Resumen para desarrollo (backend desde el IDE, BD en Docker):

```bash
cd backend
cp .env.example .env             # OBLIGATORIO antes de cualquier comando de compose
docker compose up -d db          # PostgreSQL en localhost:5432
SPRING_PROFILES_ACTIVE=dev mvn spring-boot:run
```

Swagger UI en `http://localhost:8080/swagger-ui.html`.

> Desde la tarea 005, `docker-compose.yml` declara `JWT_SECRET` como variable
> **requerida**. Si no existe `backend/.env`, compose falla de inmediato —
> incluso para `up -d db` — con un mensaje que dice qué falta. Es intencional:
> el backend no debe arrancar nunca firmando tokens con el secreto de ejemplo.

### Estado verificado al 2026-08-19 (entorno de desarrollo de este equipo)

- **Docker Desktop**: instalado y funcionando (motor corriendo, `docker
  compose` disponible). Requirió WSL2 (Windows 11 Home no tiene Hyper-V).
- **Maven 3.9.16**: no está disponible vía `winget` — se instaló manualmente
  desde el binario oficial (`dlcdn.apache.org`, checksum SHA-512 verificado)
  en `%USERPROFILE%\tools\apache-maven-3.9.16`, agregado al `PATH` de
  usuario (no de sistema — no requirió permisos de administrador).
- **`JAVA_HOME`**: apunta al JDK 21 que ya trae Android Studio instalado
  (`C:\Program Files\Android\Android Studio\jbr`), en vez de instalar un JDK
  aparte. El `pom.xml` declara Java 17 como versión de proyecto — un JDK 21
  compila igual (Maven usa el flag `--release` para el bytecode objetivo),
  así que no hace falta un JDK 17 exacto.
- **Confirmado con `mvn compile`: `BUILD SUCCESS`.** El backend sí compila.

Si alguien más monta el entorno desde cero, necesita: JDK 17+ en el `PATH`
(o `JAVA_HOME` apuntando a uno), Maven (no viene con `winget`, hay que
bajarlo del sitio oficial), y Docker Desktop con WSL2 en Windows Home. Todo
esto son variables de entorno de **usuario**, no cambios a nivel de sistema.

## Levantar el backend en un servidor (todo en Docker)

Verificado de punta a punta el **2026-08-20** en la VM de pruebas
(Ubuntu Server 26.04, Docker 29.1.3 + Compose 2.40.3) — ver
`docs/agent-reports/005-backend-en-servidor-ubuntu.md`. Es la primera vez que
este backend corre fuera de la máquina del desarrollador.

El servidor **no necesita Java ni Maven**: `backend/Dockerfile` es multi-etapa
y compila con Maven dentro de la imagen de build.

### Requisitos en el servidor
- Docker Engine + plugin Compose, usables sin `sudo` (usuario en el grupo
  `docker`).
- El repo clonado, y ~2 GB libres para imágenes y el caché de dependencias.

### Pasos

```bash
git clone <repo> ~/trabajito && cd ~/trabajito/backend

# 1) .env REAL (nunca se commitea; backend/.gitignore ya lo ignora)
cp .env.example .env
sed -i "s|^JWT_SECRET=.*|JWT_SECRET=$(openssl rand -base64 48)|" .env
sed -i "s|^DB_PASSWORD=.*|DB_PASSWORD=$(openssl rand -base64 24 | tr -dc 'A-Za-z0-9' | head -c 24)|" .env
chmod 600 .env

# 2) Construir la imagen del backend (la 1ª vez tarda varios minutos:
#    descarga la imagen de Maven y todas las dependencias)
docker compose build api

# 3) Levantar db + api
docker compose up -d

# 4) Comprobar: ambos deben quedar "healthy"
docker compose ps
docker compose logs -f api
```

`api` depende de `db` con `condition: service_healthy`, así que Spring Boot no
arranca hasta que PostgreSQL acepta conexiones. Ambos servicios tienen
healthcheck (`pg_isready` y `GET /v3/api-docs`), así que `docker compose ps`
distingue "arrancando" de "listo" sin adivinar.

### Comprobar que responde de verdad

```bash
# registro
curl -s -X POST http://localhost:8080/api/auth/registro \
  -H 'Content-Type: application/json' \
  -d '{"correo":"prueba@trabajito.local","password":"Prueba1234",
       "nombres":"Prueba","apellidos":"Servidor","rol":"TRABAJADOR"}'

# login → guarda el token
TOKEN=$(curl -s -X POST http://localhost:8080/api/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"correo":"prueba@trabajito.local","password":"Prueba1234"}' \
  | sed -E 's/.*"token":"([^"]+)".*/\1/')

# llamada autenticada
curl -s http://localhost:8080/api/auth/yo -H "Authorization: Bearer $TOKEN"
```

### Puertos y exposición

- `API_PORT_BIND` (por defecto `8080`) publica la API en **todas** las
  interfaces. En una VM NAT hace falta así para que el port forwarding del
  hipervisor funcione (el reenvío apunta a la IP de la guest, no a su
  loopback).
- `DB_PORT_BIND` (por defecto `127.0.0.1:5432`) deja PostgreSQL accesible
  solo desde el propio servidor. El backend la alcanza por la red interna de
  Docker (`db:5432`), no por el puerto publicado: **no hay razón para exponer
  la BD**.

### Operación

```bash
docker compose logs -f api            # seguir logs
docker compose restart api            # reiniciar solo el backend
docker compose down                   # parar (los volúmenes sobreviven)
docker compose down -v                # parar Y BORRAR los datos
git pull && docker compose build api && docker compose up -d   # desplegar cambios
```

Los datos viven en volúmenes de Docker (`trabajito_pgdata`,
`trabajito_uploads`), no en el árbol del repo: un `git pull` o un rebuild no
los toca.

### Limitaciones conocidas de este montaje

- Sin HTTPS ni reverse proxy: es una VM de pruebas, no producción.
- `JPA_DDL_AUTO=update` — Hibernate crea/ajusta el esquema. Antes de producción
  hay que migrar a Flyway/Liquibase y poner `validate` (pendiente conocido).
- Sin backups automáticos de PostgreSQL.
- Los archivos subidos van a disco local en un volumen, no a S3/MinIO.

## Checklist de "tarea terminada" (todo agente, antes de pedir revisión)

- [ ] El código relacionado con la tarea fue leído antes de modificarlo (no
      se asumió su comportamiento).
- [ ] `docs/agent-tasks/<tarea>.md` existe y refleja lo que realmente se hizo
      (no solo lo planeado).
- [ ] Si tocaste Flutter: `flutter analyze` no introduce errores nuevos,
      `flutter test` pasa (o el fallo preexistente de `widget_test.dart` fue
      justo lo que arreglaste).
- [ ] Si tocaste el backend: compila y los tests del módulo pasan, o se
      documentó explícitamente por qué no se pudo verificar.
- [ ] No se agregaron secretos, tokens ni credenciales al diff.
- [ ] No se borró funcionalidad existente sin autorización.
- [ ] Se creó/actualizó el reporte en `docs/agent-reports/<tarea>.md`.
- [ ] Si el cambio es arquitectónico (nuevo patrón, nueva dependencia grande,
      cambio de contrato de API o de modelo de datos), hay un ADR en
      `docs/decisions.md`.
