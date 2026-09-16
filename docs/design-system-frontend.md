---
name: trabajito-frontend-design
description: Sistema de diseño frontend de Trabajito para construir interfaces Flutter profesionales, ergonomicas, minimalistas y consistentes.
---

# Trabajito Frontend Design System

## 1. Proposito

Trabajito debe sentirse como una aplicacion profesional que simplifica conseguir y ofrecer trabajo, sin sentirse como una bolsa de empleo tradicional.

La interfaz debe combinar:
- Elegancia y minimalismo.
- Facilidad de uso.
- Accesibilidad.
- Ergonomia.
- Claridad visual.
- Identidad propia de Trabajito.

El diseño puede inspirarse en principios de Apple, Instagram, Snapchat, Uber, Spotify y Apple TV, pero nunca debe convertirse en una copia visual de ninguna de ellas.

## 2. Identidad visual

### Colores oficiales

- Azul Marino: `#0D1B2A`
- Azul Profesional: `#1565C0`
- Amarillo Dorado: `#FFC107`
- Verde Moderno: `#20C997`
- Gris Claro: `#F1F3F6`

### Proporcion visual aproximada

- Azul Marino: 62%
- Gris Claro: 20%
- Azul Profesional: 9%
- Verde Moderno: 5%
- Amarillo Dorado: 4%

Estas proporciones son una guia visual, no una regla matematica absoluta.

## 3. Tipografia

La tipografia oficial es **Sora**.

Debe utilizarse de forma consistente en:
- Titulos.
- Subtitulos.
- Texto principal.
- Labels.
- Botones.
- Estados.
- Navegacion.

No introducir otras familias tipograficas sin una razon justificada.

## 4. Espaciado

Trabajito utiliza un sistema de espaciado basado en multiplos de 4px.

Valores preferidos:

- 4px
- 8px
- 12px
- 16px
- 20px
- 24px
- 32px
- 40px
- 48px
- 64px

Evitar valores arbitrarios como:
- 13px
- 17px
- 19px
- 27px

salvo que exista una razon tecnica o visual clara.

## 5. Principios de interfaz

- Priorizar jerarquia visual sobre bordes.
- Utilizar pocos borders.
- Utilizar cards solamente cuando representen una unidad real de informacion.
- Utilizar sombras de forma contextual y sutil.
- Evitar interfaces saturadas.
- Evitar decoracion sin funcion.
- Priorizar contenido y acciones importantes.
- Mantener una accion primaria clara por pantalla.

## 6. Botones

Utilizar un sistema consistente de botones:

- Primary
- Secondary
- Tertiary
- Text
- Destructive
- Icon

Todos deben compartir:
- Altura consistente.
- Radio consistente.
- Tipografia consistente.
- Estados de loading.
- Estados disabled.
- Estados pressed.
- Feedback visual.

## 7. Iconografia

Utilizar **Lucide Icons** como sistema principal de iconos.

No mezclar diferentes familias de iconos sin una razon justificada.

## 8. Animaciones

Las animaciones deben sentirse naturales y contextuales.

Nunca utilizar animaciones solamente para decorar.

Priorizar:
- Transiciones suaves.
- Feedback inmediato.
- Motion reducido cuando corresponda.
- Duraciones consistentes.
- Curvas naturales.

## 9. Ergonomia

La interfaz debe poder utilizarse comodamente con una sola mano.

Priorizar:
- Acciones importantes en zonas accesibles.
- Navegacion sencilla.
- Targets tactiles suficientemente grandes.
- Jerarquia clara.
- Pocos pasos innecesarios.

## 10. Flutter

La arquitectura debe ser flexible.

Antes de crear un componente nuevo:

1. Buscar componentes existentes.
2. Reutilizar si es posible.
3. Extender el componente existente si corresponde.
4. Crear uno nuevo solamente cuando sea necesario.
5. Si se crea un componente nuevo y es reutilizable, incorporarlo al Design System.

Evitar duplicacion de componentes.

## 11. Regla de consistencia

Una pantalla nueva no debe inventar:

- Nuevos colores.
- Nuevas tipografias.
- Nuevos radios.
- Nuevos sistemas de botones.
- Nuevos sistemas de espaciado.
- Nuevas sombras.
- Nuevas animaciones.

Debe utilizar el Design System existente.

## 12. Mejoras UX

El agente puede mejorar una decision de UX cuando detecte una solucion claramente superior.

Cuando el cambio sea importante, debe explicar brevemente:

- Que cambio.
- Por que lo cambio.
- Que problema de UX resuelve.

No realizar rediseños arbitrarios.

## 13. Estados

Todo componente interactivo debe considerar cuando corresponda:

- Default.
- Pressed.
- Focused.
- Disabled.
- Loading.
- Error.
- Success.
- Empty.

## 14. Accesibilidad

Considerar:

- Contraste.
- Tamaños tactiles.
- Lectores de pantalla.
- Labels semanticamente correctos.
- Escalado de texto.
- Navegacion clara.

## 15. Regla principal

Antes de implementar cualquier pantalla:

**Pensar primero en el sistema, despues en el componente y finalmente en la pantalla.**

La interfaz debe sentirse como una sola aplicacion, no como un conjunto de pantallas creadas independientemente.

---

## Nota de procedencia (añadida 2026-09-12)

Este documento vivía fuera del repositorio (`Desktop\skills trabajito\`) y se
incorporó aquí a petición explícita del dueño del proyecto, para que quede
versionado. **Esta copia en `docs/` es la fuente de verdad** (se lee con
`git log`/`git diff` como cualquier otro documento del proyecto). Hay además
una copia idéntica en `.claude/skills/trabajito-frontend-design/SKILL.md`
para que Claude Code la cargue automáticamente como skill en cada sesión
**en esta máquina** — esa copia está en `.gitignore` (`.claude/skills/` es
para skills reinstalables vía `npx skills add`, no para contenido propio) y
por tanto **no viaja con el repo**: en un clon nuevo o en la máquina de otro
agente humano, hay que volver a copiarla desde aquí a mano si se quiere el
autocargado. Si las dos copias alguna vez difieren, esta de `docs/` manda.

Relación con lo que ya existía en el código antes de esta incorporación:

- **Colores**: coinciden exactamente con `AppColores` (`lib/nucleo/tema/app_colores.dart`)
  y con lo que ADR-0016 (`docs/decisions.md`) ya había auditado y decidido
  mantener — no hay conflicto, este documento confirma la paleta existente.
- **Tipografía (Sora) y espaciado en múltiplos de 4**: ya implementado por
  `AppTipografia`/`AppEspaciado` (tarea 031, ADR-0016).
- **Iconografía (Lucide Icons, sección 7)**: **no implementado todavía** — la
  app usa `Icons.*` (Material Icons) en la mayoría de pantallas. Adoptar
  Lucide Icons de forma sistemática es una migración de superficie completa
  (nueva dependencia + decenas de archivos) y se está planificando aparte
  como su propia iniciativa (ver `docs/decisions.md` por un ADR de
  iconografía cuando exista).
