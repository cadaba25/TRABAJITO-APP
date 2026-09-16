#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Trabajito - prueba de integracion del flujo de negocio contra la API real.
#
# Tarea 006 (qa-agent). NO son tests unitarios: esto golpea un backend que ya
# esta corriendo contra PostgreSQL de verdad y comprueba, ademas de los
# codigos HTTP, que el DINERO cuadre (saldo == suma de movimientos_cartera).
#
# Uso (desde el servidor donde corre el backend):
#   bash backend/scripts/prueba-flujo-negocio.sh
#
# Variables:
#   API_URL      URL base de la API           (default: http://localhost:8080)
#   COMPOSE_DIR  directorio del docker-compose (default: el padre de scripts/)
#                Se usa para consultar la BD con psql.
#   SIN_PSQL=1   no consultar la BD (solo API). Se saltan los cuadres de BD.
#
# Codigo de salida:
#   0  todo bien, o solo fallaron comprobaciones marcadas como FALLO CONOCIDO
#   1  hubo al menos un fallo NO esperado (regresion)
#
# Los "FALLO CONOCIDO" son bugs ya diagnosticados y con tarea abierta:
#   BUG-007  integridad del dinero: race condition en cartera/escrow y
#            redondeo sub-centavo  -> docs/agent-tasks/007-*.md
#   BUG-008  ARREGLADO en la tarea 008 (ADR-0005): el registro publico ya no
#            puede crear ADMIN. Sus comprobaciones siguen aqui, pero ya sin
#            marca de fallo conocido: ahora son test de regresion.
#   BUG-009  ARREGLADO en la tarea 009 (ADR-0008): los errores de cliente ya
#            devuelven 400/401/404/405/415 en vez de 500, y todo error queda
#            en el log. Sus comprobaciones siguen aqui, ya sin marca de fallo
#            conocido: ahora son test de regresion.
#   BUG-010  ARREGLADO en la tarea 010 (ADR-0007): cancelar tras la entrega
#            responde 409, entregar exige evidencias y el reclamo a soporte
#            congela el escrow. Sus comprobaciones siguen aqui, ya sin marca
#            de fallo conocido: ahora son test de regresion.
#
# Tarea 019 (backend-agent): se anadio la seccion "PERFIL COMPLETO DEL
#   TRABAJADOR" (habilidades, experiencia, estudios y privacidad del perfil
#   ajeno), las comprobaciones de reputacion separada por rol dentro del paso
#   10, y "postularse a tu propio trabajo" paso de 400 a 409 A PROPOSITO
#   (decision del dueno). Si ves 400 ahi, es una regresion.
#
# Tarea 024 (security-agent): seccion "CIERRE DE SESION - familia y todos los
#   dispositivos". El logout revoca ahora la FAMILIA entera de refresh tokens
#   (ADR-0012), no solo la fila presentada, y existe POST /api/auth/logout-todos
#   para cerrar sesion en todos los dispositivos. Son 12 comprobaciones mas y
#   NINGUNA gasta intentos fallidos del cupo por IP.
# ---------------------------------------------------------------------------
set -u

API="${API_URL:-http://localhost:8080}"
COMPOSE_DIR="${COMPOSE_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
SIN_PSQL="${SIN_PSQL:-0}"
TS="$(date +%s%N | cut -c1-13)"
PASS=0; FAIL=0; KNOWN=0
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

rojo()  { printf '\033[31m%s\033[0m\n' "$*"; }
verde() { printf '\033[32m%s\033[0m\n' "$*"; }
ama()   { printf '\033[33m%s\033[0m\n' "$*"; }
titulo(){ echo; echo "=========================================================="; echo "$*"; echo "=========================================================="; }

# --- helpers --------------------------------------------------------------
# api METODO RUTA [TOKEN] [BODY] -> imprime el codigo HTTP; cuerpo en $TMP/body
api() {
  local m="$1" ruta="$2" tk="${3:-}" body="${4:-}"
  local args=(-s -o "$TMP/body" -w '%{http_code}' -X "$m" "$API$ruta")
  [ -n "$tk" ] && args+=(-H "Authorization: Bearer $tk")
  if [ -n "$body" ]; then args+=(-H 'Content-Type: application/json' -d "$body"); fi
  curl "${args[@]}"
}
campo() { jq -r "$1" < "$TMP/body" 2>/dev/null; }

psql_() {
  [ "$SIN_PSQL" = "1" ] && return 0
  ( cd "$COMPOSE_DIR" && docker compose exec -T db \
      psql -U trabajito -d trabajito -tAc "$1" < /dev/null ) | tr -d '\r'
}

# ok "descripcion" esperado obtenido [BUG-xxx]
ok() {
  local desc="$1" esp="$2" obt="$3" bug="${4:-}"
  if [ "$esp" = "$obt" ]; then
    PASS=$((PASS+1)); verde "  OK    $desc  ($obt)"
  elif [ -n "$bug" ]; then
    KNOWN=$((KNOWN+1)); ama "  BUG   $desc  esperado=$esp obtenido=$obt  [FALLO CONOCIDO $bug]"
  else
    FAIL=$((FAIL+1)); rojo "  FALLA $desc  esperado=$esp obtenido=$obt"
    echo "        cuerpo: $(head -c 300 "$TMP/body")"
  fi
}

# registrar CORREO NOMBRE ROL -> deja el token en $TOKEN y el id en $ULTIMO_ID.
# No devuelve por stdout porque necesita exportar dos valores (y una
# sustitucion de comandos correria en un subshell: las asignaciones se perderian).
TOKEN=""; ULTIMO_ID=""
registrar() {
  local r
  r=$(curl -s -X POST "$API/api/auth/registro" -H 'Content-Type: application/json' \
      -d "{\"correo\":\"$1\",\"password\":\"Prueba1234\",\"nombres\":\"$2\",\"apellidos\":\"QA\",\"rol\":\"$3\"}")
  TOKEN=$(echo "$r" | jq -r .token)
  ULTIMO_ID=$(echo "$r" | jq -r .usuario.id)
}
crear_trabajo() { # token titulo -> id
  curl -s -X POST "$API/api/trabajos" -H 'Content-Type: application/json' \
    -H "Authorization: Bearer $1" \
    -d "{\"titulo\":\"$2\",\"descripcion\":\"Trabajo de prueba automatizada.\"}" | jq -r .id
}
postular() { # token trabajoId -> postulacionId
  curl -s -X POST "$API/api/postulaciones" -H 'Content-Type: application/json' \
    -H "Authorization: Bearer $1" -d "{\"trabajoId\":\"$2\",\"mensaje\":\"Me interesa.\"}" | jq -r .id
}
saldo_api() { curl -s "$API/api/auth/yo" -H "Authorization: Bearer $1" | jq -r .saldo; }
evidencia() { # token trabajoId [texto] -> codigo HTTP (silencioso)
  curl -s -o /dev/null -w '%{http_code}' -X POST "$API/api/trabajos/$2/evidencias" \
    -H 'Content-Type: application/json' -H "Authorization: Bearer $1" \
    -d "{\"texto\":\"${3:-Trabajo terminado, foto adjunta.}\",\"archivoUrl\":\"/uploads/qa.jpg\"}"
}

command -v jq >/dev/null || { rojo "Falta jq"; exit 1; }
echo "API=$API   COMPOSE_DIR=$COMPOSE_DIR   SIN_PSQL=$SIN_PSQL"

