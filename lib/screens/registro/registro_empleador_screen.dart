import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/auth_service.dart';
import '../../models/usuario.dart';
import '../../utils/constantes.dart';
import '../../widgets/custom_textfield.dart';

/// Formulario de registro de 3 pasos para empleadores
/// (personas particulares o empresas que buscan contratar).
class RegistroEmpleadorScreen extends StatefulWidget {
  const RegistroEmpleadorScreen({super.key});

  @override
  State<RegistroEmpleadorScreen> createState() =>
      _RegistroEmpleadorScreenState();
}

class _RegistroEmpleadorScreenState extends State<RegistroEmpleadorScreen> {
  final _authService = AuthService();
  int _paso = 1;
  bool _cargando = false;

  /// 'persona' | 'empresa' — define qué campos se piden.
  String _tipoEmpleador = 'persona';
  bool get _esEmpresa => _tipoEmpleador == 'empresa';

  // ── PASO 1: CUENTA ─────────────────────────────────────────
  final _p1Form = GlobalKey<FormState>();
  final _nombresCtrl         = TextEditingController();
  final _apellidosCtrl       = TextEditingController();
  final _dniCtrl             = TextEditingController();
  final _nombreEmpresaCtrl   = TextEditingController();
  final _rtnCtrl             = TextEditingController();
  final _cargoCtrl           = TextEditingController();
  final _correoCtrl          = TextEditingController();
  final _contrasenaCtrl      = TextEditingController();
  final _confirmarCtrl       = TextEditingController();
  bool _terminosAceptados    = false;

  // ── PASO 2: CONTACTO Y UBICACIÓN ───────────────────────────
  final _p2Form = GlobalKey<FormState>();
  final _diaCtrl      = TextEditingController();
  final _mesCtrl      = TextEditingController();
  final _anioCtrl     = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  final _telAltCtrl   = TextEditingController();
  final _cpCtrl       = TextEditingController();
  String? _departamento;
  String? _ciudad;

  // ── PASO 3: INFORMACIÓN ADICIONAL ──────────────────────────
  final _p3Form = GlobalKey<FormState>();
  String? _sectorEmpresa;
  String? _tamanoEmpresa;
  final _sitioWebCtrl    = TextEditingController();
  final _descripcionCtrl = TextEditingController();

