---
id: 030
titulo: "Backend: endpoint mínimo de tarjetas + validar JWT en el CONNECT de WebSocket"
estado: en-progreso
agente: "backend-agent"
creada: 2026-09-10
rama: "feature/tarjetas-y-websocket-jwt"
---

## Objetivo

Dos huecos independientes del backend que bloquean la fase 2b-2 (migrar
`cartera_service` y `calificacion_service` de Firestore a la API) y la
migración del chat. **Son dos partes independientes — pueden ir en commits
separados, pero en la misma rama/PR por ser ambas backend-agent y pequeñas.**

## Parte A — Endpoint mínimo de tarjetas (para `cartera`)

**Contexto:** `lib/services/cartera_service.dart` (Firestore) guarda tarjetas
falsas (solo últimos 4 dígitos, sin PAN real — es un prototipo sin pasarela
de pago, documentado así en su propio docstring) en una subcolección por
usuario. El backend **no tiene ni entidad ni endpoint** para esto
(confirmado: `grep -ri tarjeta backend/src` no encuentra nada). Sin esto, la
fase 2b-2 tendría que **borrar** la función de "tarjetas guardadas" — pérdida
de funcionalidad que la regla 4 de `CLAUDE.md` no permite sin autorización
explícita, y aquí el costo de mantenerla es bajo.

**Qué construir**, siguiendo el patrón de módulos existente
(`com.trabajito.modules.pagos` ya tiene `MovimientoCartera`):

- Entidad `Tarjeta` (tabla `tarjetas`): `id` (UUID), `usuario_id` (FK a
  `usuarios`), `marca` (string corto: visa/mastercard/amex/otra — deducida
  en el cliente hoy, puedes recibirla ya calculada o recalcularla), `ultimos4`
  (4 chars), `titular`, `vencimiento` (string `MM/AA`, no valides fecha real:
  es prototipo), `creado_en`. **Nunca** un campo para el número completo ni
  el CVV — ni el cliente los manda hoy.
- `GET /api/cartera/tarjetas` — lista las tarjetas del usuario autenticado
  (nunca las de otro — sácalo del JWT, no de un parámetro).
- `POST /api/cartera/tarjetas` — agrega una. Igual validación mínima que ya
  hace el cliente (número ≥13 dígitos antes de quedarse con los últimos 4;
  puedes repetirla en el servidor, no confíes solo en el cliente).
- `DELETE /api/cartera/tarjetas/{id}` — solo si la tarjeta es del usuario
  autenticado (404, no 403, si es de otro — no reveles que existe, mismo
  criterio que el resto de la API).
- `ddl-auto=update` no pone `NOT NULL` en tablas con filas (ver
  `docs/agent-context/repo-snapshot.md` → "Flyway/Liquibase: propuesto, NO
  implementado"): usa el mismo patrón de columnas nullable + validación en
  capa de servicio que ya usa el resto del esquema.
- Tests: creación, listado (solo las propias), borrado (propio → 200, ajeno
  → 404), validación de número corto → 400. Sigue el patrón de
  `PerfilCompletoHttpTest` (MockMvc + H2) si hace falta capa HTTP, o
  unitario con Mockito si basta.
- Documenta en `docs/api.md` (sección `/api/cartera`).

## Parte B — Validar el JWT en el CONNECT de WebSocket

**Contexto:** `WebSocketConfig` tiene un `TODO`: el `CONNECT` a `/ws` **no
valida el JWT**. Documentado como riesgo abierto desde hace varias tareas
("Hoy no explota porque el chat sigue en Firestore. Taparlo **antes** de
migrarlo, no después" — `docs/agent-context/RETOMAR-AQUI.md`). Es
**requisito** para migrar el chat (tarea futura), y conviene cerrarlo ya
porque es puramente backend y no depende de que el chat exista.

**Qué hacer:**

1. Localiza `WebSocketConfig` (`grep -rn TODO backend/src --include=*.java`
   para encontrar el marcador exacto) y el punto donde se acepta el
   `CONNECT` STOMP.
2. Añade un `ChannelInterceptor` (o el mecanismo que ya use Spring en este
   proyecto para HTTP — reutiliza el mismo `JwtAuthFilter`/lógica de
   validación de token que ya existe, **no reescribas la validación de JWT
   desde cero**) que, en el frame `CONNECT`, exige el mismo access token
   (`Authorization: Bearer ...` o el header STOMP equivalente) y lo valida
   igual que una petición HTTP normal: firma, expiración, usuario existente
   y activo.
3. `CONNECT` sin token válido → rechazar la conexión (no deja pasar el
   frame). Un token válido pero expirado a mitad de sesión — deja eso para
   la tarea del chat (no lo resuelvas aquí si complica el alcance; anótalo
   como pendiente en el reporte si lo dejas fuera).
4. Test: conectar por STOMP sin token → rechazado. Con token válido →
   aceptado. Con token de un usuario `activo=false` → rechazado. Revisa si
   ya existe una forma de testear WebSocket en este backend (busca en
   `backend/src/test`); si no existe ninguna, un test de integración con
   un cliente STOMP de test es aceptable, documenta cómo correrlo.
5. **No implementes el resto del chat.** Esta tarea es solo cerrar el
   agujero de autenticación del transporte; los STOMP handlers de mensajería
   son la tarea de migración del chat, aparte.

## Módulos afectados

Solo `backend/`. No toca `lib/`, no cambia ningún contrato existente (Parte
A es aditiva; Parte B cierra un agujero, no cambia el comportamiento de nada
que ya funcione, porque el WebSocket no tiene consumidor real todavía).

## Criterios de aceptación

- [ ] `mvn -q compile` sin errores.
- [ ] `mvn test` verde (o el fallo explicado si algo no se puede correr en
      este entorno — dilo explícitamente, no afirmes "pasa" sin correrlo).
- [ ] Parte A: los 3 endpoints + tests + `docs/api.md` actualizado.
- [ ] Parte B: el `TODO` de `WebSocketConfig` desaparece, reemplazado por
      validación real; test que lo prueba en rojo/verde (sin el arreglo,
      falla).
- [ ] `docs/database.md` refleja la tabla `tarjetas` nueva.
- [ ] Reporte en `docs/agent-reports/030-*.md`.
- [ ] No hace falta desplegar en la VM para esta tarea (no hay consumidor
      real aún), pero dilo en el reporte si decides probarlo ahí.

## Notas del agente que la ejecuta

(Se va llenando mientras se trabaja.)
