---
id: 006
tarea: docs/agent-tasks/006-flujos-negocio-contra-postgres.md
agente: "qa-agent"
fecha: 2026-08-21
---

## Objetivo (copiado de la tarea)

La tarea 005 dejó el backend corriendo en el servidor Ubuntu y validó que
**arranca y que la autenticación funciona** (registro/login/JWT → 200). Pero
**los flujos de negocio nunca se han ejercitado contra PostgreSQL real**:
publicar trabajo → postularse → aceptar postulación → reservar pago (escrow)
→ iniciar → terminar → aceptar y liberar el pago → calificar.

## Resumen ejecutivo

**El flujo feliz completo (pasos 1–10) funciona de punta a punta contra
PostgreSQL real y el dinero cuadra al céntimo... mientras las peticiones
lleguen de una en una.** En cuanto hay concurrencia o entradas raras, se
rompe:

| # | Fallo | Severidad | Tarea |
|---|---|---|---|
| 1 | **Se puede crear dinero de la nada**: L. 1000 recargados → L. 2000 pagados. Race condition sin bloqueo en cartera/escrow + redondeo sub-centavo | **Crítica** | [007](../agent-tasks/007-integridad-dinero-cartera-escrow.md) |
| 2 | **Cualquiera se registra con `rol: ADMIN`** y usa `/api/admin/**` (se suspendió la cuenta de otro usuario en la prueba) | **Crítica** | [008](../agent-tasks/008-registro-publico-permite-rol-admin.md) |
| 3 | El empleador **cancela después de la entrega**, recupera el escrow completo y el trabajador se queda sin pago ni asignación | Alta | [010](../agent-tasks/010-cancelacion-unilateral-tras-la-entrega.md) |
| 4 | 11 tipos de error de cliente devuelven **HTTP 500**, y el handler genérico **no loguea nada** | Media | [009](../agent-tasks/009-errores-no-mapeados-devuelven-500.md) |

Lo que sí quedó sólido: la máquina de estados secuencial, **toda** la
autorización que se probó (9 comprobaciones de "un tercero no puede…", todas
403), el escrow con saldo insuficiente, el reembolso por cancelación
temprana, las calificaciones bidireccionales y el promedio de reputación.

## Cambios realizados

Ninguno en código de aplicación. Esta tarea era de diagnóstico y así se
mantuvo: **no se arregló ningún fallo**, cada uno quedó como tarea nueva
(007, 008, 009, 010) con su reproducción exacta.

Lo único que se añade al repo es la prueba automatizada:
**`backend/scripts/prueba-flujo-negocio.sh`** — 102 comprobaciones contra un
backend en marcha. Verifica códigos HTTP **y** el dinero (saldo por API,
saldo en la BD, y el cuadre `usuarios.saldo == SUM(movimientos_cartera.monto)`).
Las comprobaciones que hoy fallan por un bug conocido están etiquetadas
(`BUG-007`…`BUG-010`) y **no** hacen fallar el script: sale 0 mientras solo
fallen esas, y 1 en cuanto aparezca un fallo nuevo. Así sirve de test de
regresión desde ya, y de verificación de los arreglos cuando se hagan.

## Archivos modificados

- `backend/scripts/prueba-flujo-negocio.sh` (nuevo)
- `docs/agent-tasks/007-integridad-dinero-cartera-escrow.md` (nueva)
- `docs/agent-tasks/008-registro-publico-permite-rol-admin.md` (nueva)
- `docs/agent-tasks/009-errores-no-mapeados-devuelven-500.md` (nueva)
- `docs/agent-tasks/010-cancelacion-unilateral-tras-la-entrega.md` (nueva)
- `docs/agent-tasks/006-flujos-negocio-contra-postgres.md` (estado + notas)
- `docs/agent-context/repo-snapshot.md`
- `docs/agent-reports/006-flujos-negocio-contra-postgres.md` (este archivo)

No se tocó `lib/**` ni `backend/src/**`.

## Decisiones tomadas

**No arreglar nada, ni siquiera lo trivial.** Añadir los `@Valid` que faltan
era un cambio de dos líneas, pero son 11 endpoints y cambia el contrato de la
API (500 → 400) documentado en `docs/api.md`. Va a la tarea 009 con el resto,
en vez de quedar como un cambio suelto sin registrar.

