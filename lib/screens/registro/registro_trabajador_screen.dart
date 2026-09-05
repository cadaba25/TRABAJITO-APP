import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/auth_service.dart';
import '../../models/usuario.dart';
import '../../utils/constantes.dart';
import '../../widgets/custom_textfield.dart';
import '../../widgets/entrada_etiquetas.dart';




/// Formulario de registro de 5 pasos para trabajadores.
class RegistroTrabajadorScreen extends StatefulWidget {
  const RegistroTrabajadorScreen({super.key});

  @override
  State<RegistroTrabajadorScreen> createState() =>
      _RegistroTrabajadorScreenState();
}

class _RegistroTrabajadorScreenState extends State<RegistroTrabajadorScreen> {
  final _authService = AuthService();
  int _paso = 1;
  bool _cargando = false;

  // ── PASO 1 ─────────────────────────────────────────────────
  final _p1Form = GlobalKey<FormState>();
  final _nombresCtrl         = TextEditingController();
  final _apellidosCtrl       = TextEditingController();
  final _dniCtrl             = TextEditingController();
  final _correoCtrl          = TextEditingController();
  final _contrasenaCtrl      = TextEditingController();
  final _confirmarCtrl       = TextEditingController();
  bool _terminosAceptados    = false;
  String _contrasenaValor    = '';

  // ── PASO 2 ─────────────────────────────────────────────────
  final _p2Form = GlobalKey<FormState>();
  final _diaCtrl      = TextEditingController();
  final _mesCtrl      = TextEditingController();
  final _anioCtrl     = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  final _telEmergCtrl = TextEditingController();
  final _cpCtrl       = TextEditingController();
  String? _genero;
  String? _departamento;
  String? _ciudad;

  // ── PASO 3 (CV) ────────────────────────────────────────────


  // ── PASO 4 (Experiencia) ───────────────────────────────────
  final _p4Form = GlobalKey<FormState>();
  final List<String> _habilidades = [];
  bool? _trabajaActualmente;
  bool? _hasTrabajado;
  final _empresaCtrl     = TextEditingController();
  final _puestoCtrl      = TextEditingController();
  final _habilidadesCtrl = TextEditingController();
  final _descripcionCtrl = TextEditingController();
  final _fInicioExpCtrl  = TextEditingController(); // MM/AAAA
  final _fFinExpCtrl     = TextEditingController(); // MM/AAAA

  // ── PASO 5 (Estudios) ──────────────────────────────────────
  final _p5Form = GlobalKey<FormState>();
  bool? _tieneEstudios;
  String? _nivelEstudio;
  final _centroCtrl     = TextEditingController();
  final _fInicioEstCtrl = TextEditingController();
  final _fFinEstCtrl    = TextEditingController();
  bool _cursandoActualmente = false;

