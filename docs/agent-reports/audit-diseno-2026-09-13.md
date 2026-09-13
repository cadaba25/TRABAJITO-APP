# Auditoría de diseño — 2026-09-13

Auditoría de diagnóstico (sin arreglos) de `lib/funcionalidades/**` contra
`docs/design-system-frontend.md` y `docs/design-system-ux-patrones.md`, en la
rama `feature/integracion-rediseno-e-iconografia`. **No se tocó código.**

Alcance explícito: no se re-audita paleta/tipografía/espaciado (ADR-0016, ya
hecho), no se marca la falta de Lucide como incumplimiento (ADR-0017, en
curso), no se entra en `lib/screens/**` (chat, cartera, calificaciones —
Firestore, fase 2b-2, fuera de alcance de ambos documentos de diseño según el
propio ADR-0016).

Método: lectura completa de los dos documentos, lectura de
`docs/agent-context/repo-snapshot.md` (para no repetir auditorías ya hechas
en las tareas 031-043), y `grep`/lectura dirigida sobre los 61 archivos de
`lib/funcionalidades/**`. No se usó el emulador (auditoría de código, no
visual); los hallazgos de contraste se derivan de los mismos pares de color
que ya midió y documentó ADR-0016 (WCAG 2.x), no de una medición nueva.

---

## Resumen ejecutivo

El sistema de diseño está sólido en sus fundamentos (paleta, tipografía,
espaciado, radios — ADR-0016) pero **el sistema de botones de la sección 6
nunca se construyó**: solo `ElevatedButton`/`OutlinedButton` tienen un tema
global consistente (altura 52, radio, tipografía); `TextButton`, los botones
"destructivos" y los botones de ícono se reinventan pantalla por pantalla,
con alturas que rompen el propio criterio de "altura consistente" del
documento y llegan a caer por debajo del tamaño táctil mínimo accesible en al
menos 5 sitios. El segundo hallazgo más importante es que **el contraste
dorado-sobre-claro que ADR-0016 corrigió en 4 sitios puntuales (botón
primario, checkbox, precio) reaparece sin corregir en al menos 15 usos más**
de `AppColores.acento` como color de texto/ícono — la solución
(`AppColores.doradoTexto`/`colorPrecio()`) ya existe en el código, solo no se
aplicó de forma sistemática. Además hay un hallazgo de navegación real: la
pestaña "Trabajadores" y "Ranking" muestran tarjetas con una flecha que
promete ver el perfil del trabajador, pero solo `postulantes_screen.dart`
sabe llegar a `DetalleTrabajadorScreen` — en las otras dos pantallas la
flecha dispara un "función disponible próximamente". El resto del catálogo
(loading/empty/error, información progresiva, registro por pasos, FAB como
acción primaria) está en buen estado y no requiere trabajo nuevo. Los dos
hallazgos grandes (botones, contraste) tocan 10+ archivos cada uno y deberían
planificarse como tareas propias del `tech-lead`, del mismo calibre que
ADR-0016/0017; el resto son arreglos puntuales de 1-5 archivos.

---

## Hallazgos priorizados

### 1. [ALTO — necesita plan de tech-lead] No existe un sistema de botones (sección 6 del primer documento)

**Regla incumplida:** sección 6 — "Primary/Secondary/Tertiary/Text/
Destructive/Icon... Todos deben compartir: altura consistente, radio
consistente, tipografía consistente, estados de loading/disabled/pressed,
feedback visual."

**Qué existe hoy:** `lib/nucleo/tema/app_tema.dart` define
`elevatedButtonTheme`/`outlinedButtonTheme` con altura fija (52),
`AppRadios.campo` y tipografía (`fontSize: 16, fontWeight: w600`) — esto
cubre razonablemente bien "Primary" (`ElevatedButton`) y "Secondary"
(`OutlinedButton`) **cuando se usan sin overrides** (buen ejemplo:
`hoja_filtros_trabajos.dart:69-86`, dos botones `Expanded` sin estilo propio,
altura y radio consistentes).