**El script marca los bugs conocidos en vez de omitirlos.** La alternativa
—comprobar el comportamiento actual (que da 500) para que "pase"— convertiría
el test en cómplice del bug. Aquí se comprueba el comportamiento **correcto**,
y cuando se arregle cada tarea la línea pasa sola de amarillo a verde.

**Las pruebas se hicieron contra la BD compartida del servidor, sin limpiarla.**
Cada ejecución crea usuarios con correo `qa.*.<timestamp>@trabajito.local`, así
que es re-ejecutable sin colisiones. Es un servidor de pruebas con datos
desechables; borrar filas habría destruido la evidencia de los descuadres.
**Consecuencia a tener en cuenta:** en esa BD hay ahora usuarios con el saldo
descuadrado a propósito y un usuario ADMIN de prueba
(`qa.escalada.*@trabajito.local`, `escalada*@trabajito.local`). Si alguien va
a hacer otras pruebas ahí, que lo sepa.

**No se probó el WebSocket/chat** (fuera de alcance según la tarea). Ver
"Pendientes".

## Problemas encontrados

### FALLO 1 (CRÍTICO) — se puede crear dinero de la nada · tarea 007

**1a. Doble gasto del saldo entre dos trabajos.** Un empleador con L. 1000
reserva L. 1000 en dos trabajos distintos a la vez.

Petición (dos en paralelo, una por trabajo):

```
POST /api/trabajos/{T1}/reservar-pago     POST /api/trabajos/{T2}/reservar-pago
Authorization: Bearer <token empleador>   Authorization: Bearer <token empleador>
{"monto":1000,"tiempo":"1 dia"}           {"monto":1000,"tiempo":"1 dia"}
```

Respuesta real: **`200` y `200`**. Estado en la BD:

```
     titulo     |  estado  | monto_acordado | pago_retenido
----------------+----------+----------------+---------------
 DobleGasto uno | ACORDADO |        1000.00 | t
 DobleGasto dos | ACORDADO |        1000.00 | t

   tipo    |  monto   | saldo_resultante
-----------+----------+------------------
 RECARGA   |  1000.00 |          1000.00
 RETENCION | -1000.00 |             0.00
 RETENCION | -1000.00 |             0.00     <- se retuvo 2000 teniendo 1000
```

Completando los dos flujos **de forma totalmente normal y secuencial**
(iniciar → terminar → aceptar en cada uno, ambos `200 COMPLETADO`):

```
                  correo                   |  saldo
-------------------------------------------+---------
 dobleg.emp....@trabajito.local            |    0.00
 dobleg.tra1...@trabajito.local            | 1000.00
 dobleg.tra2...@trabajito.local            | 1000.00

Recargado (unica entrada de dinero al sistema): 1000.00
Suma de saldos de los 3 usuarios:               2000.00
```

**Entró L. 1000, salieron L. 2000.** Esperado: la segunda reserva debía
devolver 400 "Saldo insuficiente".

**1b. Doble toque en el mismo trabajo (escrow).** 5 × `reservar-pago` en
paralelo → códigos `200 200 409 409 409`; el saldo baja 1000 pero se escriben
**dos** filas `RETENCION` de -1000 (`saldo_resultante` 9000.00 en las dos:
lost update de manual).

**1c. Doble toque al liberar el pago.** 5 × `POST /api/trabajos/{id}/aceptar`
en paralelo sobre un trabajo en `ESPERANDO_CONFIRMACION`:

```
codigos HTTP: 200 200 200 200 200        <- ninguno rechazado
saldo trabajador ANTES  = 0.00
saldo trabajador DESPUES= 1000.00
LIBERACIONES registradas (esperado 1): 4  filas, 4000.00 en total
pagos_confirmados del empleador (esperado 1): 2
```

El guardia `if (t.isPagoLiberado()) return t;` **sí** funciona en secuencial
(probado: un segundo `aceptar` posterior devuelve 200 sin mover dinero). Solo
falla en concurrencia. Es exactamente la clase de bug del histórico de
"botones que se quedan cargando por multi-toque".

**1d. El libro de movimientos deja de cuadrar.**

```
                 correo                 |  saldo  | suma_mov |   dif
----------------------------------------+---------+----------+----------
 conc.emp....@trabajito.local           | 9000.00 |  8000.00 |  1000.00
 conc.tra....@trabajito.local           | 1000.00 |  4000.00 | -3000.00
```

