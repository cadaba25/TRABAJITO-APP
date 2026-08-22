---
id: 008
tarea: docs/agent-tasks/008-registro-publico-permite-rol-admin.md
agente: "security-agent"
fecha: 2026-08-21
---

## Objetivo (copiado de la tarea)

`POST /api/auth/registro` es un endpoint **público** (`permitAll` en
`SecurityConfig`) y acepta el campo `rol` tal cual viene del cliente,
incluyendo `ADMIN`. Cualquiera con acceso a la API puede crear una cuenta de
administrador y usar todo `/api/admin/**`.

**Alcance:** esto es el backend Spring Boot + JWT propio (`backend/`). **No**
aplica a Firebase Authentication, que es el auth que la app usa hoy en
producción y que no maneja el concepto de `rol` que hay aquí. Los dos sistemas
conviven; ver `docs/architecture.md` y ADR-0002.

## Cambios realizados

1. **El rol deja de ser un campo de dominio en la entrada pública.** Nuevo
   enum `RolPublico { TRABAJADOR, EMPLEADOR }` en el DTO de registro;
   `RegistroRequest.rol` pasa de `Rol` (dominio, con `ADMIN`) a `RolPublico`, y
   `AuthService` traduce con `req.rol().aRol()`. `ADMIN` deja de ser
   *expresable* en la petición: no es un `if` que alguien pueda borrar en un
   refactor, es el tipo el que no lo admite.
2. **Valor no reconocido → 400 de validación, no 500 ni fallback silencioso.**
   `RolPublico` deserializa con un `@JsonCreator` que devuelve `null` para
   cualquier valor que no sea `TRABAJADOR`/`EMPLEADOR` (incluidos `"ADMIN"`,
   `"admin"`, `"ROLE_ADMIN"` y `"SUPERJEFE"`), y el `@NotNull` del DTO lo
   convierte en el 400 uniforme que ya emitía `GlobalExceptionHandler`.
3. **Aprovisionamiento de administradores fuera de la API.** `DataSeeder`
   (`@Profile("dev")`, con `admin@trabajito.local / Admin1234` **fijo en el
   código**) se sustituye por `AdminInicialSeeder`, gobernado por
   `ADMIN_INICIAL_CORREO` / `ADMIN_INICIAL_PASSWORD`: inerte sin ambas
   variables en cualquier perfil, exige contraseña de 12 caracteres o más, y
   **no promueve cuentas existentes** (promover en silencio a alguien que se
   registró solo sería la misma escalada por otra puerta).
4. **Tests.** Nuevo `RegistroRolTest` (11 tests) sobre deserialización JSON +
   Bean Validation, que es la capa donde ocurre el ataque real, más un test en
   `AuthServiceTest` que recorre todos los `RolPublico` y comprueba que
   ninguno persiste `ADMIN`. Los 22 tests previos siguen pasando.
5. **`prueba-flujo-negocio.sh`.** El bloque `BUG-008` pasa de "fallo conocido"
   a test de regresión, con variantes del ataque (`admin` en minúsculas,
   `ROLE_ADMIN`), la comprobación en BD de que no queda fila, y la vía de
   `PUT /api/usuarios/me`.
6. **Documentación.** ADR-0005 en `docs/decisions.md` (escrito **antes** de
   implementar, como pide la regla 9); `backend/README.md` documenta por
   primera vez cómo se crea un ADMIN legítimamente; `docs/api.md` añade la
   convención "los campos que otorgan privilegios no se aceptan del cliente".

## Archivos modificados

- `backend/src/main/java/com/trabajito/modules/auth/dto/RolPublico.java` (nuevo)
- `backend/src/main/java/com/trabajito/modules/auth/dto/RegistroRequest.java`
- `backend/src/main/java/com/trabajito/modules/auth/AuthService.java`
- `backend/src/main/java/com/trabajito/config/AdminInicialSeeder.java` (nuevo,
  sustituye a `config/DataSeeder.java`, borrado)
- `backend/src/main/resources/application.yml` (`trabajito.admin-inicial.*`)
- `backend/src/test/java/com/trabajito/modules/auth/dto/RegistroRolTest.java` (nuevo)
- `backend/src/test/java/com/trabajito/modules/auth/AuthServiceTest.java`
- `backend/src/test/java/com/trabajito/TrabajitoApplicationTests.java` (solo el
  javadoc, que citaba `DataSeeder`)