**Qué falta:**
- **No hay `textButtonTheme`, `iconButtonThemeData` ni `filledButtonTheme`.**
  `TextButton`/`IconButton` caen al estilo por defecto de Material 3, sin
  relación declarada con el resto del sistema.
- **No existe un "Destructive" como variante del sistema.** Se reimplementa
  ad hoc con `ElevatedButton.styleFrom(backgroundColor: AppColores.error)`
  en al menos 7 sitios distintos, cada uno con su propio `minimumSize`:
  `lib/funcionalidades/perfil/pantallas/configuracion_screen.dart:41-44,83-86`,
  `lib/funcionalidades/trabajos/pantallas/mis_publicaciones_screen.dart:84-86,116-118`,
  `lib/funcionalidades/inicio/pantallas/inicio_screen.dart:86-88`,
  `lib/funcionalidades/trabajos/pantallas/widgets/dialogo_confirmacion.dart:44-48`,
  `lib/funcionalidades/trabajos/pantallas/widgets/dialogo_reclamar_problema.dart:77-79`.
  Ninguno importa de un componente compartido; si mañana cambia el rojo de
  "destructivo" hay que tocar 7 archivos.
- **"Altura consistente" se rompe justo donde más se nota (diálogos).** El
  tema fija 52px, pero los botones de `AlertDialog` de arriba lo pisan con
  `minimumSize: const Size(100, 40)`, y hay además `Size(0, 32)` (enlaces de
  texto en tarjetas/formularios) y `Size(0, 42)`/`Size(140, 36)` en otros
  sitios (ver hallazgo 4). El documento pide "altura consistente" como
  propiedad compartida de *todo* el sistema, no solo del botón de pantalla
  completa.
- **No hay componente de "Icon button" con criterio propio** (tamaño mínimo,
  variante con/sin fondo). Los 10 `IconButton` del código son cada uno un
  caso suelto: unos con `tooltip`, otros sin; uno con
  `visualDensity: VisualDensity.compact` (`avisos_perfil.dart:54`, reduce el
  área táctil por debajo del default de Material).
- **No hay estado de loading dentro del botón como parte del sistema.** El
  patrón sí existe (`SizedBox` + `CircularProgressIndicator` reemplazando el
  texto mientras `cargando`), pero está duplicado a mano en
  `login_screen.dart:227-235`, y como componente propio solo para el registro
  en `boton_continuar_paso.dart` — no hay un `BotonPrimario`/`AppButton`
  único que lo encapsule para toda la app.

**Por qué importa:** es la pieza más transversal de un design system — la
comparten literalmente todas las pantallas — y es la que primero se nota
cuando falta ("¿por qué este diálogo tiene un botón más chico que ese otro?").
También es la causa raíz de dos hallazgos más abajo (targets táctiles
pequeños, confirmaciones inconsistentes): sin un componente único, cada
pantalla nueva decide su propio criterio.

**Tamaño del arreglo:** cross-módulo. Diseñar `BotonPrimario`/
`BotonSecundario`/`BotonTerciario`/`BotonTexto`/`BotonDestructivo`/
`BotonIcono` en `lib/compartido/widgets/` y migrar ~20 archivos que hoy usan
Material puro con overrides. Mismo calibre que ADR-0016 (tareas 031-037):
necesita que el `tech-lead` lo planifique y lo reparta, no es un cambio de un
agente en una sesión.

---

### 2. [ALTO — necesita plan de tech-lead] Contraste dorado-sobre-claro sigue sin corregirse fuera de los 4 sitios que ya arregló ADR-0016

**Regla incumplida:** sección 14 del primer documento ("Contraste") y
sección 15 del segundo ("Auditoría final — Accesibilidad"). No es una regla
nueva: es la *misma* que motivó la tarea 031 (`AppTema`) y el commit
`aa2fd65` de la tarea 034 (`colorPrecio()`), que midieron **blanco/dorado
sobre dorado/blanco = 1.63:1**, muy por debajo del mínimo AA (4.5:1).

