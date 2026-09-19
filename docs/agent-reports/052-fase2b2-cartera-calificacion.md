# Reporte 052: cartera y calificaciones a la API

Rama `feature/052-cartera-calificacion-api` (desde `docs/plan-demo-completa`). Estado: en-revision.

## Qué se hizo

- `CarteraService` nuevo en `lib/funcionalidades/cartera/datos/`: `listarTarjetas`, `agregarTarjeta`, `eliminarTarjeta(id)` (sin uid), `recargarSaldo(monto)` y `movimientos()`. Modelo `MovimientoCartera` junto a él. Desaparece `streamSaldo`: el saldo sale de `sesionActual` y se refresca con `PerfilService.recargarPerfil()` (al entrar y tras recargar).
- `CalificacionService` nuevo en `lib/funcionalidades/calificaciones/datos/`: `calificar(idTrabajo, estrellas, comentario)` (sin transacción, el servidor hace todo) y `listarDe(uid, {rol})`.
- Pantallas movidas con `git mv` a `funcionalidades/cartera/pantallas/cartera_screen.dart` y `funcionalidades/calificaciones/pantallas/calificar_sheet.dart`. `CarteraScreen` pasó a `StatefulWidget` (carga puntual + deslizar para actualizar); los diálogos salieron a `dialogos_cartera.dart` (257 y 89 líneas, bajo el techo). `SeccionResenas` (compartido) usa `Future` y muestra error real en lugar de "sin reseñas" si falla.
- Inyección: ambos servicios en `proveedoresDeLaApp()`. `mostrarCalificarSheet` lee el servicio del contexto de quien la abre y se lo pasa a la hoja.
- Eliminado: los dos servicios de Firestore de `lib/services/`, `desdeFirestore`/`aFirestore` de `Tarjeta` y `Calificacion` (quedó sin `cloud_firestore` esos dos modelos), y las constantes `tarjetas`/`calificaciones` de `firestore_colecciones.dart` (el archivo sigue: lo usa `chat_service`).
- Rutas nuevas en `RutasApi`.
- `ChatService` no se tocó. `cartera_screen` y `calificar_sheet` no importaban nada de chat (confirmado).

## Contrato usado (verificado contra el código Java, no contra un servidor en vivo)

- `TarjetaController`/`TarjetaRequest`/`TarjetaResponse`: GET lista, POST `{numero,titular,vencimiento,marca?}` -> 201, DELETE `{id}`.
- `PagoController`: `POST /recargar {monto}` responde el saldo nuevo (número); `GET /movimientos` devuelve la entidad `MovimientoCartera` tal cual (`tipo`, `monto`, `saldoResultante`, `trabajoId`, `descripcion`, `creadoEn`).
- `CalificacionController`: `POST {trabajoId, estrellas, comentario}`; el receptor y `rolCalificado` los deduce el servidor. Los 409 traen "Ya calificaste este trabajo" / "El trabajo aún no está completado" y se muestran tal cual. `GET /usuario/{id}?rol=`.
- Los JSON de los tests salen de esos records Java y de `docs/api.md`, no de un `curl` a la VM (sin acceso desde este entorno).

## Hallazgo para backend (no bloquea)

`CalificacionResponse` no incluye el nombre del autor. Las reseñas se pintan como "Anónimo" (regresión visual frente a Firestore, que guardaba `deNombre`). Petición: añadir `autorNombre` al DTO (el modelo ya lo lee). `MovimientoCartera` se expone como entidad JPA, contra la norma de DTOs; funcional pero conviene un DTO.

## Cifras reales

- `flutter test`: 315 pasan, 0 fallan (baseline 296; +19 nuevos: 8 servicio cartera, 4 servicio calificación, 4 pantalla cartera, 3 hoja/reseñas).
- `flutter analyze`: 11 avisos, todos preexistentes (baseline 12; se limpió un `withOpacity` del archivo movido). Sin errores.
- Test existente modificado: `perfil_tab_test.dart` ("abrir la pestaña no pide nada al servidor"). Aserción `peticiones isEmpty` era cierta solo porque las reseñas iban por Firestore; ahora exige que lo único pedido sea `GET /api/calificaciones/usuario/{id}` (una vez). El test estaba desactualizado por el cambio, no el cambio mal.

## No verificado

- Nada contra el backend real ni en emulador (sin acceso a la VM; no se abrió ningún emulador). Que el PR #8 (tarjetas) esté desplegado en la VM no está confirmado.
- `calificador`/`paraUid` de `mostrarCalificarSheet` ya no se usan dentro de la hoja (el servidor los deduce); se dejaron en la firma para no tocar a `detalle_trabajo_screen`. Limpieza pendiente.
- `movimientos()` existe y está probado pero ninguna pantalla lo muestra todavía.
- `test/manual/generar_capturas_perfil_inicio.dart` menciona Firestore en un comentario y no se revisó.