- `backend/scripts/prueba-flujo-negocio.sh`
- `backend/.env.example`, `backend/docker-compose.yml`, `backend/README.md`
- `docs/decisions.md` (ADR-0005), `docs/api.md`
- `docs/agent-tasks/009-errores-no-mapeados-devuelven-500.md` (nota de
  coordinación por el solape), `docs/agent-tasks/011-exposicion-del-servidor-de-pruebas.md`
  (nuevo, hallazgo lateral)

## Evidencia real: antes y después

Todo contra el servidor de pruebas (VM Ubuntu, `http://localhost:8080` desde la
propia VM), no en local.

### ANTES (imagen del commit `ce7fd14`, reproducido de nuevo en esta tarea)

```
POST /api/auth/registro {"correo":"antes.esc.<ts>@trabajito.local", ...,"rol":"ADMIN"}
-> HTTP 200
   usuario.rol = "ADMIN"
   JWT: {"sub":"07b8f6bd-...","correo":"antes.esc...","rol":"ADMIN","iat":...,"exp":...}

GET /api/admin/estadisticas   (con ese token)
-> HTTP 200  {"reportesAbiertos":0,"trabajos":19,"usuarios":31}

BD: SELECT correo, rol FROM usuarios WHERE id='07b8f6bd-...'
->  antes.esc.<ts>@trabajito.local | ADMIN     (1 row)

POST /api/auth/registro con "rol":"SUPERJEFE"
-> HTTP 500 {"error":"Internal Server Error","message":"Error interno del servidor"}
```

### DESPUÉS (commit `1256a9a`, con `docker compose build api` + `up -d api`)

```
"rol":"ADMIN"       -> HTTP 400 {"error":"Bad Request","message":"Datos inválidos",
                                 "fields":{"rol":"El rol debe ser TRABAJADOR o EMPLEADOR"}}
"rol":"admin"       -> HTTP 400
"rol":"ROLE_ADMIN"  -> HTTP 400
"rol":"SUPERJEFE"   -> HTTP 400   (antes 500)
sin campo "rol"     -> HTTP 400

BD: SELECT count(*) FROM usuarios WHERE correo LIKE 'desp.%'   -- tras los 5 intentos
->  0                                    <- no se creó NINGUNA fila

"rol":"TRABAJADOR"  -> HTTP 200 |  desp.tra.<ts>@trabajito.local | TRABAJADOR
"rol":"EMPLEADOR"   -> HTTP 200 |  desp.emp.<ts>@trabajito.local | EMPLEADOR
```

Arranque del contenedor, confirmando que el seeder es inerte sin las variables:

```
c.trabajito.config.AdminInicialSeeder : ADMIN_INICIAL_* no definido:
                                        no se aprovisiona ningún administrador
```

### Otras vías para auto-asignarse rol (lo que pedía la tarea)

Auditoría estática: `grep -rn "setRol|\.rol\(" backend/src/main` devuelve
exactamente **dos** escrituras de `rol` en todo el backend —
`AuthService.registrar()` y el seeder. `Usuario` nunca se enlaza desde un
`@RequestBody` (ningún controller recibe una entidad JPA), así que tampoco hay
*mass assignment* por esa vía.

`ActualizarPerfilRequest` **no tiene campo `rol`** y Spring Boot deja
`FAIL_ON_UNKNOWN_PROPERTIES=false`, o sea que los campos de más se ignoran en
silencio. Verificado contra el servidor, antes y después del cambio:

```
PUT /api/usuarios/me
{"nombres":"P2","rol":"ADMIN","saldo":99999,"activo":false,"trabajosCompletados":50}
-> {"rol":"TRABAJADOR","saldo":0.00,"trabajosCompletados":0}
   GET /api/admin/estadisticas con ese token -> 403
```

La ruta `PUT /api/usuarios/perfil` que citaba la tarea **no existe**; la real
es `PUT /api/usuarios/me` (la inexistente devuelve 403, otro caso de la 009).

Detalle que refuerza el arreglo: las autoridades de Spring Security se derivan
de la fila en BD (`JwtAuthFilter` → `usuarios.findById` → `UsuarioPrincipal` →
`new SimpleGrantedAuthority("ROLE_" + usuario.getRol())`), **no** del claim
`rol` del token. Por eso el único camino real a `/api/admin/**` era persistir
`rol='ADMIN'`, y por eso cerrarlo en el registro basta.

## Decisiones tomadas