# --- actores --------------------------------------------------------------
titulo "0. Registro de actores"
registrar "qa.emp.$TS@trabajito.local" Elena EMPLEADOR; TK_EMP=$TOKEN; ID_EMP=$ULTIMO_ID
registrar "qa.tra.$TS@trabajito.local" Tomas TRABAJADOR; TK_TRA=$TOKEN; ID_TRA=$ULTIMO_ID
registrar "qa.ter.$TS@trabajito.local" Tulio TRABAJADOR; TK_TER=$TOKEN; ID_TER=$ULTIMO_ID
ok "empleador registrado"  "true" "$([ -n "$ID_EMP" ] && echo true)"
ok "trabajador registrado" "true" "$([ -n "$ID_TRA" ] && echo true)"
echo "  empleador=$ID_EMP  trabajador=$ID_TRA  tercero=$ID_TER"

# --- FLUJO FELIZ ----------------------------------------------------------
titulo "FLUJO FELIZ (pasos 1-10)"

echo "-- 1. Publicar trabajo"
ok "POST /api/trabajos" 200 "$(api POST /api/trabajos "$TK_EMP" '{"titulo":"Instalar 3 lamparas LED","descripcion":"Sala y cocina.","categoria":"Electricidad","departamento":"Francisco Morazan","ciudad":"Tegucigalpa","presupuesto":"L. 1200","plazo":"Corto plazo"}')"
TRABAJO=$(campo .id)
ok "estado inicial" ACTIVO "$(campo .estado)"

echo "-- 2. Postularse (trabajador)"
ok "POST /api/postulaciones" 200 "$(api POST /api/postulaciones "$TK_TRA" "{\"trabajoId\":\"$TRABAJO\",\"mensaje\":\"5 anios de experiencia\"}")"
POSTULACION=$(campo .id)
ok "estado de la postulacion" PENDIENTE "$(campo .estado)"

echo "-- 3. Ver postulantes (empleador)"
ok "GET /api/postulaciones?trabajoId=" 200 "$(api GET "/api/postulaciones?trabajoId=$TRABAJO" "$TK_EMP")"
ok "cantidad de postulantes" 1 "$(campo 'length')"

echo "-- 4. Aceptar postulacion"
ok "POST /api/postulaciones/{id}/aceptar" 200 "$(api POST "/api/postulaciones/$POSTULACION/aceptar" "$TK_EMP")"
ok "postulacion ACEPTADA" ACEPTADA "$(campo .estado)"
api GET "/api/trabajos/$TRABAJO" "$TK_EMP" >/dev/null
ok "trabajo ASIGNADO" ASIGNADO "$(campo .estado)"
ok "trabajador asignado" "$ID_TRA" "$(campo .trabajadorAsignadoId)"

echo "-- 5. Recargar cartera del empleador (L. 2000)"
ok "POST /api/cartera/recargar" 200 "$(api POST /api/cartera/recargar "$TK_EMP" '{"monto":2000}')"
ok "saldo tras recargar (API)" "2000.00" "$(saldo_api "$TK_EMP")"
[ "$SIN_PSQL" = 1 ] || ok "saldo tras recargar (BD)" "2000.00" "$(psql_ "SELECT saldo FROM usuarios WHERE id='$ID_EMP'")"

echo "-- 6. Reservar pago / escrow (L. 1500)"
ok "POST /api/trabajos/{id}/reservar-pago" 200 "$(api POST "/api/trabajos/$TRABAJO/reservar-pago" "$TK_EMP" '{"monto":1500,"tiempo":"2 dias"}')"
ok "trabajo ACORDADO" ACORDADO "$(campo .estado)"
ok "pagoRetenido" true "$(campo .pagoRetenido)"
ok "DINERO: saldo del empleador 2000-1500" "500.00" "$(saldo_api "$TK_EMP")"
api GET /api/cartera/movimientos "$TK_EMP" >/dev/null
ok "movimiento RETENCION de -1500" "-1500.00" "$(campo '[.[]|select(.tipo=="RETENCION")][0].monto')"

echo "-- 7. Iniciar (trabajador)"
ok "POST /api/trabajos/{id}/iniciar" 200 "$(api POST "/api/trabajos/$TRABAJO/iniciar" "$TK_TRA")"
ok "trabajo EN_PROGRESO" EN_PROGRESO "$(campo .estado)"

echo "-- 8. Terminar (trabajador, con evidencias obligatorias)"
ok "sin evidencias NO se puede entregar" 409 "$(api POST "/api/trabajos/$TRABAJO/terminar" "$TK_TRA")"
ok "POST /api/trabajos/{id}/evidencias" 200 "$(evidencia "$TK_TRA" "$TRABAJO" "Lamparas instaladas")"
ok "POST /api/trabajos/{id}/terminar" 200 "$(api POST "/api/trabajos/$TRABAJO/terminar" "$TK_TRA")"
ok "trabajo ESPERANDO_CONFIRMACION" ESPERANDO_CONFIRMACION "$(campo .estado)"

echo "-- 9. Aceptar y liberar el pago (empleador)"
ok "POST /api/trabajos/{id}/aceptar" 200 "$(api POST "/api/trabajos/$TRABAJO/aceptar" "$TK_EMP")"
ok "trabajo COMPLETADO" COMPLETADO "$(campo .estado)"
ok "pagoLiberado" true "$(campo .pagoLiberado)"
ok "DINERO: el trabajador recibio 1500" "1500.00" "$(saldo_api "$TK_TRA")"
ok "DINERO: el empleador sigue en 500" "500.00" "$(saldo_api "$TK_EMP")"
api GET /api/cartera/movimientos "$TK_TRA" >/dev/null
ok "movimiento LIBERACION de +1500" "1500.00" "$(campo '[.[]|select(.tipo=="LIBERACION")][0].monto')"
ok "el trabajador tiene exactamente 1 movimiento" 1 "$(campo 'length')"

echo "-- 10. Calificar (ambas partes)"
ok "empleador califica" 200 "$(api POST /api/calificaciones "$TK_EMP" "{\"trabajoId\":\"$TRABAJO\",\"estrellas\":5,\"comentario\":\"Excelente.\"}")"
ok "trabajador califica" 200 "$(api POST /api/calificaciones "$TK_TRA" "{\"trabajoId\":\"$TRABAJO\",\"estrellas\":4,\"comentario\":\"Pago puntual.\"}")"
api GET "/api/trabajos/$TRABAJO" "$TK_EMP" >/dev/null
ok "trabajo FINALIZADO tras ambas calificaciones" FINALIZADO "$(campo .estado)"
if [ "$SIN_PSQL" != 1 ]; then
  ok "promedio del trabajador" "5.00" "$(psql_ "SELECT calificacion_promedio FROM usuarios WHERE id='$ID_TRA'")"
  ok "promedio del empleador"  "4.00" "$(psql_ "SELECT calificacion_promedio FROM usuarios WHERE id='$ID_EMP'")"
  ok "trabajos_completados del trabajador" 1 "$(psql_ "SELECT trabajos_completados FROM usuarios WHERE id='$ID_TRA'")"
  ok "pagos_confirmados del empleador"     1 "$(psql_ "SELECT pagos_confirmados FROM usuarios WHERE id='$ID_EMP'")"
  # Reputacion separada por rol (tarea 019): la resena por HACER el trabajo no
  # puede mejorar la fama de buen pagador, ni al reves.
  ok "el trabajador tiene 5.00 COMO TRABAJADOR" "5.00" "$(psql_ "SELECT calificacion_como_trabajador FROM usuarios WHERE id='$ID_TRA'")"
  ok "  ...y 0 como contratista" "0.00" "$(psql_ "SELECT calificacion_como_empleador FROM usuarios WHERE id='$ID_TRA'")"
  ok "el empleador tiene 4.00 COMO CONTRATISTA" "4.00" "$(psql_ "SELECT calificacion_como_empleador FROM usuarios WHERE id='$ID_EMP'")"
  ok "  ...y 0 como trabajador" "0.00" "$(psql_ "SELECT calificacion_como_trabajador FROM usuarios WHERE id='$ID_EMP'")"
  ok "total por rol del trabajador" 1 "$(psql_ "SELECT total_calificaciones_como_trabajador FROM usuarios WHERE id='$ID_TRA'")"
  ok "total por rol del empleador" 1 "$(psql_ "SELECT total_calificaciones_como_empleador FROM usuarios WHERE id='$ID_EMP'")"
  ok "la resena al trabajador se guardo como TRABAJADOR" "TRABAJADOR" "$(psql_ "SELECT rol_calificado FROM calificaciones WHERE trabajo_id='$TRABAJO' AND receptor_id='$ID_TRA'")"
  ok "la resena al empleador se guardo como EMPLEADOR" "EMPLEADOR" "$(psql_ "SELECT rol_calificado FROM calificaciones WHERE trabajo_id='$TRABAJO' AND receptor_id='$ID_EMP'")"
