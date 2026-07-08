import 'package:flutter/material.dart';
import '../../models/chat.dart';
import '../../models/usuario.dart';
import '../../services/chat_service.dart';
import '../../utils/constantes.dart';
import '../chat_screen.dart';

/// Pestaña "Chats": conversaciones del usuario con la otra parte.
class ChatsTab extends StatelessWidget {
  final Usuario usuario;
  const ChatsTab({super.key, required this.usuario});

  @override
  Widget build(BuildContext context) {
    final oscuro = Theme.of(context).brightness == Brightness.dark;
    final servicio = ChatService();

    return StreamBuilder<List<Chat>>(
      stream: servicio.streamMisChats(usuario.uid),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return const Center(
              child: CircularProgressIndicator(color: AppColores.acento));
        }
        final chats = snap.data ?? [];
        if (chats.isEmpty) {
          return _estadoVacio(oscuro);
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          itemCount: chats.length,
          itemBuilder: (context, i) => _tarjeta(context, chats[i], oscuro),
        );
      },
    );
  }

  Widget _tarjeta(BuildContext context, Chat chat, bool oscuro) {
    final superficie = oscuro ? AppColores.superficieOscura : AppColores.blanco;
    final borde = oscuro ? AppColores.bordeOscuro : AppColores.grisClaro;
    final textoPrincipal = oscuro ? AppColores.textoOscuro : AppColores.texto;
    final textoSec = oscuro ? AppColores.grisMedio : AppColores.grisTexto;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => ChatScreen(chat: chat, usuario: usuario)),
      ),
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
              backgroundColor: AppColores.acento.withOpacity(0.15),
              child: Text(
                chat.otroNombre(usuario.uid).isNotEmpty
                    ? chat.otroNombre(usuario.uid)[0].toUpperCase()
                    : '?',
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
                    chat.otroNombre(usuario.uid),
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
            if (chat.pagoAcordado && chat.tiempoAcordado)
              const Icon(Icons.handshake_rounded,
                  color: AppColores.verde, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _estadoVacio(bool oscuro) {
    final textoSec = oscuro ? AppColores.grisMedio : AppColores.grisTexto;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.forum_outlined, size: 56, color: AppColores.grisMedio),
            const SizedBox(height: 14),
            Text(
              usuario.esEmpleador
                  ? 'Aún no tienes chats.\nSe crean al seleccionar a un postulante.'
                  : 'Aún no tienes chats.\nSe crean cuando te seleccionan para un trabajo.',
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
