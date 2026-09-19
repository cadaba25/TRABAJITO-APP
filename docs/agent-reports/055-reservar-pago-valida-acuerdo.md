# 055 - reservar-pago valida el acuerdo del chat (backend-agent)

Rama `feature/055-reservar-pago-valida-acuerdo` (desde `feature/054-backend-chat-demo`). Sin push ni merge.

## Problema
`POST /api/trabajos/{id}/reservar-pago` retenia el monto que mandaba el cliente sin mirar
el chat: un cliente manipulado podia retener 1 L. en vez de lo acordado (o cualquier tiempo).

## Cambio
`TrabajoService.reservarPago` (ahora recibe `ChatRoomRepository`), en este orden:
1. Estado ASIGNADO y ya retenido -> devuelve el trabajo (idempotente, sin mirar el chat).
2. Monto invalido (<=0, >2 decimales) -> 400 (igual que antes).
3. Chat inexistente o sin `pagoAcordado && tiempoAcordado` -> **409** con mensaje claro.
4. Monto (normalizado a 2 decimales) != `pagoMonto` del chat -> **400**.
5. Tiempo != `tiempoValor` (trim, sin distinguir mayusculas) -> **400**.
6. Se retiene y se guarda el monto ya normalizado (sin cambios).
Sin cambios de contrato JSON ni de esquema. Documentado en `docs/api.md`.

## Tests
- `TrabajoServiceTest`: 5 nuevos (sin chat 409, solo pago acordado 409, monto manipulado 400,
  tiempo manipulado 400, idempotencia sin mirar el chat); los 5 tests existentes de
  reservarPago ahora preparan un chat acordado. 45 pasan.
- `IntegridadCarteraConcurrenteTest` (Testcontainers): `crearTrabajoAsignado` crea el chat
  acordado (1000 L. / "1 día"); "1 dia" -> "1 día". **Se omite sin Docker: 8 skipped, NO ejecutado.**
- `backend/scripts/prueba-flujo-negocio.sh`: helper `acordar_chat` antes de cada reservar-pago
  y 3 comprobaciones nuevas (409/400/400). **NO ejecutado** (requiere servidor levantado).

## Pregunta de producto abierta
El chat habla de pago **"por hora"** ("Pago acordado: L. 150.00 / hora"), pero
`reservar-pago` retiene ese monto como **total** del trabajo. Para la demo se trata como
total. Hay que decidir: (a) cambiar el texto del chat a "total", o (b) modelar tarifa x horas.

## Entorno
JDK 24: Mockito inline falla ("Could not modify all classes ... PagoService") en 59 tests
por entorno (sin cambios mios). Solo para verificar corri con
`-DargLine="-Dnet.bytebuddy.experimental=true"` (sin tocar pom.xml): 138 run, 0 fallos,
0 errores, 8 skipped (Docker).