fi

# --- CASOS BORDE: autorizacion --------------------------------------------
titulo "CASOS BORDE - autorizacion"
T2=$(crear_trabajo "$TK_EMP" "Pintar una pared")
P2=$(postular "$TK_TRA" "$T2")
ok "un tercero no ve los postulantes ajenos" 403 "$(api GET "/api/postulaciones?trabajoId=$T2" "$TK_TER")"
ok "un tercero no acepta postulaciones ajenas" 403 "$(api POST "/api/postulaciones/$P2/aceptar" "$TK_TER")"
api POST "/api/postulaciones/$P2/aceptar" "$TK_EMP" >/dev/null
ok "un tercero no reserva el pago de un trabajo ajeno" 403 "$(api POST "/api/trabajos/$T2/reservar-pago" "$TK_TER" '{"monto":10}')"
ok "el trabajador asignado tampoco reserva el pago" 403 "$(api POST "/api/trabajos/$T2/reservar-pago" "$TK_TRA" '{"monto":10}')"
ok "el empleador no puede iniciar el trabajo" 403 "$(api POST "/api/trabajos/$T2/iniciar" "$TK_EMP")"
ok "un tercero no puede liberar el pago" 403 "$(api POST "/api/trabajos/$T2/aceptar" "$TK_TER")"
ok "sin token no se puede recargar" 401 "$(api POST /api/cartera/recargar '' '{"monto":99999}')"
ok "token invalido -> 401" 401 "$(api GET /api/auth/yo 'no.es.un.token')"

# --- CASOS BORDE: maquina de estados --------------------------------------
titulo "CASOS BORDE - maquina de estados"
ok "postularse dos veces al mismo trabajo" 409 "$(api POST /api/postulaciones "$TK_TRA" "{\"trabajoId\":\"$T2\"}")"
ok "postularse a tu propio trabajo -> 409 (tarea 019; antes 400)" 409 "$(api POST /api/postulaciones "$TK_EMP" "{\"trabajoId\":\"$T2\"}")"
ok "aceptar dos veces la misma postulacion" 409 "$(api POST "/api/postulaciones/$P2/aceptar" "$TK_EMP")"
ok "liberar el pago antes de la entrega" 409 "$(api POST "/api/trabajos/$T2/aceptar" "$TK_EMP")"
ok "calificar un trabajo no completado" 409 "$(api POST /api/calificaciones "$TK_EMP" "{\"trabajoId\":\"$T2\",\"estrellas\":5}")"
ok "calificar dos veces el mismo trabajo" 409 "$(api POST /api/calificaciones "$TK_EMP" "{\"trabajoId\":\"$TRABAJO\",\"estrellas\":1}")"
ok "un ajeno califica un trabajo en el que no participo" 403 "$(api POST /api/calificaciones "$TK_TER" "{\"trabajoId\":\"$TRABAJO\",\"estrellas\":1}")"
ok "iniciar un trabajo sin escrow" 409 "$(api POST "/api/trabajos/$T2/iniciar" "$TK_TRA")"
ok "calificar un trabajo inexistente" 404 "$(api POST /api/calificaciones "$TK_EMP" '{"trabajoId":"00000000-0000-0000-0000-000000000000","estrellas":5}')"
ok "calificar con 0 estrellas" 400 "$(api POST /api/calificaciones "$TK_EMP" "{\"trabajoId\":\"$TRABAJO\",\"estrellas\":0}")"
ok "calificar con 9 estrellas" 400 "$(api POST /api/calificaciones "$TK_EMP" "{\"trabajoId\":\"$TRABAJO\",\"estrellas\":9}")"

# --- CASOS BORDE: dinero --------------------------------------------------
titulo "CASOS BORDE - dinero"
registrar "qa.pobre.$TS@trabajito.local" Pedro EMPLEADOR; TK_POB=$TOKEN; ID_POB=$ULTIMO_ID
T3=$(crear_trabajo "$TK_POB" "Trabajo sin fondos")
P3=$(postular "$TK_TRA" "$T3"); api POST "/api/postulaciones/$P3/aceptar" "$TK_POB" >/dev/null
ok "reservar pago con saldo insuficiente" 400 "$(api POST "/api/trabajos/$T3/reservar-pago" "$TK_POB" '{"monto":1500}')"
ok "  ...y el saldo sigue en 0" "0.00" "$(saldo_api "$TK_POB")"
api GET "/api/trabajos/$T3" "$TK_POB" >/dev/null
ok "  ...y el trabajo NO quedo ACORDADO" ASIGNADO "$(campo .estado)"
ok "recargar monto negativo" 400 "$(api POST /api/cartera/recargar "$TK_POB" '{"monto":-500}')"
ok "recargar monto cero" 400 "$(api POST /api/cartera/recargar "$TK_POB" '{"monto":0}')"
ok "recargar sin campo monto" 400 "$(api POST /api/cartera/recargar "$TK_POB" '{}')"
ok "recargar monto como texto" 400 "$(api POST /api/cartera/recargar "$TK_POB" '{"monto":"mil"}')"
ok "recargar monto desbordado" 400 "$(api POST /api/cartera/recargar "$TK_POB" '{"monto":99999999999999999999}')"
ok "  ...el saldo sigue intacto" "0.00" "$(saldo_api "$TK_POB")"
ok "reservar pago con monto negativo" 400 "$(api POST "/api/trabajos/$T3/reservar-pago" "$TK_POB" '{"monto":-100}')"
ok "cancelar un trabajo con el pago ya liberado" 409 "$(api POST "/api/trabajos/$TRABAJO/cancelar" "$TK_EMP" '{"reabrir":true}')"

echo "-- reembolso por cancelacion"
api POST /api/cartera/recargar "$TK_POB" '{"monto":200}' >/dev/null
api POST "/api/trabajos/$T3/reservar-pago" "$TK_POB" '{"monto":200}' >/dev/null
ok "saldo tras reservar los 200" "0.00" "$(saldo_api "$TK_POB")"
ok "el trabajador no puede rechazar con el escrow puesto" 409 "$(api POST "/api/trabajos/$T3/rechazar" "$TK_TRA")"
ok "cancelar sin decir si se reabre o se cierra -> 400" 400 "$(api POST "/api/trabajos/$T3/cancelar" "$TK_POB")"
ok "el empleador cancela y reabre" 200 "$(api POST "/api/trabajos/$T3/cancelar" "$TK_POB" '{"reabrir":true}')"
ok "DINERO: reembolso completo de los 200" "200.00" "$(saldo_api "$TK_POB")"
ok "el trabajo vuelve a ACTIVO" ACTIVO "$(campo .estado)"
[ "$SIN_PSQL" = 1 ] || ok "no queda ninguna postulacion ACEPTADA colgando" 0 \
   "$(psql_ "SELECT count(*) FROM postulaciones WHERE trabajo_id='$T3' AND estado='ACEPTADA'")"

