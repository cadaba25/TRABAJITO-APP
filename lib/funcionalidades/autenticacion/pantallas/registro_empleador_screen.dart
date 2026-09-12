import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../datos/auth_service.dart';
import '../../perfil/datos/perfil_service.dart';
import '../../../compartido/modelos/usuario.dart';
import '../../../nucleo/dominio/roles.dart';
import '../../../nucleo/espaciado/app_espaciado.dart';
import '../../../nucleo/textos/mensajes_error.dart';
import '../../../compartido/widgets/indicador_pasos.dart';
import '../../../compartido/widgets/mostrar_snackbar.dart';
import '../../../nucleo/tema/colores_por_tema.dart';
import 'widgets/registro_empleador/paso_contacto_empleador.dart';
import 'widgets/registro_empleador/paso_cuenta_empleador.dart';
import 'widgets/registro_empleador/paso_info_empresa_empleador.dart';

part 'registro_empleador_logica.dart';

/// Formulario de registro de 3 pasos para empleadores
/// (personas particulares o empresas que buscan contratar).
///
/// **Nota de ADR-0014/ADR-0016 (tarea 033):** el UI de cada paso vive en
/// `widgets/registro_empleador/paso_*.dart` (ver la decisión de "partir o
/// no partir" en `docs/agent-reports/033-*.md`). La lógica de
/// avanzar/validar/guardar vive en `registro_empleador_logica.dart`,
/// `part of` este archivo — comparte biblioteca y por tanto el acceso a los
/// campos privados de `_RegistroEmpleadorScreenState`, sin cambiar una sola
/// regla de negocio.
class RegistroEmpleadorScreen extends StatefulWidget {
  const RegistroEmpleadorScreen({super.key});

  @override
  State<RegistroEmpleadorScreen> createState() =>
      _RegistroEmpleadorScreenState();
}

class _RegistroEmpleadorScreenState extends State<RegistroEmpleadorScreen> {
  /// Inyectado por `provider` desde la raíz de composición
  /// (`nucleo/inyeccion/proveedores.dart`). Antes esta línea decía
  /// `= AuthService()`, y por eso esta pantalla no admitía un doble.
  ///
  /// Es `late` porque `context` no existe todavía cuando se inicializan
  /// los campos del `State`: se resuelve en el primer uso, que siempre
  /// ocurre desde un manejador de evento.
  late final AuthService _authService = context.read<AuthService>();

  /// El registro crea la cuenta con [AuthService.registrar] y a continuación
  /// completa el perfil, que desde la tarea 027 (parte B-2) vive en
  /// [PerfilService]. Por eso esta pantalla usa los dos servicios.
  late final PerfilService _perfilService = context.read<PerfilService>();
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

  // Lógica de avanzar/validar/guardar: `registro_empleador_logica.dart`
  // (`_avanzar`, `_avanzarPasoN`, `_finalizarPersona`, `_finalizarRegistro`,
  // `_esMayor18`, `_setPaso`, `_retroceder` — extensión `part of` este
  // archivo, ver la decisión de partir-o-no-partir en
  // `docs/agent-reports/033-*.md`).

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
              padding: const EdgeInsets.symmetric(horizontal: AppEspaciado.xl),
              child: IndicadorPasos(
                  pasoActual: _paso, totalPasos: _esEmpresa ? 3 : 2),
            ),
            const SizedBox(height: AppEspaciado.xs),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: AppEspaciado.xl),
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
      case 1:
        return PasoCuentaEmpleador(
          formKey: _p1Form,
          esEmpresa: _esEmpresa,
          alCambiarTipo: (esEmpresa) => setState(
              () => _tipoEmpleador = esEmpresa ? 'empresa' : 'persona'),
          nombreEmpresaCtrl: _nombreEmpresaCtrl,
          rtnCtrl: _rtnCtrl,
          cargoCtrl: _cargoCtrl,
          nombresCtrl: _nombresCtrl,
          apellidosCtrl: _apellidosCtrl,
          dniCtrl: _dniCtrl,
          correoCtrl: _correoCtrl,
          contrasenaCtrl: _contrasenaCtrl,
          confirmarCtrl: _confirmarCtrl,
          terminosAceptados: _terminosAceptados,
          alCambiarTerminos: (v) => setState(() => _terminosAceptados = v),
          cargando: _cargando,
          onAvanzar: _avanzar,
        );
      case 2:
        return PasoContactoEmpleador(
          formKey: _p2Form,
          esEmpresa: _esEmpresa,
          diaCtrl: _diaCtrl,
          mesCtrl: _mesCtrl,
          anioCtrl: _anioCtrl,
          telefonoCtrl: _telefonoCtrl,
          telAltCtrl: _telAltCtrl,
          cpCtrl: _cpCtrl,
          departamento: _departamento,
          alCambiarDepartamento: (v) => setState(() {
            _departamento = v;
            _ciudad = null;
          }),
          ciudad: _ciudad,
          alCambiarCiudad: (v) => setState(() => _ciudad = v),
          cargando: _cargando,
          onAvanzar: _avanzar,
        );
      case 3:
        return PasoInfoEmpresaEmpleador(
          formKey: _p3Form,
          sectorEmpresa: _sectorEmpresa,
          alCambiarSector: (v) => setState(() => _sectorEmpresa = v),
          tamanoEmpresa: _tamanoEmpresa,
          alCambiarTamano: (v) => setState(() => _tamanoEmpresa = v),
          sitioWebCtrl: _sitioWebCtrl,
          descripcionCtrl: _descripcionCtrl,
          cargando: _cargando,
          onFinalizar: _avanzar,
        );
      default:
        return const SizedBox();
    }
  }
}