**Qué se corrigió (no repetir):** `onPrimary`/`onSecondary`/botón primario/
checkbox en modo oscuro (031); el precio en `tarjeta_trabajo.dart` y
`tarjeta_mi_publicacion.dart` en modo claro, vía `AppColores.doradoTexto` +
`colorPrecio(context)` (034, `colores_por_tema.dart:66`).

**Qué sigue sin corregirse — el mismo par de colores, en modo claro,
reaparece como color de texto/ícono directo (`AppColores.acento`, no
`colorPrecio()`) en al menos estos sitios:**
- `lib/funcionalidades/trabajos/pantallas/widgets/tarjeta_trabajo.dart:63-67`
  (inicial del avatar) y `:87` (`_Chip` de categoría — texto dorado sobre
  fondo con tinte dorado al 100% de opacidad de borde).
- `lib/funcionalidades/postulaciones/pantallas/widgets/tarjeta_postulante.dart:72,101-110`
  (ya señalado como "hallazgo lateral, no corregido" por la propia tarea 036
  — se confirma aquí que sigue así).
- `lib/funcionalidades/perfil/pantallas/ranking_tab.dart:168-172,235,252`
  (medalla/posición y puntaje del ranking).
- `lib/funcionalidades/perfil/pantallas/trabajadores_tab.dart:101,130,195,219`
  (especialidad y otros textos de la tarjeta de trabajador).
- `lib/funcionalidades/perfil/pantallas/widgets/formulario_editar_perfil.dart:70`
  (`tt.tituloGrande.copyWith(color: AppColores.acento)`).
- `lib/funcionalidades/autenticacion/pantallas/login_screen.dart:223`
  ("¿Olvidaste tu contraseña?", `TextButton` con texto dorado sobre fondo
  blanco/superficie — el caso más simple y más grave: es un enlace de acción
  real, no un adorno).
- `lib/funcionalidades/autenticacion/pantallas/bienvenida_registro_screen.dart:51,114`
  y `lib/funcionalidades/autenticacion/pantallas/widgets/registro/terminos_condiciones_checkbox.dart:25`
  (texto de "Términos y condiciones").

**Por qué importa:** el propio proyecto ya demostró (ADR-0016) que este par
falla WCAG AA y que existe una variante correcta
(`AppColores.doradoTexto`/`colorPrecio()`). Dejarlo sin aplicar de forma
sistemática significa que la app tiene, hoy, más de una decena de textos con
contraste insuficiente en modo claro para usuarios con baja visión —
exactamente el defecto que ADR-0016 se propuso cerrar, solo que a medias.

**Tamaño del arreglo:** cross-módulo (≥10 archivos, dos funcionalidades). Es
mecánicamente idéntico al patrón que ya resolvió la tarea 034
(`AppColores.acento` → `colorPrecio(context)`/`doradoTexto` cuando el color
se usa como texto/ícono sobre superficie clara, no como fondo), pero el
volumen y la necesidad de revisar cada caso en contexto (modo oscuro puede
seguir usando `acento` sin problema, como ya hace `AppTema.temaOscuro()`)
justifica una tarea propia planificada, no un parche suelto.

---

### 3. [MEDIO — arreglo puntual, 2 archivos] "Trabajadores" y "Ranking" prometen un perfil que no está cableado