Las de diseño están razonadas en **ADR-0005** (`docs/decisions.md`), incluidas
las alternativas descartadas. Resumen del porqué del enfoque elegido:

- **Por qué no un `if (req.rol() == Rol.ADMIN) throw` en `AuthService`:** es el
  cambio más pequeño, pero deja el campo peligroso en el contrato, depende de
  que nadie lo borre al refactorizar, y no arregla el 500 del rol desconocido.
  Misma cantidad de trabajo, defensa más débil.
- **Por qué el 400 sale de `@NotNull` y no de un handler nuevo:** el mapeo
  global de errores es alcance de la tarea 009. Haciéndolo así, el arreglo de
  seguridad no depende de que la 009 se haga primero y no pisa su trabajo.
- **Por qué se quitó la contraseña fija del seeder:** `admin@trabajito.local /
  Admin1234` está publicada en Git y quedaba a un `SPRING_PROFILES_ACTIVE=dev`
  de distancia de convertirse en una cuenta real. Es una credencial conocida,
  no un dato de prueba. La sustituye una vía que sirve en cualquier entorno y
  que por defecto no crea nada (arrancar **sin ningún ADMIN** es el estado
  seguro por defecto).
- **Por qué no hay endpoint para crear/promover admins:** añade superficie de
  ataque a un backend que todavía no tiene consumidor y no resuelve el arranque
  en frío. Queda como candidato para cuando ADR-0002 se decida.
- **Se aceptó `rol` en minúsculas/con espacios** (`" trabajador "` → válido).
  Cambio de comportamiento deliberado y hacia lo permisivo *solo* dentro de los
  valores ya permitidos; antes eso reventaba con 500.
- **Se tocó `backend/scripts/prueba-flujo-negocio.sh`, que es artefacto de la
  tarea 006 (`qa-agent`).** Era necesario: sus comprobaciones de BUG-008
  esperaban el comportamiento vulnerable (registraban un ADMIN y guardaban su
  token). Se reescribió ese bloque para afirmar el comportamiento correcto y se
  le quitó la marca de fallo conocido, para que una regresión futura salga como
  fallo real y no como "ya lo sabíamos". La tarea 006 está `hecho`, así que no
  hay conflicto con trabajo en curso.

## Problemas encontrados

- **La BD del servidor de pruebas tenía 5 cuentas `rol='ADMIN'`** creadas por
  las pruebas de las tareas 006 y 008 (una la creé yo al reproducir el "antes").
  El arreglo cierra la puerta pero **no revoca lo ya concedido**. Como todas
  comparten la contraseña conocida `Prueba1234` y el puerto 8080 de esa VM está
  abierto en `0.0.0.0`, se desactivaron sin borrarlas (para no destruir la
  evidencia que citan los reportes 006 y 008):

  ```sql
  UPDATE usuarios SET activo=false WHERE rol='ADMIN' AND activo=true;  -- UPDATE 5
  ```

  Reversible con `UPDATE usuarios SET activo=true WHERE correo='...'`. Las
  cinco: `escalada.1787356485116@`, `escalada2.1787356527011@`,
  `qa.escalada.1787356941077@`, `antes.esc.1787357901@` (todas `.local`) y
  `verif.admin.1787357486@trabajito.com`.
- Al desactivarlas se confirmó otra cosa: **el login de una cuenta suspendida
  devuelve 500**, no 401/403 (es una `DisabledException`/`LockedException` que
  `GlobalExceptionHandler` no contempla; `UsuarioPrincipal.isEnabled()` e
  `isAccountNonLocked()` devuelven `usuario.isActivo()`). Ya estaba listado en
  la tarea 009; se le añadió allí la recomendación concreta de seguridad:
  devolver **el mismo 401 y el mismo mensaje** que unas credenciales
  incorrectas, porque hoy la diferencia de códigos permite distinguir "cuenta
  suspendida" de "contraseña mala" desde un endpoint público.
- **Hallazgo lateral, fuera de alcance:** la VM de pruebas publica la API en
  `0.0.0.0:8080` con `CORS_ORIGINS=*` y decenas de cuentas con contraseña
  conocida. Abierto como
  `docs/agent-tasks/011-exposicion-del-servidor-de-pruebas.md` (`devops-agent`).

## Tests ejecutados

**Unitarios (máquina local, Maven + el JDK 21 del JBR de Android Studio):**