**1e. Redondeo sub-centavo (mismo origen, sin concurrencia).**

```
POST /api/trabajos/{id}/reservar-pago  {"monto":0.005}   -> 200
saldo del empleador antes:   100.00
saldo del empleador despues: 100.00   <- no se le cobro nada
trabajos.monto_acordado:       0.01   <- pero se guardo redondeado
(flujo completo) saldo del trabajador: +0.01
>> El empleador pago 0.00 y el trabajador recibio 0.01
```

Diagnóstico (código, no adivinado): `PagoService` hace
`u.setSaldo(u.getSaldo() ± monto)` sobre una entidad leída en la misma
transacción, sin `FOR UPDATE`, sin `@Version` y sin `UPDATE ... SET saldo =
saldo ± ?`. En `READ COMMITTED` dos transacciones leen el mismo saldo y la
última escritura gana. Y nada valida la escala del monto frente al
`numeric(12,2)` de la columna.

### FALLO 2 (CRÍTICO, seguridad) — registro público con rol ADMIN · tarea 008

```
POST /api/auth/registro
{"correo":"escalada2@trabajito.local","password":"Prueba1234",
 "nombres":"N","apellidos":"A","rol":"ADMIN"}

-> HTTP 200,  usuario.rol = "ADMIN"
   payload del JWT emitido:
   {"sub":"20c89649-...","correo":"escalada2@trabajito.local","rol":"ADMIN",
    "iat":1787356527,"exp":1787961327}

GET /api/admin/estadisticas          (ese token) -> 200 {"reportesAbiertos":0,"trabajos":7,"usuarios":17}
GET /api/admin/estadisticas          (token TRABAJADOR, control) -> 403
POST /api/admin/usuarios/{otro}/suspender (ese token) -> 200
     y la victima queda activo=false: su siguiente login ya no funciona
```

Esperado: el registro público no debería poder elegir `ADMIN`.

Comprobado también que el `DataSeeder` (`admin@trabajito.local / Admin1234`)
**no** se activó en el servidor: `SPRING_PROFILES_ACTIVE` está vacío y
`SELECT correo, rol FROM usuarios WHERE rol='ADMIN'` devolvía 0 filas antes de
esta prueba. El agujero es el registro, no el seeder.

### FALLO 3 (ALTA) — cancelar después de la entrega · tarea 010

```
Escrow de 400 puesto, el trabajador inicia y marca TERMINADO
(estado = ESPERANDO_CONFIRMACION)

POST /api/trabajos/{id}/cancelar   (empleador)
-> HTTP 200 {"estado":"ACTIVO","montoAcordado":0,"pagoRetenido":false,"pagoLiberado":false}

saldo del trabajador: 0.00   (entregó el trabajo y no cobró nada)
trabajos: estado=ACTIVO, trabajador_asignado_id=NULL
```

`cancelarContratacion()` solo comprueba `pagoLiberado`; no mira el estado.
Esperado: 409 o un flujo de disputa. Efecto lateral: tras cancelar, la
postulación del trabajador **sigue `ACEPTADA`** sobre un trabajo `ACTIVO` sin
asignado.

Lo que sí funciona bien: el reembolso legítimo (reserva 200 → saldo 0.00 →
cancelar → saldo 200.00, con `RETENCION` -200 y `REEMBOLSO` +200 en el libro),
y cancelar dos veces **no** reembolsa dos veces.

### FALLO 4 (MEDIA) — errores de cliente → 500, y sin logs · tarea 009

Once entradas devolvieron `500 {"error":"Internal Server Error","message":
"Error interno del servidor"}` en lugar de un 4xx (tabla completa en la tarea
009). Ejemplo:

```
POST /api/cartera/recargar  {}          -> 500   (esperado 400: monto obligatorio)
GET  /api/trabajos/no-es-uuid           -> 500   (esperado 400)
GET  /api/no-existe                     -> 500   (esperado 404)
GET  /api/cartera/recargar  (es POST)   -> 500   (esperado 405)
POST /api/auth/registro "rol":"SUPERJEFE" -> 500 (esperado 400)
POST /api/auth/login de un usuario suspendido -> 500 (esperado 401/403)
```

Y el log **vacío** tras provocarlos:

```
$ docker compose logs api --since 5m 2>&1 | wc -l
0
```

