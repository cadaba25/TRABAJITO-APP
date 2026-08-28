#!/usr/bin/env bash
# Verificacion de punta a punta del contrato que consume la app tras la tarea
# 020 (fase 2a de ADR-0009). Se ejecuta CONTRA EL BACKEND EN MARCHA:
#
#   ssh -i "$HOME/.ssh/trabajito_vm" -p 2222 -o BatchMode=yes cadaba@127.0.0.1 \
#       "bash -s" < docs/agent-reports/scripts/020-verificar-auth-contra-el-backend.sh
#
# Recorre el mismo orden que la app: registro -> los 5 pasos del perfil ->
# cerrar sesion -> volver a entrar -> comprobar que el CV sigue ahi -> editar
# el perfil SIN mandar habilidades -> comprobar que el CV no se borro.
#
# Ojo: crea cuentas de prueba y gasta cupo del freno de fuerza bruta por IP
# (20 intentos fallidos en 15 min, compartido por todo lo que sale del host).
#
# NO se llego a ejecutar entero: el tunel SSH a la VM dejo de responder
# mientras se cerraba la tarea 020. Cada una de sus afirmaciones si esta
# verificada por separado; ver el reporte 020, seccion "Tests ejecutados".
set -u
API=http://localhost:8080
CORREO="f020e@trabajito.test"
PASS="Trabajito2026x"
ok=0; fallo=0
chk() { if [ "$2" = "$3" ]; then ok=$((ok+1)); echo "OK   $1"; else fallo=$((fallo+1)); echo "FALLO $1 -> esperado [$3] obtenido [$2]"; fi; }

echo "== PASO 1 del registro: POST /api/auth/registro =="
R=$(curl -s -X POST $API/api/auth/registro -H "Content-Type: application/json" \
  -d "{\"correo\":\"$CORREO\",\"password\":\"$PASS\",\"nombres\":\"Maria Jose\",\"apellidos\":\"Fuentes Cruz\",\"dni\":\"0801199712345\",\"telefono\":\"99112233\",\"rol\":\"TRABAJADOR\",\"departamento\":\"Cortes\",\"ciudad\":\"San Pedro Sula\"}")
T=$(echo "$R" | jq -r .token); REF=$(echo "$R" | jq -r .refreshToken)
chk "el registro devuelve token" "$([ ${#T} -gt 20 ] && echo si || echo no)" "si"
chk "el usuario del registro NO trae CV (null)" "$(echo "$R" | jq -r '.usuario.habilidades')" "null"

echo "== la app pide /api/auth/yo justo despues (por eso mismo) =="
Y=$(curl -s $API/api/auth/yo -H "Authorization: Bearer $T")
chk "/yo SI trae las listas (vacias, no null)" "$(echo "$Y" | jq -c '.habilidades')" "[]"
chk "registroCompleto arranca en false" "$(echo "$Y" | jq -r '.registroCompleto')" "false"

echo "== PASO 2: PUT /api/usuarios/me con fecha en dd/MM/aaaa =="
P2=$(curl -s -X PUT $API/api/usuarios/me -H "Authorization: Bearer $T" -H "Content-Type: application/json" \
  -d '{"fechaNacimiento":"15/03/1995","genero":"Femenino","telefono":"99112233","telefonoEmergencia":"33445566","viveEnHonduras":true,"departamento":"Cortes","ciudad":"San Pedro Sula","codigoPostal":"21101","pais":"Honduras"}')
chk "la fecha vuelve en ISO" "$(echo "$P2" | jq -r .fechaNacimiento)" "1995-03-15"

echo "== menor de 18: el servidor lo rechaza aunque la pantalla no mire =="
M=$(curl -s -X PUT $API/api/usuarios/me -H "Authorization: Bearer $T" -H "Content-Type: application/json" -d '{"fechaNacimiento":"01/01/2015"}')
chk "edad minima 400" "$(echo "$M" | jq -r .status)" "400"
chk "mensaje en espanol listo para el usuario" "$(echo "$M" | jq -r .message)" "Debes tener al menos 18 años para usar Trabajito"

echo "== PASO 4: POST experiencia =="
E=$(curl -s -X POST $API/api/usuarios/me/experiencia -H "Authorization: Bearer $T" -H "Content-Type: application/json" \
  -d '{"empresa":"Panaderia La Espiga","puesto":"Reposteria","habilidades":"pan, pasteles","descripcion":"turno de madrugada","fechaInicio":"03/2019","fechaFin":"","trabajaActualmente":true}')
chk "experiencia creada con id" "$([ "$(echo "$E" | jq -r .id)" != "null" ] && echo si || echo no)" "si"

echo "== PASO 5: estudio + habilidades + registroCompleto =="
ES=$(curl -s -X POST $API/api/usuarios/me/estudios -H "Authorization: Bearer $T" -H "Content-Type: application/json" \
  -d '{"nivel":"Tecnico","centro":"INFOP","fechaInicio":"2016","fechaFin":"2018","cursandoActualmente":false}')
