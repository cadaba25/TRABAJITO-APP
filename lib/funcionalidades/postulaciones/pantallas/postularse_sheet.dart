import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../compartido/modelos/postulacion.dart';
import '../../../compartido/modelos/publicacion.dart';
import '../../../compartido/modelos/usuario.dart';
import '../datos/postulacion_service.dart';
import '../../../nucleo/espaciado/app_espaciado.dart';
import '../../../nucleo/tema/app_colores.dart';
import '../../../compartido/widgets/boton_primario.dart';
import '../../../compartido/widgets/custom_textfield.dart';
import '../../../compartido/widgets/estado_exito.dart';
import '../../../compartido/widgets/mostrar_snackbar.dart';
import '../../../nucleo/tema/colores_por_tema.dart';
import '../../../nucleo/tipografia/app_tipografia.dart';

/// Muestra el modal para postularse a un trabajo.
/// Devuelve true si la postulación se envió.
Future<bool?> mostrarPostularseSheet(
  BuildContext context, {
  required Publicacion publicacion,
  required Usuario usuario,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _PostularseSheet(publicacion: publicacion, usuario: usuario),
  );
}

class _PostularseSheet extends StatefulWidget {
  final Publicacion publicacion;
  final Usuario usuario;
  const _PostularseSheet({required this.publicacion, required this.usuario});

  @override
  State<_PostularseSheet> createState() => _PostularseSheetState();
}

class _PostularseSheetState extends State<_PostularseSheet> {
  final _mensajeCtrl = TextEditingController();
  late final _servicio = context.read<PostulacionService>();
  bool _cargando = false;

  /// `true` mientras se enseña el check de éxito (ADR-0015, fase 6), justo
  /// antes de cerrar la hoja. `detalle_trabajo_screen.dart` sigue leyendo
  /// `true` del `pop`, solo que unos milisegundos más tarde.
  bool _exito = false;

  @override
  void dispose() {
    _mensajeCtrl.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    if (_cargando) return;
    setState(() => _cargando = true);
    final postulacion = Postulacion(
      idPublicacion: widget.publicacion.id,
      tituloPublicacion: widget.publicacion.titulo,
      uidTrabajador: widget.usuario.uid,
      nombreTrabajador: widget.usuario.nombreCorto,
      uidEmpleador: widget.publicacion.uidEmpleador,
      mensaje: _mensajeCtrl.text.trim(),
      fechaPostulacion: DateTime.now(),
    );
    final error = await _servicio.postular(postulacion);
    if (!mounted) return;
    setState(() => _cargando = false);
    if (error != null) {
      mostrarSnackBar(context, error, esError: true);
      return;
    }
    setState(() => _exito = true);
    await Future.delayed(duracionExitoVisible);
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final oscuro = Theme.of(context).brightness == Brightness.dark;
    final superficie = oscuro ? AppColores.superficieOscura : AppColores.blanco;
    final padInf = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: padInf),
      child: Container(
        padding: const EdgeInsets.fromLTRB(AppEspaciado.xl, AppEspaciado.md,
            AppEspaciado.xl, AppEspaciado.xl),
        decoration: BoxDecoration(
          color: superficie,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(AppRadios.chip)),
        ),
        child: _exito
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: AppEspaciado.xl),
                child: EstadoExito(mensaje: '¡Postulación enviada!'),
              )
            : _formulario(),
      ),
    );
  }

  Widget _formulario() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 40,
            height: 4,
            // Radio 2: barra de agarre nativa del sheet, no una tarjeta/chip
            // (mismo criterio de excepción que el checkbox de AppTema).
            margin: const EdgeInsets.only(bottom: AppEspaciado.lg),
            decoration: BoxDecoration(
              color: AppColores.grisMedio,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        Text('Postularme',
            style: Theme.of(context)
                .textTheme
                .titulo
                .copyWith(color: colorTextoFuerte(context))),
        const SizedBox(height: AppEspaciado.xs),
        Text(widget.publicacion.titulo,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context)
                .textTheme
                .cuerpoChico
                .copyWith(color: colorTextoSuave(context))),
        const SizedBox(height: AppEspaciado.lg),
        CustomTextField(
          controller: _mensajeCtrl,
          label: 'Mensaje al contratador (opcional)',
          hint: 'Cuéntale por qué eres ideal para este trabajo...',
          maxLines: 4,
          maxLength: 400,
        ),
        const SizedBox(height: AppEspaciado.md),
        BotonPrimario(
          texto: 'Enviar postulación',
          cargando: _cargando,
          onPressed: _enviar,
        ),
      ],
    );
  }
}
