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
#   BUG-008  cualquiera puede auto-registrarse con rol ADMIN
#            -> docs/agent-tasks/008-*.md
#   BUG-009  errores no mapeados devuelven HTTP 500
#            -> docs/agent-tasks/009-*.md
#   BUG-010  el empleador puede cancelar tras la entrega y recuperar el escrow
#            -> docs/agent-tasks/010-*.md
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

echo "-- 8. Terminar (trabajador)"
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
ok "sin token no se puede recargar" 401 "$(api POST /api/cartera/recargar '' '{"monto":99999}')" BUG-009
ok "token invalido -> 401" 401 "$(api GET /api/auth/yo 'no.es.un.token')"

# --- CASOS BORDE: maquina de estados --------------------------------------
titulo "CASOS BORDE - maquina de estados"
ok "postularse dos veces al mismo trabajo" 409 "$(api POST /api/postulaciones "$TK_TRA" "{\"trabajoId\":\"$T2\"}")"
ok "postularse a tu propio trabajo" 400 "$(api POST /api/postulaciones "$TK_EMP" "{\"trabajoId\":\"$T2\"}")"
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
ok "recargar sin campo monto" 400 "$(api POST /api/cartera/recargar "$TK_POB" '{}')" BUG-009
ok "recargar monto como texto" 400 "$(api POST /api/cartera/recargar "$TK_POB" '{"monto":"mil"}')" BUG-009
ok "recargar monto desbordado" 400 "$(api POST /api/cartera/recargar "$TK_POB" '{"monto":99999999999999999999}')" BUG-009
ok "  ...el saldo sigue intacto" "0.00" "$(saldo_api "$TK_POB")"
ok "reservar pago con monto negativo" 400 "$(api POST "/api/trabajos/$T3/reservar-pago" "$TK_POB" '{"monto":-100}')"
ok "cancelar un trabajo con el pago ya liberado" 409 "$(api POST "/api/trabajos/$TRABAJO/cancelar" "$TK_EMP")"

echo "-- reembolso por cancelacion"
api POST /api/cartera/recargar "$TK_POB" '{"monto":200}' >/dev/null
api POST "/api/trabajos/$T3/reservar-pago" "$TK_POB" '{"monto":200}' >/dev/null
ok "saldo tras reservar los 200" "0.00" "$(saldo_api "$TK_POB")"
ok "el trabajador no puede rechazar con el escrow puesto" 409 "$(api POST "/api/trabajos/$T3/rechazar" "$TK_TRA")"
ok "el empleador cancela" 200 "$(api POST "/api/trabajos/$T3/cancelar" "$TK_POB")"
ok "DINERO: reembolso completo de los 200" "200.00" "$(saldo_api "$TK_POB")"
ok "el trabajo vuelve a ACTIVO" ACTIVO "$(campo .estado)"

echo "-- redondeo sub-centavo (BUG-007)"
registrar "qa.red.$TS@trabajito.local" Rita EMPLEADOR; TK_RED=$TOKEN; ID_RED=$ULTIMO_ID
api POST /api/cartera/recargar "$TK_RED" '{"monto":100}' >/dev/null
T4=$(crear_trabajo "$TK_RED" "Redondeo de centavos")
P4=$(postular "$TK_TRA" "$T4"); api POST "/api/postulaciones/$P4/aceptar" "$TK_RED" >/dev/null
api POST "/api/trabajos/$T4/reservar-pago" "$TK_RED" '{"monto":0.005}' >/dev/null
ok "reservar 0.005 debe cobrarle algo al empleador (o rechazarse)" "no" \
   "$([ "$(saldo_api "$TK_RED")" = "100.00" ] && echo si || echo no)" BUG-007
SALDO_TRA_ANTES=$(saldo_api "$TK_TRA")
api POST "/api/trabajos/$T4/iniciar"  "$TK_TRA" >/dev/null
api POST "/api/trabajos/$T4/terminar" "$TK_TRA" >/dev/null
api POST "/api/trabajos/$T4/aceptar"  "$TK_RED" >/dev/null
ok "el trabajador no debe recibir mas de lo que pago el empleador" "$SALDO_TRA_ANTES" "$(saldo_api "$TK_TRA")" BUG-007

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
api POST "/api/trabajos/$TC1/iniciar"  "$TK_TRA" >/dev/null
api POST "/api/trabajos/$TC1/terminar" "$TK_TRA" >/dev/null
for i in 1 2 3 4 5; do
  curl -s -o /dev/null -X POST "$API/api/trabajos/$TC1/aceptar" -H "Authorization: Bearer $TK_CON" &
