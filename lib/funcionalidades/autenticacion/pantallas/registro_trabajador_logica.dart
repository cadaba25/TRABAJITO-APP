// ignore_for_file: invalid_use_of_protected_member
// `setState`/`widget` son `@protected` de `State`, pensado para impedir que
// código AJENO al widget lo llame desde fuera. Aquí el "ajeno" es aparente:
// el analizador no reconoce los métodos de una `extension on
// _RegistroTrabajadorScreenState` como "instance members of subclasses of
// State" (no forman parte de la jerarquía de clases, aunque compartan
// biblioteca vía `part of`), así que marca cada llamada. En tiempo de
// ejecución es exactamente `_RegistroTrabajadorScreenState` (un `State` de
// verdad) llamando a su propio `setState`, ni más ni menos que si el método
// estuviera escrito dentro de la clase — la supresión es de este archivo
// nada más, no de todo el proyecto.
part of 'registro_trabajador_screen.dart';

/// Lógica de avanzar/validar/guardar de [RegistroTrabajadorScreen], separada
/// del archivo de la pantalla para que este último se quede por debajo del
/// techo de 300 líneas de ADR-0014 tras aplicar los tokens de ADR-0016
/// (tarea 033) — ver la decisión completa en `docs/agent-reports/033-*.md`.
///
/// Es una extensión sobre `_RegistroTrabajadorScreenState`, no una clase ni
/// un servicio nuevo: como `part of` comparte biblioteca con
/// `registro_trabajador_screen.dart`, tiene acceso completo a los campos
/// privados del `State` (`_p1Form`, `_authService`, `setState`, etc.) sin
/// exponer nada nuevo ni cambiar una sola regla de negocio. Es el mismo
/// motivo por el que la tarea 033 decidió NO mover estos métodos a los
/// widgets de cada paso: dependen unos de otros (edad mínima antes de
/// guardar, orden de llamadas a `PerfilService`) y moverlos a un widget sin
/// estado habría sido un refactor de comportamiento, no solo de
/// presentación.
extension _LogicaRegistroTrabajador on _RegistroTrabajadorScreenState {
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
      case 3: _setPaso(4); break; // CV es opcional
      case 4: await _avanzarPaso4(); break;
      case 5: await _finalizarRegistro(); break;
    }
  }

  Future<void> _avanzarPaso1() async {
    if (!_p1Form.currentState!.validate()) return;
    if (!_terminosAceptados) {
      mostrarSnackBar(context, 'Debes aceptar los términos y condiciones', esError: true);
      return;
    }
    setState(() => _cargando = true);
    // Un solo `POST /api/auth/registro`: crea la cuenta y deja la sesión
    // iniciada. Con Firebase eran dos pasos (cuenta en Auth + documento en
    // Firestore) y el segundo podía fallar dejando una cuenta sin perfil.
    final error = await _authService.registrar(
      datos: Usuario(
        uid: '', // lo asigna el servidor
        tipoUsuario: ValoresDefecto.rolTrabajador,
        nombres: _nombresCtrl.text.trim(),
        apellidos: _apellidosCtrl.text.trim(),
        dni: _dniCtrl.text.trim(),
        correo: _correoCtrl.text.trim(),
        fechaRegistro: DateTime.now(),
        rol: ValoresDefecto.rolTrabajador,
      ),
      contrasena: _contrasenaCtrl.text,
    );
    if (!mounted) return;
    setState(() => _cargando = false);
    if (error != null) {
      mostrarSnackBar(context, error, esError: true);
      return;
    }
    _setPaso(2);
  }

  Future<void> _avanzarPaso2() async {
    if (!_p2Form.currentState!.validate()) return;
    // Validar edad mínima 18 años (bloqueante)
    if (!_esMayor18()) {
      mostrarSnackBar(context, MensajesError.menorEdad, esError: true);
      return;
    }
    final fechaNac = '${_diaCtrl.text}/${_mesCtrl.text}/${_anioCtrl.text}';
    setState(() => _cargando = true);
    // El backend acepta `dd/MM/yyyy` además de ISO, y **vuelve a comprobar los
    // 18 años por su cuenta** (ADR-0011): si la comprobación de arriba se
    // saltara, respondería 400 con el motivo en español.
    final error = await _perfilService.actualizarCampos({
      'fechaNacimiento': fechaNac,
      'genero': _genero ?? '',
      'telefono': _telefonoCtrl.text.trim(),
      'telefonoEmergencia': _telEmergCtrl.text.trim(),
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
    _setPaso(3);
  }

  Future<void> _avanzarPaso4() async {
    // Si no hay experiencia, avanzar directo
    if (_trabajaActualmente == false && _hasTrabajado == false) {
      _setPaso(5);
      return;
    }
    if (!_p4Form.currentState!.validate()) return;
    final exp = Experiencia(
      empresa: _empresaCtrl.text.trim(),
      puesto: _puestoCtrl.text.trim(),
      habilidades: _habilidadesCtrl.text.trim(),
      descripcion: _descripcionCtrl.text.trim(),
      fechaInicio: _fInicioExpCtrl.text.trim(),
      fechaFin: _trabajaActualmente == true ? '' : _fFinExpCtrl.text.trim(),
      trabajaActualmente: _trabajaActualmente ?? false,
    );
    setState(() => _cargando = true);
    // La experiencia es un sub-recurso propio en el backend
    // (`POST /api/usuarios/me/experiencia`), no un campo del perfil.
    final error = await _perfilService.agregarExperiencia(exp);
    if (!mounted) return;
    setState(() => _cargando = false);
    if (error != null) {
      mostrarSnackBar(context, error, esError: true);
      return;
    }
    _setPaso(5);
  }

  Future<void> _finalizarRegistro() async {
    // Estudios
    if (_tieneEstudios == true && !_p5Form.currentState!.validate()) return;
    setState(() => _cargando = true);

    String? error;
    if (_tieneEstudios == true) {
      error = await _perfilService.agregarEstudio(Estudio(
        nivel: _nivelEstudio ?? '',
        centro: _centroCtrl.text.trim(),
        fechaInicio: _fInicioEstCtrl.text.trim(),
        fechaFin: _cursandoActualmente ? '' : _fFinEstCtrl.text.trim(),
        cursandoActualmente: _cursandoActualmente,
      ));
    }
    // Las habilidades tienen su propia ruta y son un reemplazo de la lista
    // entera. Aquí la lista es la que acaba de componer el formulario, así que
    // mandarla es correcto (a diferencia de tomarla de un `Usuario` que venga
    // de un login, donde vendría vacía por no haberla pedido).
    error ??= await _perfilService.reemplazarHabilidades(_habilidades);
    error ??= await _perfilService.actualizarCampos({'registroCompleto': true});

    if (!mounted) return;
    setState(() => _cargando = false);
    if (error != null) {
      mostrarSnackBar(context, error, esError: true);
      return;
    }
    // Deja el perfil de la sesión con el CV recién guardado, para que la
    // pantalla de perfil lo enseñe sin pedir nada más.
    await _perfilService.recargarPerfil();
    if (!mounted) return;
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
