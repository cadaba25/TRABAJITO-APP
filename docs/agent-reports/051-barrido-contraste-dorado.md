---
tarea: 051-barrido-contraste-dorado
agente: flutter-agent
fecha: 2026-09-16
estado: en-revision
---

## Resumen

Barrido completo de `AppColores.acento` (dorado) usado como color de
texto/ícono directo sobre superficie clara en `lib/funcionalidades/`, más el
`chipThemeData` que faltaba para los 3 `ChoiceChip` con el mismo par
blanco/dorado (1.63:1) que ya midió ADR-0016. Todos los cambios usan
`colorAcentoTexto(context)` (ya existente desde la tarea 050 en
`lib/nucleo/tema/colores_por_tema.dart`) — no hizo falta crearla.

**Nota operativa sobre el git de esta sesión**: el worktree asignado
apuntaba a una rama vieja (`worktree-agent-ac02a5b338c5add48`, en el commit
de la tarea 019) en vez de `feature/barrido-contraste-dorado`, que ya estaba
en uso por el checkout principal y no se pudo checkoutear aquí (git lo
bloquea: una rama solo puede estar activa en un worktree a la vez). Se creó
`work/barrido-contraste-dorado` apuntando al mismo commit `87bdede` (idéntico
contenido a `feature/barrido-contraste-dorado` en ese punto) y se trabajó
ahí. El tech-lead debe fusionar/renombrar esta rama sobre
`feature/barrido-contraste-dorado` antes de abrir el PR — el contenido es el
mismo, solo cambia el nombre local.

## Verificación de los dos enlaces migrados por la tarea 050

Confirmado, no se tocaron:
- `lib/funcionalidades/autenticacion/pantallas/login_screen.dart`: grep de
  `AppColores.acento` en este archivo da **cero resultados** (nada que
  arreglar; los dos `BotonTexto` — "¿Olvidaste tu contraseña?" y
  "Regístrate" — ya resuelven su propio color).
- `lib/funcionalidades/autenticacion/pantallas/bienvenida_registro_screen.dart`:
  el enlace "Inicia sesión" sigue siendo `BotonTexto` (línea ~112), sin
  tocar. Sí se editó el resto del archivo (ver abajo).

## Archivos tocados (19)

### Los 8 del reporte de auditoría original

1. `lib/funcionalidades/trabajos/pantallas/widgets/tarjeta_trabajo.dart` —
   texto de la inicial del avatar → `colorAcentoTexto(context)`. El `_Chip`
   privado ganó un parámetro opcional `colorTexto` (por defecto `color`) para
   poder mantener el fondo con tinte dorado y corregir solo el texto del chip
   de categoría, sin duplicar el widget.
2. `lib/funcionalidades/postulaciones/pantallas/widgets/tarjeta_postulante.dart`
   — texto de la inicial del avatar y el ícono de comillas (`format_quote`,
   con su alpha 0.7 preservado) → `colorAcentoTexto(context)`. Los fondos y
   bordes con alpha se quedan igual.
3. `lib/funcionalidades/perfil/pantallas/ranking_tab.dart` — texto de la
   inicial del avatar y el puntaje (conteo de trabajos) →
   `colorAcentoTexto(context)`. El ícono de trofeo de la cabecera
   (`_cabecera`, línea ~181) **no se tocó a propósito**: vive sobre un
   gradiente fijo `principal`→`azulProfesional` (siempre oscuro,
   independiente del tema), la misma excepción que ya usa
   `AppTema.temaOscuro()` — revisado y dejado igual, no es un olvido.
4. `lib/funcionalidades/perfil/pantallas/trabajadores_tab.dart` — texto de la
   inicial del avatar y de "especialidad" → `colorAcentoTexto(context)`.
5. `lib/funcionalidades/perfil/pantallas/widgets/formulario_editar_perfil.dart`
   — `tt.tituloGrande.copyWith(color: AppColores.acento)` →
   `colorAcentoTexto(context)`.
6. `lib/funcionalidades/autenticacion/pantallas/bienvenida_registro_screen.dart`
   — título "¡Hola!" → `colorAcentoTexto(context)`. También, al revisar el
   resto del archivo por el grep final (punto 4 de la tarea), se corrigieron
   dos usos del mismo patrón que el reporte original no había listado: el
   ícono de `_TarjetaOpcion` (búsqueda/maletín) y la flecha `›` de la misma
   tarjeta, ambos íconos informativos sobre el fondo con tinte dorado.
7. `lib/funcionalidades/autenticacion/pantallas/widgets/registro/terminos_condiciones_checkbox.dart`
   — `estiloEnlace` del `RichText` → `colorAcentoTexto(context)`. Se quitó el
   import de `app_colores.dart`, que quedó sin uso. Sigue sin `onTap`, como
   pedía la tarea.
