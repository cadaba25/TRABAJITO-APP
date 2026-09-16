# Retomar aquí — 2026-09-15

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

`develop` tiene ya integradas 037/041/043 y los hotfixes puntuales de la
auditoría (tarea 049, commit `2fd5e1d`). La rama activa ahora mismo es
`feature/sistema-de-botones` (tarea 050, **cerrada a `en-revision` el
2026-09-15, todavía sin commitear/PR**): construyó los 6 componentes de botón
compartidos (`lib/compartido/widgets/boton_*.dart`) que pide la sección 6 de
`docs/design-system-frontend.md` y migró ~21 pantallas que reinventaban
`TextButton`/`ElevatedButton.styleFrom`/`IconButton` a mano. Verificado en
sesión: `grep` de esos cuatro patrones sobre `lib/funcionalidades/**` da cero
resultados, `flutter analyze` en 0 errores y **`flutter test` pasa 289/289**.
El crecimiento de `detalle_trabajo_screen.dart` (987→1226 líneas) quedó
resuelto como excepción justificada (100% reformateo de `dart format`, cero
negocio nuevo) — razonamiento completo en
`docs/agent-reports/050-sistema-de-botones.md`, que recomienda partir ese
archivo en subwidgets en una tarea futura (no se hizo aquí, fuera de
alcance). `docs/agent-tasks/050-sistema-de-botones.md` ya tiene
`estado: en-revision` y sus criterios de aceptación marcados. Falta: commit
en la rama, y que alguien (qa-agent / revisión humana) la lleve a `hecho` y
la mergee a `develop`.

La tarea 051 (barrido de contraste dorado) queda **desbloqueada** — la 050
llegó a `en-revision`. Ojo: pisa los mismos archivos que 050 tocó
(`login_screen.dart`, `bienvenida_registro_screen.dart`); si 050 todavía no
está mergeada a `develop`, arráncala sobre esta misma rama o sobre una rama
que parta de `feature/sistema-de-botones`, no desde `develop`, para no perder
esos cambios.

**`flutter analyze`: 12 issues, 0 errores** (todas deprecaciones/infos
preexistentes, ninguna en código nuevo de botones). **`flutter test`: 289
pasan.**

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

1. **Commitear y abrir PR de la tarea 050** (ya en `en-revision`, con
   reporte y criterios marcados — falta el commit en la rama y que
   qa-agent/revisión humana la lleve a `hecho` y la mergee a `develop`).
2. **Tarea 051** (barrido de contraste dorado) — ya desbloqueada.
3. **Fase 2b-2, mitad fácil**: migrar `cartera_service` y
   `calificacion_service` a la API. Sin WebSocket, riesgo bajo.
4. **Autenticar el WebSocket** (backend). Es **requisito** del paso 5.
5. **Migrar el chat** — la pieza más incierta de toda la migración: pasa de
   streams de Firestore a STOMP, que nunca se ha ejercitado. Al cerrarla
   desaparece Firestore de `lib/`, y se cierra **la única costura que queda
   entre las dos mitades**: `DetalleTrabajoScreen._reservarPago` todavía lee
   el acuerdo de pago del chat de Firestore para mandárselo a
   `POST /api/trabajos/{id}/reservar-pago`.
6. **Probar el tramo económico entero en el emulador.** Solo es posible tras
   el paso 5, y es lo que convierte la demo en "flujos completos".

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
