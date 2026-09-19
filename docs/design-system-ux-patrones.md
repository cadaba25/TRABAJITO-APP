---
name: trabajito-product-ui-ux
description: Patrones de UI y UX para diseñar e implementar pantallas y funcionalidades de Trabajito de forma consistente, ergonomica y profesional.
---

# Trabajito Product UI UX

Esta habilidad define como deben construirse las pantallas y funcionalidades de Trabajito utilizando el Design System oficial.

## Principio fundamental

Cada pantalla debe responder claramente:

1. Donde estoy.
2. Que puedo hacer.
3. Que informacion necesito.
4. Cual es la accion principal.
5. Que sucede despues.

## Regla de una accion primaria

Cada pantalla debe tener una accion principal claramente identificable.

Las acciones secundarias nunca deben competir visualmente con ella.

## Trabajos

La pantalla de trabajos debe priorizar:

- Descubrimiento.
- Busqueda.
- Filtros.
- Ubicacion.
- Categoria.
- Estado.
- Informacion esencial del trabajo.

No mostrar informacion innecesaria en la vista inicial.

## Detalle de trabajo

Debe mostrar progresivamente:

1. Titulo.
2. Descripcion.
3. Ubicacion.
4. Presupuesto o informacion de pago.
5. Tiempo.
6. Contratista.
7. Estado.
8. Accion principal.

La informacion secundaria puede aparecer debajo o mediante interacciones adicionales.

## Postulaciones

Las postulaciones deben mostrar claramente:

- Trabajo.
- Trabajador.
- Estado.
- Propuesta.
- Fecha.
- Acciones disponibles.

Los estados deben ser visualmente distinguibles sin depender solamente del color.

## Chat

El chat debe sentirse rapido, limpio y humano.

Debe priorizar:

- Mensajes.
- Estado de lectura cuando corresponda.
- Campo de entrada.
- Adjuntos cuando existan.
- Acciones relacionadas con el trabajo.

No convertir el chat en una pantalla excesivamente cargada.

## Negociacion

Las acciones como:

- Proponer pago.
- Proponer tiempo.
- Aceptar propuesta.
- Rechazar propuesta.

deben utilizar componentes estructurados.

No depender exclusivamente de mensajes de texto para representar informacion importante.

## Contratacion

Cuando un trabajador sea contratado, el cambio debe ser evidente.

Mostrar:

- Estado.
- Trabajo asociado.
- Personas involucradas.
- Pago.
- Tiempo.
- Siguientes pasos.

## Wallet y pagos

La informacion financiera debe ser extremadamente clara.

Priorizar:

- Saldo.
- Movimientos.
- Estado del pago.
- Trabajo asociado.
- Comision cuando corresponda.
- Acciones disponibles.

Evitar ambiguedades.

## Calificaciones

Las calificaciones deben permitir:

- Seleccionar puntuacion.
- Escribir comentario.
- Ver informacion relevante de la otra persona.

El sistema debe evitar presionar al usuario para calificar.

## Perfil

El perfil debe presentar progresivamente:

- Informacion personal.
- Tipo de cuenta.
- Experiencia.
- Trabajos completados.
- Estudios.
- Reputacion.
- Informacion profesional.

## Ranking

El ranking debe priorizar:

- Claridad.
- Reputacion.
- Informacion relevante.
- Comparacion sencilla.

Evitar convertirlo en una pantalla visualmente saturada.

## Registro

El registro debe minimizar la friccion.

Dividir formularios largos en pasos cuando mejore la experiencia.

Cada paso debe tener:

- Contexto.
- Campos necesarios.
- Validacion.
- Accion siguiente.

## Login

El login debe ser directo.

No agregar informacion innecesaria.

Los errores deben explicar claramente que ocurrio y como solucionarlo.

## Estados de pantalla

Todas las pantallas deben considerar:

### Loading

Utilizar skeletons o indicadores contextuales dependiendo del contenido.

### Empty

Explicar:

- Que esta vacio.
- Por que puede estar vacio.
- Que puede hacer el usuario.

Cuando sea apropiado utilizar ilustraciones.

### Error

Mostrar:

- Que ocurrio.
- Que puede hacer el usuario.
- Accion para intentar nuevamente cuando corresponda.

### Success

El feedback debe ser claro pero no intrusivo.

## Navegacion

La navegacion debe ser minima.

Evitar:

- Menus innecesarios.
- Profundidad excesiva.
- Acciones duplicadas.
- Navegacion confusa.

## Gestos

Los gestos pueden utilizarse cuando sean intuitivos.

Nunca esconder una accion critica exclusivamente detras de un gesto.

## Bottom sheets

Utilizarlos para:

- Filtros.
- Opciones contextuales.
- Acciones secundarias.
- Informacion complementaria.

No utilizarlos para reemplazar una pantalla completa cuando la tarea requiere concentracion.

## Confirmaciones

Las acciones destructivas deben requerir confirmacion cuando exista riesgo real.

La confirmacion debe explicar claramente:

- Que sucedera.
- Si es reversible.
- Que accion esta confirmando.

## Responsive

Las pantallas deben adaptarse a diferentes:

- Telefonos.
- Orientaciones cuando corresponda.
- Tamaños de pantalla.
- Densidades.

No asumir un unico tamaño de dispositivo.

## Informacion progresiva

No mostrar toda la informacion disponible inmediatamente.

Primero mostrar lo necesario para tomar la decision.

La informacion adicional puede aparecer posteriormente.

## Regla de componentes

Antes de crear un componente:

1. Buscar si existe.
2. Reutilizarlo.
3. Extenderlo.
4. Crear uno nuevo solamente si es necesario.

Los nuevos componentes reutilizables deben integrarse al Design System.

## Regla de producto

Trabajito debe sentirse como:

**Una aplicacion profesional que simplifica conseguir y ofrecer trabajo, sin sentirse como una bolsa de empleo tradicional.**

## Auditoria final

Antes de considerar terminada una pantalla verificar:

- Consistencia visual.
- Espaciado.
- Tipografia.
- Colores.
- Jerarquia.
- Accion primaria.
- Estados.
- Loading.
- Empty.
- Error.
- Accesibilidad.
- Responsive.
- Ergonomia.
- Reutilizacion de componentes.
- Animaciones.
- Navegacion.
- Feedback.

Una pantalla terminada no es solamente una pantalla que funciona.

Debe sentirse parte del mismo producto.

---

## Nota de procedencia (añadida 2026-09-12)

Complemento de `docs/design-system-frontend.md` (mismo origen:
`Desktop\skills trabajito\`, incorporado al repo a petición explícita del
dueño). **Esta copia en `docs/` es la fuente de verdad**; hay una copia
idéntica en `.claude/skills/trabajito-product-ui-ux/SKILL.md` para el
autocargado de Claude Code en esta máquina, pero esa está en `.gitignore` y
no viaja con el repo — ver la nota completa en `docs/design-system-frontend.md`.

Este documento es de **patrones de producto por tipo de
pantalla**, no de tokens visuales — no redefine paleta/tipografía/espaciado
(eso ya lo fija ADR-0016 y el otro documento). Nadie ha auditado todavía
cuánto de esto ya cumple el código existente (loading/empty/error por
pantalla, gestos, confirmaciones, etc.) — tómalo como checklist a futuro, no
como algo ya verificado contra `lib/`.
