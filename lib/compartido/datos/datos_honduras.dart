// ─────────────────────────────────────────────────────────────
// DATOS DE HONDURAS
// ─────────────────────────────────────────────────────────────
class DatosHonduras {
  static const List<String> departamentos = [
    'Atlántida', 'Choluteca', 'Colón', 'Comayagua', 'Copán',
    'Cortés', 'El Paraíso', 'Francisco Morazán', 'Gracias a Dios',
    'Intibucá', 'Islas de la Bahía', 'La Paz', 'Lempira',
    'Ocotepeque', 'Olancho', 'Santa Bárbara', 'Valle', 'Yoro',
  ];

  static const Map<String, List<String>> ciudadesPorDepartamento = {
    'Atlántida':           ['La Ceiba', 'El Porvenir', 'Esparta', 'Jutiapa', 'La Masica', 'San Francisco', 'Tela', 'Arizona'],
    'Choluteca':           ['Choluteca', 'Apacilagua', 'Concepción de María', 'Duyure', 'El Corpus', 'El Triunfo', 'Marcovia', 'Morolica', 'Namasigüe', 'Orocuina', 'Pespire', 'San Antonio de Flores', 'San Isidro', 'San José', 'San Marcos de Colón', 'Santa Ana de Yusguare'],
    'Colón':               ['Trujillo', 'Balfate', 'Iriona', 'Limón', 'Sabá', 'Santa Fe', 'Santa Rosa de Aguán', 'Sonaguera', 'Tocoa', 'Bonito Oriental'],
    'Comayagua':           ['Comayagua', 'Ajuterique', 'El Rosario', 'Esquías', 'Humuya', 'La Libertad', 'Lamaní', 'La Trinidad', 'Lejamaní', 'Meámbar', 'Minas de Oro', 'Ojos de Agua', 'San Jerónimo', 'San José de Comayagua', 'San José del Potrero', 'San Luis', 'San Sebastián', 'Siguatepeque', 'Trinidad', 'Villa de San Antonio'],
    'Copán':               ['Santa Rosa de Copán', 'Cabañas', 'Concepción', 'Copán Ruinas', 'Corquín', 'Cucuyagua', 'Dolores', 'Dulce Nombre', 'El Paraíso', 'Florida', 'La Jigua', 'La Unión', 'Nueva Arcadia', 'San Agustín', 'San Antonio', 'San Jerónimo', 'San José', 'San Juan de Opoa', 'San Nicolás', 'San Pedro', 'Santa Rita', 'Trinidad de Copán', 'Veracruz'],
    'Cortés':              ['San Pedro Sula', 'Choloma', 'La Lima', 'Omoa', 'Pimienta', 'Potrerillos', 'Puerto Cortés', 'San Antonio de Cortés', 'San Francisco de Yojoa', 'San Manuel', 'Santa Cruz de Yojoa', 'Villanueva', 'El Progreso'],
    'El Paraíso':          ['Yuscarán', 'Alauca', 'Danlí', 'El Paraíso', 'Güinope', 'Jacaleapa', 'Liure', 'Morocelí', 'Oropolí', 'Potrerillos', 'San Antonio de Flores', 'San Lucas', 'San Matías', 'Soledad', 'Teupasenti', 'Texiguat', 'Vado Ancho', 'Yauyupe', 'Trojes'],
    'Francisco Morazán':   ['Tegucigalpa', 'Alubaren', 'Cedros', 'Curarén', 'El Porvenir', 'Güaimaca', 'La Libertad', 'La Venta', 'Lepaterique', 'Maraita', 'Marale', 'Nueva Armenia', 'Ojojona', 'Orica', 'Reitoca', 'Sabanagrande', 'San Antonio de Oriente', 'San Buenaventura', 'San Ignacio', 'San Juan de Flores', 'San Miguelito', 'Santa Ana', 'Santa Lucía', 'Talanga', 'Tatumbla', 'Valle de Ángeles', 'Villa de San Francisco', 'Vallecillo'],
    'Gracias a Dios':      ['Puerto Lempira', 'Brus Laguna', 'Ahuas', 'Juan Francisco Bulnes', 'Villeda Morales', 'Wampusirpe'],
    'Intibucá':            ['La Esperanza', 'Camasca', 'Colomoncagua', 'Concepción', 'Dolores', 'Intibucá', 'Jesús de Otoro', 'Magdalena', 'Masaguara', 'San Antonio', 'San Isidro', 'San Juan', 'San Marcos de la Sierra', 'San Miguelito', 'Santa Lucía', 'Yamaranguila', 'San Francisco de Opalaca'],
    'Islas de la Bahía':   ['Roatán', 'Guanaja', 'José Santos Guardiola', 'Utila'],
    'La Paz':              ['La Paz', 'Aguanqueterique', 'Cabañas', 'Cane', 'Chinacla', 'Guajiquiro', 'Lauterique', 'Marcala', 'Mercedes de Oriente', 'Opatoro', 'San Antonio del Norte', 'San Juan', 'San Pedro de Tutule', 'Santa Ana', 'Santa Elena', 'Santa María', 'Santiago de Puringla', 'Yarula'],
    'Lempira':             ['Gracias', 'Belén', 'Candelaria', 'Cololaca', 'Erandique', 'Gualcince', 'Guarita', 'La Campa', 'La Iguala', 'Las Flores', 'La Unión', 'La Virtud', 'Lepaera', 'Mapulaca', 'Piraera', 'San Andrés', 'San Francisco', 'San Juan Guarita', 'San Manuel Colohete', 'San Rafael', 'San Sebastián', 'Santa Cruz', 'Talgua', 'Tambla', 'Tomalá', 'Valladolid', 'Virginia', 'San Marcos de Caiquín'],
    'Ocotepeque':          ['Ocotepeque', 'Belén Gualcho', 'Concepción', 'Dolores Merendón', 'Fraternidad', 'La Encarnación', 'La Labor', 'Lucerna', 'Mercedes', 'San Fernando', 'San Francisco del Valle', 'San Jorge', 'San Marcos', 'Santa Fe', 'Sensenti', 'Sinuapa'],
    'Olancho':             ['Juticalpa', 'Campamento', 'Catacamas', 'Concordia', 'Dulce Nombre de Culmí', 'El Rosario', 'Esquipulas del Norte', 'Gualaco', 'Guarizama', 'Guata', 'Guayape', 'Jano', 'La Unión', 'Mangulile', 'Manto', 'Salamá', 'San Esteban', 'San Francisco de Becerra', 'San Francisco de la Paz', 'Santa María del Real', 'Silca', 'Yocón', 'Patuca'],
    'Santa Bárbara':       ['Santa Bárbara', 'Arada', 'Atima', 'Azacualpa', 'Ceguaca', 'Chinda', 'Concepción del Norte', 'Concepción del Sur', 'El Níspero', 'Gualala', 'Ilama', 'Macuelizo', 'Naranjito', 'Nuevo Celilac', 'Petoa', 'Protección', 'Quimistán', 'San Francisco de Ojuera', 'San José de Colinas', 'San Luis', 'San Marcos', 'San Nicolás', 'San Pedro Zacapa', 'San Vicente Centenario', 'Santa Rita', 'Trinidad'],
    'Valle':               ['Nacaome', 'Alianza', 'Amapala', 'Aramecina', 'Caridad', 'Goascorán', 'Langue', 'San Francisco de Coray', 'San Lorenzo'],
    'Yoro':                ['Yoro', 'Arenal', 'El Negrito', 'El Progreso', 'Jocón', 'Morazán', 'Olanchito', 'Santa Rita', 'Sulaco', 'Victoria', 'Yorito'],
  };

