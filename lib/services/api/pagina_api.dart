import 'api_excepciones.dart';

/// Una página de resultados del backend.
///
/// Spring Data devuelve las listas paginadas con este envoltorio (verificado
/// contra el servidor real en `GET /api/trabajos?page=0&size=1`):
///
/// ```json
/// {"content":[...],"totalElements":27,"totalPages":2,"number":0,"size":20,
///  "first":true,"last":false,"numberOfElements":20,"empty":false,
///  "pageable":{...},"sort":{...}}
/// ```
///
/// No todos los endpoints paginan: algunos devuelven un array pelado. Por eso
/// [desdeJson] acepta las dos formas y trata el array como una página única.
///
/// **Para qué sirve en la fase 2:** el `tech-lead` decidió que los
/// `StreamBuilder` de Firestore se sustituyen por carga puntual +
/// `RefreshIndicator`. Ese patrón necesita saber si hay más páginas
/// ([hayMas]) para el scroll infinito, y cuántos elementos hay en total para
/// los contadores de la UI.
class PaginaApi<T> {
  const PaginaApi({
    required this.elementos,
    required this.pagina,
    required this.tamano,
    required this.totalElementos,
    required this.totalPaginas,
    required this.esPrimera,
    required this.esUltima,
  });

  final List<T> elementos;

  /// Índice de esta página, empezando en 0.
  final int pagina;

  /// Tamaño de página pedido.
  final int tamano;

  /// Total de elementos en todas las páginas.
  final int totalElementos;

  final int totalPaginas;
  final bool esPrimera;
  final bool esUltima;

  bool get estaVacia => elementos.isEmpty;

  /// `true` si queda al menos una página por pedir.
  bool get hayMas => !esUltima;

  /// Número de la página siguiente, o `null` si esta es la última.
  int? get paginaSiguiente => hayMas ? pagina + 1 : null;

  /// Página única a partir de una lista ya construida (para endpoints que
  /// devuelven un array pelado, o para tests).
  factory PaginaApi.unica(List<T> elementos) => PaginaApi<T>(
        elementos: elementos,
        pagina: 0,
        tamano: elementos.length,
        totalElementos: elementos.length,
        totalPaginas: elementos.isEmpty ? 0 : 1,
        esPrimera: true,
        esUltima: true,
      );

  /// Lee el envoltorio de Spring o un array pelado y aplica [mapear] a cada
  /// elemento.
  ///
  /// Lanza [RespuestaIlegible] si lo recibido no es ninguna de las dos cosas,
  /// que es lo que pasa cuando la app apunta a algo que no es el backend.
  static PaginaApi<T> desdeJson<T>(
    Object? json,
    T Function(Map<String, dynamic> elemento) mapear,
  ) {
    if (json is List) {
      return PaginaApi<T>.unica(_mapearLista(json, mapear));
    }
    if (json is! Map<String, dynamic>) {
      throw RespuestaIlegible(
          detalle: 'Se esperaba una lista o una página; llegó ${json.runtimeType}');
    }
    final contenido = json['content'];
    if (contenido is! List) {
      throw RespuestaIlegible(
          detalle: 'La página no trae "content" como lista (llegó '
              '${contenido.runtimeType})');
    }
    final elementos = _mapearLista(contenido, mapear);
    return PaginaApi<T>(
      elementos: elementos,
      pagina: _entero(json['number']),
      tamano: _entero(json['size'], siFalta: elementos.length),
      totalElementos: _entero(json['totalElements'], siFalta: elementos.length),
      totalPaginas: _entero(json['totalPages'], siFalta: 1),
      esPrimera: json['first'] is bool ? json['first'] as bool : true,
      esUltima: json['last'] is bool ? json['last'] as bool : true,
    );
  }

  static List<T> _mapearLista<T>(
    List<Object?> crudos,
    T Function(Map<String, dynamic>) mapear,
  ) {
    final resultado = <T>[];
    for (final elemento in crudos) {
      if (elemento is! Map) {
        throw RespuestaIlegible(
            detalle: 'Elemento de lista que no es un objeto: '
                '${elemento.runtimeType}');
      }
      resultado.add(mapear(Map<String, dynamic>.from(elemento)));
    }
    return resultado;
  }

  static int _entero(Object? valor, {int siFalta = 0}) =>
      valor is num ? valor.toInt() : siFalta;

  @override
  String toString() => 'PaginaApi(${elementos.length}/$totalElementos, '
      'página ${pagina + 1}/$totalPaginas)';
}
