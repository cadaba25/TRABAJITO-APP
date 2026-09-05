import 'dart:io' show Platform;

/// Configuración de a qué servidor habla la app y con qué márgenes de tiempo.
///
/// **Por qué no está la URL escrita a fuego:** el backend se ve en una
/// dirección distinta según dónde corra la app (emulador de Android,
/// dispositivo físico en la misma red, servidor de demo). Hay dos formas de
/// fijarla, en este orden de prioridad:
///
/// 1. **Override en caliente** — [fijarUrlBase]. Lo usan los tests y, cuando
///    exista, una pantalla de ajustes de desarrollo. `ApiClient` lo persiste
///    en el almacén del dispositivo, así que **sobrevive al reinicio y no
///    obliga a recompilar**.
/// 2. **En tiempo de compilación** — `--dart-define=TRABAJITO_API_URL=...`:
///
///    ```
///    flutter run --dart-define=TRABAJITO_API_URL=http://192.168.0.15:8080
///    ```
///
/// 3. Si no hay ninguna de las dos, se usa [urlBasePorDefecto], que solo
///    pretende servir para desarrollo local (ver su documentación: en un
///    dispositivo físico **no** funciona y hay que usar 1 o 2).
///
/// Ver `docs/development.md` → "Apuntar la app al backend".
abstract final class ConfiguracionApi {
  ConfiguracionApi._();

  /// Nombre de la variable de `--dart-define`. Se expone para documentarlo en
  /// un solo sitio y que los mensajes de error puedan citarlo.
  static const String variableEntorno = 'TRABAJITO_API_URL';

  static const String _urlCompilada = String.fromEnvironment(variableEntorno);

  static String? _urlEnCaliente;

  /// Puerto en el que escucha el backend Spring Boot (`server.port`).
  static const int puertoBackend = 8080;

  /// Prefijo común de todos los endpoints del backend.
  static const String prefijoApi = '/api';

  /// Cuánto se espera una respuesta antes de darla por perdida.
  ///
  /// Firestore gestionaba esto por su cuenta; con HTTP hay que ponerlo a mano
  /// o una petición contra un servidor caído deja la pantalla cargando para
  /// siempre.
  static const Duration tiempoLimite = Duration(seconds: 20);

  /// Margen con el que se considera "ya caducado" el token de acceso.
  ///
  /// El token vive 15 min (ADR-0010). Se renueva 30 s antes de su caducidad
  /// real para que una petición no salga con un token que caduca en vuelo.
  static const Duration margenRenovacion = Duration(seconds: 30);

  /// URL que se usa cuando nadie ha configurado nada.
  ///
  /// - **Emulador de Android**: `10.0.2.2` es el alias del `localhost` del PC
  ///   visto desde dentro del emulador. `localhost` a secas apunta al propio
  ///   emulador y **no** encuentra el servidor.
  /// - **Cualquier otro sitio** (escritorio, tests): `localhost`.
  /// - **Dispositivo físico**: ninguna de las dos sirve. Hay que pasar la IP
  ///   del PC en la red local con `--dart-define` o [fijarUrlBase].
  static String get urlBasePorDefecto {
    final anfitrion = Platform.isAndroid ? '10.0.2.2' : 'localhost';
    return 'http://$anfitrion:$puertoBackend';
  }

  /// URL base efectiva, sin barra final.
  static String get urlBase {
    final enCaliente = _urlEnCaliente;
    if (enCaliente != null && enCaliente.isNotEmpty) return normalizar(enCaliente);
    if (_urlCompilada.isNotEmpty) return normalizar(_urlCompilada);
    return normalizar(urlBasePorDefecto);
  }

  /// `true` si la URL viene de un `--dart-define` o de un override, es decir,
  /// si alguien la configuró de verdad en vez de caer en el valor por defecto.
  static bool get urlConfigurada =>
      (_urlEnCaliente != null && _urlEnCaliente!.isNotEmpty) ||
      _urlCompilada.isNotEmpty;

  /// Cambia la URL base en caliente. `null` o vacío vuelve al valor anterior
  /// de la cadena (dart-define o defecto).
  static void fijarUrlBase(String? url) {
    _urlEnCaliente = (url == null || url.trim().isEmpty) ? null : url.trim();
  }

  /// Quita la barra final para poder concatenar rutas sin duplicar `/`.
  static String normalizar(String url) {
    var limpia = url.trim();
    while (limpia.endsWith('/')) {
      limpia = limpia.substring(0, limpia.length - 1);
    }
    return limpia;
  }
}

/// Rutas del backend, en un solo sitio para no repetir literales por el
/// código (mismo criterio que `FirestoreColecciones` en `utils/constantes.dart`).
///
/// Están las de la capa de sesión (fase 1) y las del perfil (fase 2a); las
/// fases siguientes irán añadiendo las del resto de servicios.
abstract final class RutasApi {
  RutasApi._();