done; wait
if [ "$SIN_PSQL" != 1 ]; then
  ok "una sola LIBERACION registrada" 1 "$(psql_ "SELECT count(*) FROM movimientos_cartera WHERE trabajo_id='$TC1' AND tipo='LIBERACION'")" BUG-007
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

# --- CASOS BORDE: cancelacion abusiva -------------------------------------
titulo "CASOS BORDE - cancelacion tras la entrega (BUG-010)"
registrar "qa.abus.$TS@trabajito.local" Abel EMPLEADOR; TK_AB=$TOKEN; ID_AB=$ULTIMO_ID
api POST /api/cartera/recargar "$TK_AB" '{"monto":400}' >/dev/null
T5=$(crear_trabajo "$TK_AB" "Cancelar tras entrega")
P5=$(postular "$TK_TER" "$T5"); api POST "/api/postulaciones/$P5/aceptar" "$TK_AB" >/dev/null
api POST "/api/trabajos/$T5/reservar-pago" "$TK_AB" '{"monto":400}' >/dev/null
api POST "/api/trabajos/$T5/iniciar"  "$TK_TER" >/dev/null
api POST "/api/trabajos/$T5/terminar" "$TK_TER" >/dev/null
ok "el empleador NO deberia cancelar una entrega ya hecha" 409 \
   "$(api POST "/api/trabajos/$T5/cancelar" "$TK_AB")" BUG-010

# --- CASOS BORDE: seguridad -----------------------------------------------
titulo "CASOS BORDE - seguridad (BUG-008)"
registrar "qa.escalada.$TS@trabajito.local" Eva ADMIN; TK_ESC=$TOKEN; ID_ESC=$ULTIMO_ID
[ "$SIN_PSQL" = 1 ] || ok "el registro publico NO deberia crear un ADMIN" "" "$(psql_ "SELECT rol FROM usuarios WHERE id='$ID_ESC'")" BUG-008
ok "un ADMIN auto-registrado NO deberia entrar al panel" 403 "$(api GET /api/admin/estadisticas "$TK_ESC")" BUG-008
ok "un usuario normal no entra al panel admin" 403 "$(api GET /api/admin/estadisticas "$TK_TRA")"

# --- CASOS BORDE: mapeo de errores HTTP -----------------------------------
titulo "CASOS BORDE - mapeo de errores HTTP (BUG-009)"
ok "ruta inexistente -> 404" 404 "$(api GET /api/no-existe "$TK_TRA")" BUG-009
ok "metodo no permitido -> 405" 405 "$(api GET /api/cartera/recargar "$TK_TRA")" BUG-009
ok "JSON malformado -> 400" 400 "$(api POST /api/cartera/recargar "$TK_TRA" 'no soy json')" BUG-009
ok "UUID invalido en la ruta -> 400" 400 "$(api GET /api/trabajos/no-es-uuid "$TK_TRA")" BUG-009
ok "enum invalido en el registro -> 400" 400 "$(api POST /api/auth/registro '' "{\"correo\":\"rolmalo.$TS@trabajito.local\",\"password\":\"Prueba1234\",\"nombres\":\"N\",\"apellidos\":\"A\",\"rol\":\"SUPERJEFE\"}")" BUG-009
ok "postular con trabajoId nulo -> 400" 400 "$(api POST /api/postulaciones "$TK_TRA" '{"mensaje":"sin id"}')" BUG-009
ok "calificar con trabajoId nulo -> 400" 400 "$(api POST /api/calificaciones "$TK_TRA" '{"estrellas":5}')" BUG-009
ok "titulo vacio -> 400" 400 "$(api POST /api/trabajos "$TK_EMP" '{"titulo":"   ","descripcion":"x"}')"
ok "titulo de 80 caracteres -> 400" 400 "$(api POST /api/trabajos "$TK_EMP" "{\"titulo\":\"$(printf 'A%.0s' $(seq 80))\",\"descripcion\":\"x\"}")"
ok "correo duplicado -> 409" 409 "$(api POST /api/auth/registro '' "{\"correo\":\"qa.emp.$TS@trabajito.local\",\"password\":\"Prueba1234\",\"nombres\":\"N\",\"apellidos\":\"A\",\"rol\":\"EMPLEADOR\"}")"
ok "password corta -> 400" 400 "$(api POST /api/auth/registro '' "{\"correo\":\"corta.$TS@trabajito.local\",\"password\":\"123\",\"nombres\":\"N\",\"apellidos\":\"A\",\"rol\":\"EMPLEADOR\"}")"

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