**Regla incumplida:** principio fundamental del segundo documento ("Qué
puedo hacer", "Navegación... evitar navegación confusa") y sección "Perfil"
("El perfil debe presentar progresivamente...").

**Qué pasa:** `DetalleTrabajadorScreen` (`lib/funcionalidades/perfil/pantallas/detalle_trabajador_screen.dart`)
existe y funciona — es la pantalla de perfil público de un trabajador — pero
en todo `lib/` **solo la usa `postulantes_screen.dart:84`** (al ver a un
postulante). Las otras dos pantallas que muestran tarjetas de trabajador:
- `lib/funcionalidades/perfil/pantallas/trabajadores_tab.dart:244-248`: cada
  tarjeta termina en un `IconButton` con flecha `arrow_forward_ios_rounded`
  cuyo `onPressed` es `_proximamente` (línea 46: muestra un `SnackBar`
  "Función disponible próximamente"). El resto de la tarjeta tampoco es
  tocable (no hay `InkWell`/`GestureDetector` envolviendo el `Container` de
  `_tarjeta`, línea 179).
- `lib/funcionalidades/perfil/pantallas/ranking_tab.dart`: las filas no
  tienen ningún manejador de toque; no hay ni siquiera el intento de la
  flecha.

**Por qué importa:** el directorio de trabajadores y el ranking son
exactamente las dos pantallas donde un empleador esperaría poder entrar al
perfil completo de alguien antes de decidir contratarlo — es el caso de uso
central de "Trabajadores" según la sección "Perfil"/"Ranking" del segundo
documento. Hoy la flecha es una promesa visual rota.

**Tamaño del arreglo:** puntual. `DetalleTrabajadorScreen` ya recibe
`Usuario` como parámetro (igual que en `postulantes_screen.dart:84`); cablear
`Navigator.push` en los dos archivos es un cambio contenido, sin tocar
contratos de datos ni el backend.

---

### 4. [MEDIO — arreglo puntual, 5 archivos] Targets táctiles por debajo del mínimo accesible

**Regla incumplida:** sección 9 ("Targets táctiles suficientemente grandes")
y sección 14 ("Tamaños táctiles") del primer documento.

**Dónde:**
- `lib/funcionalidades/autenticacion/pantallas/login_screen.dart:217-218` —
  "¿Olvidaste tu contraseña?", `TextButton.styleFrom(minimumSize: const
  Size(0, 32))`.
- `lib/funcionalidades/postulaciones/pantallas/mis_postulaciones_screen.dart:244-247`
  — "Retirar", mismo `Size(0, 32)`.
- `lib/funcionalidades/trabajos/pantallas/widgets/tarjeta_trabajo.dart:121,130`
  — dos botones con `Size(0, 42)`.
- `lib/funcionalidades/autenticacion/pantallas/widgets/registro_trabajador/paso_cv_trabajador.dart:65`
  — `Size(140, 36)`.
- `lib/funcionalidades/perfil/pantallas/widgets/avisos_perfil.dart:54` —
  `visualDensity: VisualDensity.compact` en un `IconButton` de acción real
  ("Actualizar").

Todos son **acciones reales** (recuperar contraseña, retirar una
postulación, actuar sobre una tarjeta de trabajo, subir CV, reintentar una
carga), no elementos decorativos — el estándar de 44×44 (Apple HIG) / 48×48
(Material) aplica.

**Por qué importa:** afecta directamente a accesibilidad motriz y es fácil
de reproducir en cualquier dispositivo con dedos grandes o baja precisión.

**Tamaño del arreglo:** puntual, 5 archivos, cambio de una línea cada uno
(sería trivial si existiera el componente del hallazgo 1, que es la razón
real por la que esto pasó).

---

### 5. [MEDIO — arreglo puntual, 1 archivo] "Retirar postulación" no pide confirmación, a diferencia de acciones equivalentes

**Regla incumplida:** sección "Confirmaciones" del segundo documento — "Las
acciones destructivas deben requerir confirmación cuando exista riesgo
real."

**Qué pasa:** `lib/funcionalidades/postulaciones/pantallas/mis_postulaciones_screen.dart:114-118`
(`_retirar`) llama a `ejecutarConCarga(context, () =>
_postService.retirar(p.id), ...)` directamente al tocar el botón — sin
diálogo previo. En cambio, acciones de peso comparable en el resto de la app
sí confirman: "Cancelar contratación"
(`dialogo_cancelar_contratacion.dart`), "Rechazar trabajo"
(`mostrarDialogoConfirmacion`), "Dar de baja tu cuenta" y "Cerrar sesión"
(`configuracion_screen.dart`).

**Por qué importa:** retirar una postulación pierde el puesto del trabajador
en la cola de esa oferta — es una acción con consecuencia real, tratada de
forma inconsistente con acciones de riesgo similar en la misma app. Un
usuario que toca por error "Retirar" no tiene forma de deshacerlo.

**Tamaño del arreglo:** puntual — envolver la llamada en
`mostrarDialogoConfirmacion` (ya existe y es exactamente para esto), 1
archivo.

---

### 6. [BAJO — arreglo puntual, 4 archivos] Labels semánticos ausentes en algunos `IconButton`

**Regla incumplida:** sección 14 ("Labels semánticamente correctos",
"Lectores de pantalla").

**Dónde:** los tres botones "atrás" (flecha) de
`bienvenida_registro_screen.dart:21-25`,
`registro_empleador_screen.dart:115-119` y
`registro_trabajador_screen.dart:125-129` no tienen `tooltip` ni `Semantics`
(un lector de pantalla los anuncia solo como "botón", sin decir qué hacen).
El botón "próximamente" de `trabajadores_tab.dart:244-248` tampoco —
agravado por el hallazgo 3: ni siquiera hace lo que su ícono visual promete.
Contraste: 6 de los 10 `IconButton` del código sí tienen `tooltip`
(`inicio_screen.dart`, `login_screen.dart` con el de tema,
`barra_busqueda_trabajos.dart`, `avisos_perfil.dart`,
`cabecera_perfil.dart`), muestra que el criterio existe pero no se aplica
parejo.

**Tamaño del arreglo:** trivial, agregar `tooltip: 'Atrás'` en los tres
primeros; el cuarto se resuelve solo si se corrige el hallazgo 3.

---

### 7. [BAJO/MEDIO — coordinar con la tarea que ya toca ese archivo] `detalle_trabajo_screen.dart` no sigue el orden de información progresiva documentado

**Regla incumplida:** sección "Detalle de trabajo" del segundo documento —
orden esperado: 1. Título, 2. Descripción, 3. Ubicación, 4. Presupuesto,
5. Tiempo, 6. Contratista, 7. Estado, 8. Acción principal.

**Qué pasa:** el orden real en
`lib/funcionalidades/trabajos/pantallas/detalle_trabajo_screen.dart:198-270`
es: contratista + estado (badge) → chips de categoría/plazo → **título** →
tarjeta de ubicación/presupuesto/asignado → **descripción** → tarjeta de
"Contrato"/estado (repite el estado) → acciones. El título aparece después
del bloque de autor/estado, no primero, y la descripción aparece después de
ubicación/presupuesto, invirtiendo el orden 2↔3-4 del documento.

**Por qué importa:** es una diferencia real de jerarquía de lectura, aunque
menor — el título sigue siendo lo primero *grande* que se lee, solo que hay
una fila de "quién publicó" antes. Es más una discrepancia formal con la
lista del documento que un problema de usabilidad grave.

**Tamaño del arreglo:** puntual en términos de líneas de código (reordenar
`Column` children), pero **este archivo ya es la excepción viva más grande
al techo de 300 líneas (987) y tiene una tarea futura pendiente para
extraerle la máquina de estados** (ADR-0014, "cuando se migre el chat"/tarea
012). Recomendación: no despachar esto solo — agruparlo con la próxima tarea
que ya tenga que abrir este archivo, para no multiplicar sesiones de merge
sobre el archivo más grande del proyecto.

---

### 8. [BAJO — deuda ya documentada, se reconfirma aquí] Reutilización de componentes incompleta

**Regla incumplida:** sección "Regla de componentes" del segundo documento y
"Auditoría final" ("Reutilización de componentes").

**Qué pasa:** `mis_postulaciones_screen.dart` (298 líneas, al límite del
techo) duplica sus propios estados vacío/error en vez de reutilizar
`EstadoErrorPostulantes`/`EstadoVacioPostulantes`, ya extraídos para
`postulantes_screen.dart` en la tarea 027 B-2b — esto ya lo documentó la
tarea 036 como fuera de su alcance ("tokens, no deduplicación estructural").
El diálogo de "Seleccionar postulante" en `postulantes_screen.dart`
(`_seleccionar`) tampoco reutiliza `dialogo_confirmacion.dart` — también ya
documentado por la 036 como decisión consciente (cambiaría texto/color de
botón). No es un hallazgo nuevo: se reconfirma porque la sección 15 del
segundo documento lo pide explícitamente como parte del checklist de cierre,
y sigue sin resolverse.

**Tamaño del arreglo:** puntual si se acepta el cambio visual menor que la
036 evitó a propósito (mover "Seleccionar" al estilo `dialogo_confirmacion`
cambiaría el texto de los botones y el color de la acción afirmativa a
rojo). Requiere una decisión de producto, no solo de código.

---

### 9. [INFORMATIVO — fuera de alcance real de esta auditoría] Wallet, chat y calificaciones no se pudieron auditar

`docs/design-system-ux-patrones.md` dedica secciones enteras a "Chat",
"Negociación", "Wallet y pagos" y "Calificaciones". Esas cuatro superficies
viven hoy en `lib/screens/**` (Firestore, fase 2b-2), explícitamente fuera de
alcance de esta tarea y de ADR-0016. No se puede afirmar hoy cuánto cumplen
ni incumplen esas secciones — queda pendiente para cuando se migren.

---

## Lo que ya está bien (no repetir trabajo)

- **Loading/empty/error del feed, ranking, postulantes y "mis
  publicaciones" están bien resueltos y son distinguibles entre sí** (no se
  confunde "vacío" con "error", cada uno con su propio ícono/mensaje y
  "desliza para reintentar" cuando aplica) — ver `estados_feed.dart`,
  `ranking_tab.dart:_estadoError/_estadoVacio`,
  `estados_postulantes.dart`/`estados_mis_publicaciones.dart`.
