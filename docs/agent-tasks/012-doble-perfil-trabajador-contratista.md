---
id: 012
titulo: "Doble perfil: una cuenta puede tener rol de trabajador y de contratista, y alternar entre ellos"
estado: todo
agente: ""   # requiere plan del tech-lead: modelo de datos + backend + Flutter
creada: 2026-08-21
rama: ""
---

## Origen y especificación

Requisito del dueño del proyecto, precisado el 2026-08-26. Su analogía:

> *"como cuando en need for speed el videojuego podia ser corredor ilegal y
> poder cambiar de rol a policia, sin eliminar el rol en pausa"*

Y el flujo concreto que describió:

> *"seria con una misma cuenta cambiar de «rol», que en caso la cuenta se
> inicio con rol de contratista y quiere trabajar, con la misma cuenta pueda
> rellenar el formulario de trabajador y que se cambie a la interfaz de
> trabajador, en caso quiera volver a contratista, que vaya a
> configuracion/perfil/ y que haya un boton de cambiar a contratista si es
> trabajador o cambiar a trabajador si es contratista, habran personas que
> quieran las dos cosas y otras que solo quieran un solo rol"*

## Qué significa exactamente

Esto **responde** las preguntas que esta ficha tenía abiertas. Ya no hay que
decidirlas:

1. **Los roles se acumulan, no se sustituyen.** Una cuenta puede tener uno o
   los dos. Activar el segundo **no borra ni degrada el primero**: queda "en
   pausa", con sus datos intactos (su reputación, su historial).
2. **Activar el segundo rol exige rellenar su formulario.** Un contratista
   que quiere trabajar debe completar el formulario de trabajador
   (`registro_trabajador_screen.dart`), y viceversa
   (`registro_empleador_screen.dart`). No se activa con un solo clic: hacen
   falta los datos de ese rol.
3. **Cambiar entre roles ya activos es instantáneo**, desde
   `configuración → perfil`, con un botón que dice "Cambiar a contratista" o
   "Cambiar a trabajador" según en cuál estés.
4. **La interfaz cambia por completo** según el rol activo.
5. **Tener los dos roles es opcional.** Mucha gente querrá solo uno, y el
   flujo de esa gente no debe complicarse: quien nunca active el segundo rol
   no debería notar que existe esta funcionalidad, más allá de la invitación.
6. **La invitación al otro rol** es la que ya pidió antes: una pestaña o
   tarjeta con "¿Te gustaría contratar servicios?" para el trabajador, y "Te
   interesaría también trabajar" para el contratista.

## Lo que sigue sin decidir (y hay que resolver antes de programar)

1. **¿Una reputación o dos?** Hoy `calificacionPromedio` es un solo campo.
   Ser buen trabajador y ser buen contratista son cosas distintas: mezclar
   ambas en una sola nota puede ser injusto y confuso. **Recomendación del
   `tech-lead`: dos reputaciones separadas**, porque separarlas después
   obliga a repartir calificaciones ya emitidas, y eso no tiene solución
   buena. Falta la aprobación del dueño.
2. **¿Puede alguien postularse a su propio trabajo?** Con los dos roles
   activos, nada lo impediría. Hoy no hay ninguna comprobación. Casi
   seguramente hay que bloquearlo.
3. **Qué pasa con las cuentas existentes** — en la práctica, poco: los datos
   de Firebase son de prueba y se descartan (ADR-0009).

## Impacto técnico

El modelo actual guarda **un solo rol por usuario**, y en los dos stacks:

- **Backend (destino, ADR-0009):** `usuarios.rol` es un enum de un valor
  (`Rol`), y desde la tarea 008 el registro público solo acepta `TRABAJADOR`
  o `EMPLEADOR` (`RolPublico`). Además **el rol viaja dentro del JWT** como
  claim, así que cambiar de modo no es solo cosa de la interfaz: hay que
  decidir si el token cambia al cambiar de rol, o si el rol activo deja de
  vivir en el token.
- **Firestore (se va, ADR-0009):** `usuarios.tipoUsuario` y `usuarios.rol`,
  también de un solo valor.

Forma probable (a confirmar en el plan): separar **capacidades habilitadas**
(qué roles tiene la cuenta) de **rol activo** (en cuál está ahora mismo). El
JWT debería llevar las capacidades; el rol activo puede ser estado de la app
o un campo del usuario.

## Dependencia con la migración

**Hacer esto en Firestore sería trabajo tirado.** ADR-0009 decidió migrar al
backend propio, así que esta funcionalidad debe construirse **sobre
PostgreSQL**, encajada en el plan de
`docs/agent-tasks/014-migracion-de-firebase-al-backend.md` — concretamente,
el modelo de datos de roles debe quedar decidido **antes** de reescribir el
registro y el login de Flutter, o se escriben dos veces.

## Fuera de alcance de esta ficha

No implementar todavía. Falta que el `tech-lead` plantee al dueño las tres
preguntas abiertas de arriba (sobre todo la de la reputación) y escriba el
plan por módulos.
