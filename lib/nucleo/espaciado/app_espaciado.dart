/// Escala de espaciado con nombre de la app (ADR-0016, fase de fundamentos —
/// tarea 031).
///
/// **Ningún `SizedBox(height/width: ...)` ni `EdgeInsets.all/symmetric(...)`
/// nuevo con un número suelto fuera de aquí.** Mismo criterio que
/// `AppMovimiento` (ADR-0015) para duraciones/curvas y `AppTipografia`
/// (ADR-0016) para tipografía.
///
/// Auditoría que motiva esta clase (ADR-0016, `docs/decisions.md`): ≈19
/// valores distintos de espaciado en `SizedBox` (2 a 40) y 7 en
/// `EdgeInsets.all` (6, 12, 14, 16, 20, 24, 32) en
/// `lib/funcionalidades/**`. La escala sugerida por el ADR (4/8/12/16/24/32)
/// cubre 6 de esos 7 valores de `EdgeInsets.all` casi exactos (falta el 14,
/// que es un caso suelto de redondeo entre `md` y `lg`, no un patrón real) y
/// es progresión geométrica ~1.5–2×, suficiente para todo lo medido — se usa
/// tal cual, sin ajustar.
abstract final class AppEspaciado {
  /// 4 px. El hueco más chico: entre un icono y su texto, o entre dos líneas
  /// muy juntas.
  static const double xs = 4;

  /// 8 px. Separación corta dentro de un mismo grupo (chip y su etiqueta,
  /// filas de una lista compacta).
  static const double sm = 8;

  /// 12 px. Separación por defecto entre elementos de un formulario o de una
  /// tarjeta.
  static const double md = 12;

  /// 16 px. Márgenes de pantalla y separación entre secciones chicas. Es el
  /// valor que ya usan los botones/campos de `AppTema`
  /// (`contentPadding` horizontal).
  static const double lg = 16;

  /// 24 px. Separación entre bloques grandes de una pantalla.
  static const double xl = 24;

  /// 32 px. El hueco más grande: encabezados de pantalla, espacio antes de
  /// una acción principal.
  static const double xxl = 32;
}

/// Roles de radio de borde (ADR-0016 decisión 3), consolidando los 10
/// valores sueltos de `BorderRadius.circular(...)` detectados en la
/// auditoría (2, 4, 8, 10, 12, 14, 16, 18, 20, 24) en tres roles con nombre.
///
/// Se declaran como `double` (no `BorderRadius`) para que sirvan tanto a
/// `BorderRadius.circular(...)` como a `RoundedRectangleBorder` o a un
/// `Radius.circular(...)` suelto, sin forzar una forma concreta.
abstract final class AppRadios {
  /// 12 px. Campos de texto y botones — el valor que ya usaba `AppTema`
  /// antes de esta tarea; se nombra, no se cambia (cero cambio visual).
  static const double campo = 12;

  /// 16 px. Tarjetas y contenedores de contenido.
  static const double tarjeta = 16;

  /// 20 px. Chips, pastillas y badges — formas casi/del todo redondeadas.
  static const double chip = 20;
}