echo "-- cancelacion eligiendo CERRAR el trabajo (tarea 010)"
T3B=$(crear_trabajo "$TK_POB" "Trabajo que se cierra")
P3B=$(postular "$TK_TRA" "$T3B"); api POST "/api/postulaciones/$P3B/aceptar" "$TK_POB" >/dev/null
ok "el empleador cancela y cierra" 200 "$(api POST "/api/trabajos/$T3B/cancelar" "$TK_POB" '{"reabrir":false}')"
ok "el trabajo queda CANCELADO" CANCELADO "$(campo .estado)"
[ "$SIN_PSQL" = 1 ] || ok "y sus postulaciones quedan RECHAZADA" 0 \
   "$(psql_ "SELECT count(*) FROM postulaciones WHERE trabajo_id='$T3B' AND estado IN ('ACEPTADA','PENDIENTE')")"

echo "-- redondeo sub-centavo (BUG-007)"
registrar "qa.red.$TS@trabajito.local" Rita EMPLEADOR; TK_RED=$TOKEN; ID_RED=$ULTIMO_ID
api POST /api/cartera/recargar "$TK_RED" '{"monto":100}' >/dev/null
T4=$(crear_trabajo "$TK_RED" "Redondeo de centavos")
P4=$(postular "$TK_TRA" "$T4"); api POST "/api/postulaciones/$P4/aceptar" "$TK_RED" >/dev/null
# Desde la tarea 007 un monto con mas de 2 decimales se RECHAZA con 400 en vez
# de redondearse en silencio (que era el bug: al empleador se le cobraba 0.00 y
# el trabajador cobraba 0.01). El check viejo miraba solo el saldo, y como una
# peticion rechazada tampoco mueve el saldo, seguia marcando BUG-007 para
# siempre. Ahora se comprueba lo que de verdad importa: que se rechace.
ok "reservar 0.005 se rechaza (mas de 2 decimales)" "400" \
   "$(api POST "/api/trabajos/$T4/reservar-pago" "$TK_RED" '{"monto":0.005}')"
ok "  ...y no le movio el saldo al empleador" "100.00" "$(saldo_api "$TK_RED")"
# El resto de esta seccion asumia que el escrow de 0.005 habia entrado; ahora no
# entra, asi que se reserva un monto valido para poder seguir el flujo.
api POST "/api/trabajos/$T4/reservar-pago" "$TK_RED" '{"monto":100}' >/dev/null
SALDO_TRA_ANTES=$(saldo_api "$TK_TRA")
api POST "/api/trabajos/$T4/iniciar"  "$TK_TRA" >/dev/null
evidencia "$TK_TRA" "$T4" >/dev/null
api POST "/api/trabajos/$T4/terminar" "$TK_TRA" >/dev/null
api POST "/api/trabajos/$T4/aceptar"  "$TK_RED" >/dev/null
# El trabajador cobra exactamente lo que el empleador puso en garantia (100.00),
# ni un centavo mas: eso era el defecto B de la tarea 007.
ok "el trabajador recibe exactamente lo que pago el empleador" \
   "$(awk -v a="$SALDO_TRA_ANTES" 'BEGIN{printf "%.2f", a+100}')" "$(saldo_api "$TK_TRA")"
ok "  ...y el empleador quedo en 0.00" "0.00" "$(saldo_api "$TK_RED")"

# --- CASOS BORDE: doble toque / concurrencia ------------------------------
titulo "CASOS BORDE - doble toque y concurrencia (BUG-007)"
registrar "qa.con.$TS@trabajito.local" Carla EMPLEADOR; TK_CON=$TOKEN; ID_CON=$ULTIMO_ID
api POST /api/cartera/recargar "$TK_CON" '{"monto":1000}' >/dev/null
TC1=$(crear_trabajo "$TK_CON" "Concurrencia A")
TC2=$(crear_trabajo "$TK_CON" "Concurrencia B")
PC1=$(postular "$TK_TRA" "$TC1"); PC2=$(postular "$TK_TER" "$TC2")
api POST "/api/postulaciones/$PC1/aceptar" "$TK_CON" >/dev/null
api POST "/api/postulaciones/$PC2/aceptar" "$TK_CON" >/dev/null

echo "-- doble gasto: 2 reservas simultaneas de 1000 con solo 1000 de saldo"
for t in "$TC1" "$TC2"; do
  curl -s -o /dev/null -X POST "$API/api/trabajos/$t/reservar-pago" \
    -H 'Content-Type: application/json' -H "Authorization: Bearer $TK_CON" \
    -d '{"monto":1000,"tiempo":"1 dia"}' &
done; wait
if [ "$SIN_PSQL" != 1 ]; then
  RETENIDO=$(psql_ "SELECT COALESCE(SUM(monto_acordado),0) FROM trabajos WHERE id IN ('$TC1','$TC2') AND pago_retenido")
  ok "no se puede retener mas de lo que hay en la cartera" "1000.00" "$RETENIDO" BUG-007
fi
ok "  ...saldo tras las dos reservas" "0.00" "$(saldo_api "$TK_CON")"

echo "-- doble toque en liberar el pago"
# OJO: de las dos reservas simultaneas de arriba solo UNA gana (eso es el
# arreglo de la tarea 007 haciendo su trabajo), y cual gana es no
# determinista. Antes se asumia que era TC1 y, cuando ganaba TC2, toda esta
# seccion fallaba en silencio y reportaba un BUG-007 falso. Hay que averiguar
# cual quedo con el escrow y seguir con ese.
if [ "$SIN_PSQL" != 1 ]; then
  TC_GANADOR=$(psql_ "SELECT id FROM trabajos WHERE id IN ('$TC1','$TC2') AND pago_retenido LIMIT 1")
  TK_GANADOR=$TK_TRA
  [ "$TC_GANADOR" = "$TC2" ] && TK_GANADOR=$TK_TER
else
  TC_GANADOR=$TC1; TK_GANADOR=$TK_TRA
fi
api POST "/api/trabajos/$TC_GANADOR/iniciar"  "$TK_GANADOR" >/dev/null
evidencia "$TK_GANADOR" "$TC_GANADOR" >/dev/null
# Precondicion explicita: si la entrega no llega a ESPERANDO_CONFIRMACION, la
# comprobacion de abajo no prueba nada. Mejor que se vea.
ok "  ...precondicion: el trabajo ganador queda entregado" "200" \
   "$(api POST "/api/trabajos/$TC_GANADOR/terminar" "$TK_GANADOR")"
for i in 1 2 3 4 5; do
  curl -s -o /dev/null -X POST "$API/api/trabajos/$TC_GANADOR/aceptar" -H "Authorization: Bearer $TK_CON" &
done; wait
if [ "$SIN_PSQL" != 1 ]; then
  ok "una sola LIBERACION registrada" 1 "$(psql_ "SELECT count(*) FROM movimientos_cartera WHERE trabajo_id='$TC_GANADOR' AND tipo='LIBERACION'")" BUG-007
fi

echo "-- doble toque al postularse"
TC3=$(crear_trabajo "$TK_CON" "Concurrencia C")
: > "$TMP/codes"
for i in 1 2 3 4 5; do
  curl -s -o /dev/null -w '%{http_code}\n' -X POST "$API/api/postulaciones" \
    -H 'Content-Type: application/json' -H "Authorization: Bearer $TK_TRA" \
    -d "{\"trabajoId\":\"$TC3\"}" >> "$TMP/codes" &
