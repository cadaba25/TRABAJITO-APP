// ignore_for_file: invalid_use_of_protected_member
// `setState` es `@protected` de `State`, pensado para impedir que código
// AJENO al widget lo llame desde fuera. Aquí el "ajeno" es aparente: el
// analizador no reconoce los métodos de una `extension on
// _RegistroEmpleadorScreenState` como "instance members of subclasses of
// State" (no forman parte de la jerarquía de clases, aunque compartan
// biblioteca vía `part of`), así que marca cada llamada. En tiempo de
// ejecución es exactamente `_RegistroEmpleadorScreenState` (un `State` de
// verdad) llamando a su propio `setState`, ni más ni menos que si el método
// estuviera escrito dentro de la clase — la supresión es de este archivo
// nada más, no de todo el proyecto.
part of 'registro_empleador_screen.dart';

/// Lógica de avanzar/validar/guardar de [RegistroEmpleadorScreen], separada
/// del archivo de la pantalla para que este último se quede por debajo del
/// techo de 300 líneas de ADR-0014 tras aplicar los tokens de ADR-0016
/// (tarea 033) — ver la decisión completa en `docs/agent-reports/033-*.md`.
///
/// Es una extensión sobre `_RegistroEmpleadorScreenState`, no una clase ni
/// un servicio nuevo: como `part of` comparte biblioteca con
/// `registro_empleador_screen.dart`, tiene acceso completo a los campos
/// privados del `State` sin exponer nada nuevo ni cambiar una sola regla de
/// negocio. Mismo motivo que en `registro_trabajador_logica.dart`: estos
/// métodos dependen unos de otros (edad mínima antes de guardar, orden de
/// llamadas a `PerfilService`, ramas persona/empresa) y moverlos a un widget
/// sin estado habría sido un refactor de comportamiento, no solo de
/// presentación.
extension _LogicaRegistroEmpleador on _RegistroEmpleadorScreenState {
  // ─────────────────────────────────────────────────────────
  // VALIDAR Y AVANZAR PASO
  // ─────────────────────────────────────────────────────────
  Future<void> _avanzar() async {
    // Evita envíos duplicados (p. ej. doble toque) que podrían crear
    // múltiples cuentas o guardar datos repetidos.
    if (_cargando) return;
    switch (_paso) {
      case 1: await _avanzarPaso1(); break;
      case 2: await _avanzarPaso2(); break;
      case 3: await _finalizarRegistro(); break;
    }
  }

  Future<void> _avanzarPaso1() async {
    if (!_p1Form.currentState!.validate()) return;
    if (!_terminosAceptados) {
      mostrarSnackBar(context, 'Debes aceptar los términos y condiciones', esError: true);
      return;
    }
    setState(() => _cargando = true);
    // Un solo `POST /api/auth/registro` crea la cuenta y abre la sesión. Los
    // campos de empresa no caben en `RegistroRequest` (solo admite correo,
    // contraseña, nombres, apellidos, DNI, teléfono, rol, departamento y
    // ciudad), así que van justo después con `PUT /api/usuarios/me`.
    final error = await _authService.registrar(
      datos: Usuario(
        uid: '', // lo asigna el servidor
        tipoUsuario: ValoresDefecto.rolEmpleador,
        nombres: _nombresCtrl.text.trim(),
        apellidos: _apellidosCtrl.text.trim(),
        dni: _dniCtrl.text.trim(),
        correo: _correoCtrl.text.trim(),
        fechaRegistro: DateTime.now(),
        rol: ValoresDefecto.rolEmpleador,
      ),
      contrasena: _contrasenaCtrl.text,
    );
    if (!mounted) return;
    if (error != null) {
      setState(() => _cargando = false);
      mostrarSnackBar(context, error, esError: true);
      return;
    }
    final errorEmpresa = await _perfilService.actualizarCampos({
      'tipoEmpleador': _tipoEmpleador,
      'nombreEmpresa': _esEmpresa ? _nombreEmpresaCtrl.text.trim() : '',
      'rtn': _esEmpresa ? _rtnCtrl.text.trim() : '',
      'cargoContacto': _esEmpresa ? _cargoCtrl.text.trim() : '',
    });
    if (!mounted) return;
    setState(() => _cargando = false);
    if (errorEmpresa != null) {
      mostrarSnackBar(context, errorEmpresa, esError: true);
      return;
    }
    _setPaso(2);
  }

  Future<void> _avanzarPaso2() async {
    if (!_p2Form.currentState!.validate()) return;
    // La mayoría de edad es obligatoria para todos (persona o contacto).
    if (!_esMayor18()) {
      mostrarSnackBar(context, MensajesError.menorEdad, esError: true);
      return;
    }
    final fechaNac = '${_diaCtrl.text}/${_mesCtrl.text}/${_anioCtrl.text}';
    setState(() => _cargando = true);
    // El servidor vuelve a exigir los 18 años (ADR-0011) y responde 400 con el
    // motivo en español si no se cumplen: ya no se puede ignorar el resultado.
    final error = await _perfilService.actualizarCampos({
      'fechaNacimiento': fechaNac,
      'telefono': _telefonoCtrl.text.trim(),
      'telefonoEmergencia': _telAltCtrl.text.trim(),
      'viveEnHonduras': true,
      'departamento': _departamento ?? '',
      'ciudad': _ciudad ?? '',
      'codigoPostal': _cpCtrl.text.trim(),
      'pais': 'Honduras',
    });
    if (!mounted) return;
    setState(() => _cargando = false);
    if (error != null) {
      mostrarSnackBar(context, error, esError: true);
      return;
    }
    // Las personas particulares no tienen paso adicional; las empresas sí.
    if (_esEmpresa) {
      _setPaso(3);
    } else {
      await _finalizarPersona();
    }
  }

  Future<void> _finalizarPersona() async {
    setState(() => _cargando = true);
    final error =
        await _perfilService.actualizarCampos({'registroCompleto': true});
    if (!mounted) return;
    setState(() => _cargando = false);
    if (error != null) {
      mostrarSnackBar(context, error, esError: true);
      return;
    }
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _finalizarRegistro() async {
    if (!_p3Form.currentState!.validate()) return;
    setState(() => _cargando = true);
    final error = await _perfilService.actualizarCampos({
      'sectorEmpresa': _sectorEmpresa ?? '',
      'tamanoEmpresa': _esEmpresa ? (_tamanoEmpresa ?? '') : '',
      'sitioWeb': _sitioWebCtrl.text.trim(),
      'descripcionEmpresa': _descripcionCtrl.text.trim(),
      'registroCompleto': true,
    });
    if (!mounted) return;
    setState(() => _cargando = false);
    if (error != null) {
      mostrarSnackBar(context, error, esError: true);
      return;
    }
    // Volver a la raíz: PantallaInicial ya tiene sesión activa y
    // mostrará la pantalla principal.
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  bool _esMayor18() {
    try {
      final dia = int.parse(_diaCtrl.text);
      final mes = int.parse(_mesCtrl.text);
      final anio = int.parse(_anioCtrl.text);
      final nac = DateTime(anio, mes, dia);
      final hoy = DateTime.now();
      final edad = hoy.year - nac.year -
          ((hoy.month < nac.month || (hoy.month == nac.month && hoy.day < nac.day)) ? 1 : 0);
      return edad >= 18;
    } catch (_) {
      return false;
    }
  }

  void _setPaso(int p) => setState(() => _paso = p);

  void _retroceder() {
    if (_paso > 1) {
      setState(() => _paso--);
    } else {
      Navigator.pop(context);
    }
  }
}
