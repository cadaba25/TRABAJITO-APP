import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/chat.dart';
import '../models/usuario.dart';
import '../services/chat_service.dart';
import '../utils/constantes.dart';
import '../widgets/custom_textfield.dart';

/// Conversación entre contratista y trabajador, con negociación de
/// pago y tiempo.
class ChatScreen extends StatefulWidget {
  final Chat chat;
  final Usuario usuario;
  const ChatScreen({super.key, required this.chat, required this.usuario});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _servicio = ChatService();
  final _msgCtrl = TextEditingController();

  String get _miUid => widget.usuario.uid;

  @override
  void initState() {
    super.initState();
    // Auto-repara el chat si venimos de una asignación antigua sin doc.
    _servicio.asegurarChat(widget.chat);
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    final texto = _msgCtrl.text.trim();
    if (texto.isEmpty) return;
    _msgCtrl.clear();
    final error = await _servicio.enviarMensaje(widget.chat.id, texto, _miUid);
    if (error != null && mounted) {
      mostrarSnackBar(context, error, esError: true);
    }
  }

  Future<void> _proponerPago() async {
    final ctrl = TextEditingController();
    final monto = await showDialog<double>(
      context: context,
      builder: (ctx) => _DialogoProponer(
        titulo: 'Proponer pago',
        etiqueta: 'Monto en Lempiras',
        controlador: ctrl,
        soloNumeros: true,
      ),
    );
    if (monto != null) {
      await _servicio.proponerPago(widget.chat.id, monto, _miUid);
    }
  }