done; wait
ok "el doble toque no produce 500 (debe ser 200 + 409)" 0 "$(grep -c 500 "$TMP/codes")" BUG-007
[ "$SIN_PSQL" = 1 ] || ok "solo queda 1 postulacion en la BD" 1 "$(psql_ "SELECT count(*) FROM postulaciones WHERE trabajo_id='$TC3'")"

# --- CASOS BORDE: cancelacion abusiva y disputa (tarea 010 / ADR-0007) ----
titulo "CASOS BORDE - cancelacion tras la entrega (BUG-010, arreglado)"
registrar "qa.abus.$TS@trabajito.local" Abel EMPLEADOR; TK_AB=$TOKEN; ID_AB=$ULTIMO_ID
api POST /api/cartera/recargar "$TK_AB" '{"monto":400}' >/dev/null
T5=$(crear_trabajo "$TK_AB" "Cancelar tras entrega")
P5=$(postular "$TK_TER" "$T5"); api POST "/api/postulaciones/$P5/aceptar" "$TK_AB" >/dev/null
api POST "/api/trabajos/$T5/reservar-pago" "$TK_AB" '{"monto":400}' >/dev/null
ok "una vez iniciado, el empleador ya no puede cancelar" 409 \
   "$(api POST "/api/trabajos/$T5/iniciar" "$TK_TER" >/dev/null; \
      api POST "/api/trabajos/$T5/cancelar" "$TK_AB" '{"reabrir":true}')"
ok "y el trabajador tampoco puede rechazar" 409 "$(api POST "/api/trabajos/$T5/rechazar" "$TK_TER")"
ok "entregar sin evidencias -> 409" 409 "$(api POST "/api/trabajos/$T5/terminar" "$TK_TER")"
ok "sube evidencia y entrega" 200 \
   "$(evidencia "$TK_TER" "$T5" >/dev/null; api POST "/api/trabajos/$T5/terminar" "$TK_TER")"
ok "el empleador NO puede cancelar una entrega ya hecha" 409 \
   "$(api POST "/api/trabajos/$T5/cancelar" "$TK_AB" '{"reabrir":true}')"
ok "  ...ni cerrandola" 409 "$(api POST "/api/trabajos/$T5/cancelar" "$TK_AB" '{"reabrir":false}')"
ok "DINERO: el empleador no recupero nada" "0.00" "$(saldo_api "$TK_AB")"
api GET "/api/trabajos/$T5" "$TK_AB" >/dev/null
ok "el trabajo sigue ESPERANDO_CONFIRMACION" ESPERANDO_CONFIRMACION "$(campo .estado)"
ok "  ...con el escrow intacto" true "$(campo .pagoRetenido)"

echo "-- reclamo a soporte: el dinero se congela"
ok "reclamar sin motivo -> 400" 400 "$(api POST "/api/trabajos/$T5/reclamar" "$TK_AB" '{}')"
ok "un tercero no puede reclamar" 403 \
   "$(api POST "/api/trabajos/$T5/reclamar" "$TK_TRA" '{"motivo":"me aburro"}')"
ok "el empleador reclama un problema" 200 \
   "$(api POST "/api/trabajos/$T5/reclamar" "$TK_AB" '{"motivo":"Falta una lampara","descripcion":"Solo instalo dos de tres."}')"
ok "trabajo EN_DISPUTA" EN_DISPUTA "$(campo .estado)"
ok "  ...y el escrow sigue retenido" true "$(campo .pagoRetenido)"
ok "reclamar dos veces -> 409" 409 "$(api POST "/api/trabajos/$T5/reclamar" "$TK_AB" '{"motivo":"otra vez"}')"
ok "en disputa el empleador no puede liberar el pago" 409 "$(api POST "/api/trabajos/$T5/aceptar" "$TK_AB")"
ok "en disputa el empleador no puede cancelar" 409 "$(api POST "/api/trabajos/$T5/cancelar" "$TK_AB" '{"reabrir":true}')"
ok "DINERO: el empleador sigue sin recuperar nada" "0.00" "$(saldo_api "$TK_AB")"
SALDO_TER_ANTES=$(saldo_api "$TK_TER")
[ "$SIN_PSQL" = 1 ] || ok "queda un reporte ABIERTO para soporte" 1 \
   "$(psql_ "SELECT count(*) FROM reportes WHERE trabajo_id='$T5' AND estado='ABIERTO'")"
ok "un usuario normal no resuelve disputas" 403 \
   "$(api POST "/api/admin/trabajos/$T5/resolver-disputa" "$TK_AB" '{"aFavorDe":"EMPLEADOR"}')"

echo "-- solo un ADMIN descongela el dinero"
if [ "$SIN_PSQL" = 1 ]; then
  ama "  (saltado: hace falta psql para promover a un ADMIN de prueba)"
