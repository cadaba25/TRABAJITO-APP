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

  /// Tamaño de la empresa (número de empleados).
  static const List<String> tamanos = [
    'Solo yo (independiente)',
    '2 - 10 empleados',
    '11 - 50 empleados',
    '51 - 200 empleados',
    'Más de 200 empleados',
  ];
}
