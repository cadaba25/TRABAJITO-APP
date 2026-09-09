# Retomar aquí — 2026-09-09

Nota de traspaso, escrita al pasar el proyecto de la app de escritorio a
Claude Code en terminal. Sirve para arrancar una sesión nueva **sin releer
ninguna conversación anterior**.

Para el detalle de qué existe hoy: `repo-snapshot.md`. Para el porqué de cada
decisión: `docs/decisions.md`. Esto es solo **dónde estamos y qué sigue**.

## Dónde estamos

`develop` está al día y subido (`772c5d9`). Contiene las partes **A** y **B-1**
de la tarea 027 (reestructuración de Flutter, ADR-0014):

- `lib/utils/constantes.dart` (605 líneas, 15 clases sin relación) → partido en 13.
- `lib/services/api/` → `lib/nucleo/api/`, con `api_client.dart` (649) partido
  en cuatro.
- `lib/widgets/` → `lib/compartido/widgets/`, con `custom_textfield.dart`
  (407 → 81) repartido en ocho.
- `lib/funcionalidades/autenticacion/` movida entera, con sus servicios
  **inyectados con `provider`** desde `lib/nucleo/inyeccion/proveedores.dart`.

**194 tests pasan. `flutter analyze`: 37 avisos, 0 errores.**

## Lo siguiente, en orden

1. **027 parte B-2** — mover `trabajos`, `postulaciones` y `perfil` a
   `lib/funcionalidades/`, y cerrar la anomalía que quedó abierta: **7
   pantallas siguen construyendo su propio `AuthService`**, así que hay dos
   instancias vivas. Al terminar no debe quedar ni un `final _x = Servicio();`
   dentro de un `State`. Detalle en `docs/agent-tasks/027-*.md`.
2. **Fase 2b-2, mitad fácil**: migrar `cartera_service` y
   `calificacion_service` a la API. Sin WebSocket, riesgo bajo.
3. **Autenticar el WebSocket** (backend). Es **requisito** del paso 4.
4. **Migrar el chat** — la pieza más incierta de toda la migración: pasa de
   streams de Firestore a STOMP, que nunca se ha ejercitado. Al cerrarla
   desaparece Firestore de `lib/`, y se cierra **la única costura que queda
   entre las dos mitades**: `DetalleTrabajoScreen._reservarPago` todavía lee
   el acuerdo de pago del chat de Firestore para mandárselo a
   `POST /api/trabajos/{id}/reservar-pago`.
5. **Probar el tramo económico entero en el emulador.** Solo es posible tras
   el paso 4, y es lo que convierte la demo en "flujos completos".

Después: fase 3 (borrar Firebase), CI, y recuperación de contraseña.

## Lo que hay que saber y no se deduce del código

- **El WebSocket `/ws` no valida el JWT en el CONNECT** (`TODO` en
  `WebSocketConfig`). Hoy no explota porque el chat sigue en Firestore.
  Taparlo **antes** de migrarlo, no después.
- **El feed pagina con `pagina`/`tamano`, no `page`/`size`.** Mandar los
  equivocados **no da error**: se ignoran y devuelven siempre la página 0.
  `ApiClient.obtenerPagina` manda los equivocados — hoy no rompe nada porque
  `listarFeed` va por otro camino, pero es una trampa puesta para el futuro.
- **`gestor_sesion.dart` tiene 314 líneas a propósito**, por encima del techo
  de ADR-0014. Partir `peticionConReintento` de `_renovar` separaría las dos
  mitades del **candado 2** (`refreshVisto` se lee en un método y se compara
  en el otro) y resucitaría un fallo real ya arreglado en la tarea 022. El
  techo de 300 es un disparador de revisión, no una regla ciega.
- **`ddl-auto=update` NO altera constraints existentes.** Causó dos incidentes
  reales. El apaño son componentes de arranque (`RestriccionSaldoNoNegativo`,
  `RestriccionEstadoTrabajo`).
- **Testcontainers puede saltarse en silencio**: `BUILD SUCCESS` con
  `Skipped: 6` parece verde y no probó nada. Míralo siempre.
- **Emulador: usar `Pixel_6`** (Android 13), no `Pixel_9` (Android 17 preview,
  da ANR). `flutter emulators --launch Pixel_6`.
- **Los tests unitarios con Mockito no detectaron ninguno de los 4 fallos
  graves de la tarea 006.** Para el backend, la prueba que vale es
  `backend/scripts/prueba-flujo-negocio.sh` (219 comprobaciones).

## Método que ha funcionado, y conviene no perder

**Verificar por cuenta propia lo que reporta un agente, no darlo por bueno.**
Ha cazado un `reclamar` que devolvía 500, un `BUG-007` falso de un script no
determinista, y una comprobación de privacidad mal hecha (mía). La forma más
barata y contundente: **romper el código a propósito y ver si el test se pone
rojo**. Si no se pone, el test no valía.

## Problemas abiertos, por gravedad

**Seguridad:** WebSocket sin autenticar · no existe cambiar ni recuperar
contraseña (017, regresión real frente a Firebase) · nadie puede llegar a
"cerrar sesión en todos los dispositivos" (025, el endpoint existe y no hay
botón) · el límite por IP cuenta a todos como uno detrás de Docker (016) · el
servidor de pruebas en `0.0.0.0` con `CORS_ORIGINS=*` (011).

**Funcional:** el tramo económico nunca se ha ejecutado en la app · no se
puede editar una publicación (`PUT /api/trabajos/{id}` no existe) · las
reputaciones por rol llegan del backend y la app no las lee · disputas sin
motivo ni resolución en pantalla · evidencias sin fotos · doble rol (012) sin
plan · contratos (013) **en pausa por decisión del dueño**.

**Proceso:** **no hay CI** — nadie corre los tests en un PR, y con ello el
techo de 300 líneas de ADR-0014 no lo vigila nadie · faltan tests de la
mayoría de pantallas (la DI de la 027 es lo que los hace posibles).
