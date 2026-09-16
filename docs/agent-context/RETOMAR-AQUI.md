# Retomar aquí — 2026-09-16

Nota de traspaso, escrita al pasar el proyecto de la app de escritorio a
Claude Code en terminal. Sirve para arrancar una sesión nueva **sin releer
ninguna conversación anterior**.

Para el detalle de qué existe hoy: `repo-snapshot.md` (ojo: su propia cabecera
dice "última actualización 2026-09-12" — tampoco está al día con lo de abajo).
Para el porqué de cada decisión: `docs/decisions.md`. Esto es solo **dónde
estamos y qué sigue**.

> Actualizada 2026-09-15: la versión anterior (2026-09-09) daba por hecha solo
> la parte A/B-1 de la tarea 027 y citaba 194 tests. Desde entonces se
> cerraron B-2/B-2b (`trabajos`/`postulaciones`/`perfil` ya viven en
> `lib/funcionalidades/`, cero `final _x = Servicio();` dentro de un `State`),
> se aplicaron los tokens de tipografía/espaciado/radios de ADR-0016 (tareas
> 031-039) y los fundamentos de Lucide Icons de ADR-0017 (tarea 043), y el
> dueño hizo una auditoría de diseño completa (2026-09-13, ver
> `docs/agent-reports/audit-diseno-2026-09-13.md`) que abrió las tareas 050 y
> 051 (abajo).

## Dónde estamos

**2026-09-16 — todo el backlog de PRs y de trabajo local acumulado ya está
en `develop`.** Resumen de lo que pasó, en orden, todo verificado con `gh pr
view`/`git merge-base`/hashes de commit (no asumido) — el detalle completo,
con cada hash, vive en el historial de commits de `docs/agent-context/
RETOMAR-AQUI.md` de esta misma sesión, esto es solo el estado final:

1. **Tarea 027** cerrada (PR #7 `916c237` + fix de metadata PR #16 `005c0e9`).
2. **Cadena de 7 PRs apilados** (#8 tarea 030 + #9→#10→#12→#13→#14→#15,
   tareas 028/031-035) reapuntada a `develop` una por una y mergeada en
   orden. `develop` llegó hasta la tarea 035.
3. **Trabajo local nunca empujado** (036/037/039/041/043/049/050, en
   `feature/sistema-de-botones`) rebaseado sobre el `develop` del paso 2
   (limpio, sin conflictos; 3 merges locales vacíos descartados), pusheado,
   y abierto como **PR #17**.
4. Antes de mergear el #17, se dispararon **qa-agent** y **security-agent**
   en paralelo (cada uno en su propio worktree) a revisar 049 y 050
   específicamente — ambos dieron **APTO**. qa-agent cerró un hueco real de
   cobertura (3 componentes de botón sin aserción de "tap bloqueado durante
   `cargando`") y escribió 5 tests deterministas nuevos para sustituir la
   verificación visual de la 049 que no se pudo hacer (acceso a la VM de
   pruebas bloqueado por política de sandbox del agente, no por falta de
   intento). security-agent confirmó que ningún cambio de "solo estilo" traía
   lógica de negocio, auth o dinero escondida, y que nada tocó `backend/` ni
   `firestore.rules`. Sus dos commits se reconciliaron a mano (conflicto
   esperado: ambos añadían su sección al final de los mismos 2 archivos de
   tarea) y **PR #17 se mergeó** a `develop` (`691bdba`).

**`develop` ahora tiene integradas de verdad, en orden:** 027, 030, 028, 031,
032, 033, 034, 035, 036, 037, 039, 041, 043, 049, 050. `flutter analyze`: 12
issues, 0 errores (preexistentes). `flutter test`: **296/296**.

**Sin tocar, a propósito:** PR #5 (ya era ancestro de `develop`, sin
contenido nuevo) y PR #6 (`develop`→`master`, promoción de release — decisión
aparte, no se tocó).

