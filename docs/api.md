# API del backend (Spring Boot)

El mapa completo y detallado de endpoints ya está documentado en
[`backend/README.md`](../backend/README.md) — no se duplica aquí para evitar
que dos documentos se desincronicen. Este archivo es un resumen de alto nivel
más las reglas que `backend-agent` debe seguir al tocar la API.

**Recuerda:** ningún endpoint de esta API es consumido por la app Flutter
todavía (ver `docs/architecture.md`). Cambiar un contrato aquí hoy no rompe
nada en producción — pero si tu tarea es justo la de empezar a conectar
Flutter a un endpoint, coordínate con `flutter-agent` y documenta el contrato
exacto (request/response) en el reporte de la tarea antes de que el otro lado
lo consuma.

## Grupos de recursos (ver detalle de rutas en `backend/README.md`)

| Base path | Módulo | Auth |
|---|---|---|
| `/api/auth` | registro, login, refresh, logout, logout-todos, `/yo` | público (excepto `/yo` y `logout-todos`) |
| `/api/usuarios` | perfil completo (con CV: habilidades, experiencia, estudios), ranking, baja de cuenta | JWT |
| `/api/trabajos` | ciclo de vida completo del trabajo (publicar → asignar → iniciar → entregar → aceptar / cancelar / rechazar / reclamar) | JWT |
| `/api/postulaciones` | postularse, aceptar, retirar | JWT |
| `/api/trabajos/{id}/evidencias` | evidencias de avance | JWT |
| `/api/chats` (+ WebSocket `/ws`) | mensajería y negociación de pago/tiempo | JWT |
| `/api/cartera` | saldo y movimientos (prototipo — sin pasarela real) | JWT |
| `/api/calificaciones` | calificar y ver reseñas | JWT |
| `/api/notificaciones` | notificaciones in-app | JWT |
| `/api/reportes` | denuncias | JWT |
| `/api/admin` | panel de administración **y resolución de disputas de dinero** | JWT + rol `ADMIN` |
| `/api/archivos` | subida de archivos (a disco local, no S3/object storage) | JWT |

Documentación interactiva (Swagger UI vía springdoc-openapi):
`http://localhost:8080/swagger-ui.html` cuando el backend corre localmente.

## Reglas de negocio que la API impone (ADR-0007, tarea 010)

El principio, en palabras del dueño del proyecto: *"nunca ninguna de las dos
partes debe tener la ventaja de irse ganando"*. Traducido a contratos de API:

- **Cancelar solo antes de iniciar.** `POST /api/trabajos/{id}/cancelar` se
  admite desde `ACTIVO`/`ASIGNADO`/`ACORDADO`; desde `EN_PROGRESO` responde
  `409` y no mueve el escrow. Lo mismo para el trabajador con
  `POST /api/trabajos/{id}/rechazar`: la regla es simétrica.
- **El empleador elige el destino al cancelar.** El body
  `{"reabrir": true|false}` es **obligatorio** (`true` → el trabajo vuelve al
  feed como `ACTIVO`; `false` → queda `CANCELADO`). Sin ese campo, `400`.
- **Entregar exige evidencias.** `POST /api/trabajos/{id}/terminar` responde
  `409` si el trabajador no subió ninguna evidencia
  (`POST /api/trabajos/{id}/evidencias`). Tras una petición de corrección hace
  falta una evidencia **posterior** a esa petición.
- **Reclamar a soporte congela el dinero.**
  `POST /api/trabajos/{id}/reclamar` (motivo obligatorio, lo pueden usar las
  **dos** partes) deja el trabajo `EN_DISPUTA` con el escrow retenido: ni
  `aceptar`, ni `cancelar`, ni `rechazar` lo mueven (`409`). Abre un `Reporte`
  `ABIERTO` para la bandeja de soporte.
- **Solo un `ADMIN` descongela.** `GET /api/admin/trabajos/en-disputa` lista la
  cola y `POST /api/admin/trabajos/{id}/resolver-disputa` con
  `{"aFavorDe":"TRABAJADOR"|"EMPLEADOR","resolucion":"..."}` libera o
  reembolsa. No hay repartos parciales todavía.

La tabla completa de transiciones (desde qué estado, quién puede, qué pasa con
el escrow) está en `docs/decisions.md` → ADR-0007. El mapa de rutas detallado
sigue en `backend/README.md`.

## Sesión y login (ADR-0010, tarea 015)

La autenticación tiene **dos piezas** desde la tarea 015. Es el contrato que
la app Flutter debe implementar en la fase 0/1 de la migración (tarea 014).

