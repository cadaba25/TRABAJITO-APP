---
id: 013
titulo: "Aceptación de contrato: trabajador y contratista al cerrar un acuerdo"
estado: en-pausa
agente: ""   # requiere plan del tech-lead: Flutter + backend + texto legal
creada: 2026-08-25
rama: ""
---

## Origen

Requisito del dueño del proyecto (2026-08-25), planteado mientras se decidían
las reglas de cancelación de la tarea 010:

> *"cuando se acepta el trabajo el trabajador debe aver una casilla de
> aceptar contrato temporal con un link que redirija al contrato legal que
> haremos despues, tambien un contrato de parte del contratista, donde se
> acuerden terminos y condiciones especificas de como trabaja la
> aplicacion"*

## Objetivo

Que ambas partes acepten explícitamente un contrato antes de que el trabajo
arranque, y que esa aceptación quede **registrada** (quién, cuándo, qué
versión del texto).

- **Trabajador:** casilla de "acepto el contrato temporal", con enlace al
  texto legal completo.
- **Contratista:** su propio contrato, con los términos y condiciones de
  cómo funciona la aplicación.

## Bloqueante

**El texto legal todavía no existe** — el dueño indicó que se redactará
después. Sin ese texto no se puede cerrar esta tarea, pero sí se puede
diseñar el modelo de datos y la mecánica, dejando el contenido como
marcador de posición.

## Preguntas a resolver antes de implementar

1. ¿En qué momento exacto se acepta? La tarea 010 fija la máquina de estados
   `ASIGNADO → ACORDADO → EN_PROGRESO`. Lo natural es exigirlo para pasar a
   `ACORDADO` (cuando se reserva el pago), pero hay que confirmarlo.
2. ¿La aceptación es **por trabajo** (cada contrato firmado aparte) o **una
   vez por usuario** (al registrarse)? Legalmente suelen ser cosas distintas:
   los T&C de la plataforma se aceptan una vez; el contrato de un trabajo
   concreto, cada vez.
3. ¿Hay que **versionar** el texto? Si el contrato cambia, ¿los acuerdos ya
   firmados siguen bajo la versión antigua? (Normalmente sí, y por eso hay
   que guardar qué versión se aceptó, no solo un booleano.)
4. ¿Dónde vive el texto legal? ¿URL externa, pantalla dentro de la app, o
   documento servido por el backend?
5. ¿Qué pasa con los usuarios y trabajos que ya existen?

## Módulos afectados (preliminar — lo confirma el `tech-lead`)

- **Backend:** entidad nueva (algo como `AceptacionContrato`: usuario,
  trabajo, versión, fecha, IP), validación en la transición a `ACORDADO`.
- **Flutter:** casilla en el flujo de acuerdo, pantalla o enlace al texto.
- **Datos:** afecta a los dos stacks mientras ADR-0002 siga abierto (hoy la
  app vive en Firestore; el backend, en Postgres) — ver también la tarea 012,
  que tiene el mismo problema.
- **Legal:** el texto en sí. No lo redacta un agente.

## Fuera de alcance de esta ficha

No implementar todavía. Esta tarea existe para que el requisito quede
registrado con sus preguntas abiertas y no se pierda.
