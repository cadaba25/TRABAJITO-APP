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
import 'widgets/registro_trabajador/paso_cuenta_trabajador.dart';
import 'widgets/registro_trabajador/paso_cv_trabajador.dart';
import 'widgets/registro_trabajador/paso_datos_personales_trabajador.dart';
import 'widgets/registro_trabajador/paso_estudios_trabajador.dart';
import 'widgets/registro_trabajador/paso_experiencia_trabajador.dart';

part 'registro_trabajador_logica.dart';

/// Formulario de registro de 5 pasos para trabajadores.
///
/// **Nota de ADR-0014/ADR-0016 (tarea 033):** el UI de cada paso vive en
/// `widgets/registro_trabajador/paso_*.dart` (ver la decisión de "partir o
/// no partir" en `docs/agent-reports/033-*.md`). La lógica de
/// avanzar/validar/guardar (que depende de sí misma entre pasos: edad
/// mínima antes de guardar, orden de llamadas a `PerfilService`) vive en
/// `registro_trabajador_logica.dart`, `part of` este archivo — comparte
/// biblioteca y por tanto el acceso a los campos privados de
/// `_RegistroTrabajadorScreenState`, sin cambiar una sola regla de negocio.
class RegistroTrabajadorScreen extends StatefulWidget {
  const RegistroTrabajadorScreen({super.key});

  @override
  State<RegistroTrabajadorScreen> createState() =>
      _RegistroTrabajadorScreenState();
}

class _RegistroTrabajadorScreenState extends State<RegistroTrabajadorScreen> {
  /// Inyectado por `provider` desde la raíz de composición
  /// (`nucleo/inyeccion/proveedores.dart`). Antes esta línea decía
  /// `= AuthService()`, y por eso esta pantalla no admitía un doble.
  ///
  /// Es `late` porque `context` no existe todavía cuando se inicializan
  /// los campos del `State`: se resuelve en el primer uso, que siempre
  /// ocurre desde un manejador de evento.
  late final AuthService _authService = context.read<AuthService>();

  /// El registro crea la cuenta con [AuthService.registrar] y a continuación
  /// completa el perfil y el CV, que desde la tarea 027 (parte B-2) vive en
  /// [PerfilService]. Por eso esta pantalla usa los dos servicios.
  late final PerfilService _perfilService = context.read<PerfilService>();
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

  // Lógica de avanzar/validar/guardar: `registro_trabajador_logica.dart`
  // (`_avanzar`, `_avanzarPasoN`, `_finalizarRegistro`, `_esMayor18`,
  // `_setPaso`, `_retroceder` — extensión `part of` este archivo, ver la
  // decisión de partir-o-no-partir en `docs/agent-reports/033-*.md`).

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
              padding: const EdgeInsets.symmetric(horizontal: AppEspaciado.xl),
              child: IndicadorPasos(pasoActual: _paso, totalPasos: 5),
            ),
            const SizedBox(height: AppEspaciado.xs),
            // Contenido del paso actual
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
        return PasoCuentaTrabajador(
          formKey: _p1Form,
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
        return PasoDatosPersonalesTrabajador(
          formKey: _p2Form,
          diaCtrl: _diaCtrl,
          mesCtrl: _mesCtrl,
          anioCtrl: _anioCtrl,
          telefonoCtrl: _telefonoCtrl,
          telEmergCtrl: _telEmergCtrl,
          cpCtrl: _cpCtrl,
          genero: _genero,
          alCambiarGenero: (v) => setState(() => _genero = v),
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
        return PasoCvTrabajador(onAvanzar: _avanzar);
      case 4:
        return PasoExperienciaTrabajador(
          formKey: _p4Form,
          habilidades: _habilidades,
          trabajaActualmente: _trabajaActualmente,
          alCambiarTrabajaActualmente: (v) => setState(() {
            _trabajaActualmente = v;
            if (v) _hasTrabajado = null;
          }),
          hasTrabajado: _hasTrabajado,
          alCambiarHasTrabajado: (v) => setState(() => _hasTrabajado = v),
          empresaCtrl: _empresaCtrl,
          puestoCtrl: _puestoCtrl,
          habilidadesCtrl: _habilidadesCtrl,
          descripcionCtrl: _descripcionCtrl,
          fInicioExpCtrl: _fInicioExpCtrl,
          fFinExpCtrl: _fFinExpCtrl,
          cargando: _cargando,
          onAvanzar: _avanzar,
        );
      case 5:
        return PasoEstudiosTrabajador(
          formKey: _p5Form,
          tieneEstudios: _tieneEstudios,
          alCambiarTieneEstudios: (v) => setState(() => _tieneEstudios = v),
          nivelEstudio: _nivelEstudio,
          alCambiarNivel: (v) => setState(() => _nivelEstudio = v),
          centroCtrl: _centroCtrl,
          fInicioEstCtrl: _fInicioEstCtrl,
          fFinEstCtrl: _fFinEstCtrl,
          cursandoActualmente: _cursandoActualmente,
          alCambiarCursando: (v) => setState(() => _cursandoActualmente = v),
          cargando: _cargando,
          onFinalizar: _avanzar,
        );
      default:
        return const SizedBox();
    }
  }
}