| Campo de la respuesta | Qué es |
|---|---|
| `token` | JWT de **acceso**. Va en `Authorization: Bearer`. Vida corta (**15 min** por defecto; antes 7 días). No se puede revocar: por eso dura poco. |
| `refreshToken` | Cadena **opaca** (no es un JWT), larga (30 días) y **revocable**. Solo sirve para pedir un `token` nuevo. |
| `tokenType` | Siempre `"Bearer"`. |
| `expiraEnSegundos` | Vida del `token` de acceso, para que el cliente sepa cuándo renovar sin decodificar el JWT. |
| `usuario` | El perfil, igual que antes. |

Lo devuelven `POST /api/auth/registro`, `POST /api/auth/login` y
`POST /api/auth/refresh`.

| Endpoint | Cuerpo | Respuesta |
|---|---|---|
| `POST /api/auth/refresh` | `{"refreshToken":"..."}` | `200` con un par **nuevo** (el refresh usado queda revocado: rota en cada uso). `401` si es inválido, caducado, ya usado o la cuenta está suspendida. |
| `POST /api/auth/logout` | `{"refreshToken":"..."}` | `204` siempre que el cuerpo sea válido (también si el token ya no existía: un logout no debe servir para averiguar qué tokens valen). Revoca la **familia entera** de esa sesión, no solo el token presentado (ADR-0012). |
| `POST /api/auth/logout-todos` | *(vacío)* — **exige `Authorization: Bearer`** | `204`: cierra la sesión en **todos los dispositivos** del usuario, incluido el que lo pide. `401` sin token de acceso válido. Es la única ruta de `/api/auth/**` que no es pública. |

Cuatro reglas del contrato que no son negociables:

- **Rotación con detección de robo.** Cada `refresh` invalida el token que se
  presentó. Si alguien vuelve a usar uno ya rotado, se interpreta como token
  robado y se revoca **toda la familia** de esa sesión: el ladrón y la víctima
  se quedan fuera, y la víctima lo nota y vuelve a entrar. El cliente **no**
  debe reintentar un refresh con un token que ya cambió.
- **Cerrar sesión invalida de verdad, y mata la sesión entera.** Tras `logout`
  dan `401` **todos** los refresh tokens de esa familia, no solo el presentado
  (tarea 024, ADR-0012). Importa porque el cliente puede estar cerrando sesión
  con un token que una renovación en vuelo ya rotó: antes, el par recién
  emitido sobrevivía al `logout` y la sesión seguía utilizable. El `logout`
  revoca la familia **aunque el token que se le presente ya esté revocado o
  caducado**; con un token desconocido no hace nada y responde `204` igual.
  El `token` de acceso ya emitido sigue siendo válido hasta que caduque
  (≤15 min): es la consecuencia asumida de que un JWT firmado no se puede
  retirar. Si algún día hace falta corte inmediato, es un ADR nuevo.
- **Un dispositivo no arrastra a los demás.** `logout` cierra solo la sesión
  desde la que se llama (una familia = un dispositivo). Para cerrarlas todas
  —lo que uno busca al sospechar que le robaron la cuenta— está
  `POST /api/auth/logout-todos`, que exige token de acceso válido. Tras
  llamarlo, el propio cliente debe borrar su sesión local: su refresh acaba de
  morir también.
- **En la base de datos solo se guarda el hash** (SHA-256) del refresh token,
  nunca su valor. Una fuga de la tabla no entrega sesiones utilizables.

### Freno de fuerza bruta en el login

`POST /api/auth/login` cuenta los intentos **fallidos** en una ventana de 15
minutos, por dos ejes:

| Eje | Tope | Qué pasa al superarlo |
|---|---|---|
| Por IP | 20 fallos | `429` **antes** de comprobar la contraseña (no gasta BCrypt). |
| Por cuenta | 5 fallos | Los intentos con contraseña **incorrecta** responden `429`. |

**La contraseña correcta nunca se rechaza por este mecanismo.** Es deliberado y
es la parte del diseño que no se puede tocar sin un ADR: si el freno por cuenta
bloqueara la cuenta, cualquiera que sepa tu correo podría dejarte fuera a
voluntad. Por eso el `429` por cuenta sustituye al `401` de un intento que ya
había fallado, nunca a un `200`. Un login correcto además limpia el contador.

El `429` trae la cabecera `Retry-After` (segundos). Un cliente honesto debe
respetarla y no reintentar en bucle.

### Política de contraseñas (registro)

Mínimo **10** caracteres y máximo **72** (BCrypt trunca ahí: aceptar más daría
una falsa sensación de fortaleza). No se exigen mayúsculas/dígitos/símbolos
—criterio NIST 800-63B, longitud sobre complejidad— pero se rechazan las de
lista común, las de solo dígitos y el mismo carácter repetido. El error es un
`400` normal con el motivo en `fields.password`, en español.

## Perfil completo y reputación por rol (ADR-0011, tarea 019)

