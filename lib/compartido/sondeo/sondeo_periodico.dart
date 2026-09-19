import 'dart:async';

import 'package:flutter/widgets.dart';

/// Repite una tarea cada cierto tiempo mientras la app está en primer plano
/// (ADR-0018: el chat va por REST con sondeo, no por WebSocket).
///
/// - **Nunca solapa**: si la tarea anterior sigue en vuelo, el tic se salta.
/// - **Se pausa en segundo plano** (`paused`/`hidden`/`detached`) y al volver
///   ejecuta la tarea al instante y retoma el ritmo.
/// - **Quien lo crea debe llamar a [detener]** en `dispose`: cancela el
///   `Timer` y suelta el observador del ciclo de vida.
/// - Los errores de la tarea se tragan: un tic fallido no debe tumbar nada; la
///   tarea decide qué hacer con sus fallos (normalmente conservar lo último).
class SondeoPeriodico with WidgetsBindingObserver {
  SondeoPeriodico({required this.cada, required this.tarea});

  final Duration cada;
  final Future<void> Function() tarea;

  Timer? _timer;
  bool _activo = false;
  bool _enCurso = false;

  /// Hay un temporizador corriendo (falso si está pausado o detenido).
  bool get corriendo => _timer != null;

  /// Empieza a sondear. El primer tic llega tras [cada]; para cargar ya, la
  /// pantalla llama a [ejecutarAhora].
  void iniciar() {
    if (_activo) return;
    _activo = true;
    WidgetsBinding.instance.addObserver(this);
    _armar();
  }

  /// Ejecuta la tarea ya (p. ej. tras enviar un mensaje) sin cambiar el ritmo.
  Future<void> ejecutarAhora() async {
    if (_enCurso) return;
    _enCurso = true;
    try {
      await tarea();
    } catch (e) {
      debugPrint('Fallo en un tic de sondeo: $e');
    } finally {
      _enCurso = false;
    }
  }

  void detener() {
    _activo = false;
    _timer?.cancel();
    _timer = null;
    WidgetsBinding.instance.removeObserver(this);
  }

  void _armar() {
    _timer?.cancel();
    _timer = Timer.periodic(cada, (_) => ejecutarAhora());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_activo) return;
    switch (state) {
      case AppLifecycleState.resumed:
        if (_timer == null) {
          _armar();
          ejecutarAhora();
        }
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        _timer?.cancel();
        _timer = null;
      case AppLifecycleState.inactive:
        break;
    }
  }
}
