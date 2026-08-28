/// Ayudas para leer el JSON del backend en los modelos.
///
/// Existen porque el backend manda `null` en cualquier campo opcional
/// (verificado contra el servidor real: `"dni":null`, `"fotoUrl":null`,
/// `"trabajadorAsignadoId":null`...), mientras que los modelos de la app usan
/// cadena vacía y `0` como "sin valor" —así lo hacía `desdeFirestore()`—.
/// Sin estas ayudas, cada `desdeJson()` acabaría lleno de `?? ''` y de casts
/// que revientan cuando llega un tipo inesperado.
///
/// Regla general: **un JSON raro no debe tumbar una pantalla**. Cuando un
/// campo no se entiende se devuelve el valor por defecto, igual que hacía la
/// capa de Firestore.
library;

/// Texto, o `''` si viene `null`, ausente o de otro tipo.
String textoJson(Object? valor, [String siFalta = '']) =>
    valor is String ? valor : (valor == null ? siFalta : '$valor');

/// Número decimal (montos, calificaciones). El backend serializa los
/// `BigDecimal` como número JSON (`0`, `0.00`, `1250.50`), pero se acepta
/// también texto por si algún endpoint los manda entrecomillados.
double decimalJson(Object? valor, [double siFalta = 0]) {
  if (valor is num) return valor.toDouble();
  if (valor is String) return double.tryParse(valor) ?? siFalta;
  return siFalta;
}

/// Número entero (contadores, estrellas).
int enteroJson(Object? valor, [int siFalta = 0]) {
  if (valor is num) return valor.toInt();
  if (valor is String) return int.tryParse(valor) ?? siFalta;
  return siFalta;
}

/// Booleano. El backend los manda como `true`/`false` de verdad; se acepta
/// `"true"` por si acaso.
bool boolJson(Object? valor, [bool siFalta = false]) {
  if (valor is bool) return valor;
  if (valor is String) return valor.toLowerCase() == 'true';
  return siFalta;
}

/// Fecha ISO-8601 en UTC, tal y como Jackson serializa un `Instant`:
/// `"2026-08-27T04:46:47.688473359Z"` (nanosegundos incluidos — `DateTime`
/// los trunca a microsegundos, que es de sobra).
///
/// Devuelve `null` si el campo falta o no se puede leer, para que el modelo
/// decida si eso significa "sin fecha" o "ahora".
DateTime? fechaJsonOpcional(Object? valor) {
  if (valor is! String || valor.isEmpty) return null;
  return DateTime.tryParse(valor)?.toLocal();
}

/// Como [fechaJsonOpcional] pero con valor por defecto, para los campos que en
/// el modelo de la app no son nulables (`fechaCreacion`, `fecha`...).
///
/// Se usa la hora local del dispositivo como último recurso, igual que hacía
/// `desdeFirestore()`.
DateTime fechaJson(Object? valor, {DateTime? siFalta}) =>
    fechaJsonOpcional(valor) ?? siFalta ?? DateTime.now();

/// Convierte un `DateTime` al formato que espera el backend: ISO-8601 **en
/// UTC**, con `Z` al final. Mandar la hora local sin zona haría que el
/// servidor la interpretara como UTC y desplazara todo 6 horas (Honduras es
/// UTC-6).
String fechaAJson(DateTime fecha) => fecha.toUtc().toIso8601String();

/// Lista de textos (`habilidades`, `participantes`).
List<String> listaTextoJson(Object? valor) {
  if (valor is! List) return const [];
  return valor.map((e) => '$e').toList(growable: false);
}

/// Lista de objetos JSON, ya tipada. Los elementos que no sean objetos se
/// descartan en vez de tumbar el parseo entero.
List<Map<String, dynamic>> listaObjetosJson(Object? valor) {
  if (valor is! List) return const [];
  return [
    for (final e in valor)
      if (e is Map) Map<String, dynamic>.from(e),
  ];
}
