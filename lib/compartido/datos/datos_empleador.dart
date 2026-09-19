// ─────────────────────────────────────────────────────────────
// DATOS DE EMPLEADOR
// ─────────────────────────────────────────────────────────────
class DatosEmpleador {
  /// Sectores / rubros más comunes para servicios autónomos en Honduras.
  static const List<String> sectores = [
    'Hogar y limpieza',
    'Construcción y remodelación',
    'Plomería',
    'Electricidad',
    'Pintura',
    'Jardinería',
    'Mecánica y automotriz',
    'Tecnología e informática',
    'Diseño y publicidad',
    'Belleza y estética',
    'Salud y cuidados',
    'Educación y tutorías',
    'Eventos y catering',
    'Transporte y mudanzas',
    'Comercio y ventas',
    'Restaurante y alimentos',
    'Administración y oficina',
    'Otro',
  ];

  /// Plazo del trabajo por contratación.
  static const List<String> plazos = [
    'Corto plazo',
    'Medio plazo',
    'Largo plazo',
  ];

  /// Unidad por la que se cobra la tarifa de un trabajo (tarea 039). El
  /// `presupuesto` de una publicación sigue siendo texto libre de principio a
  /// fin (`Publicacion.presupuesto`); esta lista solo alimenta el selector
  /// que arma ese texto en `publicar_trabajo_screen.dart`/
  /// `editar_trabajo_screen.dart`, no cambia el contrato con el backend.
  static const List<String> unidadesTarifa = [
    'día',
    'hora',
    'semana',
    'contratación completa',
  ];

  /// Tamaño de la empresa (número de empleados).
  static const List<String> tamanos = [
    'Solo yo (independiente)',
    '2 - 10 empleados',
    '11 - 50 empleados',
    '51 - 200 empleados',
    'Más de 200 empleados',
  ];
}
