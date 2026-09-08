import 'mapeo_enum_api.dart';

/// Roles tal y como los nombra el backend (enum `Rol`).
///
/// La app los guarda en minúscula (`'trabajador'`, `'empleador'`) desde
/// Firestore; el backend los manda en mayúscula. `ADMIN` no tiene pantallas en
/// la app (el panel de administración es solo de la API), pero se conserva
/// como `'admin'` en vez de convertirlo en otro rol: rebajarlo a empleador
/// sería inventarle permisos que no le tocan.
class RolesApi {
  static const String admin = 'admin';

  static const List<String> todos = [
    ValoresDefecto.rolTrabajador,
    ValoresDefecto.rolEmpleador,
    admin,
  ];

  /// `"TRABAJADOR"` → `'trabajador'`. Lo desconocido cae en trabajador, que es
  /// el rol con menos privilegios.
  static String desdeApi(Object? valor) => MapeoEnumApi.desdeApi(
        valor,
        todos,
        siNoSeConoce: ValoresDefecto.rolTrabajador,
      );

  static String aApi(String rol) => MapeoEnumApi.aApi(rol);
}

class ValoresDefecto {
  static const String rolTrabajador   = 'trabajador';
  static const String rolEmpleador    = 'empleador';
  static const String fotoPerfilVacia = '';
  static const String estadoActivo    = 'activo';
}