- **Acción primaria clara vía `FloatingActionButton.extended`** en
  `inicio_screen.dart` (publicar, solo para empleador en la pestaña
  "Trabajos") y `mis_publicaciones_screen.dart` — no compite con acciones
  secundarias.
- **Registro dividido en pasos con contexto/validación/acción siguiente**
  (8 pasos entre los dos registros) cumple la sección "Registro" del segundo
  documento.
- **Estados de trabajo/postulación se distinguen por texto + color, no solo
  por color** (badges con `EstadosTrabajo.etiqueta`/similar).
- **Gestos**: no se encontró ninguna acción crítica escondida
  exclusivamente detrás de un gesto (swipe/long-press). El único
  `Dismissible` que apareció en la búsqueda fue un falso positivo
  (`barrierDismissible`).
- **Confirmaciones destructivas de peso real ya están bien resueltas**:
  "Dar de baja cuenta" explica reversibilidad y qué se conserva; "Cancelar
  contratación"/"Rechazar trabajo" confirman antes de ejecutar.
- **Contraste**: fuera del patrón dorado-como-texto (hallazgo 2), no se
  encontraron otros pares de color sospechosos en los puntos revisados
  (badges de estado, textos secundarios en modo oscuro, `AppTema` en
  general).

---

## Resumen para el tech-lead

