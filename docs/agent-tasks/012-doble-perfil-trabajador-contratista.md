---
id: 012
titulo: "Doble perfil: un mismo usuario puede trabajar y contratar, cambiando de modo"
estado: todo
agente: ""   # requiere plan del tech-lead: toca modelo de datos + Flutter + backend
creada: 2026-08-21
rama: ""
---

## Origen

Decisión de producto del dueño del proyecto (2026-08-21), en respuesta al
hallazgo de la tarea 006 de que **no existe ninguna verificación de rol** en
los flujos de negocio (un `TRABAJADOR` puede publicar trabajos y un
`EMPLEADOR` puede postularse — ambos devuelven 200).

**La decisión NO es "arreglar" eso restringiendo por rol.** Es al revés: que
ambos lados puedan contratar y trabajar es el comportamiento deseado, pero
hoy no se refleja en la interfaz, y ahí está el verdadero problema.

> Cita del dueño: quiere "que de parte de los 2 se pueda contratar y
> trabajar pero que se vea reflejado en el front (ejemplo: una pestaña que
> diga «Te interesaría también trabajar» para los contratistas y «¿Te
> gustaría contratar servicios?» para el trabajador)... como dos perfiles
> diferentes en el que el usuario puede entrar, pero con su mismo usuario y
> contraseña, el usuario al cambiar de «rol» su interfaz cambiaría según el
> rol seleccionado".

**Carácter provisional:** el dueño indicó que la forma definitiva se
decidirá con los socios de la empresa. Esto es la dirección para ahora, no
un contrato cerrado. No conviene construir encima algo caro de deshacer.

## Objetivo

Un usuario tiene **una sola cuenta** (mismo correo y contraseña) y puede
alternar entre dos modos de uso:

- **Modo trabajador** — busca trabajos, se postula, entrega, cobra.
- **Modo contratista** — publica trabajos, elige postulantes, paga.

La interfaz cambia según el modo activo. Cada modo invita al otro
("¿Te gustaría contratar servicios?" / "Te interesaría también trabajar").

## Por qué esto NO es una tarea simple de UI

Choca con el modelo de datos actual, en los dos stacks:

- **Firestore (en uso hoy):** `usuarios.tipoUsuario` y `usuarios.rol`
  guardan **un solo valor** (`'trabajador'` | `'empleador'`). Ver
  `lib/models/usuario.dart` y `lib/utils/constantes.dart`.
- **PostgreSQL (backend, sin consumidor):** `usuarios.rol` es un enum de un
  solo valor (`Rol`), y desde la tarea 008 el registro solo acepta
  `TRABAJADOR` o `EMPLEADOR` (`RolPublico`). El `rol` viaja **dentro del
  JWT** como claim, lo que hace que cambiar de modo no sea solo un cambio de
  UI: hay que decidir si el token cambia, si el modo va aparte, o si el rol
  deja de estar en el token.

Además, el registro actual (`bienvenida_registro_screen.dart`) **obliga a
elegir uno de los dos caminos al crear la cuenta**, con formularios
distintos (`registro_trabajador_screen.dart` vs
`registro_empleador_screen.dart`, este último de ~874 líneas). Si toda
cuenta puede ser ambas cosas, hay que decidir qué datos se piden al
registrarse y cuáles se piden después, al activar el segundo modo.

## Preguntas a resolver ANTES de implementar (las decide el tech-lead con el usuario)

1. ¿El modo activo es **estado de sesión** (cambia con un botón, no se
   persiste), o un **campo persistido** del usuario?
2. ¿`rol` pasa a ser una **lista** (`roles: [TRABAJADOR, EMPLEADOR]`), o se
   separa en "capacidades habilitadas" + "modo activo"?
3. ¿El JWT sigue llevando `rol`? Si el usuario cambia de modo, ¿se emite un
   token nuevo? (Ver también la tarea de refresh tokens, aún sin crear.)
4. ¿Qué pasa con las cuentas que YA existen en Firestore con un solo rol?
5. Un usuario en modo trabajador, ¿puede postularse a **su propio** trabajo
   publicado en modo contratista? (Hoy nada lo impide — verificar.)
6. ¿La reputación es **una sola** o hay dos separadas (estrellas como
   trabajador vs. como contratista)? Hoy `calificacionPromedio` es un solo
   campo, y son reputaciones conceptualmente distintas.

## Dependencia con ADR-0002

Esta funcionalidad toca el modelo de datos de **los dos** stacks. Si se
implementa primero en Firestore y luego se migra a Postgres, se hace dos
veces. Conviene resolverla **después** de decidir ADR-0002, o diseñarla de
forma que sirva para ambos. Es justo el tipo de decisión que el `tech-lead`
debe plantear al usuario antes de que nadie escriba código.

## Fuera de alcance de esta ficha

No implementar nada todavía. Esta tarea existe para que la decisión quede
registrada y no se pierda, y para que el trabajo se planifique bien cuando
llegue su turno.
