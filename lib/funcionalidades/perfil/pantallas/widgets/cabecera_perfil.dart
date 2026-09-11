import 'package:flutter/material.dart';
import '../../../../compartido/modelos/usuario.dart';
import '../../../../compartido/widgets/estrellas.dart';
import '../../../../nucleo/tema/app_colores.dart';

/// Cabecera de la pestaña "Perfil": avatar, nombre, badge de rol y estrellas,
/// sobre un degradado. Extraída de `perfil_tab.dart` en la tarea 027 B-2b.
class CabeceraPerfil extends StatelessWidget {
  final Usuario usuario;
  final bool esEmpleador;
  final VoidCallback onConfiguracion;

  const CabeceraPerfil({
    super.key,
    required this.usuario,
    required this.esEmpleador,
    required this.onConfiguracion,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColores.principal, AppColores.azulProfesional],
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              onPressed: onConfiguracion,
              icon: const Icon(Icons.settings_outlined, color: Colors.white),
              tooltip: 'Configuración',
            ),
          ),
          CircleAvatar(
            radius: 38,
            backgroundColor: Colors.white.withValues(alpha: 0.18),
            child: Text(
              usuario.iniciales,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            usuario.nombreVisible,
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: AppColores.dorado.withValues(alpha: 0.20),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              esEmpleador ? 'EMPLEADOR' : 'TRABAJADOR',
              style: const TextStyle(
                  color: AppColores.dorado,
                  fontSize: 11,
                  fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 10),
          Estrellas(
            valor: usuario.calificacionPromedio,
            total: usuario.totalCalificaciones,
            colorTexto: Colors.white,
          ),
        ],
      ),
    );
  }
}