  @override
  void dispose() {
    for (final c in [
      _nombresCtrl, _apellidosCtrl, _dniCtrl,
      _correoCtrl, _contrasenaCtrl, _confirmarCtrl,
      _diaCtrl, _mesCtrl, _anioCtrl, _telefonoCtrl, _telEmergCtrl,
      _cpCtrl,
      _empresaCtrl, _puestoCtrl, _habilidadesCtrl, _descripcionCtrl,
      _fInicioExpCtrl, _fFinExpCtrl, _centroCtrl, _fInicioEstCtrl, _fFinEstCtrl,
    ]) { c.dispose(); }
    super.dispose();
  }

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
    final error = await _authService.actualizarCampos({
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
    final error = await _authService.agregarExperiencia(exp);
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
      error = await _authService.agregarEstudio(Estudio(
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
    error ??= await _authService.reemplazarHabilidades(_habilidades);
    error ??= await _authService.actualizarCampos({'registroCompleto': true});

    if (!mounted) return;
    setState(() => _cargando = false);
    if (error != null) {
      mostrarSnackBar(context, error, esError: true);
      return;
    }
    // Deja el perfil de la sesión con el CV recién guardado, para que la
    // pantalla de perfil lo enseñe sin pedir nada más.
    await _authService.recargarPerfil();
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
    if (_paso > 1) setState(() => _paso--);
    else Navigator.pop(context);
  }

  // ─────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: colorTextoFuerte(context)),
          onPressed: _retroceder,
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Indicador de pasos
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: IndicadorPasos(pasoActual: _paso, totalPasos: 5),
            ),
            const SizedBox(height: 4),
            // Contenido del paso actual
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _construirPasoActual(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _construirPasoActual() {
    switch (_paso) {
      case 1: return _paso1();
      case 2: return _paso2();
      case 3: return _paso3();
      case 4: return _paso4();
      case 5: return _paso5();
      default: return const SizedBox();
    }
  }

  // ─────────────────────────────────────────────────────────
  // PASO 1: CUENTA
  // ─────────────────────────────────────────────────────────
  Widget _paso1() {
    return Form(
      key: _p1Form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),
          _titulo('Crea tu cuenta'),
          const SizedBox(height: 24),
          CustomTextField(
            controller: _nombresCtrl,
            label: 'Nombres *',
            hint: 'Como aparece en tu documento',
            iconoInicio: Icons.person_outline,
            validador: (v) => (v == null || v.trim().isEmpty) ? MensajesError.campoObligatorio : null,
          ),
          const SizedBox(height: 14),
          CustomTextField(
            controller: _apellidosCtrl,
            label: 'Apellidos *',
            iconoInicio: Icons.person_outline,
            validador: (v) => (v == null || v.trim().isEmpty) ? MensajesError.campoObligatorio : null,
          ),
          const SizedBox(height: 14),
          CustomTextField(
            controller: _dniCtrl,
            label: 'DNI *',
            hint: '0801199912345',
            iconoInicio: Icons.badge_outlined,
            tipoTeclado: TextInputType.number,
            formateadores: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(13),
            ],
            validador: (v) {
              if (v == null || v.trim().isEmpty) return MensajesError.campoObligatorio;
              if (v.trim().length != 13) return MensajesError.dniInvalido;
              return null;
            },
          ),
          const SizedBox(height: 14),
          CustomTextField(
            controller: _correoCtrl,
            label: 'Correo electrónico *',
            hint: 'ejemplo@correo.com',
            iconoInicio: Icons.email_outlined,
            tipoTeclado: TextInputType.emailAddress,
            validador: (v) {
              if (v == null || v.trim().isEmpty) return MensajesError.campoObligatorio;
              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(v.trim())) {
                return MensajesError.correoInvalido;
              }
              return null;
            },
          ),
          const SizedBox(height: 14),
          CustomTextField(
            controller: _contrasenaCtrl,
            label: 'Contraseña *',
            iconoInicio: Icons.lock_outline,
            esContrasena: true,
            validador: (v) {
              if (v == null || v.isEmpty) return MensajesError.campoObligatorio;
              // De 10 a 72 caracteres: lo que exige el backend (ADR-0010). Pedir
              // menos aqui haria que el usuario rellenara todos los pasos para
              // que el servidor lo rechazara al final.
              if (v.length < ReglasCuenta.contrasenaMinima) {
                return MensajesError.contrasenaMuyCorta;
              }
              if (v.length > ReglasCuenta.contrasenaMaxima) {
                return MensajesError.contrasenaMuyLarga;
              }
              return null;
            },
            alTerminar: (_) => setState(() => _contrasenaValor = _contrasenaCtrl.text),
          ),
          // Listener para actualizar indicador
          ValueListenableBuilder(
            valueListenable: _contrasenaCtrl,
            builder: (_, __, ___) => Column(
              children: [
                const SizedBox(height: 8),
                IndicadorFuerzaContrasena(contrasena: _contrasenaCtrl.text),
              ],
            ),
          ),
          const SizedBox(height: 14),
          CustomTextField(
            controller: _confirmarCtrl,
            label: 'Confirmar contraseña *',
            iconoInicio: Icons.lock_outline,
            esContrasena: true,
            accionTeclado: TextInputAction.done,
            validador: (v) {
              if (v == null || v.isEmpty) return MensajesError.campoObligatorio;
              if (v != _contrasenaCtrl.text) return MensajesError.contrasenasNoCoinc;
              return null;
            },
          ),
          const SizedBox(height: 20),
          // Términos y condiciones
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: _terminosAceptados,
                onChanged: (v) => setState(() => _terminosAceptados = v ?? false),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: RichText(
                    text: TextSpan(
                      style: TextStyle(
                          fontSize: 13, color: colorTextoSuave(context)),
                      children: const [
                        TextSpan(text: 'Acepto las '),
                        TextSpan(
                          text: 'Condiciones de servicio',
                          style: TextStyle(
                              color: AppColores.acento,
                              fontWeight: FontWeight.w600),
                        ),
                        TextSpan(text: ' y la '),
                        TextSpan(
                          text: 'Política de privacidad',
                          style: TextStyle(
                              color: AppColores.acento,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _cargando ? null : _avanzar,
            child: _cargando
                ? const SizedBox(
                    height: 20, width: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2.5),
                  )
                : const Text('Crear cuenta'),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // PASO 2: DATOS PERSONALES
  // ─────────────────────────────────────────────────────────
  Widget _paso2() {
    return Form(
      key: _p2Form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),
          _titulo('Datos Personales'),
          const SizedBox(height: 24),

          // Fecha de nacimiento
          Text('Fecha de nacimiento *',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                  color: colorTextoFuerte(context))),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _diaCtrl,
                  decoration: _decoFecha('DD'),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(2)],
                  validator: (v) => (v == null || v.isEmpty) ? 'Requerido' : null,
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text('/', style: TextStyle(fontSize: 20, color: AppColores.grisMedio)),
              ),
              Expanded(
                child: TextFormField(
                  controller: _mesCtrl,
                  decoration: _decoFecha('MM'),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(2)],
                  validator: (v) => (v == null || v.isEmpty) ? 'Requerido' : null,
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text('/', style: TextStyle(fontSize: 20, color: AppColores.grisMedio)),
              ),
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: _anioCtrl,
                  decoration: _decoFecha('AAAA'),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(4)],
                  validator: (v) => (v == null || v.isEmpty) ? 'Requerido' : null,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),
          CustomDropdown(
            label: 'Género (opcional)',
            valor: _genero,
            opciones: DatosHonduras.generos,
            icono: Icons.wc_outlined,
            alCambiar: (v) => setState(() => _genero = v),
          ),

          const SizedBox(height: 16),
          CustomTextField(
            controller: _telefonoCtrl,
            label: 'Teléfono personal *',
            iconoInicio: Icons.phone_outlined,
            tipoTeclado: TextInputType.phone,
            formateadores: [FilteringTextInputFormatter.digitsOnly],
            validador: (v) {
              if (v == null || v.trim().isEmpty) return MensajesError.campoObligatorio;
              if (v.trim().length < 8) return MensajesError.telefonoInvalido;
              return null;
            },
          ),

          const SizedBox(height: 14),
          CustomTextField(
            controller: _telEmergCtrl,
            label: 'Teléfono de emergencia *',
            iconoInicio: Icons.phone_in_talk_outlined,
            tipoTeclado: TextInputType.phone,
            formateadores: [FilteringTextInputFormatter.digitsOnly],
            validador: (v) {
              if (v == null || v.trim().isEmpty) return MensajesError.campoObligatorio;
              if (v.trim().length < 8) return MensajesError.telefonoInvalido;
              return null;
            },
          ),

          const SizedBox(height: 20),
          _SelectorPaisLocalTrab(alTocarFuera: () =>
              mostrarSnackBar(context, MensajesError.soloHonduras)),
          const SizedBox(height: 16),

          CustomTextField(
            controller: _cpCtrl,
            label: 'Código postal',
            iconoInicio: Icons.markunread_mailbox_outlined,
            tipoTeclado: TextInputType.number,
            formateadores: [FilteringTextInputFormatter.digitsOnly],
          ),
          const SizedBox(height: 14),
          CustomDropdown(
            label: 'Departamento *',
            valor: _departamento,
            opciones: DatosHonduras.departamentos,
            icono: Icons.map_outlined,
            alCambiar: (v) => setState(() {
              _departamento = v;
              _ciudad = null;
            }),
            validador: (v) =>
                (v == null || v.isEmpty) ? MensajesError.campoObligatorio : null,
          ),
          if (_departamento != null) ...[
            const SizedBox(height: 14),
            CustomDropdown(
              label: 'Ciudad / Municipio *',
              valor: _ciudad,
              opciones: DatosHonduras.ciudadesPorDepartamento[_departamento] ?? [],
              icono: Icons.location_city_outlined,
              alCambiar: (v) => setState(() => _ciudad = v),
              validador: (v) =>
                  (v == null || v.isEmpty) ? MensajesError.campoObligatorio : null,
            ),
          ],

          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: _cargando ? null : _avanzar,
            child: _cargando
                ? const SizedBox(
                    height: 20, width: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2.5))
                : const Text('Guardar y continuar'),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // PASO 3: SUBIR CV (OPCIONAL)
  // ─────────────────────────────────────────────────────────
  Widget _paso3() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        _titulo('Subir CV'),
        const SizedBox(height: 8),
        Text(
          'Sube tu CV en PDF y ahorra tiempo en tus aplicaciones.',
          style: TextStyle(color: colorTextoSuave(context), fontSize: 14, height: 1.5),
        ),
        const SizedBox(height: 32),
        // Área de carga (solo UI, subida de archivos en v0.3)
        Container(
          height: 160,
          decoration: BoxDecoration(
            color: colorSuperficie(context),
            border: Border.all(
              color: AppColores.acento.withOpacity(0.35),
              width: 1.5,
              style: BorderStyle.solid,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.upload_file_outlined,
                  size: 40, color: AppColores.acento.withOpacity(0.6)),
              const SizedBox(height: 12),
              Text('Adjunta tu CV aquí',
                  style: TextStyle(
                      color: colorTextoSuave(context), fontWeight: FontWeight.w500)),
              const SizedBox(height: 4),
              const Text('PDF, DOC o DOCX — Máx. 5MB',
                  style: TextStyle(fontSize: 11, color: AppColores.grisMedio)),
              const SizedBox(height: 12),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(140, 36),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                onPressed: () {
                  mostrarSnackBar(context,
                      'Subida de archivos disponible en la próxima versión');
                },
                child: const Text('Seleccionar archivo'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        ElevatedButton(
          onPressed: _avanzar,
          child: const Text('Continuar'),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: _avanzar,
          child: Text('Ahora no',
              style: TextStyle(color: colorTextoSuave(context))),
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────
  // PASO 4: EXPERIENCIA LABORAL
  // ─────────────────────────────────────────────────────────
  Widget _paso4() {
    // Determinar si el botón debe estar habilitado
    final puedeAvanzar = _trabajaActualmente != null;

    return Form(
      key: _p4Form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),
          _titulo('Tus habilidades'),
          const SizedBox(height: 6),
          Text(
            'Agrega lo que sabes hacer. Esto ayuda a que te encuentren.',
            style: TextStyle(color: colorTextoSuave(context), fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 16),
          EntradaEtiquetas(
            etiquetas: _habilidades,
            sugerencias: DatosHonduras.habilidadesSugeridas,
            etiquetaCampo: 'Agregar habilidad',
          ),
          const SizedBox(height: 28),

          _titulo('Añadir experiencia'),
          const SizedBox(height: 24),

          BotonesSiNo(
            pregunta: '¿Estás trabajando actualmente?',
            valorActual: _trabajaActualmente,
            alCambiar: (v) => setState(() {
              _trabajaActualmente = v;
              if (v) _hasTrabajado = null;
            }),
          ),

          if (_trabajaActualmente == false) ...[
            const SizedBox(height: 20),
            BotonesSiNo(
              pregunta: '¿Has trabajado anteriormente?',
              valorActual: _hasTrabajado,
              alCambiar: (v) => setState(() => _hasTrabajado = v),
            ),
          ],

          // Mostrar campos si trabaja o ha trabajado
          if (_trabajaActualmente == true ||
              (_trabajaActualmente == false && _hasTrabajado == true)) ...[
            const SizedBox(height: 20),
            CustomTextField(
              controller: _empresaCtrl,
              label: 'Nombre de la empresa *',
              iconoInicio: Icons.business_outlined,
              validador: (v) =>
                  (v == null || v.trim().isEmpty) ? MensajesError.campoObligatorio : null,
            ),
            const SizedBox(height: 14),
            CustomTextField(
              controller: _puestoCtrl,
              label: 'Puesto / Cargo *',
              iconoInicio: Icons.work_outline,
              validador: (v) =>
                  (v == null || v.trim().isEmpty) ? MensajesError.campoObligatorio : null,
            ),
            const SizedBox(height: 14),
            CustomTextField(
              controller: _habilidadesCtrl,
              label: 'Habilidades (opcional)',
              hint: 'p. ej. Excel, atención al cliente',
              iconoInicio: Icons.star_outline,
            ),
            const SizedBox(height: 14),
            CustomTextField(
              controller: _descripcionCtrl,
              label: 'Descripción del puesto (opcional)',
              hint: 'Describe tus funciones y logros...',
              maxLines: 4,
              maxLength: 500,
            ),
            const SizedBox(height: 14),
            // Fecha inicio
            CustomTextField(
              controller: _fInicioExpCtrl,
              label: 'Fecha de inicio * (MM/AAAA)',
              hint: '01/2022',
              iconoInicio: Icons.calendar_today_outlined,
              tipoTeclado: TextInputType.datetime,
              validador: (v) =>
                  (v == null || v.trim().isEmpty) ? MensajesError.campoObligatorio : null,
            ),
            // Fecha fin solo si no trabaja actualmente
            if (_trabajaActualmente == false) ...[
              const SizedBox(height: 14),
              CustomTextField(
                controller: _fFinExpCtrl,
                label: 'Fecha de fin * (MM/AAAA)',
                hint: '06/2023',
                iconoInicio: Icons.calendar_today_outlined,
                tipoTeclado: TextInputType.datetime,
                validador: (v) =>
                    (v == null || v.trim().isEmpty) ? MensajesError.campoObligatorio : null,
              ),
            ],
          ],

          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: puedeAvanzar ? _avanzar : null,
            child: _cargando
                ? const SizedBox(
                    height: 20, width: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2.5))
                : const Text('Siguiente'),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // PASO 5: ESTUDIOS
  // ─────────────────────────────────────────────────────────
  Widget _paso5() {
    final puedeAvanzar = _tieneEstudios != null;

    return Form(
      key: _p5Form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),
          _titulo('Añadir estudios'),
          const SizedBox(height: 24),

          BotonesSiNo(
            pregunta: '¿Tienes estudios?',
            valorActual: _tieneEstudios,
            alCambiar: (v) => setState(() => _tieneEstudios = v),
          ),

          if (_tieneEstudios == true) ...[
            const SizedBox(height: 20),
            CustomDropdown(
              label: 'Nivel de estudios *',
              valor: _nivelEstudio,
              opciones: DatosHonduras.nivelesEstudio,
              icono: Icons.school_outlined,
              alCambiar: (v) => setState(() => _nivelEstudio = v),
              validador: (v) =>
                  (v == null || v.isEmpty) ? MensajesError.campoObligatorio : null,
            ),
            const SizedBox(height: 14),
            CustomTextField(
              controller: _centroCtrl,
              label: 'Centro / Institución *',
              iconoInicio: Icons.account_balance_outlined,
              validador: (v) =>
                  (v == null || v.trim().isEmpty) ? MensajesError.campoObligatorio : null,
            ),
            const SizedBox(height: 14),
            CustomTextField(
              controller: _fInicioEstCtrl,
              label: 'Fecha de inicio * (MM/AAAA)',
              hint: '01/2018',
              iconoInicio: Icons.calendar_today_outlined,
              tipoTeclado: TextInputType.datetime,
              validador: (v) =>
                  (v == null || v.trim().isEmpty) ? MensajesError.campoObligatorio : null,
            ),
            const SizedBox(height: 14),
            // Fecha de fin solo si no está cursando
            if (!_cursandoActualmente)
              CustomTextField(
                controller: _fFinEstCtrl,
                label: 'Fecha de fin (MM/AAAA)',
                hint: '12/2022',
                iconoInicio: Icons.calendar_today_outlined,
                tipoTeclado: TextInputType.datetime,
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                Checkbox(
                  value: _cursandoActualmente,
                  onChanged: (v) =>
                      setState(() => _cursandoActualmente = v ?? false),
                ),
                Text(
                  'Cursando actualmente',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: colorTextoFuerte(context)),
                ),
              ],
            ),
          ],

          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: puedeAvanzar ? _avanzar : null,
            child: _cargando
                ? const SizedBox(
                    height: 20, width: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2.5))
                : const Text('Finalizar registro'),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────────────────
  Widget _titulo(String texto) {
    return Text(
      texto,
      style: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w800,
        color: colorTextoFuerte(context),
        letterSpacing: -0.5,
      ),
    );
  }

  InputDecoration _decoFecha(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppColores.grisMedio),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      filled: true,
      fillColor: colorSuperficie(context),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colorBorde(context), width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colorBorde(context), width: 1.5),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: AppColores.acento, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColores.error, width: 1.5),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// SELECTOR DE PAÍS (local Honduras / fuera del país próximamente)
// ─────────────────────────────────────────────────────────────
class _SelectorPaisLocalTrab extends StatelessWidget {
  final VoidCallback alTocarFuera;
  const _SelectorPaisLocalTrab({required this.alTocarFuera});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Ubicación',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: colorTextoFuerte(context))),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                decoration: BoxDecoration(
                  color: AppColores.acento.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColores.acento, width: 1.5),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.check_circle, color: AppColores.acento, size: 16),
                    SizedBox(width: 6),
                    Text('Honduras',
                        style: TextStyle(
                            color: AppColores.acento, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: alTocarFuera,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                  decoration: BoxDecoration(
                    color: colorSuperficie(context),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: colorBorde(context), width: 1.5),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Text('Fuera del país',
                          style: TextStyle(
                              color: AppColores.grisMedio,
                              fontWeight: FontWeight.w600,
                              fontSize: 12)),
                      SizedBox(width: 6),
                      Text('Pronto',
                          style: TextStyle(
                              color: AppColores.grisMedio,
                              fontSize: 10,
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