Causa: `@ExceptionHandler(Exception.class)` captura también las excepciones de
Spring MVC y no registra nada. Los `null` revientan porque **11 de los 15
`@RequestBody` de los controllers no llevan `@Valid`** (los `@NotNull` de los
records son código muerto). Los 4 que sí lo llevan responden correctamente:

```
POST /api/trabajos {"titulo":"   ","descripcion":"x"}
-> 400 {"message":"Datos inválidos","fields":{"titulo":"must not be blank"}}
```

También inconsistente: `GET /api/auth/yo` sin token → **401** con JSON, pero
`POST /api/cartera/recargar` sin token → **403 con cuerpo vacío**.

### Observaciones menores (sin tarea propia, van al `tech-lead`)

- **No hay ninguna comprobación de rol en los flujos de negocio.** Un
  `TRABAJADOR` publica trabajos (200) y un `EMPLEADOR` se postula como
  trabajador a un trabajo ajeno (200). Puede ser deliberado (una persona puede
  ser las dos cosas); es una decisión de producto, no la tomo yo. Anotado en
  la tarea 008.
- **Serialización inconsistente de `BigDecimal`**: la misma respuesta devuelve
  `"montoAcordado":1500` recién creada y `"montoAcordado":1500.00` al releerla
  de la BD. Un cliente que compare strings o use `==` se va a llevar una
  sorpresa.
- **`EstadoTrabajo.CANCELADO` no se usa nunca**: `reabrir()` devuelve el
  trabajo a `ACTIVO`. El enum documenta un estado que el código no produce.
- La restricción única de `postulaciones` y la de `chat_rooms` **sí** salvaron
  los datos en las pruebas de concurrencia (1 sola fila en ambos casos) — la
  BD está mejor defendida que la capa de servicio. Aun así el usuario ve un
  500 en vez de un 409.

## Tests ejecutados

Todo se corrió **en el servidor** (VM Ubuntu de la tarea 005) vía SSH, contra
los contenedores `api` + `db` reales, con `curl` y `psql`. El backend estaba
`Up (healthy)` en ambos servicios durante toda la sesión.

### Script versionado (lo re-ejecutable)

```
$ ssh ... 'COMPOSE_DIR=$HOME/trabajito/backend bash ~/qa/prueba-flujo-negocio.sh'
```

Resultado real (última ejecución completa, 2026-08-21):