```
export JAVA_HOME="C:\Program Files\Android\Android Studio\jbr"
export PATH="$PATH:/c/Users/enigm/tools/apache-maven-3.9.16/bin"
cd backend && mvn -q -B test
```

BUILD SUCCESS. **34/34 tests pasan** (antes 22): `TrabajitoApplicationTests` 1,
`AuthServiceTest` 7 (6 + el nuevo), `RegistroRolTest` 11 (nuevo),
`TrabajoServiceTest` 15. Comprobado en `target/surefire-reports/*.xml`:
`failures="0" errors="0"` en los cuatro.

**Contra el servidor real** (VM Ubuntu; imagen reconstruida con
`docker compose build api && docker compose up -d api`): las pruebas manuales
de la sección "Evidencia real" más el script completo:

```
ssh ... "cd ~/trabajito && bash backend/scripts/prueba-flujo-negocio.sh"
```

```
  OK:                  86      (antes 80)
  Fallos conocidos:    19      (antes 22)
  Fallos NO esperados: 0
  EXIT=0
```

Los 3 que dejaron de fallar son exactamente los de BUG-008 más el
`"rol":"SUPERJEFE"` que estaba marcado como BUG-009. El bloque de seguridad
sale entero en verde:

```
CASOS BORDE - seguridad (BUG-008: escalada de privilegios)
  OK    el registro publico con rol ADMIN -> 400  (400)
  OK    y NO deja ninguna fila en la BD  (0)
  OK    rol 'admin' en minusculas -> 400  (400)
  OK    rol 'ROLE_ADMIN' -> 400  (400)
  OK    PUT /api/usuarios/me no puede cambiar el rol  (TRABAJADOR)
  OK    un usuario normal no entra al panel admin  (403)
```

**No probado (dicho explícitamente, no asumido):** el camino "feliz" de
`AdminInicialSeeder` (crear de verdad un ADMIN con `ADMIN_INICIAL_*`) **no** se
ejecutó en el servidor, a propósito, para no dejar allí una cuenta de
administrador con contraseña conocida. Se verificó el camino inerte (log del
arranque real) y el bean se instancia sin problemas en el test de contexto de
Spring; el resto de esa clase está verificado solo por lectura. Tampoco se
corrió `flutter analyze`/`flutter test`: esta tarea no toca `lib/**`.

## Pendientes

- **Limpiar / recrear la BD del servidor de pruebas** — las 5 cuentas ADMIN
  quedan desactivadas pero presentes, y siguen los saldos descuadrados de la
  tarea 006. Recogido en la tarea 011, junto con la exposición en `0.0.0.0`.
- **Tarea 009** (mapeo de errores) sigue abierta: 10 de los 11 casos siguen
  dando 500, incluido el login de cuenta suspendida. Se le dejaron dos notas.
- **Sin tests de la capa HTTP.** No existe ni un test con `MockMvc` en el
  backend, así que la comprobación de que `POST /api/auth/registro` con ADMIN
  responde 400 *a través de Spring Security + el handler de validación* solo
  existe contra el servidor real, no en `mvn test`. Un `@WebMvcTest` de
  `AuthController` cerraría ese hueco — candidato para `qa-agent`.
- **Decisión de producto pendiente (no la tomé, como pedía la tarea):** hoy no
  hay ninguna verificación de rol en los flujos de negocio; un `TRABAJADOR`
  puede publicar trabajos y un `EMPLEADOR` puede postularse (ambos 200,
  reconfirmado en esta ejecución del script). Lo que aporto desde seguridad:
  (a) permitirlo no es un agujero de seguridad — los servicios sí comprueban
  *dueño/participante*, que es la defensa que importa para el dinero y los
  datos; (b) si se decide restringirlo, hay que resolver antes el caso real de
  "una misma persona contrata y trabaja", porque `usuarios.rol` es un solo
  valor y forzaría a esa persona a tener dos cuentas; (c) modelarlo como
  conjunto de roles (`TRABAJADOR` + `EMPLEADOR` a la vez) sería un cambio de
  modelo de datos, no un `@PreAuthorize` suelto. Es del `tech-lead`.
- **Política del JWT:** el token dura 7 días y no hay refresh ni revocación.
  Suspender una cuenta o cambiarle el rol sí surte efecto inmediato (el filtro
  consulta la BD en cada request), que es lo que salva a este backend de que
  los tokens ADMIN ya emitidos sigan sirviendo. No se auditó la política de
  expiración/rotación como parte de esta tarea.
