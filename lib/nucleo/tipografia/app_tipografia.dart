import 'package:flutter/material.dart';

/// Type scale con nombre de la app (ADR-0016, fase de fundamentos — tarea 031).
///
/// **Ningún `TextStyle(fontSize: ..., fontWeight: ...)` literal nuevo fuera de
/// aquí.** Si una pantalla necesita un tamaño/peso/interlineado que no está en
/// esta lista, se añade aquí primero — exactamente el mismo criterio que
/// `AppMovimiento` fijó para duraciones y curvas en ADR-0015.
///
/// Auditoría que motiva esta clase (ADR-0016, `docs/decisions.md`): 18
/// valores de `fontSize` y 5 de `fontWeight` sueltos en
/// `lib/funcionalidades/**`, sin criterio documentado de cuándo usar cada
/// uno. Cada rol de aquí fija tamaño + peso + interlineado **como conjunto**
/// (principio de `apple-design` §15), no solo el tamaño.
///
/// La familia tipográfica es siempre `Sora` — no cambia con el rol ni con el
/// tema (ADR-0016 decisión 1: la fuente de marca no se toca).
///
/// **Roles** (6 sugeridos por ADR-0016 + 1 que la auditoría de esta tarea
/// encontró que faltaba — ver `docs/agent-reports/031-*.md`):
/// - [tituloGrande]: cabeceras de bienvenida/hero (ADR-0016 no lo preveía;
///   la auditoría encontró `fontSize: 28/w900` en `bienvenida_registro_screen`
///   sin ningún rol de la lista original que lo cubriera — `titulo` a 22 es
///   demasiado chico para ese uso).
/// - [titulo]: título de sección/pantalla.
/// - [subtitulo]: subtítulos y cabeceras de tarjeta.
/// - [cuerpo]: texto de cuerpo por defecto.
/// - [cuerpoChico]: texto secundario/metadatos.
/// - [etiqueta]: chips, badges, texto de apoyo muy pequeño.
/// - [numero]: montos y precios — cifras tabulares para que no "bailen" al
///   cambiar de dígito.
abstract final class AppTipografia {
  static const String familia = 'Sora';

  /// Cabeceras de bienvenida/hero. 28 / w800 / interlineado 1.2.
  static const TextStyle tituloGrande = TextStyle(
    fontFamily: familia,
    fontSize: 28,
    fontWeight: FontWeight.w800,
    height: 1.2,
    letterSpacing: -0.5,
  );

  /// Título de sección o de pantalla. 22 / w700 / interlineado 1.25.
  static const TextStyle titulo = TextStyle(
    fontFamily: familia,
    fontSize: 22,
    fontWeight: FontWeight.w700,
    height: 1.25,
    letterSpacing: -0.3,
  );

  /// Subtítulo o cabecera de tarjeta. 17 / w600 / interlineado 1.3.
  static const TextStyle subtitulo = TextStyle(
    fontFamily: familia,
    fontSize: 17,
    fontWeight: FontWeight.w600,
    height: 1.3,
  );

  /// Cuerpo de texto por defecto. 15 / w500 / interlineado 1.4.
  static const TextStyle cuerpo = TextStyle(
    fontFamily: familia,
    fontSize: 15,
    fontWeight: FontWeight.w500,
    height: 1.4,
  );

  /// Texto secundario o metadatos (fechas, ubicaciones, contadores).
  /// 13 / w500 / interlineado 1.35.
  static const TextStyle cuerpoChico = TextStyle(
    fontFamily: familia,
    fontSize: 13,
    fontWeight: FontWeight.w500,
    height: 1.35,
  );

  /// Chips, badges y texto de apoyo muy pequeño. 11 / w600 / interlineado
  /// 1.2, con tracking positivo (a este tamaño hace falta más separación
  /// entre letras para no verse apretado — `apple-design` §15).
  static const TextStyle etiqueta = TextStyle(
    fontFamily: familia,
    fontSize: 11,
    fontWeight: FontWeight.w600,
    height: 1.2,
    letterSpacing: 0.3,
  );

  /// Montos y precios. 20 / w700 / interlineado 1.1, con cifras tabulares
  /// (mismo ancho por dígito) para que un monto no cambie de anchura al
  /// actualizarse.
  static const TextStyle numero = TextStyle(
    fontFamily: familia,
    fontSize: 20,
    fontWeight: FontWeight.w700,
    height: 1.1,
    fontFeatures: [FontFeature.tabularFigures()],
  );
}

/// Acceso a los roles de [AppTipografia] desde `Theme.of(context).textTheme`,
/// tal como pide ADR-0016 ("accesible desde `Theme.of(context).textTheme.<rol>`
/// ... o un helper equivalente — documenta la decisión").
///
/// **Decisión documentada:** `TextTheme` de Material fija de antemano sus
/// campos (`bodyLarge`, `titleMedium`, etc.); no se puede *añadir* un campo
/// nuevo a esa clase sin perder los roles nativos que Flutter/Material usan
/// internamente (por ejemplo, `AppBar`/`Text` widgets que leen `bodyMedium`
/// por defecto). Una extensión de Dart resuelve exactamente esto: agrega
/// getters con nombre (`titulo`, `cuerpo`, ...) al `TextTheme` existente
/// **sin tocar ni sustituir** ninguno de sus campos nativos, así que
/// `Theme.of(context).textTheme.bodyLarge` y
/// `Theme.of(context).textTheme.titulo` conviven. Es el mismo patrón que ya
/// usa el propio SDK de Flutter para extensiones de tema.
extension AppTextThemeExtension on TextTheme {
  TextStyle get tituloGrande => AppTipografia.tituloGrande;
  TextStyle get titulo => AppTipografia.titulo;
  TextStyle get subtitulo => AppTipografia.subtitulo;
  TextStyle get cuerpo => AppTipografia.cuerpo;
  TextStyle get cuerpoChico => AppTipografia.cuerpoChico;
  TextStyle get etiqueta => AppTipografia.etiqueta;
  TextStyle get numero => AppTipografia.numero;
}