9 hallazgos: 2 de alto impacto que tocan 10+ archivos cada uno y deberían
planificarse como tareas propias (sistema de botones — sección 6; barrido de
contraste dorado-como-texto — sección 14, continuación directa de
ADR-0016/tarea 034), 1 hallazgo de navegación real (directorio de
trabajadores y ranking no llevan al perfil que ya existe), y el resto son
arreglos puntuales de 1-5 archivos (targets táctiles pequeños, confirmación
faltante en "retirar postulación", labels semánticos, orden de información
en el detalle de trabajo, y deuda de reutilización ya conocida). Los tres
más importantes, en orden: (1) el sistema de botones no existe como tal —
Primary/Secondary sí, Tertiary/Text/Destructive/Icon no, con alturas que se
rompen justo en diálogos; (2) el contraste dorado-sobre-claro que ADR-0016
corrigió en 4 sitios reaparece sin corregir en 15+ más, con la solución ya
escrita en el código (`colorPrecio()`/`doradoTexto`) y sin aplicar; (3)
"Trabajadores" y "Ranking" prometen ver un perfil (flecha visual) que no
está cableado, mientras la pantalla de destino ya existe y funciona desde
`postulantes_screen.dart`. Ninguno de los tres requiere backend ni cambia
contratos de datos. No se tocó código en esta auditoría.
