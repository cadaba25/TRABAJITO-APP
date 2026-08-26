---
id: 011
titulo: "El servidor de pruebas expone la API en 0.0.0.0 con datos y cuentas de prueba"
estado: todo   # todo | en-progreso | en-revision | hecho | bloqueada
agente: "devops-agent"
creada: 2026-08-21
rama: ""
---

## Objetivo

Hallazgo lateral de la tarea 008 (security-agent), fuera de su alcance. La VM
Ubuntu de pruebas publica el backend en **todas** las interfaces y con una
configuración pensada para desarrollo:

```
$ docker compose ps --format '{{.Service}} {{.Ports}}'
api  0.0.0.0:8080->8080/tcp, [::]:8080->8080/tcp
db   127.0.0.1:5432->5432/tcp        <- esto sí está bien
```

En `backend/.env` del servidor: `API_PORT_BIND=8080` (es decir, `0.0.0.0`),
`CORS_ORIGINS=*`, `JPA_DDL_AUTO=update`.

Por qué importa, sumando lo que ya sabemos de las tareas 006 y 008:

- Todas las cuentas creadas por `backend/scripts/prueba-flujo-negocio.sh` y por
  las pruebas manuales usan la **misma contraseña conocida** (`Prueba1234`), y
  el script se ha corrido varias veces: hay decenas de cuentas válidas.
- El registro sigue siendo público (correctamente), así que cualquiera que
  alcance el puerto puede crear cuentas y ejercitar la API.
- La cartera permite recargar saldo sin pasarela real y **el dinero no cuadra**
  con concurrencia (tarea 007, sin arreglar).
- Hasta la tarea 008, cualquiera podía además auto-registrarse como `ADMIN`.
  Eso ya está cerrado, pero es la muestra de que ese puerto no debería estar
  abierto al mundo mientras el backend siga siendo un prototipo.

No es una vulnerabilidad del código: es configuración de despliegue. Y no
afecta a producción (la app usa Firebase; nadie consume este backend).

## Contexto relevante

- `backend/docker-compose.yml` y `backend/.env.example` — `API_PORT_BIND` ya
  soporta el formato `127.0.0.1:8080`, solo que en el servidor no se usa.
- `docs/agent-reports/005-backend-en-servidor-ubuntu.md` — cómo se desplegó.
- `docs/agent-reports/008-registro-publico-permite-rol-admin.md` — de dónde
  sale este hallazgo y el estado en que quedó la BD de pruebas.

## Criterios de aceptación

- [ ] Decidir (con el usuario/`tech-lead`) si esa VM debe ser alcanzable desde
      fuera. Si no: `API_PORT_BIND=127.0.0.1:8080` y acceso por túnel SSH.
      Si sí: al menos filtrar por IP en el firewall y acotar `CORS_ORIGINS`.
- [ ] Dejar escrito en `docs/development.md` qué configuración es la esperada
      en esa VM, para que no se vuelva a quedar en los valores de desarrollo.
- [ ] Decidir qué hacer con los datos de prueba acumulados (cuentas con
      contraseña conocida, saldos descuadrados a propósito por la tarea 006,
      5 cuentas `rol='ADMIN'` que la tarea 008 dejó **desactivadas** pero no
      borradas). Opción recomendada: recrear el volumen de la BD desde cero
      cuando las tareas 007 y 010 ya no necesiten esa evidencia.
- [ ] Comprobar el resultado desde fuera de la VM, no solo leer el `.env`.

## Notas del agente que la ejecuta

Ojo: no borres la BD antes de confirmar con quien lleva las tareas 007 y 010
que ya no necesitan los datos descuadrados como evidencia.
