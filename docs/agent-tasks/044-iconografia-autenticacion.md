---
id: 044
titulo: "Iconografía — autenticación: login, bienvenida y los dos registros (ADR-0017)"
estado: todo
agente: "flutter-agent"
creada: 2026-09-12
rama: "feature/iconografia-autenticacion"   # sobre feature/iconografia-fundamentos (043)
---

## Objetivo

Aplicar el mapa de la tarea 043 a la funcionalidad `autenticacion`: los 13
archivos de `lib/funcionalidades/autenticacion/` que usan `Icons.*` hoy —
`bienvenida_registro_screen.dart`, `login_screen.dart`,
`registro_empleador_screen.dart`, `registro_trabajador_screen.dart`,
`widgets/registro/selector_pais_honduras.dart`,
`widgets/registro_empleador/{paso_contacto_empleador,paso_cuenta_empleador,
paso_info_empresa_empleador}.dart`,
`widgets/registro_trabajador/{paso_cuenta_trabajador,paso_cv_trabajador,
paso_datos_personales_trabajador,paso_estudios_trabajador,
paso_experiencia_trabajador}.dart`.

**Depende de la 043 (necesita el paquete instalado y el mapa fijado). No
depende de 045/046/047** (funcionalidad distinta, sin solapamiento de
archivos) — puede ir en paralelo a la 045 si hace falta.

## Contexto relevante

- ADR-0017. Reporte de la 043 para el mapa `Icons.*` → `LucideIcons.*` y los
  casos semánticos ya decididos.
- Presta atención especial a `paso_datos_personales_trabajador.dart`: es el
  paso que probablemente use `Icons.wc_outlined` (campo de género) — usa el
  equivalente ya decidido en ADR-0017 (`LucideIcons.venusAndMars`), no
  inventes uno nuevo.

## Qué NO es esta tarea

- No cambia ninguna regla de `ReglasCuenta` ni la validación de los
  formularios.
- No toca `lib/compartido/widgets/` (ya migrado en la 043) ni
  `AuthService`/`PerfilService`.
- No añade animación nueva fuera de la lista cerrada de ADR-0015.
- No toca tipografía/espaciado/paleta más allá de lo que ya haya hecho
  ADR-0016 (032/033) — esta tarea es solo iconos.

## Qué hacer

1. Reemplaza cada `Icons.*` por su `LucideIcons.*` equivalente (mapa de la
   043) en los 13 archivos listados arriba.
2. Verifica que el par "variante rellena / variante de contorno" que Material
   usaba para distinguir estados (si existe en algún selector de esta
   funcionalidad) se preserve con el par equivalente de Lucide — no dejes un
   estado "seleccionado" y "no seleccionado" iguales visualmente por usar el
   mismo glifo para ambos sin querer.
3. Si alguno de los 13 archivos tenía un `Icon` con `size`/`color` calculado
   a partir de una propiedad específica de Material (poco probable, pero
   verifícalo), confirma que el widget `Icon(LucideIcons.algo, ...)` acepta
   los mismos parámetros sin cambios de comportamiento.

## Criterios de aceptación

- [ ] Los 13 archivos usan `LucideIcons.*`; cero `Icons.*` restantes
      (`grep -rn "Icons\." lib/funcionalidades/autenticacion` vacío, salvo
      un uso justificado y documentado).
- [ ] Ningún archivo pasa de 300 líneas como consecuencia de este cambio (si
      alguno ya estaba cerca — los dos registros son las excepciones vivas
      conocidas de ADR-0014 — anótalo).
- [ ] `flutter analyze` sin errores nuevos; `flutter test` verde, incluidos
      los tests de `registro_empleador_screen_test.dart` y cualquier otro que
      dependa de un `find.byIcon` — actualízalos si hace falta y anótalo.
- [ ] Capturas antes/después de login, bienvenida y al menos un paso de cada
      registro (claro y oscuro).
- [ ] Reporte en `docs/agent-reports/044-*.md`.

## Notas del agente que la ejecuta

(Se va llenando mientras se trabaja.)