  @override
  void dispose() {
    for (final c in [
      _nombresCtrl, _apellidosCtrl, _dniCtrl,
      _nombreEmpresaCtrl, _rtnCtrl, _cargoCtrl,
      _correoCtrl, _contrasenaCtrl, _confirmarCtrl,
      _diaCtrl, _mesCtrl, _anioCtrl, _telefonoCtrl, _telAltCtrl,
      _cpCtrl, _sitioWebCtrl, _descripcionCtrl,
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
    final errorEmpresa = await _authService.actualizarCampos({
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
    final error = await _authService.actualizarCampos({
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
        await _authService.actualizarCampos({'registroCompleto': true});
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
    final error = await _authService.actualizarCampos({
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: IndicadorPasos(
                  pasoActual: _paso, totalPasos: _esEmpresa ? 3 : 2),
            ),
            const SizedBox(height: 4),
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
          const SizedBox(height: 6),
          Text(
            'Cuéntanos quién contratará en Trabajito.',
            style: TextStyle(color: colorTextoSuave(context), fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 20),

          // Selector tipo de empleador
          Row(
            children: [
              Expanded(
                child: _TarjetaTipo(
                  titulo: 'Persona',
                  descripcion: 'Contrato para mí o mi hogar',
                  icono: Icons.person_outline,
                  seleccionado: !_esEmpresa,
                  onTap: () => setState(() => _tipoEmpleador = 'persona'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _TarjetaTipo(
                  titulo: 'Empresa',
                  descripcion: 'Contrato en nombre de un negocio',
                  icono: Icons.business_outlined,
                  seleccionado: _esEmpresa,
                  onTap: () => setState(() => _tipoEmpleador = 'empresa'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Datos de la empresa (solo si aplica)
          if (_esEmpresa) ...[
            CustomTextField(
              controller: _nombreEmpresaCtrl,
              label: 'Nombre de la empresa *',
              iconoInicio: Icons.business_outlined,
              validador: (v) => (v == null || v.trim().isEmpty)
                  ? MensajesError.campoObligatorio : null,
            ),
            const SizedBox(height: 14),
            CustomTextField(
              controller: _rtnCtrl,
              label: 'RTN (opcional)',
              hint: '08011985123456',
              iconoInicio: Icons.badge_outlined,
              tipoTeclado: TextInputType.number,
              formateadores: [FilteringTextInputFormatter.digitsOnly],
            ),
            const SizedBox(height: 14),
            Text(
              'Datos de la persona de contacto',
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600,
                  color: colorTextoFuerte(context)),
            ),
            const SizedBox(height: 14),
          ],

          CustomTextField(
            controller: _nombresCtrl,
            label: 'Nombres *',
            hint: 'Como aparece en tu documento',
            iconoInicio: Icons.person_outline,
            validador: (v) => (v == null || v.trim().isEmpty)
                ? MensajesError.campoObligatorio : null,
          ),
          const SizedBox(height: 14),
          CustomTextField(
            controller: _apellidosCtrl,
            label: 'Apellidos *',
            iconoInicio: Icons.person_outline,
            validador: (v) => (v == null || v.trim().isEmpty)
                ? MensajesError.campoObligatorio : null,
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

          if (_esEmpresa) ...[
            const SizedBox(height: 14),
            CustomTextField(
              controller: _cargoCtrl,
              label: 'Cargo en la empresa (opcional)',
              hint: 'p. ej. Gerente, Propietario',
              iconoInicio: Icons.work_outline,
            ),
          ],

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
          ),
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
                      style: TextStyle(fontSize: 13, color: colorTextoSuave(context)),
                      children: const [
                        TextSpan(text: 'Acepto las '),
                        TextSpan(
                          text: 'Condiciones de servicio',
                          style: TextStyle(
                              color: AppColores.acento, fontWeight: FontWeight.w600),
                        ),
                        TextSpan(text: ' y la '),
                        TextSpan(
                          text: 'Política de privacidad',
                          style: TextStyle(
                              color: AppColores.acento, fontWeight: FontWeight.w600),
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
  // PASO 2: CONTACTO Y UBICACIÓN
  // ─────────────────────────────────────────────────────────
  Widget _paso2() {
    return Form(
      key: _p2Form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),
          _titulo('Datos de contacto'),
          const SizedBox(height: 24),

          // Fecha de nacimiento (obligatoria · mayoría de edad)
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

          CustomTextField(
            controller: _telefonoCtrl,
            label: _esEmpresa ? 'Teléfono de la empresa *' : 'Teléfono *',
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
            controller: _telAltCtrl,
            label: 'Teléfono alternativo (opcional)',
            iconoInicio: Icons.phone_in_talk_outlined,
            tipoTeclado: TextInputType.phone,
            formateadores: [FilteringTextInputFormatter.digitsOnly],
            validador: (v) {
              if (v != null && v.trim().isNotEmpty && v.trim().length < 8) {
                return MensajesError.telefonoInvalido;
              }
              return null;
            },
          ),

          const SizedBox(height: 20),
          _SelectorPaisLocal(alTocarFuera: () =>
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
                : Text(_esEmpresa ? 'Guardar y continuar' : 'Finalizar registro'),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // PASO 3: INFORMACIÓN ADICIONAL
  // ─────────────────────────────────────────────────────────
  Widget _paso3() {
    return Form(
      key: _p3Form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),
          _titulo('Sobre tu empresa'),
          const SizedBox(height: 8),
          Text(
            'Esta información ayuda a los profesionales a conocer mejor tu empresa.',
            style: TextStyle(
                color: colorTextoSuave(context), fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 24),

          CustomDropdown(
            label: 'Sector / Rubro *',
            valor: _sectorEmpresa,
            opciones: DatosEmpleador.sectores,
            icono: Icons.category_outlined,
            alCambiar: (v) => setState(() => _sectorEmpresa = v),
            validador: (v) =>
                (v == null || v.isEmpty) ? MensajesError.campoObligatorio : null,
          ),

          ...[
            const SizedBox(height: 14),
            CustomDropdown(
              label: 'Tamaño de la empresa *',
              valor: _tamanoEmpresa,
              opciones: DatosEmpleador.tamanos,
              icono: Icons.groups_outlined,
              alCambiar: (v) => setState(() => _tamanoEmpresa = v),
              validador: (v) =>
                  (v == null || v.isEmpty) ? MensajesError.campoObligatorio : null,
            ),
            const SizedBox(height: 14),
            CustomTextField(
              controller: _sitioWebCtrl,
              label: 'Sitio web (opcional)',
              hint: 'www.empresa.com',
              iconoInicio: Icons.language_outlined,
              tipoTeclado: TextInputType.url,
              validador: (v) {
                if (v == null || v.trim().isEmpty) return null;
                final patron = RegExp(
                    r'^(https?:\/\/)?([\w-]+\.)+[\w-]{2,}(\/\S*)?$');
                return patron.hasMatch(v.trim())
                    ? null : MensajesError.sitioWebInvalido;
              },
            ),
          ],

          const SizedBox(height: 14),
          CustomTextField(
            controller: _descripcionCtrl,
            label: 'Descripción de la empresa (opcional)',
            hint: 'A qué se dedica tu empresa...',
            maxLines: 4,
            maxLength: 500,
          ),

          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: _cargando ? null : _avanzar,
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
      errorBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: AppColores.error, width: 1.5),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// SELECTOR DE PAÍS (local Honduras / fuera del país próximamente)
// ─────────────────────────────────────────────────────────────
class _SelectorPaisLocal extends StatelessWidget {
  final VoidCallback alTocarFuera;
  const _SelectorPaisLocal({required this.alTocarFuera});

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

// ─────────────────────────────────────────────────────────────
// TARJETA SELECTORA DE TIPO DE EMPLEADOR
// ─────────────────────────────────────────────────────────────
class _TarjetaTipo extends StatelessWidget {
  final String titulo;
  final String descripcion;
  final IconData icono;
  final bool seleccionado;
  final VoidCallback onTap;

  const _TarjetaTipo({
    required this.titulo,
    required this.descripcion,
    required this.icono,
    required this.seleccionado,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: seleccionado
              ? AppColores.acento.withOpacity(0.10)
              : colorSuperficie(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: seleccionado ? AppColores.acento : colorBorde(context),
            width: 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icono,
                color: seleccionado ? AppColores.acento : AppColores.grisMedio,
                size: 26),
            const SizedBox(height: 10),
            Text(
              titulo,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: seleccionado ? AppColores.acento : colorTextoFuerte(context),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              descripcion,
              style: TextStyle(
                  fontSize: 11, color: colorTextoSuave(context), height: 1.3),
            ),
          ],
        ),
      ),
    );
  }
}
