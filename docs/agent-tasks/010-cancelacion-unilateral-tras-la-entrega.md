---
id: 010
titulo: "Reglas de cancelación y entrega: que ninguna de las dos partes pueda salir ganando"
estado: en-progreso
agente: "backend-agent"
creada: 2026-08-21
rama: "fix/reglas-cancelacion-y-entrega"
---

## Objetivo

`POST /api/trabajos/{id}/cancelar` **no valida el estado del trabajo**: solo
comprueba que el pago no esté ya liberado. El empleador puede cancelar cuando
el trabajador ya entregó (`ESPERANDO_CONFIRMACION`), recuperar el 100% del
pago en garantía y quedarse con el trabajo hecho.

Verificado contra el servidor real (tarea 006):

```
Empleador recarga 400 -> reserva 400 en escrow -> el trabajador inicia y
marca TERMINADO (estado = ESPERANDO_CONFIRMACION, entregado = true)

POST /api/trabajos/{id}/cancelar   (empleador)
-> HTTP 200
   {"estado":"ACTIVO","montoAcordado":0,"pagoRetenido":false,"pagoLiberado":false}

saldo del empleador : 400.00  (reembolso integro)
saldo del trabajador:   0.00
trabajos.trabajador_asignado_id : NULL   (se borra el vinculo)
```

Además `reabrir()` deja el trabajo `ACTIVO` como si nada hubiera pasado, pero
la postulación del trabajador **sigue `ACEPTADA`**: un trabajo `ACTIVO` sin
asignado con una postulación aceptada colgando.

## Reglas decididas por el dueño del proyecto (2026-08-25)

> **Principio rector, en sus palabras:** *"nunca ninguna de las dos partes
> debe tener la ventaja de irse ganando"*. Ante cualquier duda de diseño en
> esta tarea, esa es la regla que decide.

1. **Una vez iniciado el trabajo (`EN_PROGRESO` en adelante), NINGUNA de las
   dos partes puede cancelar.** No es solo el empleador: el trabajador
   tampoco. El dinero queda comprometido para ambos.
2. **El trabajador entrega con evidencias obligatorias.** Marcar terminado
   sin evidencia adjunta deja de ser posible.
3. **Tras la entrega, el empleador solo tiene dos caminos:**
   confirmar la entrega (libera el pago), o **reclamar un problema a
   soporte**. No puede cancelar y recuperar el dinero por su cuenta.
4. **Cancelación legítima (antes de iniciar):** el empleador **elige** si el
   trabajo queda cerrado (`CANCELADO`) o se reabre al feed para buscar otro
   trabajador.

### Sobre "reclamar un problema a soporte"

El objetivo mínimo es que **el dinero quede congelado y nadie pueda tocarlo
unilateralmente** hasta que soporte resuelva. Hoy ya existen los módulos
`reportes` y `admin`, y el enum `EstadoTrabajo` ya declara `CANCELADO` (que
nunca se usa).

Decide tú la forma concreta y documéntala, pero se espera algo así: un
endpoint que marque el trabajo en disputa, deje el escrow retenido (ni
liberado ni reembolsado), y que solo un `ADMIN` pueda resolver —liberando al
trabajador o reembolsando al empleador—. **No** construyas un sistema de
disputas completo con chat, plazos y apelaciones: eso es funcionalidad
grande y sería otra tarea. Lo que no puede quedar es dinero que una parte se
lleve sola.

## Contexto relevante

- `backend/src/main/java/com/trabajito/modules/trabajos/TrabajoService.java`
  — `cancelarContratacion()`, `reabrir()`, `marcarTerminado()` (hoy **no**
  exige evidencias), `solicitarCorreccion()` (ya existe y funciona bien),
  `aceptar()`.
- `backend/src/main/java/com/trabajito/common/enums/EstadoTrabajo.java` — la
  máquina de estados; `cancelar` la esquiva por completo.
- `backend/src/main/java/com/trabajito/modules/evidencias/` — evidencias ya
  modeladas, con endpoint `POST /api/trabajos/{id}/evidencias`.
- `backend/src/main/java/com/trabajito/modules/reportes/` y `.../admin/`.
- `rechazarAsignacion()` (trabajador) **sí** valida que no haya escrow y
  devuelve 409 con un mensaje correcto: es el modelo a seguir.
- `docs/decisions.md` ADR-0006 — el bloqueo pesimista de la tarea 007. Toda
  transición que toque dinero debe seguir usándolo y respetar el orden global
  de bloqueo.

## Criterios de aceptación

- [ ] ADR en `docs/decisions.md` (siguiente número libre) con la máquina de
      estados resultante: desde qué estado se puede cancelar, quién puede,
      y qué pasa con el escrow en cada caso.
- [ ] Cancelar en `EN_PROGRESO` o `ESPERANDO_CONFIRMACION` devuelve **409**,
      tanto para el empleador como para el trabajador. El escrow no se mueve.
- [ ] `marcarTerminado` exige al menos una evidencia asociada; sin evidencias
      devuelve 400/409 con un mensaje claro.
- [ ] Existe una vía para "reclamar un problema" que **congela** el dinero y
      que solo un `ADMIN` puede resolver (a favor de cualquiera de los dos).
- [ ] Al cancelar legítimamente, el empleador elige entre cerrar
      (`CANCELADO`) o reabrir (`ACTIVO`). Si reabre, las postulaciones
      asociadas quedan coherentes (no una `ACEPTADA` sobre un trabajo sin
      asignado).
- [ ] Tests que cubran cada regla nueva. Los de concurrencia/dinero siguen
      pasando (`IntegridadCarteraConcurrenteTest`, 6/6 — ver cómo correrlo en
      `docs/agent-reports/007-integridad-dinero-cartera-escrow.md`).
- [ ] `bash backend/scripts/prueba-flujo-negocio.sh` deja de reportar
      `BUG-010` y no introduce fallos nuevos. **Ojo:** el script asume el
      comportamiento viejo en varios sitios; actualízalo donde la regla haya
      cambiado a propósito.

## Fuera de alcance

- `lib/**` (Flutter). La UI de "entregar trabajo con evidencias" y el botón
  de reclamar a soporte se harán en una tarea aparte, cuando el contrato de
  la API esté cerrado.
- **Los contratos legales** (casilla de aceptación del trabajador y del
  contratista) — ver tarea `013-contratos-y-terminos-del-servicio.md`.
- Sistema de disputas completo (plazos, apelaciones, chat de disputa).
- Tarea 009 (errores 500) — va aparte, aunque toque archivos cercanos.

## Notas del agente que la ejecuta

(vacío — tarea en progreso)