```
==========================================================
FLUJO FELIZ (pasos 1-10)
==========================================================
  OK    POST /api/trabajos  (200)
  OK    estado inicial  (ACTIVO)
  OK    POST /api/postulaciones  (200)
  OK    estado de la postulacion  (PENDIENTE)
  OK    GET /api/postulaciones?trabajoId=  (200)
  OK    cantidad de postulantes  (1)
  OK    POST /api/postulaciones/{id}/aceptar  (200)
  OK    postulacion ACEPTADA  (ACEPTADA)
  OK    trabajo ASIGNADO  (ASIGNADO)
  OK    trabajador asignado  (8883f99d-2531-4c52-ab1b-a23d22002ec5)
  OK    POST /api/cartera/recargar  (200)
  OK    saldo tras recargar (API)  (2000.00)
  OK    saldo tras recargar (BD)  (2000.00)
  OK    POST /api/trabajos/{id}/reservar-pago  (200)
  OK    trabajo ACORDADO  (ACORDADO)
  OK    pagoRetenido  (true)
  OK    DINERO: saldo del empleador 2000-1500  (500.00)
  OK    movimiento RETENCION de -1500  (-1500.00)
  OK    POST /api/trabajos/{id}/iniciar  (200)
  OK    trabajo EN_PROGRESO  (EN_PROGRESO)
  OK    POST /api/trabajos/{id}/terminar  (200)
  OK    trabajo ESPERANDO_CONFIRMACION  (ESPERANDO_CONFIRMACION)
  OK    POST /api/trabajos/{id}/aceptar  (200)
  OK    trabajo COMPLETADO  (COMPLETADO)
  OK    pagoLiberado  (true)
  OK    DINERO: el trabajador recibio 1500  (1500.00)
  OK    DINERO: el empleador sigue en 500  (500.00)
  OK    movimiento LIBERACION de +1500  (1500.00)
  OK    el trabajador tiene exactamente 1 movimiento  (1)
  OK    empleador califica  (200)
  OK    trabajador califica  (200)
  OK    trabajo FINALIZADO tras ambas calificaciones  (FINALIZADO)
  OK    promedio del trabajador  (5.00)
  OK    promedio del empleador  (4.00)
  OK    trabajos_completados del trabajador  (1)
  OK    pagos_confirmados del empleador  (1)

CASOS BORDE - autorizacion
  OK    un tercero no ve los postulantes ajenos  (403)
  OK    un tercero no acepta postulaciones ajenas  (403)
  OK    un tercero no reserva el pago de un trabajo ajeno  (403)
  OK    el trabajador asignado tampoco reserva el pago  (403)
  OK    el empleador no puede iniciar el trabajo  (403)
  OK    un tercero no puede liberar el pago  (403)
  BUG   sin token no se puede recargar  esperado=401 obtenido=403  [BUG-009]
  OK    token invalido -> 401  (401)

CASOS BORDE - maquina de estados
  OK    postularse dos veces al mismo trabajo  (409)
  OK    postularse a tu propio trabajo  (400)
  OK    aceptar dos veces la misma postulacion  (409)
  OK    liberar el pago antes de la entrega  (409)
  OK    calificar un trabajo no completado  (409)
  OK    calificar dos veces el mismo trabajo  (409)
  OK    un ajeno califica un trabajo en el que no participo  (403)
  OK    iniciar un trabajo sin escrow  (409)
  OK    calificar un trabajo inexistente  (404)
  OK    calificar con 0 estrellas  (400)
  OK    calificar con 9 estrellas  (400)

CASOS BORDE - dinero
  OK    reservar pago con saldo insuficiente  (400)
  OK      ...y el saldo sigue en 0  (0.00)
  OK      ...y el trabajo NO quedo ACORDADO  (ASIGNADO)
  OK    recargar monto negativo  (400)
  OK    recargar monto cero  (400)
  BUG   recargar sin campo monto  esperado=400 obtenido=500  [BUG-009]
  BUG   recargar monto como texto  esperado=400 obtenido=500  [BUG-009]
  BUG   recargar monto desbordado  esperado=400 obtenido=500  [BUG-009]
  OK      ...el saldo sigue intacto  (0.00)
  OK    reservar pago con monto negativo  (400)
  OK    cancelar un trabajo con el pago ya liberado  (409)
  OK    saldo tras reservar los 200  (0.00)
  OK    el trabajador no puede rechazar con el escrow puesto  (409)
  OK    el empleador cancela  (200)
  OK    DINERO: reembolso completo de los 200  (200.00)
  OK    el trabajo vuelve a ACTIVO  (ACTIVO)
  BUG   reservar 0.005 debe cobrarle algo al empleador  esperado=no obtenido=si  [BUG-007]
  BUG   el trabajador no debe recibir mas de lo que pago el empleador
        esperado=1500.00 obtenido=1500.01  [BUG-007]

CASOS BORDE - doble toque y concurrencia
  BUG   no se puede retener mas de lo que hay en la cartera
        esperado=1000.00 obtenido=2000.00  [BUG-007]
  OK      ...saldo tras las dos reservas  (0.00)
  BUG   una sola LIBERACION registrada  esperado=1 obtenido=5  [BUG-007]
  BUG   el doble toque no produce 500  esperado=0 obtenido=4  [BUG-007]
  OK    solo queda 1 postulacion en la BD  (1)

CASOS BORDE - cancelacion tras la entrega
  BUG   el empleador NO deberia cancelar una entrega ya hecha
        esperado=409 obtenido=200  [BUG-010]

CASOS BORDE - seguridad
  BUG   el registro publico NO deberia crear un ADMIN  esperado= obtenido=ADMIN  [BUG-008]
  BUG   un ADMIN auto-registrado NO deberia entrar al panel
        esperado=403 obtenido=200  [BUG-008]
  OK    un usuario normal no entra al panel admin  (403)

CASOS BORDE - mapeo de errores HTTP
  BUG   ruta inexistente -> 404  esperado=404 obtenido=500  [BUG-009]
  BUG   metodo no permitido -> 405  esperado=405 obtenido=500  [BUG-009]
  BUG   JSON malformado -> 400  esperado=400 obtenido=500  [BUG-009]
  BUG   UUID invalido en la ruta -> 400  esperado=400 obtenido=500  [BUG-009]
  BUG   enum invalido en el registro -> 400  esperado=400 obtenido=500  [BUG-009]
  BUG   postular con trabajoId nulo -> 400  esperado=400 obtenido=500  [BUG-009]
  BUG   calificar con trabajoId nulo -> 400  esperado=400 obtenido=500  [BUG-009]
  OK    titulo vacio -> 400  (400)
  OK    titulo de 80 caracteres -> 400  (400)
  OK    correo duplicado -> 409  (409)
  OK    password corta -> 400  (400)

CUADRE CONTABLE (saldo == suma de movimientos_cartera)
  OK    cuadre de empleador  (500.00)
  BUG   cuadre de trabajador  esperado=3500.01 obtenido=6500.01  [BUG-007]
  OK    cuadre de tercero  (0.00)
  OK    cuadre de pobre  (200.00)
  BUG   cuadre de redondeo  esperado=100.00 obtenido=99.99  [BUG-007]
  BUG   cuadre de concurrente  esperado=0.00 obtenido=-1000.00  [BUG-007]
  OK    cuadre de abusivo  (400.00)

RESUMEN
  OK:                  80
  Fallos conocidos:    22  (bugs diagnosticados, con tarea abierta)
  Fallos NO esperados: 0
RESULTADO: OK, con los fallos conocidos todavia presentes
EXIT=0
```

