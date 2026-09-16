# Reporte — Tarea 050: sistema de botones compartido

**Estado final:** `en-revision`
**Rama:** `feature/sistema-de-botones`
**Verificado:** 2026-09-15

## Resumen

Se construyeron los 6 componentes de botón compartidos que pide la sección 6
de `docs/design-system-frontend.md` y se migraron todos los sitios de
`lib/funcionalidades/**` que reinventaban `TextButton`, `IconButton`,
`ElevatedButton.styleFrom`/`OutlinedButton.styleFrom` a mano.

## Componentes nuevos (`lib/compartido/widgets/`)

| Archivo | Líneas | Envuelve |
|---|---|---|
| `boton_primario.dart` → `BotonPrimario` | 73 | `ElevatedButton` |
| `boton_secundario.dart` → `BotonSecundario` | 61 | `OutlinedButton` |
| `boton_terciario.dart` → `BotonTerciario` | 70 | énfasis medio (sin caso de uso real todavía, documentado) |
| `boton_texto.dart` → `BotonTexto` | 58 | `TextButton`, color por defecto vía `colorAcentoTexto()` |
| `boton_destructivo.dart` → `BotonDestructivo` | 58 | `ElevatedButton` + `AppColores.error` |
| `boton_icono.dart` → `BotonIcono` | 50 | `IconButton`, `tooltip` requerido, 48×48 mínimo |
| `contenido_boton.dart` (interno, no listado en la tarea) | 56 | contenido compartido (texto/ícono/spinner) reusado por los 4 botones "grandes" para no duplicar la lógica de `cargando` |

Los 6 quedaron muy por debajo del techo de 300 líneas, como esperaba el
criterio de aceptación.

`colorAcentoTexto(context)` se añadió a `lib/nucleo/tema/colores_por_tema.dart`
(79 líneas, sigue bajo el techo) y `colorPrecio()` ahora la llama por dentro
sin duplicar lógica.

`boton_continuar_paso.dart` usa `BotonPrimario` por dentro; su API pública no
cambió (los 8 pasos de registro que lo llaman siguen igual).

## Tests nuevos

`test/compartido/widgets/`: `boton_primario_test.dart`,
`boton_secundario_test.dart`, `boton_terciario_test.dart`,
`boton_texto_test.dart`, `boton_destructivo_test.dart`,
`boton_icono_test.dart`. Cubren: spinner cuando `cargando: true` y bloqueo de
`onPressed`, `onPressed: null` no dispara nada, y `BotonIcono` expone el
`tooltip` requerido envolviendo el ícono.

## Archivos migrados y componente usado

| Archivo | Componente(s) |
|---|---|
| `autenticacion/.../bienvenida_registro_screen.dart` | `BotonIcono`, `BotonTexto` |
| `autenticacion/.../login_screen.dart` | `BotonIcono`, `BotonPrimario`, `BotonSecundario`, `BotonTexto` |
| `autenticacion/.../registro_empleador_screen.dart` | `BotonIcono` |
| `autenticacion/.../registro_trabajador_screen.dart` | `BotonIcono` |
| `autenticacion/.../widgets/registro/boton_continuar_paso.dart` | `BotonPrimario` (interno) |
| `autenticacion/.../widgets/registro_trabajador/paso_cv_trabajador.dart` | `BotonPrimario`, `BotonSecundario`, `BotonTexto` |
| `inicio/.../inicio_screen.dart` | `BotonDestructivo`, `BotonIcono`, `BotonTexto` |
| `perfil/.../configuracion_screen.dart` | `BotonDestructivo`, `BotonSecundario`, `BotonTexto` |
| `perfil/.../editar_perfil_screen.dart` | `BotonPrimario` |
| `perfil/.../perfil_tab.dart` | `BotonSecundario` |
| `perfil/.../widgets/accesos_rapidos_perfil.dart` | `BotonPrimario`, `BotonSecundario` |
| `perfil/.../widgets/aviso_perfil_no_disponible.dart` | `BotonPrimario` |
| `perfil/.../widgets/avisos_perfil.dart` | `BotonIcono`, `BotonSecundario` |
| `perfil/.../widgets/cabecera_perfil.dart` | `BotonIcono` |
| `perfil/.../widgets/formulario_editar_perfil.dart` | `BotonPrimario`, `BotonSecundario` |
| `postulaciones/.../mis_postulaciones_screen.dart` | `BotonTexto` |
| `postulaciones/.../postulantes_screen.dart` | `BotonPrimario`, `BotonTexto` |
| `postulaciones/.../postularse_sheet.dart` | `BotonPrimario` |
| `postulaciones/.../widgets/tarjeta_postulante.dart` | `BotonPrimario`, `BotonSecundario` |
| `trabajos/.../detalle_trabajo_screen.dart` | `BotonPrimario`, `BotonSecundario`, `BotonTexto` |
| `trabajos/.../editar_trabajo_screen.dart` | `BotonPrimario` |
| `trabajos/.../mis_publicaciones_screen.dart` | `BotonDestructivo`, `BotonTexto` |
| `trabajos/.../publicar_trabajo_screen.dart` | `BotonPrimario` |
| `trabajos/.../widgets/barra_busqueda_trabajos.dart` | `BotonIcono` (con `seleccionado: activo`) |
| `trabajos/.../widgets/dialogo_agregar_evidencia.dart` | `BotonPrimario`, `BotonTexto` |
| `trabajos/.../widgets/dialogo_cancelar_contratacion.dart` | `BotonPrimario`, `BotonTexto` |
| `trabajos/.../widgets/dialogo_confirmacion.dart` | `BotonDestructivo`, `BotonTexto` |
| `trabajos/.../widgets/dialogo_reclamar_problema.dart` | `BotonDestructivo`, `BotonTexto` |
| `trabajos/.../widgets/dialogo_solicitar_correccion.dart` | `BotonPrimario`, `BotonTexto` |
| `trabajos/.../widgets/hoja_filtros_trabajos.dart` | `BotonPrimario`, `BotonSecundario` (con `expandido: false`, dos por fila) |
| `trabajos/.../widgets/tarjeta_mi_publicacion.dart` | `BotonTexto` |
| `trabajos/.../widgets/tarjeta_trabajo.dart` | `BotonSecundario` |

