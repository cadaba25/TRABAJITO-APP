---
id: 005
titulo: "Levantar el backend Spring Boot + PostgreSQL en el servidor Ubuntu de pruebas"
estado: en-progreso
agente: devops-agent
creada: 2026-08-20
rama: "chore/backend-en-servidor-ubuntu"
---

## Objetivo

Primera fase del camino para dejar de depender de Firebase (ver ADR-0002,
todavía abierto). Antes de tocar una sola línea de Flutter, el backend
Spring Boot tiene que correr de verdad en un servidor tipo producción y
responder peticiones HTTP reales — no solo compilar y pasar tests unitarios
en la máquina de desarrollo.

Hasta hoy, `backend/` nunca se ha ejecutado fuera del entorno local del
desarrollador. `mvn test` pasa (22/22, tarea 003), pero eso no prueba que la
aplicación arranque contra un PostgreSQL real, que Hibernate cree el esquema
correctamente, ni que los endpoints respondan.

## Contexto relevante

- `docs/architecture.md` — el backend está construido pero desconectado.
- `docs/decisions.md` ADR-0002 — la migración NO está decidida. Esta tarea
  **no** migra nada de Flutter; solo valida que el backend funciona en un
  servidor. La decisión de migrar se toma después, con esta información.
- `backend/README.md` — instrucciones de arranque y mapa de la API.
- `backend/docker-compose.yml` — hoy levanta **solo PostgreSQL**; el
  servicio del backend (`api`) está comentado, con la nota de que "para
  desarrollo es más cómodo correr el backend desde el IDE".
- `backend/Dockerfile` — build multi-etapa (Maven dentro de Docker), así que
  el servidor no necesita Java ni Maven instalados.

## Entorno de pruebas (verificado 2026-08-20)

| | |
|---|---|
| Host | VirtualBox sobre Windows, red NAT con port forwarding |
| SO | Ubuntu Server 26.04 LTS, hostname `TrabajitoTestServer` |
| Recursos | 4 vCPU · 4.8 GB RAM · 25 GB disco (20 GB libres) |
| Docker | 29.1.3 + Compose 2.40.3, servicio activo, usable sin `sudo` |
| Acceso | SSH por llave: `ssh -i ~/.ssh/trabajito_vm -p 2222 cadaba@127.0.0.1` |
| Repo | clonado en `~/trabajito` (rama `develop`) |
| Puertos | hoy solo el 2222→22 (SSH) está reenviado desde el host |

`sudo` en esa VM **pide contraseña** — ningún agente puede instalar paquetes
del sistema por su cuenta. Si hace falta algo con `sudo`, hay que pedírselo
al usuario con el comando exacto.

## Criterios de aceptación

- [ ] `docker compose up -d` en el servidor levanta PostgreSQL **y** el
      backend Spring Boot juntos (hoy el servicio `api` está comentado).
- [ ] La aplicación arranca sin errores contra PostgreSQL real (no H2) e
      Hibernate crea el esquema. Verificar en los logs del contenedor.
- [ ] Los endpoints responden de verdad. Como mínimo, probado con `curl`
      desde el propio servidor: registro (`POST /api/auth/registro`), login
      (`POST /api/auth/login`) y una llamada autenticada con el JWT obtenido
      (`GET /api/auth/yo`). Pegar las respuestas reales en el reporte.
- [ ] El `.env` real vive **solo en el servidor**, nunca en Git. `JWT_SECRET`
      generado de verdad (`openssl rand -base64 48`), no el placeholder de
      `.env.example`. Si se agrega alguna variable nueva, actualizar
      `backend/.env.example` en el mismo cambio.
- [ ] Documentado en `docs/development.md` (o en `backend/README.md`, donde
      corresponda sin duplicar) cómo levantar el stack en un servidor.
- [ ] Si algo no se pudo verificar, decirlo explícitamente en el reporte en
      vez de asumirlo.

## Fuera de alcance (NO hacer en esta tarea)

- Cualquier cambio en `lib/**` (Flutter). La migración del cliente es una
  decisión aparte, todavía no tomada (ADR-0002).
- Redis: no existe en el repo y no es necesario para validar el backend.
- HTTPS/Nginx/dominio real: esto es una VM de pruebas en NAT, no producción.
- Migraciones Flyway/Liquibase: pendiente conocido, tarea aparte.

## Notas del agente que la ejecuta

(vacío — tarea en progreso)