  static const List<String> generos = [
    'Masculino', 'Femenino', 'Prefiero no decirlo',
  ];

  static const List<String> nivelesEstudio = [
    'Primaria', 'Secundaria', 'Técnico', 'Universidad', 'Maestría', 'Doctorado',
  ];

  /// Habilidades/oficios sugeridos para autocompletar el perfil del trabajador.
  static const List<String> habilidadesSugeridas = [
    // Hogar y limpieza
    'Limpieza', 'Limpieza profunda', 'Lavado de autos', 'Planchado',
    'Cuidado de mascotas', 'Niñera', 'Cuidado de adultos mayores',
    // Construcción y mantenimiento
    'Plomería', 'Electricidad', 'Pintura', 'Albañilería', 'Carpintería',
    'Herrería', 'Soldadura', 'Enderezado y pintura', 'Techos',
    'Instalación de pisos', 'Drywall', 'Impermeabilización',
    // Jardinería y campo
    'Jardinería', 'Poda de árboles', 'Fumigación', 'Agricultura',
    // Mecánica y transporte
    'Mecánica', 'Mecánica de motos', 'Electricidad automotriz',
    'Conducción', 'Mudanzas', 'Mensajería', 'Fletes', 'Mototaxi',
    // Tecnología
    'Reparación de computadoras', 'Reparación de celulares',
    'Instalación de cámaras', 'Redes e internet', 'Soporte técnico',
    'Aire acondicionado', 'Refrigeración',
    'Reparación de electrodomésticos', 'Cerrajería',
    // Belleza y salud
    'Belleza', 'Barbería', 'Maquillaje', 'Uñas', 'Masajes', 'Enfermería',
    // Alimentos y eventos
    'Cocina', 'Repostería', 'Bartender', 'Mesero', 'Catering',
    'Decoración de eventos', 'Fotografía', 'Edición de video', 'DJ',
    // Oficina y creativo
    'Costura', 'Diseño gráfico', 'Community manager', 'Redacción',
    'Contabilidad', 'Tutorías', 'Traducción', 'Atención al cliente',
    'Ventas', 'Marketing digital',
  ];
}