Hasta la tarea 019 el backend guardaba 21 campos del usuario y la app manejaba
~40 más experiencia y estudios: migrar el perfil habría perdido datos visibles.
Ya no. **Ojo con las tres cosas que cambian de forma no obvia:**

**1. Hay dos vistas del usuario, y no devuelven lo mismo.**

| Endpoint | Vista | Incluye el CV |
|---|---|---|
| `GET /api/auth/yo` | dueño | sí |
| `GET /api/usuarios/me` | dueño | sí |
| `PUT /api/usuarios/me` | dueño | sí (ya guardado) |
| `GET /api/usuarios/{id}` | **pública** | sí |
| `GET /api/usuarios/ranking` | **pública** | no (es un listado) |
| `POST /api/auth/login` · `/registro` · `/refresh` | dueño | **no** |

La vista **pública** deja en `null` `correo`, `dni`, `telefono`,
`telefonoEmergencia`, `fechaNacimiento`, `genero`, `codigoPostal`, `rtn` y
`saldo`. Sí muestra nombre, foto, presentación, ubicación (departamento/ciudad/
país), CV y reputación: lo que un contratista necesita para decidir.

En las respuestas que no traen el CV, `habilidades`, `experiencia` y `estudios`
llegan como **`null`**, que significa "no viene en esta respuesta". Lista vacía
significa "no tiene". No los confundas al mapear.

**2. El CV del trabajador se edita por partes.**

| Método | Ruta | Qué hace |
|---|---|---|
| PUT | `/api/usuarios/me` | perfil escalar; si mandas `habilidades`, **reemplaza la lista entera** |
| PUT | `/api/usuarios/me/habilidades` | reemplaza solo las habilidades (máx. 30, 60 caracteres cada una) |
| POST | `/api/usuarios/me/experiencia` | añade un puesto → **201** (máx. 30) |
| PUT · DELETE | `/api/usuarios/me/experiencia/{id}` | edita / borra un puesto propio (ajeno → **403**) |
| POST | `/api/usuarios/me/estudios` | añade un estudio → **201** (máx. 30) |
| PUT · DELETE | `/api/usuarios/me/estudios/{id}` | edita / borra un estudio propio (ajeno → **403**) |

Las habilidades se normalizan al guardar: se recortan espacios, se descartan las
vacías y no se repiten sin distinguir mayúsculas.

**Fechas.** `fechaNacimiento` entra como `dd/MM/yyyy` (lo que manda el
formulario) **o** ISO `yyyy-MM-dd`, y **sale siempre en ISO**. El servidor exige
**18 años cumplidos** (antes solo lo comprobaba la pantalla de Flutter, que es
como no comprobarlo): menor de edad → `400`. Las fechas de experiencia y
estudios son **texto libre** (`MM/AAAA`): son fechas parciales y se guardan tal
cual llegan.

**Límites de longitud.** Los campos del perfil validan el ancho real de su
columna (255 en casi todos, 500 en `urlCV`, 1000 en `descripcionEmpresa`).
Pasarse devuelve `400` con el campo señalado en `fields`, no un `500` del
driver.

**3. La reputación son dos, una por rol.** Decisión del dueño: ser buen
trabajador y ser buen contratista se califican aparte.

| Campo | Qué mide |
|---|---|
| `calificacionComoTrabajador` · `totalCalificacionesComoTrabajador` | reseñas recibidas **por hacer** el trabajo |
| `calificacionComoEmpleador` · `totalCalificacionesComoEmpleador` | reseñas recibidas **por contratar y pagar** |
| `calificacionPromedio` · `totalCalificaciones` | media global (las dos juntas), se conserva |

Cada `Calificacion` guarda `rolCalificado` (`TRABAJADOR`|`EMPLEADOR`), que sale
del papel que tenía **el receptor en ese trabajo**, no de su rol de cuenta.
`GET /api/calificaciones/usuario/{id}?rol=TRABAJADOR` filtra las reseñas de un
solo papel. `POST /api/calificaciones` y ese `GET` devuelven ahora
`CalificacionResponse`, no la entidad.

**4. Nadie se postula a su propio trabajo.** `POST /api/postulaciones` con un
trabajo propio responde **409** (`"No puedes postularte a tu propio trabajo"`).
Antes respondía 400; el cambio es deliberado y el script de regresión lo exige.

## Errores: un solo formato y un código por tipo de fallo (ADR-0008, tarea 009)

Todas las respuestas de error —vengan del controller o de la cadena de filtros
de seguridad— usan el mismo cuerpo:

```json
{"timestamp":"2026-08-26T23:49:33.103Z","status":400,"error":"Bad Request",
 "message":"Datos inválidos","fields":{"trabajoId":"Indica el trabajo al que te postulas"}}
```