8. `lib/funcionalidades/autenticacion/pantallas/login_screen.dart` — revisado,
   sin cambios (ver arriba).

### Hallazgo nuevo del tech-lead — `detalle_trabajo_screen.dart`

9. `lib/funcionalidades/trabajos/pantallas/detalle_trabajo_screen.dart` —
   texto de la inicial del avatar del autor → `colorAcentoTexto(context)`.
   El método privado `_chip(...)` ganó el mismo parámetro opcional
   `colorTexto` que `_Chip` en `tarjeta_trabajo.dart`, usado solo para el chip
   de categoría. El `RefreshIndicator(color: AppColores.acento, ...)` de la
   misma pantalla **no se tocó**, como pedía la tarea (es un spinner). No se
   reordenó el archivo (hallazgo 7 es tarea aparte). El archivo pasó de 1226
   a 1235 líneas (+9): ya excedía el techo de 300 desde antes de esta tarea
   (excepción ya documentada en el reporte de la 050 por el reformateo de
   `dart format`); esta tarea solo añade contexto, no reabre esa decisión.

### Hallazgo nuevo del tech-lead — `chipThemeData`

10. `lib/nucleo/tema/app_tema.dart` — se añadió `chipTheme: ChipThemeData(...)`
    a `temaClaro()` **y** `temaOscuro()`: `selectedColor: AppColores.acento`
    y `labelStyle` con un `WidgetStateColor` que resuelve
    `AppColores.principal` cuando el chip está seleccionado (mismo criterio
    que `onPrimary`/`onSecondary`, 10.67:1) y el texto normal del tema
    (`AppColores.texto` en claro, `AppColores.textoOscuro` en oscuro) cuando
    no. Se aplica también en oscuro porque el chip seleccionado se pone
    dorado sólido en los dos modos — el bug no depende del brillo del fondo
    de la pantalla, depende de que el propio chip se vuelve dorado.
11. `lib/funcionalidades/trabajos/pantallas/editar_trabajo_screen.dart`
12. `lib/funcionalidades/trabajos/pantallas/publicar_trabajo_screen.dart`
13. `lib/funcionalidades/trabajos/pantallas/widgets/selector_tarifa.dart`

    Los tres `ChoiceChip` dejaron de fijar `labelStyle`/`selectedColor` a
    mano (antes: `color: activo ? Colors.white : colorTextoFuerte(context)` +
    `selectedColor: AppColores.acento`, exactamente 1.63:1 cuando `activo`).
    Ahora heredan del `chipTheme`. `backgroundColor`/`side` (el borde) se
    quedaron igual — la tarea solo pedía simplificar `labelStyle`/
    `selectedColor`.

### Encontrados en el grep final (paso 4 de la tarea), no listados por el reporte ni por el tech-lead

Mismo patrón exacto (texto/ícono informativo en `AppColores.acento` crudo
sobre superficie clara), detectados al correr
`grep -rn "AppColores.acento" lib/funcionalidades/` sobre el estado actual
del código (no sobre las líneas citadas, ya desactualizadas por 049/050):

14. `lib/funcionalidades/autenticacion/pantallas/widgets/registro/selector_pais_honduras.dart`
    — el ícono de check y el texto "Honduras" de la opción seleccionada.
15. `lib/funcionalidades/autenticacion/pantallas/widgets/registro_empleador/tarjeta_tipo_empleador.dart`
    — el ícono y el título de la tarjeta cuando `seleccionado == true`.
16. `lib/funcionalidades/autenticacion/pantallas/widgets/registro_trabajador/paso_cv_trabajador.dart`
    — el ícono `upload_file_outlined` (con su alpha 0.6 preservado).
17. `lib/funcionalidades/perfil/pantallas/configuracion_screen.dart` — el
    ícono de modo claro/oscuro de la fila "Modo oscuro" (`secondary:` del
    `SwitchListTile`). El `activeThumbColor: AppColores.acento` de la misma
    fila **no se tocó**: es el pulgar de un `Switch`, un indicador de estado
    de control, no texto/ícono informativo (misma categoría que el checkbox
    de `AppTema`, ya resuelto en la 031).
18. `lib/funcionalidades/inicio/pantallas/inicio_screen.dart` —
    `selectedItemColor: AppColores.acento` del `BottomNavigationBar` (tiñe
    los íconos de la pestaña activa; las etiquetas están ocultas) →
    `colorAcentoTexto(context)`.