Verificado con `grep -rnE "TextButton\(|ElevatedButton\.styleFrom|IconButton\(|OutlinedButton\.styleFrom" lib/funcionalidades/`:
**cero resultados** — no queda ningún sitio en `lib/funcionalidades/**` que
reinvente estos widgets a mano.

`BotonTerciario` no se usó en ningún sitio real (esperado — no había caso de
uso hoy; queda documentado para el próximo que lo necesite, tal como pedía la
tarea).

## Excepción anotada: crecimiento de `detalle_trabajo_screen.dart`

El criterio de aceptación pedía que la migración de este archivo (987 líneas,
ya vivía como excepción de ADR-0014) **redujera** líneas netas. En la
práctica pasó de 987 a **1226 líneas** (+567/−331 en el diff, neto **+236**).

Revisado el diff completo línea por línea: la migración de botones en sí
(~10 sitios, `ElevatedButton.icon`/`OutlinedButton.icon`/`TextButton.icon` →
`BotonPrimario`/`BotonSecundario`/`BotonTexto`) es pareja o ligeramente más
larga por sitio — nombres de parámetro explícitos (`texto`/`icono` en vez de
`label`/`icon`) cuestan un par de líneas más en cada llamada. **El grueso del
crecimiento no tiene relación con botones**: es re-formateo de `dart format`
aplicado sobre código ya existente que no se tocó semánticamente — llamadas
con varios argumentos que antes cabían en una o dos líneas y ahora salen una
por línea con coma final (`Text(...)`, `Container(...)`, `Icon(...)`,
`linea(...)`, etc.), a lo largo de todo el archivo.

**Decisión (tomada al cerrar la tarea):** se acepta el reformateo como
excepción justificada, no se revierte a mano. Revertir selectivamente el
`dart format` sobre las partes no tocadas dejaría el archivo con dos estilos
de formato mezclados (el viejo, comprimido, y el nuevo, expandido) dentro del
mismo archivo — peor para mantenimiento que el crecimiento de líneas en sí, y
contrario a la práctica de apoyarse en el formateador estándar en vez de
pelear contra él. Ningún cambio de negocio, lógica ni copy se coló en el
diff — se verificó manualmente comparando los ~10 sitios de botones contra el
resto del diff.

Esto **no** cierra el problema de fondo: el archivo ya era una excepción viva
de ADR-0014 antes de esta tarea, y ahora la excepción es más grande (1226
líneas). No se dividió aquí porque la tarea lo prohibía explícitamente
("no reordenes el Column", fuera de alcance del hallazgo 7). **Queda
recomendado para una tarea futura de `flutter-agent`** partir
`detalle_trabajo_screen.dart` en subwidgets (candidatos naturales: la sección
de evidencias `_seccionEvidencias`, la cabecera con avatar/estado, y el
bloque `_acciones` según estado) — no se abre esa tarea aquí porque no fue
pedida y el criterio 15 de `CLAUDE.md` ya cubre el "por qué" (pantallas sin
lógica de negocio embebida).

## Verificación

- `flutter analyze`: **12 issues, 0 errores** — todas preexistentes
  (deprecaciones `withOpacity`/`value`, un `use_build_context_synchronously`,
  un `unused_element_parameter`, un `use_null_aware_elements` en un test).
  Ninguna en código nuevo de botones.
- `flutter test`: **289/289 pasan** (283 previos a la tarea 043 + 6 tests
  nuevos de los componentes de botón).
- `grep` de los 4 patrones sobre `lib/funcionalidades/**`: 0 resultados.

## Qué no se tocó (dentro de alcance esperado)

- Hallazgo 2 (contraste dorado) — solo los dos casos marcados explícitamente
  en la tarea (`login_screen.dart` "Regístrate",
  `bienvenida_registro_screen.dart` "Inicia sesión"). El resto queda para la
  tarea 051.
- Hallazgo 7 (orden de información de `detalle_trabajo_screen.dart`) — no se
  reordenó el `Column`.
- Ningún texto visible, llamada a servicio o contrato de datos cambió.

## Siguiente paso

Pasar la tarea a `en-revision` (hecho en `docs/agent-tasks/050-sistema-de-botones.md`).
Desbloquea la tarea 051 (barrido de contraste dorado).