`fields` solo aparece cuando el fallo es por campo (validación del body).

| Situación | Código | Ejemplo |
|---|---|---|
| Validación del body / tipo imposible / cuerpo ausente | `400` | `{"monto":"mil"}`, `{}` en `/api/cartera/recargar` |
| JSON malformado | `400` | body `no soy json` |
| UUID inválido en la ruta o en un query param | `400` | `GET /api/trabajos/no-es-uuid` |
| Sin token, token inválido o caducado | `401` | cualquier ruta protegida |
| Credenciales incorrectas **o cuenta suspendida** | `401` | `POST /api/auth/login` |
| Refresh token inválido, caducado, ya usado o revocado | `401` | `POST /api/auth/refresh` |
| Autenticado pero sin permiso (dueño/participante/rol) | `403` | postulaciones ajenas, `/api/admin/**` |
| Ruta inexistente | `404` | `GET /api/no-existe` |
| Método no permitido (responde también `Allow`) | `405` | `GET /api/cartera/recargar` |
| `Content-Type` no soportado | `415` | body XML |
| Estado incompatible / choque con la BD | `409` | cancelar tras la entrega, correo duplicado |
| Demasiados intentos de login (por IP o por cuenta) | `429` | `POST /api/auth/login`; trae `Retry-After` (ADR-0010) |
| Fallo no previsto | `500` | mensaje genérico; el detalle solo va al log |

Dos reglas que no se negocian al añadir endpoints:

- **`401` y `403` no son intercambiables.** `401` = no sé quién eres (hay que
  reautenticar); `403` = sé quién eres y no puedes.
- **El login no revela por qué falla.** Contraseña incorrecta y cuenta
  suspendida devuelven el mismo `401` con el mismo `message`; el motivo real
  se escribe en el log del servidor, no en la respuesta.

Ningún error se responde en silencio: los `5xx` se loguean con stacktrace
(nivel `ERROR`), los `4xx` en una línea (`DEBUG`) y los fallos de
autenticación en `INFO`.

## Convenciones que ya sigue el código (no las inventes distinto)

- Auth por header `Authorization: Bearer <token>` (JWT, ver `docs/decisions.md`
  y `backend/src/main/java/com/trabajito/security/`).
- Autorización de "dueño/participante" se resuelve en el `Service`, nunca en
  el cliente ("el cliente nunca decide permisos" — cita textual de
  `backend/README.md`). Cualquier endpoint nuevo debe seguir el mismo patrón.
- Errores centralizados vía `GlobalExceptionHandler` /
  `ApiException` (`backend/src/main/java/com/trabajito/common/exception/`) —
  no lances excepciones genéricas sin mapear.
- DTOs de request/response separados de las entidades JPA (carpeta `dto/`
  dentro de cada módulo) — no expongas entidades directamente en el body.
- **Los campos que otorgan privilegios no se aceptan del cliente.** Concreto:
  `POST /api/auth/registro` (público) solo admite `rol` = `TRABAJADOR` o
  `EMPLEADOR`; su DTO usa el enum `RolPublico`, que no incluye `ADMIN`, y
  cualquier otro valor responde 400 sin crear usuario (ADR-0005, tarea 008).
  No existe endpoint para crear ni promover administradores: se aprovisionan
  con `ADMIN_INICIAL_CORREO`/`ADMIN_INICIAL_PASSWORD` o con SQL de operación
  (ver `backend/README.md` → "Cómo se crea un ADMIN"). Si añades un endpoint
  que escriba `rol`, `saldo`, `activo` o cualquier campo de reputación,
  coordina con `security-agent`: son datos que el dueño del registro **no**
  debe poder fijar por sí mismo.

## Pendientes conocidos (del propio `backend/README.md`, no inventados)

Validación de JWT en el handshake de WebSocket, pasarela de pago real, FCM
para push real, migraciones Flyway/Liquibase, almacenamiento de objetos
(S3/MinIO) en vez de disco local y auto-liberación de escrow por inactividad.

**No existe cambio ni recuperación de contraseña** (hallazgo de la tarea 015:
la única escritura de `passwordHash` es el registro). Hoy no se nota porque la
app usa Firebase Auth, que lo trae de fábrica; con ADR-0009 desaparece. Ver
`docs/agent-tasks/017-cambio-y-recuperacion-de-contrasena.md`.

El **flujo de disputa mínimo ya existe** desde la tarea 010 (ADR-0007:
`reclamar` + resolución por `ADMIN`); lo que no existe es un sistema completo
con plazos, apelaciones, chat de disputa ni repartos parciales, ni notificación
a las partes cuando se abre o se resuelve una. Cualquiera de estos es candidato
a tarea de `backend-agent` coordinada con `security-agent` (varios tocan dinero
o auth).