19. `lib/funcionalidades/trabajos/pantallas/widgets/barra_busqueda_trabajos.dart`
    — texto del `_ChipPlazo` activo.
20. `lib/funcionalidades/trabajos/pantallas/widgets/toggle_feed_trabajos.dart`
    — texto del `_Boton` activo.

## Dejado fuera a propósito (no silenciado)

**Fondos, bordes y spinners** — exactamente lo que la tarea decía que NO es
su alcance. Quedan sin tocar (revisados uno por uno en el grep final):
`CircularProgressIndicator`/`RefreshIndicator` (~20 sitios), todos los
`.withValues(alpha: ...)` usados como fondo de círculo/chip/tarjeta, todos
los `Border.all(color: AppColores.acento, ...)`/`BorderSide(...)`, y el
`activeThumbColor` del `Switch` de `configuracion_screen.dart`. También el
ícono de trofeo de la cabecera de `ranking_tab.dart` (ver punto 3 arriba,
fondo fijo oscuro).

**Hallazgos nuevos, de la misma familia de bug pero fuera del alcance
literal de esta tarea** (no son `AppColores.acento` como texto/ícono; son
fondo sólido + texto blanco fijo, o usan `AppColores.dorado` en vez de
`AppColores.acento`). Se documentan aquí para que el tech-lead decida si
abre una tarea de seguimiento, no se silencian:

- `inicio_screen.dart:64` (`Badge` del contador de chats no leídos) y `:175`
  (`FloatingActionButton` "Publicar"), y `mis_publicaciones_screen.dart:146`
  (mismo FAB): fondo sólido `AppColores.acento` + texto/ícono
  `Colors.white`/`AppColores.blanco` fijo — el mismo 1.63:1 de ADR-0016, pero
  es un bug de "texto blanco hardcodeado", no de "`AppColores.acento` como
  texto", así que el grep de esta tarea no lo encuentra y el tech-lead no lo
  incluyó en el hallazgo 3 (que explícitamente limitó a los 3 `ChoiceChip`).
- `formulario_editar_perfil.dart:77-79` (círculo de la cámara sobre el
  avatar): mismo patrón, fondo sólido + ícono blanco fijo.
- `detalle_trabajo_screen.dart` / `tarjeta_trabajo.dart`, `_badgeEstado`:
  los estados "en progreso"/"esperando confirmación" usan
  `AppColores.dorado` (alias de `acento`, mismo valor `#FFC107`) como texto
  sobre su propio fondo con alpha — visualmente el mismo bug que el chip de
  categoría que sí se corrigió en esta tarea, pero como el literal es
  `AppColores.dorado` y no `AppColores.acento`, el grep de verificación de
  esta tarea no lo encuentra.

No se tocan porque la tarea pedía explícitamente no reabrir alcance más allá
de lo que el grep de `AppColores.acento` encuentra, y porque mezclar un
segundo tipo de arreglo (fondo sólido + contraste del texto fijo) hace más
difícil revisar este PR.

## Criterios de aceptación

- [x] Los 8 sitios del reporte original corregidos, verificados por grep
      propio (línea real, no la citada).
- [x] `detalle_trabajo_screen.dart` (avatar + chip de categoría) corregido.
- [x] `chipThemeData` añadido a `AppTema` (claro y oscuro) y los 3
      `ChoiceChip` simplificados para heredar del tema.
- [x] `grep -rn "AppColores.acento" lib/funcionalidades/` revisado caso por
      caso al final; los usos que quedan (fondo/borde/spinner/thumb) están
      justificados arriba; los hallazgos de la misma familia fuera del
      alcance literal (`AppColores.dorado`, fondos sólidos + blanco fijo)
      quedan documentados, no silenciados.
- [x] Ningún caso corregido cambia comportamiento — mismos textos, mismos
      íconos, mismas acciones; solo cambió el color resuelto.
- [x] `flutter analyze`: 12 issues, todas preexistentes (mismas que antes de
      esta tarea), 0 errores nuevos.
- [x] `flutter test`: **296/296 verde**.
- [x] Este reporte, con la lista final de archivos y la constancia de que
      los dos enlaces migrados por la 050 no se volvieron a tocar.

## Verificación

```
flutter analyze   → 12 issues, 0 errores (mismas preexistentes de antes de la tarea)
flutter test      → 00:19 +296: All tests passed!
```

No se corrió en emulador/dispositivo (no se necesitó: el cambio es de color
resuelto en build time, cubierto por los tests de widgets existentes de
`tarjeta_trabajo_test.dart`/`toggle_feed_trabajos_test.dart`/
`colores_por_tema_test.dart`, que ya pasaban y siguen pasando).

## Dependencias/paquetes

Ninguno nuevo.