**Pendiente, para la próxima sesión:**
- **Tarea 051** (barrido de contraste dorado) — implementada 2026-09-16 por
  `flutter-agent`, en `en-revision`, pendiente de mergear. 19 archivos
  tocados (`colorAcentoTexto` en los 8+2 sitios del alcance original más 8
  encontrados en el grep final; `chipThemeData` nuevo en `AppTema`). Ver
  `docs/agent-reports/051-barrido-contraste-dorado.md` — incluye una nota
  operativa sobre la rama (el worktree trabajó en
  `work/barrido-contraste-dorado`, mismo commit base que
  `feature/barrido-contraste-dorado`, porque esa ya estaba en uso en el
  checkout principal; hay que reconciliar antes del PR) y una lista de
  hallazgos de la misma familia de bug fuera del alcance literal de la tarea
  (fondos sólidos con texto blanco fijo, y `AppColores.dorado` en vez de
  `.acento` en `_badgeEstado`) para que el tech-lead decida si abre
  seguimiento. `flutter analyze`: 12 preexistentes, 0 nuevas. `flutter
  test`: 296/296.
- El hueco menor que dejó qa-agent sin cerrar: `hoja_filtros_trabajos.dart`
  (`expandido: false`) sin test de widget propio — no bloqueante, anotado
  para quien la retome.
- El worktree local `feature/fase2b2-cartera-calificacion` (+ `-impl`) trae
  mergeados los commits de la tarea 030 (ya redundante con `develop`, hay
  que reconciliarlo cuando se retome — rebasar sobre `develop` actual en vez
  de sobre `feature/tarjetas-y-websocket-jwt`, ya obsoleta). **Colisión de
  `id` ya resuelta (2026-09-16)**: su tarea se renumeró de 032 a
  `docs/agent-tasks/052-fase2b2-cartera-calificacion.md` en ambas ramas
  (commits `55d6aa9` y `deb164a`, locales, sin pushear todavía — nadie pidió
  subir esas ramas). El archivo también quedó actualizado para no seguir
  pidiendo rebasar sobre una rama obsoleta.
- Queda una carpeta residual en disco,
  `.claude/worktrees/agent-a379de9242506b7f8`, que git ya no trackea como
  worktree (se desregistró bien) pero no se pudo borrar del filesystem
  (permiso denegado, probablemente un archivo bloqueado) — inofensiva, se
  puede borrar a mano cuando el bloqueo se libere.

## Hallazgo cerrado: crecimiento de `detalle_trabajo_screen.dart`

La tarea 050 pedía explícitamente que migrar los botones de este archivo
**redujera** líneas, no las sumara. Pasó de 987 a 1226 líneas (+567/−331,
neto +236) — pero revisado el diff completo, el grueso no es negocio nuevo:
es re-formateo de `dart format` sobre código no tocado semánticamente
(llamadas con varios argumentos que ahora salen una por línea). **Decisión
tomada al cerrar la 050 (2026-09-15): se acepta como excepción justificada**
— revertir el formateo a mano dejaría el archivo con dos estilos mezclados,
peor que el crecimiento en sí. Queda recomendado (no abierto como tarea)
partir el archivo en subwidgets más adelante. Detalle completo en
`docs/agent-reports/050-sistema-de-botones.md`.

## Lo siguiente, en orden

1. **Tarea 051** (barrido de contraste dorado) — implementada, en
   `en-revision`, pendiente de mergear (ver arriba).
2. **Fase 2b-2, mitad fácil**: migrar `cartera_service` y
   `calificacion_service` a la API (ahora tarea **052**, ver worktree
   `feature/fase2b2-cartera-calificacion` — rebasar sobre `develop` antes de
   retomarla). Sin WebSocket, riesgo bajo.
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

**Funcional:** el tramo económico nunca se ha ejecutado en la app · editar una
publicación ya funciona (tareas 040/041, `PUT /api/trabajos/{id}`, solo
mientras sigue `ACTIVO`) pero seguir **borrando** o **reabrir un trabajo
cerrado** no existe · las reputaciones por rol llegan del backend y la app no
las lee · disputas sin motivo ni resolución en pantalla · evidencias sin
fotos · doble rol (012) sin plan · contratos (013) **en pausa por decisión
del dueño**.

**Proceso:** **no hay CI** — nadie corre los tests en un PR, y con ello el
techo de 300 líneas de ADR-0014 no lo vigila nadie · faltan tests de la
mayoría de pantallas (la DI de la 027 es lo que los hace posibles).