### Contabilidad del flujo feliz, paso a paso (verificada con psql)

Empleador `emp.qa.1787356128@trabajito.local`, trabajador
`tra.qa.1787356128@trabajito.local`, trabajo "Instalar 3 lamparas LED".

| Momento | Saldo empleador | Saldo trabajador | Comprobado con |
|---|---|---|---|
| Tras registrarse | 0.00 | 0.00 | `SELECT saldo FROM usuarios` |
| Intento de escrow sin saldo (400) | 0.00 | 0.00 | psql — **nada se movió** |
| Recarga de L. 2000 | 2000.00 | 0.00 | API + psql |
| Reservar L. 1500 (escrow) | **500.00** | 0.00 | API + psql |
| Liberar el pago | 500.00 | **1500.00** | API + psql |

Libro de movimientos al final (psql, tabla real):

```
              correo               |    tipo    |  monto   | saldo_resultante
-----------------------------------+------------+----------+------------------
 emp.qa.1787356128@trabajito.local | RECARGA    |  2000.00 |          2000.00
 emp.qa.1787356128@trabajito.local | RETENCION  | -1500.00 |           500.00
 tra.qa.1787356128@trabajito.local | LIBERACION |  1500.00 |          1500.00
```

Cuadre (`usuarios.saldo` vs `SUM(movimientos_cartera.monto)`):

```
              correo               | saldo_usuarios | suma_movimientos | diferencia
-----------------------------------+----------------+------------------+------------
 emp.qa.1787356128@trabajito.local |         500.00 |           500.00 |       0.00
 tra.qa.1787356128@trabajito.local |        1500.00 |          1500.00 |       0.00
```

Reputación y métricas tras calificar (5★ del empleador, 4★ del trabajador):

```
              correo               | calificacion_promedio | total_calificaciones | trabajos_completados | pagos_confirmados | trabajos_publicados
-----------------------------------+-----------------------+----------------------+----------------------+-------------------+---------------------
 emp.qa.1787356128@trabajito.local |                  4.00 |                    1 |                    0 |                 1 |                   1
 tra.qa.1787356128@trabajito.local |                  5.00 |                    1 |                    1 |                 0 |                   0
```

Trabajo en `FINALIZADO` con `calificadoPorEmpleador=true` y
`calificadoPorTrabajador=true`. **El dinero cuadra al céntimo en el camino
secuencial.**

### Respuestas reales de referencia (extractos)

Paso 6, reservar pago:

```
$ curl -s -X POST http://localhost:8080/api/trabajos/c3adc761-.../reservar-pago \
   -H "Content-Type: application/json" -H "Authorization: Bearer <emp>" \
   -d '{"monto":1500,"tiempo":"2 dias"}'
HTTP 200
{"id":"c3adc761-0b4b-4444-9663-7b4db13a295c","estado":"ACORDADO",
 "trabajadorAsignadoId":"f059fd04-aa5a-4ae3-825f-223fe0347ea9",
 "montoAcordado":1500,"tiempoAcordado":"2 dias",
 "fechaAcuerdo":"2026-08-21T23:49:56.571674293Z","pagoRetenido":true,
 "entregado":false,"pagoLiberado":false, ...}
```

