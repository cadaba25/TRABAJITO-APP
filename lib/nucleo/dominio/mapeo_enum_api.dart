/// Conversión entre los enums del backend (`MAYUSCULAS_CON_GUION_BAJO`) y los
/// valores en minúscula que usa la app.
///
/// Está aquí, junto a las constantes, para que ningún servicio ni modelo
/// escriba `"EN_PROGRESO"` a mano.
class MapeoEnumApi {
  /// Pasa el valor del backend a minúsculas y comprueba que sea uno de los
  /// [conocidos]. Si no lo es (el backend añadió un estado que la app no
  /// entiende), devuelve [siNoSeConoce] en vez de propagar un valor que
  /// ninguna pantalla sabe pintar.
  static String desdeApi(
    Object? valor,
    List<String> conocidos, {
    required String siNoSeConoce,
  }) {
    if (valor is! String || valor.isEmpty) return siNoSeConoce;
    final normalizado = valor.trim().toLowerCase();
    return conocidos.contains(normalizado) ? normalizado : siNoSeConoce;
  }

  /// `'en_progreso'` → `"EN_PROGRESO"`.
  static String aApi(String valor) => valor.trim().toUpperCase();
}
