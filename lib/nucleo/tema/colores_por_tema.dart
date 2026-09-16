import 'package:flutter/material.dart';

import 'app_colores.dart';

// El color que toca segun el tema claro u oscuro.
//
// `AppColores` es la paleta fija; esto es la parte que **depende del
// contexto**, y por eso vive aparte. Estaba escondido en
// `widgets/custom_textfield.dart` hasta la tarea 027 (parte B-1), donde no
// lo encontraba nadie: son ayudas de tema, no un campo de texto.
//
// Lo usan 15 pantallas. Antes de tocar cualquiera de las cuatro, mira quien
// las llama.
bool _esOscuro(BuildContext c) => Theme.of(c).brightness == Brightness.dark;

Color colorTextoFuerte(BuildContext c) =>
    _esOscuro(c) ? AppColores.textoOscuro : AppColores.azulOscuro;
Color colorTextoSuave(BuildContext c) =>
    _esOscuro(c) ? AppColores.grisMedio : AppColores.grisTexto;
Color colorSuperficie(BuildContext c) =>
    _esOscuro(c) ? AppColores.superficieOscura : AppColores.blanco;
Color colorBorde(BuildContext c) =>
    _esOscuro(c) ? AppColores.bordeOscuro : AppColores.grisClaro;