chk "estudio creado con id" "$([ "$(echo "$ES" | jq -r .id)" != "null" ] && echo si || echo no)" "si"
H=$(curl -s -X PUT $API/api/usuarios/me/habilidades -H "Authorization: Bearer $T" -H "Content-Type: application/json" -d '{"habilidades":["Reposteria","Panaderia","Atencion al cliente"]}')
chk "habilidades reemplazadas" "$(echo "$H" | jq -c .)" '["Reposteria","Panaderia","Atencion al cliente"]'
curl -s -o /dev/null -X PUT $API/api/usuarios/me -H "Authorization: Bearer $T" -H "Content-Type: application/json" -d '{"registroCompleto":true}'

echo "== CERRAR SESION: debe revocar de verdad =="
chk "logout 204" "$(curl -s -o /dev/null -w '%{http_code}' -X POST $API/api/auth/logout -H "Content-Type: application/json" -d "{\"refreshToken\":\"$REF\"}")" "204"
chk "el refresh revocado ya no sirve" "$(curl -s -X POST $API/api/auth/refresh -H "Content-Type: application/json" -d "{\"refreshToken\":\"$REF\"}" | jq -r .status)" "401"

echo "== VOLVER A ENTRAR: se tiene que ver TODO =="
L=$(curl -s -X POST $API/api/auth/login -H "Content-Type: application/json" -d "{\"correo\":\"$CORREO\",\"password\":\"$PASS\"}")
T2=$(echo "$L" | jq -r .token)
chk "el login tampoco trae CV (null): por eso la app pide /yo" "$(echo "$L" | jq -r '.usuario.habilidades')" "null"
Y2=$(curl -s $API/api/auth/yo -H "Authorization: Bearer $T2")
chk "habilidades intactas" "$(echo "$Y2" | jq -c .habilidades)" '["Reposteria","Panaderia","Atencion al cliente"]'
chk "experiencia intacta" "$(echo "$Y2" | jq -r '.experiencia[0].empresa')" "Panaderia La Espiga"
chk "estudios intactos" "$(echo "$Y2" | jq -r '.estudios[0].centro')" "INFOP"
chk "fecha de nacimiento intacta" "$(echo "$Y2" | jq -r .fechaNacimiento)" "1995-03-15"
chk "telefono de emergencia intacto" "$(echo "$Y2" | jq -r .telefonoEmergencia)" "33445566"
chk "registroCompleto true" "$(echo "$Y2" | jq -r .registroCompleto)" "true"

echo "== EDITAR PERFIL como lo hace la app: PUT /me SIN habilidades =="
ED=$(curl -s -X PUT $API/api/usuarios/me -H "Authorization: Bearer $T2" -H "Content-Type: application/json" \
  -d '{"telefono":"99998888","presentacion":"Reposteria por encargo"}')
chk "el PUT devuelve el perfil completo con CV" "$(echo "$ED" | jq -c .habilidades)" '["Reposteria","Panaderia","Atencion al cliente"]'
chk "el telefono se guardo" "$(echo "$ED" | jq -r .telefono)" "99998888"
chk "EL CV NO SE BORRO al editar el perfil" "$(echo "$ED" | jq -r '.experiencia | length')" "1"

echo "== PERFIL AJENO: privacidad =="
ID=$(echo "$Y2" | jq -r .id)
AJ=$(curl -s $API/api/usuarios/$ID -H "Authorization: Bearer $T2")
chk "correo oculto" "$(echo "$AJ" | jq -r .correo)" "null"
chk "dni oculto" "$(echo "$AJ" | jq -r .dni)" "null"
chk "telefono oculto" "$(echo "$AJ" | jq -r .telefono)" "null"
chk "saldo oculto" "$(echo "$AJ" | jq -r .saldo)" "null"
chk "el CV SI se ve (es lo que hay que enseñar)" "$(echo "$AJ" | jq -r '.habilidades | length')" "3"

echo "== RANKING: lo que alimenta las pestanas de personas =="
RK=$(curl -s $API/api/usuarios/ranking -H "Authorization: Bearer $T2")
chk "el ranking es un array pelado, no una pagina de Spring" "$(echo "$RK" | jq -r 'type')" "array"
chk "los elementos del ranking NO traen CV" "$(echo "$RK" | jq -r '.[0].habilidades')" "null"

echo "== CONTRASENA: 10 a 72, no 6 =="
chk "9 caracteres -> 400" "$(curl -s -X POST $API/api/auth/registro -H "Content-Type: application/json" -d '{"correo":"f020f@trabajito.test","password":"Corta123x","nombres":"A","apellidos":"B","rol":"TRABAJADOR"}' | jq -r .status)" "400"

echo
echo "RESUMEN: $ok OK, $fallo fallos"