Paso 9, liberar el pago:

```
HTTP 200
{"estado":"COMPLETADO","montoAcordado":1500.00,"pagoRetenido":true,
 "entregado":true,"pagoLiberado":true, ...}
```

Paso 10, calificar:

```
HTTP 200
{"id":"64cab3e3-...","trabajoId":"c3adc761-...","autorId":"a3eef441-...",
 "receptorId":"f059fd04-...","estrellas":5,"comentario":"Excelente trabajo, muy puntual."}
```

Casos borde de autorización (todos con el mensaje correcto en español):

```
GET  /api/postulaciones?trabajoId=...  (token del trabajador)
-> 403 {"error":"Forbidden","message":"No eres el dueño de este trabajo"}

POST /api/trabajos/{id}/iniciar        (token del empleador)
-> 403 {"error":"Forbidden","message":"No estás asignado a este trabajo"}

POST /api/calificaciones               (token de un tercero)
-> 403 {"error":"Forbidden","message":"No participaste en este trabajo"}

POST /api/trabajos/{id}/reservar-pago  (saldo 0)
-> 400 {"error":"Bad Request","message":"Saldo insuficiente. Recarga tu cartera."}
```

### Lo que NO se probó (explícito)

- **WebSocket/STOMP (`/ws`) y el chat en tiempo real.** Fuera de alcance por
  la propia tarea. Para probarlo bien haría falta un cliente STOMP (p. ej.
  `websocat` + tramas STOMP a mano, o un script Python con `stomp.py`)
  suscrito a `/topic/chats/{id}`, y comprobar que `ChatService.enviar()`
  empuja el mensaje. Sí se verificó indirectamente que
  `chatService.crearParaTrabajo()` se ejecuta al aceptar una postulación: se
  crea 1 fila en `chat_rooms` (y su índice único evitó la duplicación en la
  prueba de concurrencia).
- **Subida de archivos** (`POST /api/archivos`), evidencias, reportes,
  notificaciones y el resto de `/api/admin/**` más allá de `estadisticas` y
  `suspender`.
- **`PUT /api/usuarios/perfil`** — no se comprobó si permite cambiarse el rol
  a uno mismo (anotado como criterio en la tarea 008).
- **Expiración del JWT** (el token dura 7 días según el claim `exp`; no se
  esperó a que caducara) ni refresh tokens.
- **Carga / rendimiento.** Las pruebas de concurrencia fueron 2–5 peticiones
  simultáneas, suficientes para exponer la race condition, no para medir nada.
- **`mvn test`** no se re-ejecutó: esta tarea era de integración contra el
  servidor y no se tocó código Java. Los 22/22 de la tarea 003 siguen siendo
  la referencia, y **no detectan ninguno de los 4 fallos de arriba** (son
  unitarios con Mockito: sin BD, sin transacciones, sin HTTP).
- **Flutter** (`flutter test` / `flutter analyze`): fuera de alcance, no se
  tocó `lib/**`.

## Pendientes

1. **Tareas 007, 008, 009 y 010** — creadas, en estado `todo`. Prioridad
   sugerida: 007 y 008 primero (dinero y escalada de privilegios), 010
   después (necesita una decisión de producto antes que código), 009 al final.
2. **Decidir si los roles se aplican en los flujos de negocio** (hoy no se
   aplica ninguno). Es del `tech-lead`.
3. **Probar el WebSocket del chat** contra el servidor — sigue pendiente desde
   la tarea 005.
4. **CI que corra `backend/scripts/prueba-flujo-negocio.sh`** contra un stack
   levantado con `docker compose`. Hoy el script solo corre a mano en el
   servidor; como test de regresión automático sería mucho más útil. Requiere
   el pipeline de CI que aún no existe.
5. **Limpiar la BD del servidor** cuando se arreglen 007/008: quedaron
   usuarios con el saldo descuadrado a propósito y cuentas ADMIN de prueba.
6. **Testcontainers** para el backend: la tarea 003 dejó anotado "si en el
   futuro se necesita probar queries JPA reales, evaluar Testcontainers en ese
   momento". Ese momento llegó — la tarea 007 no se puede verificar con
   Mockito.
