import 'package:flutter/material.dart';
import '../../../../nucleo/espaciado/app_espaciado.dart';

/// Accesos rápidos de la pestaña "Perfil": "Mis publicaciones"/"Mis
/// postulaciones" (según rol) y "Cartera". Extraído de `perfil_tab.dart` en la
/// tarea 027 B-2b. La navegación la resuelve el `State` de la pestaña.
class AccesosRapidosPerfil extends StatelessWidget {
  final bool esEmpleador;
  final VoidCallback onMisTrabajos;
  final VoidCallback onCartera;

  const AccesosRapidosPerfil({
    super.key,
    required this.esEmpleador,
    required this.onMisTrabajos,
    required this.onCartera,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ElevatedButton.icon(
          onPressed: onMisTrabajos,
          icon: Icon(
              esEmpleador ? Icons.assignment_outlined : Icons.send_outlined),
          label:
              Text(esEmpleador ? 'Mis publicaciones' : 'Mis postulaciones'),
        ),
        const SizedBox(height: AppEspaciado.md),
        OutlinedButton.icon(
          onPressed: onCartera,
          icon: const Icon(Icons.account_balance_wallet_outlined),
          label: const Text('Cartera'),
        ),
      ],
    );
  }
}