else
  registrar "qa.sop.$TS@trabajito.local" Sofia EMPLEADOR; TK_ADM=$TOKEN; ID_ADM=$ULTIMO_ID
  psql_ "UPDATE usuarios SET rol='ADMIN' WHERE id='$ID_ADM'" >/dev/null
  ok "el admin ve la cola de disputas" 200 "$(api GET /api/admin/trabajos/en-disputa "$TK_ADM")"
  ok "  ...y el trabajo esta en ella" 1 "$(campo "[.[]|select(.id==\"$T5\")]|length")"
  ok "resolver con un valor invalido -> 400" 400 \
     "$(api POST "/api/admin/trabajos/$T5/resolver-disputa" "$TK_ADM" '{"aFavorDe":"NADIE"}')"
  ok "el admin resuelve a favor del trabajador" 200 \
     "$(api POST "/api/admin/trabajos/$T5/resolver-disputa" "$TK_ADM" '{"aFavorDe":"TRABAJADOR","resolucion":"Las fotos muestran el trabajo hecho."}')"
  ok "trabajo COMPLETADO" COMPLETADO "$(campo .estado)"
  ok "DINERO: el trabajador cobro los 400" \
     "$(awk -v a="$SALDO_TER_ANTES" 'BEGIN{printf "%.2f", a+400}')" "$(saldo_api "$TK_TER")"
  ok "DINERO: el empleador sigue en 0" "0.00" "$(saldo_api "$TK_AB")"
  ok "una sola LIBERACION por esa disputa" 1 \
     "$(psql_ "SELECT count(*) FROM movimientos_cartera WHERE trabajo_id='$T5' AND tipo='LIBERACION'")"
  ok "ningun REEMBOLSO por esa disputa" 0 \
     "$(psql_ "SELECT count(*) FROM movimientos_cartera WHERE trabajo_id='$T5' AND tipo='REEMBOLSO'")"
  ok "el reporte quedo RESUELTO" 0 \
     "$(psql_ "SELECT count(*) FROM reportes WHERE trabajo_id='$T5' AND estado='ABIERTO'")"
  ok "resolver dos veces la misma disputa -> 409" 409 \
     "$(api POST "/api/admin/trabajos/$T5/resolver-disputa" "$TK_ADM" '{"aFavorDe":"EMPLEADOR"}')"
fi

# --- CASOS BORDE: seguridad -----------------------------------------------
titulo "CASOS BORDE - seguridad (BUG-008: escalada de privilegios)"
# Arreglado en la tarea 008 (ADR-0005): el registro publico solo puede crear
# TRABAJADOR o EMPLEADOR. Estas comprobaciones ya NO llevan marca de fallo
# conocido: si vuelven a fallar, es una regresion de verdad.
CORREO_ESC="qa.escalada.$TS@trabajito.local"
ok "el registro publico con rol ADMIN -> 400" 400 \
   "$(api POST /api/auth/registro '' "{\"correo\":\"$CORREO_ESC\",\"password\":\"Prueba1234\",\"nombres\":\"Eva\",\"apellidos\":\"QA\",\"rol\":\"ADMIN\"}")"
[ "$SIN_PSQL" = 1 ] || ok "y NO deja ninguna fila en la BD" 0 \
   "$(psql_ "SELECT count(*) FROM usuarios WHERE correo='$CORREO_ESC'")"
# Variantes del mismo ataque: no debe colarse por mayusculas/minusculas ni
# con el prefijo que usa Spring Security internamente.
ok "rol 'admin' en minusculas -> 400" 400 \
   "$(api POST /api/auth/registro '' "{\"correo\":\"qa.esc2.$TS@trabajito.local\",\"password\":\"Prueba1234\",\"nombres\":\"Eva\",\"apellidos\":\"QA\",\"rol\":\"admin\"}")"
ok "rol 'ROLE_ADMIN' -> 400" 400 \
   "$(api POST /api/auth/registro '' "{\"correo\":\"qa.esc3.$TS@trabajito.local\",\"password\":\"Prueba1234\",\"nombres\":\"Eva\",\"apellidos\":\"QA\",\"rol\":\"ROLE_ADMIN\"}")"
# El otro camino posible para auto-asignarse rol: editar el propio perfil.
api PUT /api/usuarios/me "$TK_TRA" '{"nombres":"Tomas","rol":"ADMIN"}' >/dev/null
ok "PUT /api/usuarios/me no puede cambiar el rol" TRABAJADOR "$(campo .rol)"
ok "un usuario normal no entra al panel admin" 403 "$(api GET /api/admin/estadisticas "$TK_TRA")"

# --- CASOS BORDE: mapeo de errores HTTP -----------------------------------
# Todo este bloque estaba marcado BUG-009 (devolvia 500). Desde la tarea 009
# (ADR-0008) ya no lleva marca: es test de regresion.
titulo "CASOS BORDE - mapeo de errores HTTP (era BUG-009)"
ok "ruta inexistente -> 404" 404 "$(api GET /api/no-existe "$TK_TRA")"
ok "metodo no permitido -> 405" 405 "$(api GET /api/cartera/recargar "$TK_TRA")"
ok "JSON malformado -> 400" 400 "$(api POST /api/cartera/recargar "$TK_TRA" 'no soy json')"
ok "UUID invalido en la ruta -> 400" 400 "$(api GET /api/trabajos/no-es-uuid "$TK_TRA")"
ok "enum invalido en el registro -> 400" 400 "$(api POST /api/auth/registro '' "{\"correo\":\"rolmalo.$TS@trabajito.local\",\"password\":\"Prueba1234\",\"nombres\":\"N\",\"apellidos\":\"A\",\"rol\":\"SUPERJEFE\"}")"  # ya no es BUG-009: lo arreglo la tarea 008 para ESTE endpoint
ok "postular con trabajoId nulo -> 400" 400 "$(api POST /api/postulaciones "$TK_TRA" '{"mensaje":"sin id"}')"
ok "calificar con trabajoId nulo -> 400" 400 "$(api POST /api/calificaciones "$TK_TRA" '{"estrellas":5}')"
ok "titulo vacio -> 400" 400 "$(api POST /api/trabajos "$TK_EMP" '{"titulo":"   ","descripcion":"x"}')"
ok "titulo de 80 caracteres -> 400" 400 "$(api POST /api/trabajos "$TK_EMP" "{\"titulo\":\"$(printf 'A%.0s' $(seq 80))\",\"descripcion\":\"x\"}")"
ok "correo duplicado -> 409" 409 "$(api POST /api/auth/registro '' "{\"correo\":\"qa.emp.$TS@trabajito.local\",\"password\":\"Prueba1234\",\"nombres\":\"N\",\"apellidos\":\"A\",\"rol\":\"EMPLEADOR\"}")"
ok "password corta -> 400" 400 "$(api POST /api/auth/registro '' "{\"correo\":\"corta.$TS@trabajito.local\",\"password\":\"123\",\"nombres\":\"N\",\"apellidos\":\"A\",\"rol\":\"EMPLEADOR\"}")"
ok "recargar sin cuerpo -> 400" 400 "$(curl -s -o "$TMP/body" -w '%{http_code}' -X POST "$API/api/cartera/recargar" -H "Authorization: Bearer $TK_TRA" -H 'Content-Type: application/json')"
ok "cuerpo XML en vez de JSON -> 415" 415 "$(curl -s -o "$TMP/body" -w '%{http_code}' -X POST "$API/api/cartera/recargar" -H "Authorization: Bearer $TK_TRA" -H 'Content-Type: application/xml' -d '<monto>1</monto>')"
ok "el 401 sin token trae cuerpo JSON, no vacio" "401" "$(api POST /api/cartera/recargar '' '{"monto":1}')"
ok "  ...y ese cuerpo trae message" "true" "$([ -n "$(campo .message)" ] && [ "$(campo .message)" != null ] && echo true)"

# --- CASOS BORDE: login de una cuenta suspendida --------------------------
# Un 500 aqui (comportamiento anterior) distinguia "cuenta suspendida" de
# "contraseña incorrecta" desde un endpoint publico: enumeracion de cuentas.
# Decision de security-agent (tarea 008/009): mismo 401 y mismo mensaje.
titulo "CASOS BORDE - login de una cuenta suspendida"
if [ "$SIN_PSQL" = 1 ]; then
  ama "  (saltado: necesita psql para suspender la cuenta)"
else
  CORREO_SUSP="qa.susp.$TS@trabajito.local"
  registrar "$CORREO_SUSP" Susana TRABAJADOR
  ok "cuenta de prueba creada" "true" "$([ -n "$ULTIMO_ID" ] && echo true)"
  ok "login normal antes de suspender" 200 \
     "$(api POST /api/auth/login '' "{\"correo\":\"$CORREO_SUSP\",\"password\":\"Prueba1234\"}")"
  cod_mal=$(api POST /api/auth/login '' "{\"correo\":\"$CORREO_SUSP\",\"password\":\"NoEsLaClave99\"}")
  MSG_MAL="$(campo .message)"
  psql_ "UPDATE usuarios SET activo=false WHERE correo='$CORREO_SUSP'" >/dev/null
  cod_susp=$(api POST /api/auth/login '' "{\"correo\":\"$CORREO_SUSP\",\"password\":\"Prueba1234\"}")
  MSG_SUSP="$(campo .message)"
  ok "password incorrecta -> 401" 401 "$cod_mal"
  ok "cuenta suspendida -> 401 (antes 500)" 401 "$cod_susp"
  ok "  ...y el mensaje es indistinguible" "$MSG_MAL" "$MSG_SUSP"
  ok "token de una cuenta suspendida deja de valer" 401 "$(api GET /api/auth/yo "$TOKEN")"
fi

# --- LOGIN EXIGENTE (tarea 015, ADR-0010) ---------------------------------
# Freno de fuerza bruta, refresh token y cierre de sesion real.
# OJO al orden: este bloque gasta intentos fallidos, y el limite POR IP (20 en
# 15 min) es compartido por todo el script, porque todas las peticiones salen
# de la misma IP. Va al final a proposito. El limite por IP NO se prueba aqui
# (agotaria el cupo del resto); lo cubre LoginExigenteHttpTest.
titulo "LOGIN EXIGENTE - fuerza bruta, refresh y logout (tarea 015)"
CORREO_BF="qa.bf.$TS@trabajito.local"
registrar "$CORREO_BF" Bruta TRABAJADOR
TK_BF="$TOKEN"
ok "cuenta para la prueba de fuerza bruta creada" "true" "$([ -n "$ULTIMO_ID" ] && echo true)"

# 5 fallos seguidos siguen respondiendo 401 (un usuario despistado no nota nada).
cod5=""
for i in 1 2 3 4 5; do
  cod5=$(api POST /api/auth/login '' "{\"correo\":\"$CORREO_BF\",\"password\":\"malaClave$i\"}")
done
ok "los primeros 5 fallos responden 401 normal" 401 "$cod5"

# El 6.o ya no responde "como si nada".
cod6=$(api POST /api/auth/login '' "{\"correo\":\"$CORREO_BF\",\"password\":\"malaClave6\"}")
ok "el 6.o intento fallido -> 429 (antes: 401 infinitos)" 429 "$cod6"
ok "  ...y el 429 explica la espera" "true" \
   "$([ -n "$(campo .message)" ] && [ "$(campo .message)" != null ] && echo true)"

# LA comprobacion que justifica el diseno: el dueno legitimo NO queda bloqueado.
cod_ok=$(api POST /api/auth/login '' "{\"correo\":\"$CORREO_BF\",\"password\":\"Prueba1234\"}")
ok "el dueno entra con su password aunque la cuenta este bajo ataque" 200 "$cod_ok"
REFRESH_BF="$(campo .refreshToken)"
TK_BF="$(campo .token)"
ok "  ...y el login correcto limpia el contador (vuelve a dar 401, no 429)" 401 \
   "$(api POST /api/auth/login '' "{\"correo\":\"$CORREO_BF\",\"password\":\"otraMala\"}")"

# --- Refresh token: rotacion y deteccion de reutilizacion -----------------
ok "el login devuelve refreshToken" "true" \
   "$([ -n "$REFRESH_BF" ] && [ "$REFRESH_BF" != null ] && echo true)"
ok "POST /api/auth/refresh -> 200" 200 \
   "$(api POST /api/auth/refresh '' "{\"refreshToken\":\"$REFRESH_BF\"}")"
REFRESH_2="$(campo .refreshToken)"
TK_2="$(campo .token)"
ok "  ...devuelve un refresh DISTINTO (rotacion)" "true" \
   "$([ "$REFRESH_2" != "$REFRESH_BF" ] && echo true)"
ok "  ...y el token de acceso nuevo sirve" 200 "$(api GET /api/auth/yo "$TK_2")"
ok "reutilizar el refresh viejo -> 401 (deteccion de robo)" 401 \
   "$(api POST /api/auth/refresh '' "{\"refreshToken\":\"$REFRESH_BF\"}")"
ok "  ...y tumba toda la familia: el nuevo tampoco vale" 401 \
   "$(api POST /api/auth/refresh '' "{\"refreshToken\":\"$REFRESH_2\"}")"
ok "un refresh inventado -> 401" 401 \
   "$(api POST /api/auth/refresh '' '{"refreshToken":"esto-no-existe"}')"

# --- Logout: cerrar sesion invalida de verdad -----------------------------
cod_login=$(api POST /api/auth/login '' "{\"correo\":\"$CORREO_BF\",\"password\":\"Prueba1234\"}")
REFRESH_3="$(campo .refreshToken)"
ok "login para probar el logout" 200 "$cod_login"
ok "POST /api/auth/logout -> 204" 204 \
   "$(api POST /api/auth/logout '' "{\"refreshToken\":\"$REFRESH_3\"}")"
ok "tras el logout, el refresh ya no renueva nada" 401 \
   "$(api POST /api/auth/refresh '' "{\"refreshToken\":\"$REFRESH_3\"}")"

# --- CERRAR SESION REVOCA LA FAMILIA (tarea 024, ADR-0012) ----------------
# Antes, el logout marcaba SOLO la fila del token presentado. Si habia una
# renovacion en vuelo, el par recien rotado sobrevivia al logout y el servidor
# lo seguia aceptando (lo reprodujo la QA de la tarea 022 en el emulador).
# Aqui se reproduce ese caso exacto contra la API real.
titulo "CIERRE DE SESION - familia y todos los dispositivos (tarea 024)"
CORREO_S1="qa.sesion.$TS@trabajito.local"
registrar "$CORREO_S1" Sesionera TRABAJADOR
# El usuario ajeno se registra con api() -y no con registrar()- porque hace
# falta su refreshToken, y registrar() no deja el cuerpo en $TMP/body.
CORREO_S2="qa.sesion.otro.$TS@trabajito.local"
ok "registro de un usuario ajeno (control)" 200 \
   "$(api POST /api/auth/registro '' "{\"correo\":\"$CORREO_S2\",\"password\":\"Prueba1234\",\"nombres\":\"Ajena\",\"apellidos\":\"QA\",\"rol\":\"TRABAJADOR\"}")"
REF_AJENO="$(campo .refreshToken)"

# Dispositivo 1 (movil): login y una renovacion "en vuelo".
ok "login del dispositivo 1" 200 \
   "$(api POST /api/auth/login '' "{\"correo\":\"$CORREO_S1\",\"password\":\"Prueba1234\"}")"
REF_MOVIL_1="$(campo .refreshToken)"
ok "  ...renovacion en vuelo -> 200" 200 \
   "$(api POST /api/auth/refresh '' "{\"refreshToken\":\"$REF_MOVIL_1\"}")"
REF_MOVIL_2="$(campo .refreshToken)"

# Dispositivo 2 (tablet): otra sesion, otra familia.
ok "login del dispositivo 2" 200 \
   "$(api POST /api/auth/login '' "{\"correo\":\"$CORREO_S1\",\"password\":\"Prueba1234\"}")"
REF_TABLET_1="$(campo .refreshToken)"
TK_TABLET="$(campo .token)"

# El logout sale con el token VIEJO, que es el que el cliente tenia guardado.
ok "logout del dispositivo 1 con el token ya rotado -> 204" 204 \
   "$(api POST /api/auth/logout '' "{\"refreshToken\":\"$REF_MOVIL_1\"}")"
ok "  ...el token viejo ya no renueva" 401 \
   "$(api POST /api/auth/refresh '' "{\"refreshToken\":\"$REF_MOVIL_1\"}")"
ok "  ...y el ROTADO durante el logout tampoco (era el fallo)" 401 \
   "$(api POST /api/auth/refresh '' "{\"refreshToken\":\"$REF_MOVIL_2\"}")"
ok "  ...pero el dispositivo 2 sigue con sesion" 200 \
   "$(api POST /api/auth/refresh '' "{\"refreshToken\":\"$REF_TABLET_1\"}")"
REF_TABLET_2="$(campo .refreshToken)"

# Cerrar sesion en todos los dispositivos.
ok "POST /api/auth/logout-todos sin token de acceso -> 401" 401 \
   "$(api POST /api/auth/logout-todos)"
ok "POST /api/auth/logout-todos con token de acceso -> 204" 204 \
   "$(api POST /api/auth/logout-todos "$TK_TABLET")"
ok "  ...tambien mata la sesion desde la que se pidio" 401 \
   "$(api POST /api/auth/refresh '' "{\"refreshToken\":\"$REF_TABLET_2\"}")"
ok "  ...y no toca la sesion de OTRO usuario" 200 \
   "$(api POST /api/auth/refresh '' "{\"refreshToken\":\"$REF_AJENO\"}")"

# --- Politica de contrasenas (ADR-0010) -----------------------------------
ok "password de 9 caracteres -> 400" 400 \
   "$(api POST /api/auth/registro '' "{\"correo\":\"pol1.$TS@trabajito.local\",\"password\":\"Abcdefgh1\",\"nombres\":\"N\",\"apellidos\":\"A\",\"rol\":\"EMPLEADOR\"}")"
ok "password solo de digitos -> 400" 400 \
   "$(api POST /api/auth/registro '' "{\"correo\":\"pol2.$TS@trabajito.local\",\"password\":\"9988776655\",\"nombres\":\"N\",\"apellidos\":\"A\",\"rol\":\"EMPLEADOR\"}")"
ok "password de lista comun -> 400" 400 \
   "$(api POST /api/auth/registro '' "{\"correo\":\"pol3.$TS@trabajito.local\",\"password\":\"contrasena\",\"nombres\":\"N\",\"apellidos\":\"A\",\"rol\":\"EMPLEADOR\"}")"
ok "password razonable -> 200" 200 \
   "$(api POST /api/auth/registro '' "{\"correo\":\"pol4.$TS@trabajito.local\",\"password\":\"MiClaveDeTrabajo7\",\"nombres\":\"N\",\"apellidos\":\"A\",\"rol\":\"EMPLEADOR\"}")"
# --- PERFIL COMPLETO DEL TRABAJADOR (tarea 019) ---------------------------
# El backend no guardaba el perfil que recoge el registro de 5 pasos de la app
# (habilidades, experiencia, estudios, telefono de emergencia, fecha de
# nacimiento...), asi que la fase 2 de la migracion habria perdido datos que el
# usuario VE. Aqui se guarda un perfil entero contra Postgres y se vuelve a leer.
titulo "PERFIL COMPLETO DEL TRABAJADOR (tarea 019)"
registrar "qa.perfil.$TS@trabajito.local" Petrona TRABAJADOR; TK_PER=$TOKEN; ID_PER=$ULTIMO_ID
ok "PUT /api/usuarios/me con el perfil entero" 200 \
   "$(api PUT /api/usuarios/me "$TK_PER" '{"telefono":"9988-7766","telefonoEmergencia":"3311-2233","fechaNacimiento":"15/03/1995","genero":"Femenino","presentacion":"Electricista con 8 anos de experiencia.","urlCV":"/uploads/cv-petrona.pdf","departamento":"Cortes","ciudad":"San Pedro Sula","codigoPostal":"21102","pais":"Honduras","viveEnHonduras":true,"registroCompleto":true,"habilidades":["Electricidad","Plomeria","electricidad"]}')"
ok "  ...la fecha de nacimiento vuelve en ISO" "1995-03-15" "$(campo .fechaNacimiento)"
ok "  ...la habilidad repetida no se duplica" 2 "$(campo '.habilidades|length')"
COD_EXP=$(api POST /api/usuarios/me/experiencia "$TK_PER" '{"empresa":"Constructora del Valle","puesto":"Electricista","habilidades":"Instalaciones residenciales","descripcion":"Cableado y tableros.","fechaInicio":"01/2018","trabajaActualmente":true}')
ID_EXP=$(campo .id)
ok "POST /api/usuarios/me/experiencia -> 201" 201 "$COD_EXP"
ok "POST /api/usuarios/me/estudios -> 201" 201 \
   "$(api POST /api/usuarios/me/estudios "$TK_PER" '{"nivel":"Universidad","centro":"UNAH-VS","fechaInicio":"01/2012","fechaFin":"11/2016","cursandoActualmente":false}')"
api GET /api/auth/yo "$TK_PER" >/dev/null
ok "GET /api/auth/yo devuelve la experiencia" "Constructora del Valle" "$(campo '.experiencia[0].empresa')"
ok "  ...y los estudios" "UNAH-VS" "$(campo '.estudios[0].centro')"
ok "  ...y el telefono de emergencia" "3311-2233" "$(campo .telefonoEmergencia)"
ok "  ...y registroCompleto" "true" "$(campo .registroCompleto)"
ok "  ...y el CV" "/uploads/cv-petrona.pdf" "$(campo .urlCV)"
ok "editar un puesto propio" 200 \
   "$(api PUT "/api/usuarios/me/experiencia/$ID_EXP" "$TK_PER" '{"empresa":"Constructora del Valle","puesto":"Jefe de cuadrilla","fechaInicio":"01/2018","fechaFin":"06/2024","trabajaActualmente":false}')"
ok "editar el puesto de otra persona -> 403" 403 \
   "$(api PUT "/api/usuarios/me/experiencia/$ID_EXP" "$TK_TER" '{"empresa":"X","puesto":"Y","trabajaActualmente":false}')"
ok "menor de 18 anos -> 400" 400 \
   "$(api PUT /api/usuarios/me "$TK_PER" "{\"fechaNacimiento\":\"$(date -d '-17 years' +%d/%m/%Y)\"}")"
ok "fecha imposible (31/02) -> 400, no 500" 400 \
   "$(api PUT /api/usuarios/me "$TK_PER" '{"fechaNacimiento":"31/02/1990"}')"
ok "presentacion mas larga que su columna -> 400" 400 \
   "$(api PUT /api/usuarios/me "$TK_PER" "{\"presentacion\":\"$(printf 'x%.0s' $(seq 300))\"}")"
# El perfil publico no puede convertirse en un buscador de datos personales.
api GET "/api/usuarios/$ID_PER" "$TK_TER" >/dev/null
ok "el perfil ajeno SI muestra el CV" "Constructora del Valle" "$(campo '.experiencia[0].empresa')"
ok "  ...pero no el correo" "null" "$(campo .correo)"
ok "  ...ni el DNI" "null" "$(campo .dni)"
ok "  ...ni el telefono de emergencia" "null" "$(campo .telefonoEmergencia)"
ok "  ...ni la fecha de nacimiento" "null" "$(campo .fechaNacimiento)"
ok "  ...ni el saldo de la cartera" "null" "$(campo .saldo)"
if [ "$SIN_PSQL" != 1 ]; then
  ok "la experiencia quedo en su tabla" 1 "$(psql_ "SELECT count(*) FROM experiencias WHERE usuario_id='$ID_PER'")"
  ok "los estudios tambien" 1 "$(psql_ "SELECT count(*) FROM estudios WHERE usuario_id='$ID_PER'")"
  ok "y las habilidades" 2 "$(psql_ "SELECT count(*) FROM habilidades WHERE usuario_id='$ID_PER'")"
fi

# --- CUADRE CONTABLE ------------------------------------------------------
titulo "CUADRE CONTABLE (saldo == suma de movimientos_cartera)"
if [ "$SIN_PSQL" = 1 ]; then
  ama "  (saltado: SIN_PSQL=1)"
else
  for par in "empleador:$ID_EMP" "trabajador:$ID_TRA" "tercero:$ID_TER" "pobre:$ID_POB" "redondeo:$ID_RED" "concurrente:$ID_CON" "abusivo:$ID_AB"; do
    n=${par%%:*}; u=${par##*:}
    s=$(psql_ "SELECT saldo FROM usuarios WHERE id='$u'")
    m=$(psql_ "SELECT COALESCE(SUM(monto),0.00) FROM movimientos_cartera WHERE usuario_id='$u'")
    bug=""
    case "$n" in redondeo|concurrente|trabajador) bug="BUG-007";; esac
    ok "cuadre de $n" "$s" "$m" "$bug"
  done
fi

# --- resumen --------------------------------------------------------------
titulo "RESUMEN"
echo "  OK:                  $PASS"
echo "  Fallos conocidos:    $KNOWN  (bugs diagnosticados, con tarea abierta)"
echo "  Fallos NO esperados: $FAIL"
if [ "$FAIL" -gt 0 ]; then rojo "RESULTADO: REGRESION - hay fallos nuevos"; exit 1; fi
if [ "$KNOWN" -gt 0 ]; then ama "RESULTADO: OK, con los fallos conocidos todavia presentes"; exit 0; fi
verde "RESULTADO: TODO VERDE"; exit 0
