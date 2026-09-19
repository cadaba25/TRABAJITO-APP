import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../compartido/sondeo/sondeo_periodico.dart';
import '../../../compartido/modelos/usuario.dart';
import '../../../compartido/widgets/ejecutar_con_carga.dart';
import '../../../compartido/widgets/mostrar_snackbar.dart';
import '../../../nucleo/api/api_excepciones.dart';
import '../../../nucleo/tema/app_colores.dart';
import '../../../nucleo/tema/colores_por_tema.dart';
import '../datos/chat.dart';
import '../datos/chat_service.dart';
import '../widgets/barra_envio.dart';
import '../widgets/burbuja_mensaje.dart';
import '../widgets/dialogos_negociacion.dart';
import '../widgets/panel_negociacion.dart';

/// Conversación entre contratista y trabajador, con negociación de pago y
/// tiempo.
///
/// **Sondeo, no stream** (ADR-0018): cada [intervaloSondeo] pide el chat y
/// solo los mensajes posteriores al último recibido (`?desde=`). El `Timer` se
/// cancela en `dispose` y se pausa con la app en segundo plano
/// (`SondeoPeriodico`). Un tic fallido conserva lo que ya se ve; solo la
/// primera carga fallida enseña un aviso.
class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.chat,
    required this.usuario,
    this.intervaloSondeo = const Duration(seconds: 3),
  });

  final Chat chat;
  final Usuario usuario;
  final Duration intervaloSondeo;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late final ChatService _servicio = context.read<ChatService>();
  final _msgCtrl = TextEditingController();
  late final SondeoPeriodico _sondeo;

  late Chat _chat = widget.chat;
  final List<Mensaje> _mensajes = []; // ascendente por fecha
  bool _cargado = false;
  bool _falloCarga = false;

  String get _miUid => widget.usuario.uid;

  @override
  void initState() {
    super.initState();
    _sondeo = SondeoPeriodico(cada: widget.intervaloSondeo, tarea: _actualizar)
      ..iniciar();
    _sondeo.ejecutarAhora();
  }

  @override
  void dispose() {
    _sondeo.detener();
    _msgCtrl.dispose();
    super.dispose();
  }

  Future<void> _actualizar() async {
    try {
      final chat = await _servicio.obtenerChat(_chat.id);
      final nuevos = await _servicio.mensajes(_chat.id,
          desde: _cargado && _mensajes.isNotEmpty ? _mensajes.last.fecha : null);
      if (!mounted) return;
      final conocidos = {for (final m in _mensajes) m.id};
      final aAnadir = [
        for (final m in nuevos)
          if (!conocidos.contains(m.id)) m,
      ];
      final primeraCarga = !_cargado;
      setState(() {
        _chat = chat;
        _mensajes.addAll(aAnadir);
        _cargado = true;
        _falloCarga = false;
      });
      if (primeraCarga || aAnadir.any((m) => m.deUid != _miUid)) {
        _servicio.marcarLeido(_chat.id);
      }
    } on ExcepcionApi {
      if (mounted && !_cargado) setState(() => _falloCarga = true);
    }
  }

  Future<void> _enviar() async {
    final texto = _msgCtrl.text.trim();
    if (texto.isEmpty) return;
    _msgCtrl.clear();
    final error = await _servicio.enviarMensaje(_chat.id, texto);
    if (!mounted) return;
    if (error != null) {
      mostrarSnackBar(context, error, esError: true);
    } else {
      _sondeo.ejecutarAhora();
    }
  }

  /// Ejecuta una acción de negociación y refresca al momento (sin esperar al
  /// siguiente tic).
  Future<void> _negociar(Future<String?> Function() accion) async {
    await ejecutarConCarga(context, accion, mostrarExito: false);
    if (mounted) await _sondeo.ejecutarAhora();
  }

  Future<void> _proponerPago() async {
    final monto = await showDialog<double>(
        context: context, builder: (_) => const DialogoPago());
    if (monto != null && mounted) {
      await _negociar(() => _servicio.proponerPago(_chat.id, monto));
    }
  }

  Future<void> _proponerTiempo() async {
    final valor = await showDialog<String>(
        context: context, builder: (_) => const DialogoTiempo());
    if (valor != null && valor.trim().isNotEmpty && mounted) {
      await _negociar(() => _servicio.proponerTiempo(_chat.id, valor.trim()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_chat.otroNombre(_miUid),
            style: const TextStyle(
                fontWeight: FontWeight.w800, letterSpacing: -0.5)),
      ),
      body: Column(
        children: [
          PanelNegociacion(
            chat: _chat,
            miUid: _miUid,
            esTrabajador: !widget.usuario.esEmpleador,
            onProponerPago: _proponerPago,
            onAceptarPago: () =>
                _negociar(() => _servicio.aceptarPago(_chat.id)),
            onProponerTiempo: _proponerTiempo,
            onAceptarTiempo: () =>
                _negociar(() => _servicio.aceptarTiempo(_chat.id)),
          ),
          Expanded(child: _listaMensajes()),
          BarraEnvio(controlador: _msgCtrl, onEnviar: _enviar),
        ],
      ),
    );
  }

  Widget _listaMensajes() {
    if (!_cargado) {
      return _falloCarga
          ? Center(
              child: Text('No pudimos cargar los mensajes. Reintentando…',
                  style: TextStyle(color: colorTextoSuave(context))))
          : const Center(
              child: CircularProgressIndicator(color: AppColores.acento));
    }
    if (_mensajes.isEmpty) {
      return Center(
        child: Text('Escriban el primer mensaje',
            style: TextStyle(color: colorTextoSuave(context))),
      );
    }
    final invertidos = _mensajes.reversed.toList();
    return ListView.builder(
      reverse: true,
      padding: const EdgeInsets.all(12),
      itemCount: invertidos.length,
      itemBuilder: (_, i) =>
          BurbujaMensaje(mensaje: invertidos[i], miUid: _miUid),
    );
  }
}
