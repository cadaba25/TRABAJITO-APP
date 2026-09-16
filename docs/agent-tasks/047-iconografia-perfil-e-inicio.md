---
id: 047
titulo: "Iconografía — perfil e inicio (ADR-0017)"
estado: bloqueada
agente: "flutter-agent"
creada: 2026-09-12
rama: ""   # se crea sobre feature/iconografia-fundamentos (043) SOLO cuando la 037 esté hecha y mergeada
---

## Objetivo

Aplicar el mapa de la tarea 043 a `perfil` e `inicio`: los 11 archivos de
`lib/funcionalidades/perfil/` que usan `Icons.*` hoy
(`configuracion_screen.dart`, `detalle_trabajador_screen.dart`,
`perfil_tab.dart`, `ranking_tab.dart`, `trabajadores_tab.dart`, y
`widgets/{accesos_rapidos_perfil,aviso_perfil_no_disponible,avisos_perfil,
cabecera_perfil,formulario_editar_perfil,info_personal_perfil}.dart`) más
`lib/funcionalidades/inicio/pantallas/inicio_screen.dart` (el shell del
`BottomNav`, con los pares de icono relleno/contorno de las 5 pestañas).

## Por qué está `bloqueada` y no `todo`

**La tarea `037-rediseno-perfil-e-inicio` está en curso ahora mismo sobre
exactamente estos mismos archivos** (ver
`docs/agent-tasks/037-rediseno-perfil-e-inicio.md` y el estado real del
working tree, no solo el campo `estado:` del archivo, que puede no estar
actualizado).

**No se despacha esta tarea hasta que `037` esté en `en-revision` o `hecho` y
esos cambios estén estables** (mergeados o al menos ya no en curso). Mismo
archivo, mismo widget, conflicto de merge seguro si se adelanta.

También depende de la 043 (mapa y paquete instalados).

## Contexto relevante

- ADR-0017. Reporte de la 043 para el mapa `Icons.*` → `LucideIcons.*`.
- El reporte de la 037, una vez exista, para saber en qué quedaron
  exactamente esos archivos.
- ADR-0015: el cambio de pestaña del `BottomNav` está en la lista cerrada de
  "dónde NO hay movimiento nuevo" — no lo animes al tocar `inicio_screen.dart`,
  esta tarea es solo iconos.

## Qué NO es esta tarea

- No cambia qué se puede editar del perfil ni las reglas de `ReglasCuenta`.
- No toca `datosSinConfirmar`/`cvCargado` ni la lógica de ADR-0013.
- No añade sondeo ni cambia cuándo se recarga cada pestaña.
- No toca tokens de tipografía/espaciado/paleta (ya los aplicó/aplica la
  037).

## Qué hacer

1. Antes de tocar nada, confirma en
   `docs/agent-tasks/037-rediseno-perfil-e-inicio.md` que el estado es
   `en-revision` o `hecho`, y que la rama está mergeada.
2. Reemplaza cada `Icons.*` por su `LucideIcons.*` equivalente (mapa de la
   043) en los 12 archivos listados arriba.
3. **`inicio_screen.dart` es el caso más delicado de esta tarea**: hoy cada
   pestaña del `BottomNav` usa un par de iconos, uno "outline" para inactivo
   y uno "filled"/"rounded" para activo (`work_outline_rounded`/`work_rounded`,
   `people_outline_rounded`/`people_rounded`, `forum_outlined`/`forum_rounded`,
   `emoji_events_outlined`/`emoji_events_rounded`,
   `person_outline_rounded`/`person_rounded`). Verifica que el par
   `LucideIcons.*` elegido para cada concepto preserve esa distinción visual
   entre pestaña activa e inactiva — si el mapa de la 043 solo fijó un glifo
   por concepto sin la variante de peso/relleno, resuélvelo aquí (Lucide trae
   variantes de grosor vía `LucideIcons.xxx100`...`xxx600` y `Icon(..., fill:
   ...)` no aplica igual que Material `_rounded` vs `_outlined` — documenta
   qué usaste para distinguir estados: dos glifos distintos, un cambio de
   color/peso, o ambos) y anótalo en el reporte para que quede como
   referencia.
4. Presta atención a `emoji_events_outlined`/`emoji_events_rounded`
   ("ranking" — trofeo): confirma el nombre exacto en Lucide (`trophy` o
   `award`, según cuál transmita mejor "ranking" en el contexto de la app) y
   documenta cuál elegiste y por qué si no estaba ya fijado en el mapa de la
   043.

## Criterios de aceptación

- [ ] Confirmado y anotado en el reporte que la 037 estaba `hecho`/mergeada
      antes de empezar.
- [ ] Los 12 archivos usan `LucideIcons.*`; cero `Icons.*` restantes
      (`grep -rn "Icons\." lib/funcionalidades/perfil lib/funcionalidades/inicio`
      vacío, salvo un uso justificado y documentado).
- [ ] El par activo/inactivo de las 5 pestañas del `BottomNav` sigue siendo
      visualmente distinguible tras el cambio — verificado explícitamente,
      no solo "se ve razonable".
- [ ] El aviso de "datos sin confirmar" y la tarjeta de "CV sin cargar"
      conservan su icono de advertencia reconocible tras el cambio.
- [ ] Ningún archivo pasa de 300 líneas como consecuencia de este cambio.
- [ ] `flutter analyze` sin errores nuevos; `flutter test` verde
      (`perfil_tab_test.dart`, `editar_perfil_screen_test.dart`,
      `pantalla_inicial_test.dart` si aplica, y cualquier `find.byIcon`
      existente, actualizado si hace falta).
- [ ] Capturas antes/después de las 5 pestañas del `BottomNav`, activa e
      inactiva, claro y oscuro.
- [ ] Reporte en `docs/agent-reports/047-*.md`.

## Notas del agente que la ejecuta

(Se va llenando mientras se trabaja. El `tech-lead` debe cambiar `estado` a
`todo` cuando confirme que la 037 está `hecho`/mergeada — no lo cambies tú
mismo sin esa confirmación si no eres quien la verificó.)
