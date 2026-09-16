import 'package:flutter/material.dart';

import 'app_colores.dart';

// El color que toca segun el tema claro u oscuro.
//
// `AppColores` es la paleta fija; esto es la parte que **depende del
// contexto**, y por eso vive aparte. Estaba escondido en
// `widgets/custom_textfield.dart` hasta la tarea 027 (parte B-1), donde no
// lo encontraba nadie: son ayudas de tema, no un campo de texto.
//
// Lo usan 15 pantallas. Antes de tocar cualquiera de las cuatro, mira quien
// las llama.
bool _esOscuro(BuildContext c) => Theme.of(c).brightness == Brightness.dark;

Color colorTextoFuerte(BuildContext c) =>
    _esOscuro(c) ? AppColores.textoOscuro : AppColores.azulOscuro;
Color colorTextoSuave(BuildContext c) =>
    _esOscuro(c) ? AppColores.grisMedio : AppColores.grisTexto;
Color colorSuperficie(BuildContext c) =>
    _esOscuro(c) ? AppColores.superficieOscura : AppColores.blanco;
Color colorBorde(BuildContext c) =>
    _esOscuro(c) ? AppColores.bordeOscuro : AppColores.grisClaro;

// ── Roles añadidos en la tarea 031 (ADR-0016) ──────────────────
//
// Los dos huecos reales que encontró la auditoría de ADR-0016 al escribir
// los tokens de tipografía/espaciado — no son roles especulativos, cada uno
// tiene ya varios usos duplicados a mano en pantallas existentes.

/// Superficie secundaria: fondo de insignias/iconos/paneles que necesitan
/// distinguirse de [colorSuperficie] sin ser un color de marca puro.
///
/// Hoy varias pantallas (`bienvenida_registro_screen`, `ranking_tab`,
/// `trabajadores_tab`, los dos registros) repiten
/// `AppColores.acento.withOpacity(...)` con valores sueltos y distintos
/// (0.10, 0.12, 0.15, 0.20, 0.35) para el mismo propósito. Este rol les da
/// un nombre único; **no se migran esas pantallas en esta tarea** (031 es
/// solo fundamentos), queda para 032–037.
Color colorSuperficieAlterna(BuildContext c) => _esOscuro(c)
    ? Color.alphaBlend(AppColores.blanco.withValues(alpha: 0.06), AppColores.superficieOscura)
    : AppColores.grisClaro;

/// Fondo/relleno de un control deshabilitado o "próximamente".
///
/// Hoy coincide en valor con [colorBorde] porque así lo resuelve ya
/// `bienvenida_registro_screen` a mano
/// (`proximamente ? colorBorde(context) : AppColores.acento.withOpacity(0.12)`).
/// Se declara aparte, con su propio nombre semántico, para que 032–037 no
/// tengan que adivinar que "deshabilitado" y "borde" comparten valor por
/// coincidencia en vez de por diseño.
Color colorDeshabilitado(BuildContext c) => colorBorde(c);

// ── Rol añadido en la tarea 034 (ADR-0016) ─────────────────────

/// Color de un monto/precio destacado (rol [AppTipografia.numero]) sobre la
/// superficie de una tarjeta.
///
/// La 034 encontró que `tarjeta_trabajo.dart`/`tarjeta_mi_publicacion.dart`
/// pintaban el precio con `AppColores.acento` (dorado) directo sobre
/// [colorSuperficie] — en modo oscuro esa superficie es oscura y el
/// contraste es alto, pero en modo claro es blanco y da ~1.63:1, la misma
/// clase de defecto que arregló la 031 en el botón primario, con
/// texto/fondo invertidos. En oscuro se deja el dorado normal (ya tiene
/// contraste de sobra); en claro se usa [AppColores.doradoTexto].
Color colorPrecio(BuildContext c) =>
    _esOscuro(c) ? AppColores.acento : AppColores.doradoTexto;
