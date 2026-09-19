import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../compartido/modelos/usuario.dart';
import '../../../compartido/sondeo/sondeo_periodico.dart';
import '../../../nucleo/api/api_excepciones.dart';
import '../../../nucleo/tema/app_colores.dart';
import '../datos/chat.dart';
import '../datos/chat_service.dart';
import 'chat_screen.dart';

/// Pestaña "Chats": conversaciones del usuario con la otra parte.
///
/// Se refresca con un sondeo (ADR-0018) mientras la pestaña está montada:
/// `InicioScreen` solo construye la pestaña visible, así que al cambiar de
/// pestaña el `Timer` se cancela en `dispose`.
class ChatsTab extends StatefulWidget {
  final Usuario usuario;
  final Duration intervaloSondeo;
  const ChatsTab({
    super.key,
    required this.usuario,
    this.intervaloSondeo = const Duration(seconds: 5),
  });

  @override
  State<ChatsTab> createState() => _ChatsTabState();
}

class _ChatsTabState extends State<ChatsTab> {
  late final ChatService _servicio = context.read<ChatService>();
  late final SondeoPeriodico _sondeo;
  List<Chat>? _chats;
  bool _falloCarga = false;

  Usuario get usuario => widget.usuario;

  @override
  void initState() {
    super.initState();
    _sondeo = SondeoPeriodico(cada: widget.intervaloSondeo, tarea: _cargar)
      ..iniciar();
    _sondeo.ejecutarAhora();
  }

  @override
  void dispose() {
    _sondeo.detener();
    super.dispose();
  }

  Future<void> _cargar() async {
    try {
      final chats = await _servicio.misChats();
      if (!mounted) return;
      setState(() {
        _chats = chats;
        _falloCarga = false;
      });
    } on ExcepcionApi {
      // Con datos ya en pantalla, un tic fallido no los borra.
      if (mounted && _chats == null) setState(() => _falloCarga = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final oscuro = Theme.of(context).brightness == Brightness.dark;
    final chats = _chats;
    if (chats == null) {
      if (_falloCarga) {
        return _mensajeCentrado(
            oscuro,
            'No pudimos cargar tus chats.\nReintentando…',
            Icons.cloud_off_outlined);
      }
      return const Center(
          child: CircularProgressIndicator(color: AppColores.acento));
    }
    if (chats.isEmpty) {
      return _mensajeCentrado(
          oscuro,
          usuario.esEmpleador
              ? 'Aún no tienes chats.\nSe crean al seleccionar a un postulante.'
              : 'Aún no tienes chats.\nSe crean cuando te seleccionan para un trabajo.',
          Icons.forum_outlined);
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      itemCount: chats.length,
      itemBuilder: (context, i) => _tarjeta(context, chats[i], oscuro),
    );
  }

  Widget _tarjeta(BuildContext context, Chat chat, bool oscuro) {
    final superficie = oscuro ? AppColores.superficieOscura : AppColores.blanco;
    final borde = oscuro ? AppColores.bordeOscuro : AppColores.grisClaro;
    final textoPrincipal = oscuro ? AppColores.textoOscuro : AppColores.texto;
    final textoSec = oscuro ? AppColores.grisMedio : AppColores.grisTexto;
    final nombre = chat.otroNombre(usuario.uid);

    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => ChatScreen(chat: chat, usuario: usuario)),
        );
        // Al volver, los no leídos ya cambiaron: no esperar al siguiente tic.
        if (mounted) _sondeo.ejecutarAhora();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: superficie,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borde, width: 1),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: AppColores.acento.withValues(alpha: 0.15),
              child: Text(
                nombre.isNotEmpty ? nombre[0].toUpperCase() : '?',
                style: const TextStyle(
                    color: AppColores.acento,
                    fontWeight: FontWeight.w800,
                    fontSize: 18),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nombre,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: textoPrincipal,
                        fontSize: 15,
                        fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    chat.tituloPublicacion,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: AppColores.acento,
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    chat.ultimoMensaje,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: textoSec, fontSize: 13),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (chat.noLeidos > 0)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: const BoxDecoration(
                        color: AppColores.acento, shape: BoxShape.circle),
                    constraints:
                        const BoxConstraints(minWidth: 20, minHeight: 20),
                    alignment: Alignment.center,
                    child: Text('${chat.noLeidos}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800)),
                  ),
                if (chat.acuerdoCompleto)
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Icon(Icons.handshake_rounded,
                        color: AppColores.verde, size: 18),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _mensajeCentrado(bool oscuro, String texto, IconData icono) {
    final textoSec = oscuro ? AppColores.grisMedio : AppColores.grisTexto;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icono, size: 56, color: AppColores.grisMedio),
            const SizedBox(height: 14),
            Text(
              texto,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: textoSec, fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
