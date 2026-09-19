# 058 - QA del flujo economico de la demo

Rama: `feature/058-qa-demo-flujo-economico` (desde `demo/integracion`). Fecha 2026-09-18.
Entorno: Windows, Docker 29.7, JDK 24 (Temurin), Maven 3.9.16, Flutter 3.41.9.

## PASADO (corrido por mi, resultado visto)

1. Backend real con `docker compose up -d --build` (PostgreSQL 16 + API), `backend/.env` local
   con JWT_SECRET de prueba (esta gitignorado, no se commitea).
2. `bash backend/scripts/prueba-flujo-negocio.sh` (con `jq` 1.7.1 instalado en `~/bin`, no estaba):
   **OK 222, fallos conocidos 0, fallos no esperados 0, RESULTADO: TODO VERDE.**
   Incluye las 3 comprobaciones nuevas de la tarea 055 (reservar sin acuerdo -> 409, monto distinto -> 400,
   tiempo distinto -> 400) y el flujo feliz completo con cuadre de dinero.
3. Backend `mvn -q test -Dmaven.compiler.proc=full -Dlombok.version=1.18.40 -DargLine="-Dnet.bytebuddy.experimental=true"`
   (JAVA_HOME=temurin-24.0.2): sumando `target/surefire-reports/*.txt`: **147 tests, 0 fallos, 0 errores, 0 skipped.**
   `IntegridadCarteraConcurrenteTest`: `Tests run: 8, Failures: 0, Errors: 0, Skipped: 0` (Testcontainers si corrio).
   Nota: al final Surefire imprime `[ERROR] Surefire is going to kill self fork JVM` (System.exit tardo 30 s);
   los reportes estan completos y sin fallos, pero es ruido a investigar.
4. Contrato por curl contra el servidor real (lo que asume el cliente Flutter), todo coincide:
   - `GET /api/chats/trabajo/{id}`: 200 para ambas partes, 404 para trabajo inexistente; campos
     `pagoMonto`, `pagoAcordado`, `pagoPropuestoPor`, `tiempoValor`, `tiempoAcordado` (bool), `fechaUltimoMensaje`.
   - `GET mensajes?desde=2026-09-19T01:57:54.593257Z` (microsegundos + Z): devuelve solo los posteriores
     (exclusivo, sin duplicar el ultimo). `desde=basura` -> 400. Mensaje vacio -> 400.
   - `GET /api/chats/no-leidos`: `{"total":2,"porChat":{id:2}}`; `POST /{id}/leido` (200) los pone en 0.
     Traer mensajes NO los marca leidos: el cliente debe llamar a `/leido`.
   - `GET/POST /api/cartera/tarjetas`: `{id,marca,ultimos4,titular,vencimiento}`; la lista es por usuario
     (el otro ve `[]`). El numero completo no vuelve.
   - `GET /api/calificaciones/usuario/{id}`: incluye `autorId`, `autorNombre`, `rolCalificado`, `estrellas`.
   - Flujo por API: proponer/aceptar pago y tiempo -> mensajes PROPUESTA_* y SISTEMA; reservar-pago 200;
     iniciar; evidencia; terminar; aceptar/liberar; ambas calificaciones 200; movimiento LIBERACION +300
     y saldo del trabajador 300.00.
5. `flutter test`: **350 pasan, All tests passed.**
6. `flutter analyze`: 8 issues, 0 errores, 1 warning (`proximamente` sin uso en
   `bienvenida_registro_screen.dart:139`), el resto `info` (withOpacity deprecado, etc.).
7. Emulador Pixel_6 arranco; `flutter run -d emulator-5554` compilo, instalo y abrio la app contra el backend
   real por 10.0.2.2. Captura: el feed muestra trabajos del backend (los que creo el script) y sesion abierta.

## FALLADO

- **Bug del script (corregido, commit en esta rama):** `prueba-flujo-negocio.sh` no se actualizo en dos secciones
  para la regla de la tarea 055: "doble gasto/concurrencia" (TC1/TC2) y "cancelacion tras la entrega" (T5)
  reservaban sin `acordar_chat`, por lo que daban 409 y arrastraban ~23 falsos fallos (reportaba REGRESION,
  incluso un BUG-007 falso). Se agrego `acordar_chat` y `tiempo` en esas reservas. Tras el arreglo: TODO VERDE.
  Primera corrida sin el arreglo: 197 OK / 2 conocidos / 23 no esperados.

## NO EJECUTADO / limites

- **Flujo completo por la UI del emulador NO se ejecuto.** Solo verifique arranque, sesion y feed. No hay
  automatizacion de UI (no existen tests `integration_test`), y guiar cada paso con `adb input` no era fiable.
  El flujo se probo por API y con los tests de widgets, no tocando la app de punta a punta. Sigue pendiente
  una pasada manual de: proponer/aceptar en el panel del chat, reservar-pago, evidencia, liberar, calificar, cartera.
- Sondeo del chat (ADR-0018) en la app real: no observado en vivo; solo el contrato del endpoint.
- STOMP/WebSocket (tarea 056/057): no probado aqui.
- Doble toque en botones de la UI: no reproducido en emulador (si en el backend: concurrencia de reservar/liberar
  cubierta por el script y por IntegridadCarteraConcurrenteTest).

## Observaciones menores (no corregidas, sin tarea abierta)

- El texto de sistema dice `Propuesta de pago: L. 300 / hora` aunque el monto es total del trabajo, no por hora.
  Confuso para el usuario; revisar el texto en el backend (`ChatService`) y el panel de negociacion.
- El `creadoEn` que devuelve `POST mensajes` trae nanosegundos (`...593257222Z`) y los GET microsegundos
  (`...593257Z`). Como el truncado es hacia abajo no se pierden mensajes con el cursor `desde`, pero si el
  cliente usa el del POST como cursor puede comparar un valor mayor al guardado: conviene usar siempre el del GET.

## Limpieza

`docker compose down -v` ejecutado (sin contenedores ni volumenes); emulador cerrado; `backend/.env` local
sigue en disco pero gitignorado; archivos generados de plugins (`linux/`, `macos/`, `windows/`) revertidos.