  Future<void> _proponerTiempo() async {
    final ctrl = TextEditingController();
    final valor = await showDialog<String>(
      context: context,
      builder: (ctx) => _DialogoProponer(
        titulo: 'Proponer plazo',
        etiqueta: 'p. ej. 3 días, 1 semana',
        controlador: ctrl,
        soloNumeros: false,
      ),
    );
    if (valor != null && valor.trim().isNotEmpty) {
      await _servicio.proponerTiempo(widget.chat.id, valor.trim(), _miUid);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.chat.otroNombre(_miUid),
            style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.5)),
      ),
      body: StreamBuilder<Chat?>(
        stream: _servicio.streamChat(widget.chat.id),
        builder: (context, chatSnap) {
          final chat = chatSnap.data ?? widget.chat;
          return Column(
            children: [
              _panelNegociacion(chat),
              Expanded(child: _listaMensajes()),
              _barraEnviar(),
            ],
          );
        },
      ),
    );
  }

  // ── Panel de negociación ───────────────────────────────────
  Widget _panelNegociacion(Chat chat) {
    final oscuro = Theme.of(context).brightness == Brightness.dark;
    final superficie = oscuro ? AppColores.superficieOscura : AppColores.blanco;
    final borde = oscuro ? AppColores.bordeOscuro : AppColores.grisClaro;

    return Container(
      color: superficie,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        children: [
          _filaNegociacion(
            chat,
            icono: Icons.payments_outlined,
            titulo: 'Pago',
            valor: chat.pagoMonto > 0
                ? 'L. ${chat.pagoMonto.toStringAsFixed(0)}'
                : 'Sin propuesta',
            acordado: chat.pagoAcordado,
            pendiente: chat.pagoPendiente,
            propuestoPorMi: chat.pagoPropuestoPor == _miUid,
            onProponer: _proponerPago,
            onAceptar: () => _servicio.aceptarPago(chat.id, _miUid),
          ),
          Divider(height: 16, color: borde),
          _filaNegociacion(
            chat,
            icono: Icons.schedule_rounded,
            titulo: 'Tiempo',
            valor: chat.tiempoValor.isNotEmpty ? chat.tiempoValor : 'Sin propuesta',
            acordado: chat.tiempoAcordado,
            pendiente: chat.tiempoPendiente,
            propuestoPorMi: chat.tiempoPropuestoPor == _miUid,
            onProponer: _proponerTiempo,
            onAceptar: () => _servicio.aceptarTiempo(chat.id, _miUid),
          ),
        ],
      ),
    );
  }

  Widget _filaNegociacion(
    Chat chat, {
    required IconData icono,
    required String titulo,
    required String valor,
    required bool acordado,
    required bool pendiente,
    required bool propuestoPorMi,
    required VoidCallback onProponer,
    required Future<void> Function() onAceptar,
  }) {
    return Row(
      children: [
        Icon(icono, size: 18, color: AppColores.azulProfesional),
        const SizedBox(width: 8),
        SizedBox(
          width: 52,
          child: Text(titulo,
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: colorTextoFuerte(context))),
        ),
        Expanded(
          child: Text(
            valor,
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: acordado ? AppColores.verde : colorTextoFuerte(context)),
          ),
        ),
        if (acordado)
          const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: AppColores.verde, size: 18),
              SizedBox(width: 4),
              Text('Acordado',
                  style: TextStyle(
                      color: AppColores.verde,
                      fontWeight: FontWeight.w700,
                      fontSize: 12)),
            ],
          )
        else if (pendiente && !propuestoPorMi)
          _botonMini('Aceptar', AppColores.verde, () => onAceptar())
        else if (pendiente && propuestoPorMi)
          Text('Esperando…',
              style: TextStyle(color: colorTextoSuave(context), fontSize: 12))
        else
          _botonMini('Proponer', AppColores.acento, onProponer),
      ],
    );
  }

  Widget _botonMini(String texto, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(texto,
            style: TextStyle(
                color: color, fontWeight: FontWeight.w700, fontSize: 12)),
      ),
    );
  }

  // ── Lista de mensajes ──────────────────────────────────────
  Widget _listaMensajes() {
    return StreamBuilder<List<Mensaje>>(
      stream: _servicio.streamMensajes(widget.chat.id),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return const Center(
              child: CircularProgressIndicator(color: AppColores.acento));
        }
        final mensajes = (snap.data ?? []).reversed.toList();
        if (mensajes.isEmpty) {
          return Center(
            child: Text('Escriban el primer mensaje 👋',
                style: TextStyle(color: colorTextoSuave(context))),
          );
        }
        return ListView.builder(
          reverse: true,
          padding: const EdgeInsets.all(12),
          itemCount: mensajes.length,
          itemBuilder: (context, i) => _burbuja(mensajes[i]),
        );
      },
    );
  }

  Widget _burbuja(Mensaje m) {
    final oscuro = Theme.of(context).brightness == Brightness.dark;
    if (m.esSistema) {
      return Center(
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColores.azulProfesional.withOpacity(0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(m.texto,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: AppColores.azulProfesional,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
        ),
      );
    }
    final mio = m.deUid == _miUid;
    return Align(
      alignment: mio ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.72),
        decoration: BoxDecoration(
          color: mio
              ? AppColores.acento
              : (oscuro ? AppColores.superficieOscura : AppColores.blanco),
          borderRadius: BorderRadius.circular(16),
          border: mio
              ? null
              : Border.all(
                  color: oscuro ? AppColores.bordeOscuro : AppColores.grisClaro),
        ),
        child: Text(m.texto,
            style: TextStyle(
                color: mio
                    ? Colors.white
                    : (oscuro ? AppColores.textoOscuro : AppColores.texto),
                fontSize: 14,
                height: 1.3)),
      ),
    );
  }

  // ── Barra de envío ─────────────────────────────────────────
  Widget _barraEnviar() {
    final oscuro = Theme.of(context).brightness == Brightness.dark;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        decoration: BoxDecoration(
          color: oscuro ? AppColores.superficieOscura : AppColores.blanco,
          border: Border(
              top: BorderSide(
                  color: oscuro ? AppColores.bordeOscuro : AppColores.grisClaro)),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _msgCtrl,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _enviar(),
                minLines: 1,
                maxLines: 4,
                style: TextStyle(color: colorTextoFuerte(context)),
                decoration: InputDecoration(
                  hintText: 'Escribe un mensaje…',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: (oscuro ? AppColores.fondoOscuro : AppColores.grisLienzo),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              style: IconButton.styleFrom(backgroundColor: AppColores.acento),
              onPressed: _enviar,
              icon: const Icon(Icons.send_rounded, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

/// Diálogo para ingresar una propuesta (monto o texto).
class _DialogoProponer extends StatelessWidget {
  final String titulo;
  final String etiqueta;
  final TextEditingController controlador;
  final bool soloNumeros;
  const _DialogoProponer({
    required this.titulo,
    required this.etiqueta,
    required this.controlador,
    required this.soloNumeros,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(titulo, style: const TextStyle(fontWeight: FontWeight.w700)),
      content: TextField(
        controller: controlador,
        autofocus: true,
        keyboardType: soloNumeros ? TextInputType.number : TextInputType.text,
        inputFormatters:
            soloNumeros ? [FilteringTextInputFormatter.digitsOnly] : null,
        decoration: InputDecoration(labelText: etiqueta),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () {
            if (soloNumeros) {
              final n = double.tryParse(controlador.text.trim());
              if (n == null || n <= 0) return;
              Navigator.pop(context, n);
            } else {
              Navigator.pop(context, controlador.text.trim());
            }
          },
          child: const Text('Proponer'),
        ),
      ],
    );
  }
}