  static const String registro = '/api/auth/registro';
  static const String login = '/api/auth/login';
  static const String refresh = '/api/auth/refresh';
  static const String logout = '/api/auth/logout';
  static const String yo = '/api/auth/yo';

  // ── Perfil (tarea 020, fase 2a) ─────────────────────────────
  //
  // Ojo con la diferencia entre las dos lecturas de perfil, verificada contra
  // el servidor el 2026-08-27:
  //   · `miPerfil` / `yo`  → vista del dueño: trae correo, DNI, teléfonos,
  //     fecha de nacimiento, saldo y el CV completo.
  //   · `perfilDe(id)`     → vista pública: esos campos llegan `null` (ADR-0011).

  /// `GET`/`PUT`/`DELETE` del perfil propio.
  static const String miPerfil = '/api/usuarios/me';

  /// Reemplaza la lista completa de habilidades propias (`PUT`).
  static const String misHabilidades = '/api/usuarios/me/habilidades';

  /// `POST` para crear una experiencia laboral propia.
  static const String miExperiencia = '/api/usuarios/me/experiencia';

  /// `POST` para crear un estudio propio.
  static const String misEstudios = '/api/usuarios/me/estudios';

  /// Top 50 de trabajadores activos por trabajos completados. Es la única
  /// lista de trabajadores que expone el backend hoy: alimenta a la vez la
  /// pestaña "Trabajadores" y la de "Ranking".
  static const String ranking = '/api/usuarios/ranking';

  /// Perfil **público** de otra persona.
  static String perfilDe(String id) => '/api/usuarios/$id';

  static String miExperienciaPorId(String id) => '$miExperiencia/$id';

  static String miEstudioPorId(String id) => '$misEstudios/$id';

  // ── Trabajos y postulaciones (tarea 026, fase 2b) ───────────
  //
  // Comprobado contra el servidor el 2026-09-04. Tres cosas que no se pueden
  // adivinar mirando `docs/api.md`:
  //
  //   · El feed pagina con `pagina`/`tamano`, **no** con los `page`/`size` de
  //     Spring Data. Mandar `page=0&size=1` no da error: se ignora y devuelve
  //     la página 0 de tamaño 20, que es peor que un fallo. Por eso
  //     `PublicacionService` no usa los parámetros por defecto de
  //     `ApiClient.obtenerPagina`.
  //   · NO existe `PUT`/`PATCH`/`DELETE` de un trabajo. Editar o borrar una
  //     publicación no es posible hoy contra el backend.
  //   · `POST /{id}/cancelar` exige `{"reabrir": true|false}` sin valor por
  //     defecto: si falta, 400.

  /// Feed público de trabajos ACTIVOS (`GET`, paginado) y alta de trabajo
  /// (`POST`).
  static const String trabajos = '/api/trabajos';

  /// Trabajos publicados por quien pide (array pelado, sin paginar).
  static const String misTrabajos = '/api/trabajos/mios';

  /// Trabajos en los que quien pide es el trabajador asignado.
  static const String trabajosAsignados = '/api/trabajos/asignados';

  static String trabajo(String id) => '$trabajos/$id';

  /// Avances del trabajo: `GET` los lista, `POST` añade uno.
  static String evidenciasDe(String id) => '${trabajo(id)}/evidencias';

  /// Transiciones de la máquina de estados (ADR-0007). Cada una la valida el
  /// servidor; el cliente solo dispara.
  static String reservarPago(String id) => '${trabajo(id)}/reservar-pago';
  static String iniciarTrabajo(String id) => '${trabajo(id)}/iniciar';
  static String terminarTrabajo(String id) => '${trabajo(id)}/terminar';
  static String solicitarCorreccion(String id) =>
      '${trabajo(id)}/solicitar-correccion';
  static String aceptarTrabajo(String id) => '${trabajo(id)}/aceptar';
  static String cancelarTrabajo(String id) => '${trabajo(id)}/cancelar';
  static String rechazarTrabajo(String id) => '${trabajo(id)}/rechazar';
  static String reclamarTrabajo(String id) => '${trabajo(id)}/reclamar';

  /// `POST` para postularse; `GET ?trabajoId=` lista los postulantes de un
  /// trabajo (solo el dueño).
  static const String postulaciones = '/api/postulaciones';

  /// Postulaciones propias del trabajador.
  static const String misPostulaciones = '/api/postulaciones/mias';

  /// `DELETE` retira la postulación propia.
  static String postulacion(String id) => '$postulaciones/$id';

  /// El empleador elige a este postulante: asigna el trabajo, rechaza a los
  /// demás y **crea el chat** (todo en el servidor, en una transacción).
  static String aceptarPostulacion(String id) => '${postulacion(id)}/aceptar';
}
