# Decisiones de arquitectura (ADR)

Registro corto de decisiones importantes. Formato: contexto → decisión →
consecuencias. Un ADR nuevo por decisión, nunca se edita uno viejo salvo para
marcarlo `Reemplazado por ADR-000X`. Cualquier agente puede proponer un ADR;
`tech-lead` lo confirma antes de que se actúe sobre él.

---

## ADR-0001 — Adoptar la rama `claude/blissful-meitner-wt9tek` como base de `master`

**Fecha:** 2026-08-19
**Estado:** Aceptado

**Contexto:** `master` tenía un solo commit ("App base"). Existía una rama
remota, `claude/blissful-meitner-wt9tek`, generada por la GitHub Action
`@claude` (`.github/workflows/claude.yml`) entre el 18-jun-2026 y el
16-jul-2026 — 32 commits nunca fusionados, con casi todo el MVP de Flutter
(registro completo, feed de trabajos, postulaciones, chat, calificaciones,
cartera/escrow) y un esqueleto completo de backend Spring Boot +
PostgreSQL + JWT. El dueño del proyecto no tenía presente esta rama.

**Decisión:** Fast-forward de `master` a esa rama (sin reescribir historia,
sin conflictos posibles porque `master` era ancestro directo). Confirmado
explícitamente por el usuario antes de ejecutarlo.

**Consecuencias:**
- El punto de partida real del proyecto es mucho más avanzado de lo que
  parecía. Todos los documentos de este sistema (`docs/*.md`,
  `.claude/agents/*.md`) se escribieron sobre este estado, no sobre "App
  base".
- Ese mes de trabajo se generó de forma autónoma, respondiendo a comentarios
  `@claude` en issues/PRs, sin un proceso de revisión humana documentado.
  No se ha hecho una auditoría de calidad/seguridad de esos 32 commits como
  parte de esta tarea — es candidato a una tarea temprana de `qa-agent` +
  `security-agent` (ver `docs/agent-tasks/`).
- `test/widget_test.dart` quedó roto (referencia una clase `MyApp` que ya no
  existe) — ver `docs/development.md`.

---

## ADR-0002 — Firebase vs. backend propio: decisión de migración NO tomada

**Fecha:** 2026-08-19
**Estado:** ~~Abierto~~ → **CERRADO el 2026-08-26. Reemplazado por ADR-0009:
sí se migra.** Lo de abajo queda como registro de por qué estuvo abierto.

**Contexto:** El dueño del proyecto describió como stack objetivo Flutter +
Spring Boot + PostgreSQL + Redis + JWT + Docker. El repo real corre hoy
100% sobre Firebase (Auth + Firestore) desde el cliente Flutter, y por
separado tiene un esqueleto de backend Spring Boot completo pero
**desconectado** — ningún endpoint es consumido por la app.

**Decisión:** Ninguna todavía. Este documento existe para que ningún agente
asuma que la migración a Spring Boot está aprobada o en marcha. Migrar
significa, como mínimo: reescribir cada `*_service.dart` de Flutter para
hablar HTTP en vez del SDK de Firestore, decidir qué pasa con
`firestore.rules` y los datos ya existentes en Firestore, y resolver las
diferencias de modelado ya detectadas en `docs/database.md` (por ejemplo,
`saldo` embebido vs. ledger `MovimientoCartera`).

**Consecuencias mientras esté abierto:**
- `backend-agent` puede seguir completando el esqueleto (tests, pendientes
  listados en `backend/README.md`) porque no depende de esta decisión.
- Ningún agente debe empezar a cablear Flutter contra `/api/**` como tarea
  "de paso" dentro de otra tarea. Si se decide migrar, debe ser una tarea
  explícita planificada por `tech-lead` con el usuario, no una iniciativa
  espontánea de un agente.

---

## ADR-0003 — Sistema de agentes: 7 roles, no 10

**Fecha:** 2026-08-19
**Estado:** Aceptado

**Contexto:** La propuesta original consideraba hasta 10 agentes, incluyendo
Database, UI/UX y Code Review como roles independientes.

**Decisión:** Se combinan así (detalle y justificación completa en el
informe entregado al usuario, resumen aquí):
- **Database** se cubre desde `backend-agent` hasta que exista Flyway/Liquibase
  o el volumen de tablas lo justifique (condición explícita en
  `docs/architecture.md`, sección "Cuándo separar un Database Agent dedicado").
- **UI/UX** se cubre desde `flutter-agent` — es la única plataforma cliente
  que existe; un agente de UI/UX separado no tendría con quién coordinar
  consistencia "entre plataformas" porque solo hay una.
- **Code Review** no es un agente de Claude Code nuevo — se usa el skill ya
  instalado `code-review` (invocable como `/code-review`) más la revisión que
  ya hace `tech-lead` antes de aprobar un PR. Crear un agente aparte hubiera
  duplicado esa función.

**Consecuencias:** 7 agentes: `tech-lead`, `flutter-agent`, `backend-agent`,
`security-agent`, `qa-agent`, `devops-agent`, `docs-agent`. Si el proyecto
crece lo suficiente como para justificar separar alguno de los roles
combinados, debe documentarse como un nuevo ADR, no como un cambio silencioso.

---

## ADR-0004 — Riesgo de `soloMetricas()` en `firestore.rules`: mitigación parcial ahora, endurecimiento completo pendiente

**Fecha:** 2026-08-19
**Estado:** Aceptado (mitigación parcial implementada); endurecimiento
completo queda abierto como tarea nueva.

**Contexto:** `firestore.rules` define `soloMetricas()`, una función que
permite a CUALQUIER usuario autenticado escribir en el documento de OTRO
usuario los campos `calificacionPromedio`, `totalCalificaciones`,
`trabajosCompletados`, `trabajosPublicados`, `pagosConfirmados` y `saldo`,
sin verificar que exista una relación real (una publicación compartida)
entre quien escribe y el usuario objetivo, y sin restringir el valor ni la
dirección del cambio. El propio archivo ya admitía esto como "solo para el
prototipo de cartera".

Se auditó el código real que produce estos writes (`lib/services/
publicacion_service.dart`, `lib/services/calificacion_service.dart`,
`lib/services/cartera_service.dart`, `lib/screens/cartera_screen.dart`,
`lib/screens/detalle_trabajo_screen.dart`) para separar el riesgo teórico
del explotable:

1. **La regla de "dueño" (`request.auth.uid == uid`) ya es, por sí sola, un
   riesgo aparte y más amplio que `soloMetricas()`:** un usuario puede
   escribir CUALQUIER campo de su propio documento sin validación alguna
   (incluido `saldo`), porque `allow update` no restringe campos cuando
   `request.auth.uid == uid`. En la práctica esto **no agrega capacidad
   nueva** hoy: `CarteraService.recargarSaldo()` ya permite a cualquier
   usuario incrementar su propio `saldo` en cualquier monto sin pasarela de
   pago real (`lib/screens/cartera_screen.dart` lo etiqueta explícitamente
   como "Prototipo: los pagos son simulados"). Es decir, el dinero en `saldo`
   ya es de facto "moneda de prototipo, no dinero real" — el riesgo real de
   negocio aquí es de producto (no hay pasarela de pago), no principalmente
   de reglas de Firestore. Se deja anotado para cuando exista dinero real
   (ver Pendientes).

2. **El riesgo nuevo y explotable que sí introduce `soloMetricas()` es la
   escritura de terceros sin relación verificada**, concretamente:
   - Cualquier usuario autenticado puede, con una sola llamada directa al
     SDK/REST de Firestore (sin pasar por la app, usando su propio ID token
     — la config del proyecto Firebase es pública por diseño, la protección
     depende 100% de las reglas), poner el `saldo` de OTRO usuario cualquiera
     en `0` (o cualquier valor menor al actual): sabotaje/DoS directo contra
     la cartera de un tercero, sin relación de trabajo entre ambos.
   - El mismo mecanismo permite fijar `calificacionPromedio`,
     `totalCalificaciones`, `trabajosCompletados`, `trabajosPublicados` y
     `pagosConfirmados` de cualquier usuario a valores arbitrarios en una
     sola llamada (incluso los seis campos a la vez) — fraude de reputación
     (inflar la propia red de cómplices o difamar a un competidor a 0
     estrellas) sin que exista ninguna calificación o trabajo real de por
     medio. Esto es grave porque la reputación es la señal de confianza
     central del marketplace.
   - Se confirmó, leyendo todos los sitios donde el código real escribe
     `saldo` de un tercero (`aceptarTrabajo` → libera pago al trabajador,
     `reembolsar`/`cancelarContratacion` → reembolsa al empleador), que
     **ninguno de esos flujos legítimos reduce el saldo de otra persona** —
     todos son incrementos. `reembolsar()` no tiene ningún llamador desde
     `lib/screens/` (código muerto o pendiente de conectar a la UI;
     no se investigó más a fondo por estar fuera de alcance).

**Decisión:**
- **Mitigación parcial implementada ya, en esta misma tarea, en
  `firestore.rules`:** `soloMetricas()` ahora exige que, si `saldo` está
  entre los campos modificados, el nuevo valor sea `>=` al anterior — un
  tercero ya no puede reducir el saldo de otro usuario. Es un cambio
  aditivo y acotado: no cambia ningún campo que las reglas ya validaban
  distinto, y —verificado leyendo el código— ningún flujo legítimo hoy
  necesita que un tercero reduzca el saldo ajeno, así que no debería romper
  pago/reembolso. **No se pudo validar con el emulador de Firestore
  (`firebase` CLI no está instalado en este entorno y no hay `firebase.json`
  en el repo)** — es una verificación pendiente antes de desplegar a
  producción real.
- **No se endurecen en esta tarea** los campos de reputación
  (`calificacionPromedio`, `totalCalificaciones`, `trabajosCompletados`,
  `trabajosPublicados`, `pagosConfirmados`) ni se agrega verificación de
  relación real (misma publicación) entre quien escribe y el usuario
  objetivo, porque:
  - `calificacionPromedio` es un promedio que **legítimamente puede bajar**
    (una calificación de 1 estrella baja el promedio) — no se puede acotar
    a "solo incrementa" sin romper el flujo real de calificación.
    Validar que el nuevo promedio corresponde matemáticamente a la
    calificación real que se está creando en la misma transacción requeriría
    reglas más complejas (cruzar el `match` de `calificaciones` con el de
    `usuarios`) que no se pueden verificar sin tests de emulador, que no
    existen en este repo.
  - Acotar `totalCalificaciones`/`trabajosCompletados`/`pagosConfirmados` a
    incrementos de exactamente 1 por escritura reduce el radio de daño por
    llamada pero no lo elimina (un atacante puede llamar N veces), y sigue
    sin resolver la falta de verificación de relación real.
  - El propio archivo de tarea (`docs/agent-tasks/
    002-revisar-riesgo-saldo-firestore.md`) instruye explícitamente no
    implementar en solitario cambios que puedan romper el flujo de
    calificación/pago/asignación que depende de escrituras de terceros — y
    ese es exactamente el caso aquí.
- **Se compara contra "esperar a ADR-0002" (backend Spring Boot):** esperar
  eliminaría el problema de raíz (mover `saldo` a un ledger server-side,
  `MovimientoCartera`, ya diseñado en Postgres), pero ADR-0002 sigue "Abierto
  — no decidido" y no tiene fecha. La mitigación de `saldo` de esta tarea es
  de bajo costo y no bloquea esa migración futura; el endurecimiento de
  reputación se deja como tarea explícita en vez de esperar indefinidamente.
- Se crea `docs/agent-tasks/004-endurecer-metricas-terceros-firestore.md`
  para el trabajo pendiente: (a) instalar/configurar el emulador de
  Firestore + tests de reglas (`@firebase/rules-unit-testing`) — no existe
  hoy en el repo, es un prerrequisito real, no opcional, para tocar más esta
  función con confianza; (b) diseñar la validación de relación real
  (publicación compartida) y los límites de reputación con esos tests como
  red de seguridad; (c) evaluar si conviene mover `saldo` a una subcolección
  separada (`usuarios/{uid}/cartera/actual`) con reglas propias, más fácil
  de auditar que un campo suelto en el documento de usuario.

**Consecuencias:**
- El vector de sabotaje más grave y de menor esfuerzo (vaciar el saldo de un
  tercero con un solo write) queda cerrado hoy, sin depender de ADR-0002.
- El fraude de reputación vía terceros y la falta de verificación de
  relación real siguen abiertos — cualquier agente que toque `usuarios` o
  `firestore.rules` debe saberlo (ver tarea 004).
- El riesgo de "dueño puede escribir su propio `saldo` sin límite" también
  sigue abierto, pero se evaluó como equivalente en la práctica a la falta
  de pasarela de pago real (riesgo de producto, no de reglas) — pasa a ser
  relevante recién cuando `saldo` represente dinero real, momento en el que
  debe resolverse junto con ADR-0002, no antes.
- No hay tests automatizados de `firestore.rules` en este repo todavía; el
  cambio de esta tarea se verificó por lectura exhaustiva del código
  consumidor, no por ejecución — ver limitación explícita arriba.

---

## ADR-0005 — El rol nunca se acepta del cliente: el registro público solo crea `TRABAJADOR` o `EMPLEADOR`, y `ADMIN` se aprovisiona fuera de la API

**Fecha:** 2026-08-21
**Estado:** Aceptado (implementado en la tarea 008).
**Aplica a:** el backend Spring Boot (`backend/`) y su JWT propio. **No**
aplica a Firebase Authentication, que es el auth que la app usa hoy y que no
tiene el concepto de `rol` en el token (ver `docs/architecture.md`).

**Contexto:** `POST /api/auth/registro` es `permitAll` y `RegistroRequest`
declaraba `@NotNull Rol rol` con el enum de dominio completo, que incluye
`ADMIN`. `AuthService.registrar()` copiaba ese valor tal cual a la entidad.
Como las autoridades de Spring Security se derivan de la fila de BD
(`UsuarioPrincipal` → `usuario.getRol()`), persistir `rol='ADMIN'` es
autorización real, no solo un claim cosmético en el JWT. Verificado contra el
servidor de pruebas (tarea 006 y de nuevo en la 008): registro con
`"rol":"ADMIN"` → 200, JWT con `"rol":"ADMIN"`, `GET /api/admin/estadisticas`
→ 200 y `POST /api/admin/usuarios/{id}/suspender` sobre la cuenta de otro
usuario → 200. Hoy había 5 filas `rol='ADMIN'` en la BD de pruebas, todas
auto-registradas.

Además, el único mecanismo existente para crear un ADMIN legítimo era
`DataSeeder` (`@Profile("dev")`) con la contraseña **fija en el código**
`admin@trabajito.local / Admin1234`. No estaba activo en el servidor, pero es
una credencial conocida a un `SPRING_PROFILES_ACTIVE=dev` de distancia, y no
existía ninguna vía documentada para crear un ADMIN en un entorno que no
fuera `dev`.

**Decisión:**

1. **El rol deja de ser un campo de dominio en la entrada pública.** El
   registro público usa un enum propio del DTO, `RolPublico { TRABAJADOR,
   EMPLEADOR }` (`modules/auth/dto/RolPublico.java`), que se traduce al enum
   de dominio `Rol` en el servicio. `ADMIN` deja de ser *expresable* en la
   petición: no es una comprobación `if` que alguien pueda borrar sin querer,
   es el tipo el que no lo admite. Un test bloquea la regresión de añadir
   `ADMIN` a `RolPublico`.
2. **Valor no reconocido → 400, no 500 ni fallback silencioso.** `RolPublico`
   deserializa con un `@JsonCreator` tolerante que devuelve `null` para
   cualquier valor que no sea `TRABAJADOR`/`EMPLEADOR` (incluido `"ADMIN"` y
   `"SUPERJEFE"`), y el `@NotNull` del DTO lo convierte en un 400 de
   validación uniforme. Se eligió esto **en vez de** dejar que Jackson lance
   `HttpMessageNotReadableException`, porque hoy esa excepción cae en el
   handler genérico y produce un 500 (tarea 009). Así el arreglo de seguridad
   no depende de que la 009 se haga primero, y no toca el manejo global de
   errores, que es alcance de la 009.
3. **`ADMIN` se aprovisiona fuera de la API, nunca por auto-servicio.** No se
   añade ningún endpoint para crear ni promover administradores. El
   mecanismo soportado es un seeder de arranque explícito
   (`config/AdminInicialSeeder.java`, antes `DataSeeder`) gobernado por dos
   variables de entorno, `ADMIN_INICIAL_CORREO` y `ADMIN_INICIAL_PASSWORD`:
   sin ambas no hace nada, en ningún perfil. Se elimina la contraseña fija
   del código y la dependencia de `@Profile("dev")`. El seeder exige una
   contraseña de al menos 12 caracteres, no toca cuentas ya existentes (no
   promueve en silencio) y no vuelve a crear nada si el correo ya existe.
   Promover una cuenta existente o crear un segundo ADMIN es una operación
   manual y auditable (`UPDATE usuarios SET rol='ADMIN' ...`), documentada en
   `backend/README.md`.

**Alternativas consideradas:**

- *Un `if (req.rol() == Rol.ADMIN) throw ...` en `AuthService`.* Es el cambio
  más pequeño, pero deja el campo peligroso en el contrato y depende de que
  nadie lo borre al refactorizar; además no arregla el 500 del rol
  desconocido. Descartada por ser una defensa más débil al mismo coste.
- *Quitar `rol` del registro y que todos empiecen como `TRABAJADOR`.* Cambia
  el producto (hoy el cliente elige si se registra como trabajador o
  empleador). Fuera del alcance de una tarea de seguridad.
- *Un endpoint `POST /api/admin/usuarios/{id}/rol` para que un ADMIN promueva
  a otro.* Resuelve el "segundo admin" pero añade superficie de ataque nueva
  para un backend sin consumidor y no resuelve el arranque en frío (de dónde
  sale el primer ADMIN). Se deja como candidato para cuando ADR-0002 se
  decida a favor de migrar.
- *Mantener `DataSeeder` con `@Profile("dev")` y su contraseña fija.* Es una
  credencial conocida publicada en Git; el servidor de pruebas ya corre con
  perfil vacío justamente para esquivarla. Se prefiere una vía que sirva en
  cualquier entorno y que sea inerte por defecto.

**Consecuencias:**

- El contrato público de `POST /api/auth/registro` cambia: `rol` solo admite
  `TRABAJADOR` o `EMPLEADOR`; cualquier otro valor (incluido `ADMIN`)
  responde 400 y **no** crea usuario. Ningún cliente consume este endpoint
  hoy (la app usa Firebase), así que no rompe producción — pero cuando
  Flutter lo consuma, la pantalla de registro no debe ofrecer más que esos
  dos roles.
- Quien despliegue el backend y necesite un panel de administración debe
  definir `ADMIN_INICIAL_CORREO` y `ADMIN_INICIAL_PASSWORD` en su `.env`
  (ver `backend/.env.example`). Si no lo hace, el sistema arranca **sin
  ningún ADMIN**, que es el estado seguro por defecto.
- Las 5 cuentas `rol='ADMIN'` auto-registradas que quedaron en la BD del
  servidor de pruebas siguen siendo administradores: el arreglo cierra la
  puerta, no revoca lo ya concedido. Limpiarlas es trabajo de operación sobre
  esa BD (ver el reporte de la tarea 008); ninguna afecta a producción,
  porque ese backend no tiene consumidor.
- **Lo que este ADR NO decide:** si un `TRABAJADOR` debe poder publicar
  trabajos o un `EMPLEADOR` postularse. Hoy no hay ninguna verificación de
  rol en los flujos de negocio y ambas cosas responden 200; eso es una
  decisión de producto del `tech-lead`, no de seguridad (ver el reporte de la
  tarea 008).

---

## ADR-0006 — El dinero se protege con bloqueo pesimista y un orden global de bloqueo, no con `@Version`

**Fecha:** 2026-08-21
**Estado:** Aceptado (implementado en la tarea 007).
**Aplica a:** el backend Spring Boot (`backend/`) — `PagoService`,
`TrabajoService`, `CalificacionService` y la tabla `usuarios`. **No** aplica a
Firebase/Firestore, que es donde vive el dinero "de mentira" de la app hoy
(ver ADR-0002 y `docs/database.md`).

**Contexto:** verificado contra PostgreSQL real (tareas 006 y 007), el backend
**permitía crear dinero de la nada**: dos `POST /api/trabajos/{id}/reservar-pago`
simultáneos con saldo para uno solo devolvían ambos `200` (un empleador recargó
L. 1000 y pagó L. 2000), cinco `POST /api/trabajos/{id}/aceptar` simultáneos
escribían 3–4 filas `LIBERACION`, y `usuarios.saldo` dejaba de cuadrar con
`SUM(movimientos_cartera.monto)`. La causa es un `saldo = saldo ± monto` leído
y reescrito en Java (`read-modify-write`) sin ninguna protección, con el
aislamiento `READ COMMITTED` que trae PostgreSQL por defecto. Los guardias en
memoria (`pagoRetenido`, `pagoLiberado`) no protegen nada frente a dos
transacciones simultáneas.

Además, cualquier escritura sobre `usuarios` hecha por otro motivo
(`PUT /api/usuarios/me`, calificar, suspender una cuenta) generaba un `UPDATE`
de **todas** las columnas por dirty-checking de Hibernate, incluida `saldo`
con el valor leído al principio de esa transacción: una segunda vía para
perder una recarga sin que nadie tocara la cartera.

**Decisión:**

1. **Bloqueo pesimista (`SELECT ... FOR UPDATE`), no `@Version` optimista.**
   Toda transacción que mueva dinero o cambie el estado de un contrato bloquea
   primero las filas que va a tocar, con `@Lock(PESSIMISTIC_WRITE)` en los
   repositorios (`TrabajoRepository.findByIdParaActualizar`,
   `UsuarioRepository.findByIdParaActualizar`).
2. **Orden global de bloqueo, para que no haya deadlocks:**
   **primero `trabajos`, después `usuarios`; y varias filas de `usuarios`
   siempre en orden ascendente de UUID.** Ninguna transacción toma un bloqueo
   de `trabajos` después de uno de `usuarios`, y ninguna bloquea dos trabajos.
   Con esas dos reglas el grafo de espera no puede tener ciclos.
3. **`@DynamicUpdate` en `Usuario`:** Hibernate genera el `UPDATE` solo con las
   columnas que cambiaron, así que editar el perfil o la reputación ya no
   reescribe `saldo`.
4. **`CHECK (saldo >= 0)` en la base de datos** (`ck_usuarios_saldo_no_negativo`),
   como última línea de defensa independiente del código Java.
5. **Los montos se validan con escala exacta:** más de 2 decimales → `400`.
   No se redondea en silencio (ver "Alternativas descartadas").
6. **La concurrencia se prueba con una base de datos real** (Testcontainers +
   PostgreSQL 16), no con mocks. Es la excepción a la estrategia de testing de
   la tarea 003 ("mocks para servicios, H2 solo para el test de contexto"):
   un bug de transacciones es indetectable con Mockito.

**Alternativas descartadas:**

- *`@Version` en `BaseEntity` (bloqueo optimista) + reintentos.* Afecta a
  **todas** las entidades y añade una columna a las 11 tablas; obliga a
  escribir lógica de reintento en cada endpoint que mueva dinero, y bajo
  contención real (el caso que estamos arreglando) degrada a reintentar hasta
  agotarse. El bloqueo pesimista sobre una fila por PK, en transacciones de
  milisegundos y sin usuarios reales todavía, es más simple y más fácil de
  auditar.
- *`UPDATE usuarios SET saldo = saldo - :monto WHERE id = :id AND saldo >= :monto`
  atómico, sin bloquear.* Es correcto para el débito y era la opción más
  barata en aislamiento, pero deja el `saldo_resultante` de
  `movimientos_cartera` sin forma limpia de calcularse (habría que releerlo con
  una consulta nativa aparte para esquivar la caché de primer nivel de
  Hibernate), y **no** resuelve el otro lado del bug: la doble `LIBERACION`,
  que nace de un guardia sobre la fila de `trabajos`, no sobre el saldo. Haría
  falta bloquear `trabajos` igualmente, así que se prefiere un solo mecanismo
  coherente en vez de dos.
- *Normalizar el monto redondeando (`setScale(2, HALF_UP)`) en vez de
  rechazarlo con 400.* Redondear en silencio es justo lo que produjo el
  defecto B (el empleador pagaba `0.00` y el trabajador cobraba `0.01`).
  Rechazar es explícito, no tiene tope de abuso y el cliente se entera.
- *Subir el aislamiento a `SERIALIZABLE`.* Resuelve la corrección, pero
  convierte cualquier conflicto en un error `40001` que **igualmente** hay que
  reintentar en cada endpoint, y afecta a consultas que no tienen nada que ver
  con el dinero.
- *Introducir Flyway ya, para versionar el `CHECK`.* Es la solución correcta
  al problema de "cómo aplico un cambio de esquema de forma reproducible", y
  esta tarea lo empuja claramente — pero es una tarea aparte y con ADR propio
  (`backend/README.md` ya la lista como pendiente). Aquí el `CHECK` se declara
  con `@Check` en la entidad (BD nuevas) y se aplica a las BD ya existentes
  con un componente idempotente de arranque (`RestriccionSaldoNoNegativo`),
  explícitamente marcado como provisional.

**Consecuencias:**

- **Regla para cualquier agente que toque el backend:** si tu transacción
  escribe `usuarios.saldo`, `trabajos.pago_retenido`/`pago_liberado` o
  `monto_acordado`, tienes que bloquear la fila antes de leerla, y respetar el
  orden `trabajos` → `usuarios` (UUID ascendente). Bloquear *después* de haber
  leído la entidad sin bloqueo no sirve: Hibernate te devuelve la copia vieja
  de la caché de primer nivel.
- El contrato de la API cambia en dos puntos: un monto con más de 2 decimales
  ahora responde `400` (antes `200`), y un monto mayor que `9 999 999 999.99`
  responde `400` (antes `500`). Ningún cliente consume este backend hoy.
- Las peticiones que compiten por la misma fila se **serializan** (esperan) en
  vez de fallar. Las transacciones afectadas son cortas (una fila por PK), pero
  no hay `lock_timeout` configurado todavía: si alguna vez se añade una
  transacción larga, hay que ponerlo. Queda anotado como pendiente.
- `mvn test` gana una dependencia de test (`org.testcontainers:postgresql` +
  `spring-boot-testcontainers`) y un test que **necesita Docker**. Se salta
  solo (`@Testcontainers(disabledWithoutDocker = true)`) donde no hay Docker,
  para no romper `mvn test` a quien no lo tenga — con el coste consciente de
  que ahí la protección del dinero no se está verificando.
- El `CHECK` se aplica sobre bases de datos ya existentes como `NOT VALID` y
  después se intenta `VALIDATE`: si hay filas con `saldo < 0` heredadas, la
  validación falla, se registra un `ERROR` en el log con el número de filas
  afectadas y el arranque continúa (la restricción ya está protegiendo las
  escrituras nuevas). Bricar el arranque de la API por datos históricos sería
  peor.

---

## ADR-0007 — Cancelar solo antes de iniciar; entrega con evidencias; y el dinero atascado lo descongela un ADMIN, no una de las partes

**Fecha:** 2026-08-25
**Estado:** Aceptado (implementado en la tarea 010).
**Aplica a:** el backend Spring Boot (`backend/`) — `TrabajoService`,
`TrabajoController`, `AdminController`, `EstadoTrabajo` y la tabla `trabajos`.
**No** aplica a Firestore, que es donde vive el flujo real de la app hoy
(ADR-0002): esto cambia contratos de una API que todavía no consume nadie.

**Contexto:** verificado contra el servidor real (tarea 006, reproducido otra
vez el 2026-08-25 antes de tocar nada), `POST /api/trabajos/{id}/cancelar`
**no miraba el estado del trabajo**: solo comprobaba que el pago no estuviera
ya liberado. El empleador podía cancelar con la entrega ya hecha
(`ESPERANDO_CONFIRMACION`), recuperar el 100 % del escrow y quedarse con el
trabajo. Evidencia real, con el backend anterior:

```
POST /api/trabajos/{id}/cancelar   (empleador, tras la entrega)
-> HTTP 200 {"estado":"ACTIVO","montoAcordado":0,"pagoRetenido":false}
   saldo del empleador : 400.00   (reembolso íntegro)
   saldo del trabajador:   0.00
```

Además, `marcarTerminado()` no exigía nada: se podía "entregar" un trabajo sin
una sola evidencia, dejando al contratista sin material con el que decidir. Y
`reabrir()` devolvía el trabajo al feed dejando la postulación del trabajador
en `ACEPTADA`: un trabajo `ACTIVO`, sin asignado, con una postulación aceptada
colgando.

Las reglas las fijó el dueño del proyecto el 2026-08-25. Su principio rector,
textual: ***"nunca ninguna de las dos partes debe tener la ventaja de irse
ganando"***. Ese es el criterio que decide cualquier duda de diseño aquí.

**Decisión:**

1. **Cancelar solo antes de iniciar.** `cancelarContratacion()` se admite
   desde `ACTIVO`, `ASIGNADO` y `ACORDADO`. Desde `EN_PROGRESO` en adelante
   responde `409` y no toca el escrow — y la regla es **simétrica**:
   `rechazarAsignacion()` (el equivalente del trabajador) rechaza los mismos
   estados con el mismo `409`. Una vez iniciado, el dinero está comprometido
   para los dos.
2. **La cancelación legítima la decide el empleador, y hay que decirlo.** El
   body de `POST /api/trabajos/{id}/cancelar` pasa a llevar
   `{"reabrir": true|false}` **obligatorio**: `true` devuelve el trabajo al
   feed (`ACTIVO`), `false` lo cierra (`CANCELADO`, estado que el enum ya
   declaraba y nunca se usaba). Sin ese campo, `400`. No hay valor por
   defecto a propósito: un default silencioso decide por el usuario.
3. **Las postulaciones se resincronizan** en cada salida. Al reabrir: el
   trabajador que sale queda `RECHAZADA` (si canceló el empleador) o
   `RETIRADA` (si se salió él), y el resto de candidatos vuelven a
   `PENDIENTE` — estaban en `RECHAZADA` porque el sistema los descartó al
   aceptar a otro, no porque el empleador los rechazara. Al cerrar: todas las
   vivas pasan a `RECHAZADA`. Nunca queda una `ACEPTADA` sin asignado.
4. **Entregar exige evidencias.** `marcarTerminado()` requiere al menos una
   evidencia del trabajador asignado (`POST /api/trabajos/{id}/evidencias`,
   que ya existía); sin ella, `409`. Si el empleador pidió correcciones, hace
   falta una evidencia **posterior** a esa petición: se guarda el corte en la
   columna nueva `trabajos.fecha_solicitud_correccion`. Re-entregar lo mismo
   sin tocar nada sería la ventaja simétrica del trabajador.
5. **Reclamar a soporte (`EN_DISPUTA`), la única salida de un trabajo ya
   iniciado que no acaba en acuerdo.** `POST /api/trabajos/{id}/reclamar`
   (motivo obligatorio) deja el trabajo en el estado nuevo `EN_DISPUTA` con el
   escrow **congelado**: `pagoRetenido` sigue `true`, `montoAcordado` intacto,
   y ni `aceptar`, ni `cancelar`, ni `rechazar` pueden moverlo (`409`). Abre
   además un `Reporte` `ABIERTO` ligado al trabajo, que es lo que ve soporte.
   **Pueden reclamar las dos partes**: si solo pudiera el empleador, el
   trabajador quedaría atrapado en un trabajo que no puede cancelar y cuyo
   pago depende de que la otra parte quiera confirmarlo.
6. **Solo un `ADMIN` descongela el dinero.**
   `POST /api/admin/trabajos/{id}/resolver-disputa` con
   `{"aFavorDe":"TRABAJADOR"|"EMPLEADOR","resolucion":"..."}` libera el escrow
   al trabajador (`COMPLETADO`) o lo reembolsa al empleador (`CANCELADO`), y
   marca como `RESUELTO` los reportes abiertos del trabajo. `GET
   /api/admin/trabajos/en-disputa` es la cola de soporte. Todo `/api/admin/**`
   ya exigía rol `ADMIN` en `SecurityConfig`; no se tocó la configuración de
   seguridad.
7. **Sigue vigente ADR-0006 sin excepciones.** Las transiciones nuevas
   (`reclamar`, `resolver-disputa`) bloquean primero la fila del trabajo y
   después la del usuario que cobra, respetando el orden global
   `trabajos → usuarios` (y UUID ascendente cuando son varios).

**Máquina de estados resultante** (quién puede, desde dónde, y qué pasa con el
escrow):

| Desde | Acción | Quién | A | Escrow |
|---|---|---|---|---|
| `ACTIVO` | aceptar postulación | empleador | `ASIGNADO` | — |
| `ASIGNADO` | reservar pago | empleador | `ACORDADO` | se retiene |
| `ASIGNADO` | rechazar | trabajador | `ACTIVO` | — (no hay) |
| `ACTIVO`/`ASIGNADO`/`ACORDADO` | cancelar `reabrir:true` | empleador | `ACTIVO` | reembolso íntegro |
| `ACTIVO`/`ASIGNADO`/`ACORDADO` | cancelar `reabrir:false` | empleador | `CANCELADO` | reembolso íntegro |
| `ACORDADO` | iniciar | trabajador | `EN_PROGRESO` | retenido |
| `EN_PROGRESO` | terminar (**con evidencia**) | trabajador | `ESPERANDO_CONFIRMACION` | retenido |
| `EN_PROGRESO` / `ESPERANDO_CONFIRMACION` | **cancelar / rechazar** | cualquiera | **409, no cambia** | **no se mueve** |
| `ESPERANDO_CONFIRMACION` | solicitar corrección | empleador | `EN_PROGRESO` | retenido |
| `ESPERANDO_CONFIRMACION` | aceptar | empleador | `COMPLETADO` | se libera al trabajador |
| `EN_PROGRESO` / `ESPERANDO_CONFIRMACION` | reclamar | empleador **o** trabajador | `EN_DISPUTA` | **congelado** |
| `EN_DISPUTA` | resolver a favor del trabajador | **ADMIN** | `COMPLETADO` | se libera al trabajador |
| `EN_DISPUTA` | resolver a favor del empleador | **ADMIN** | `CANCELADO` | reembolso al empleador |
| `EN_DISPUTA` | aceptar / cancelar / rechazar | partes | **409** | **no se mueve** |
| `COMPLETADO` | calificar (ambas partes) | ambos | `FINALIZADO` | ya liberado |

**Alternativas descartadas:**

- *Dejar cancelar tras la entrega pagando una penalización parcial al
  trabajador.* Repartir el escrow requiere decidir el porcentaje, y cualquier
  porcentaje que fije el sistema le da ventaja a alguien. El dueño fue
  explícito: tras la entrega el empleador **solo** confirma o reclama.
- *Que solo el empleador pueda reclamar a soporte.* Es lo que dice la regla 3
  de la tarea al pie de la letra, pero deja al trabajador sin salida en un
  trabajo que tampoco puede cancelar: la ventaja se movería al otro lado, que
  es exactamente lo que el principio rector prohíbe. Se permite a ambos.
- *Sistema de disputas completo (plazos, apelaciones, chat de disputa,
  repartos parciales).* Fuera de alcance por decisión de la tarea. Aquí solo
  se garantiza el mínimo: que nadie se lleve el dinero solo.
- *Auto-liberar el escrow si el empleador no responde en X días.* Resuelve el
  caso "el empleador desaparece" sin soporte humano, pero necesita un job
  programado y una política de plazos que nadie ha decidido. Queda como
  pendiente (`backend/README.md` ya lo listaba).
- *Exigir la evidencia dentro del propio `POST /{id}/terminar`.* Duplicaría la
  creación de evidencias, que ya tiene su endpoint y sus reglas. Se prefiere
  que `terminar` solo valide.
- *Un `EstadoTrabajo.CANCELADO` que borre el vínculo con el trabajador, como
  hace reabrir.* Un trabajo cerrado es historial: conserva
  `trabajador_asignado_id` y las marcas de entrega, y solo apaga las banderas
  de escrow (el dinero ya volvió).

**Consecuencias:**

- **Cambia el contrato de la API en tres puntos** (ningún cliente lo consume
  hoy, ver ADR-0002): `POST /api/trabajos/{id}/cancelar` exige body con
  `reabrir` (antes no llevaba body y siempre reabría); `POST
  /api/trabajos/{id}/terminar` responde `409` si no hay evidencias (antes
  siempre `200`); y cancelar/rechazar responden `409` desde `EN_PROGRESO`
  (antes `200` con reembolso). Documentado en `docs/api.md` y
  `backend/README.md`.
- **Endpoints nuevos:** `POST /api/trabajos/{id}/reclamar`,
  `GET /api/admin/trabajos/en-disputa`,
  `POST /api/admin/trabajos/{id}/resolver-disputa`.
- **Esquema:** `EstadoTrabajo` gana `EN_DISPUTA` y `trabajos` gana cuatro
  columnas (`fecha_solicitud_correccion`, `disputa_abierta_por_id`,
  `motivo_disputa`, `resolucion_disputa`). Con `ddl-auto=update` se añaden
  solas y son nullable, así que no rompen filas existentes — pero es un
  recordatorio más de que faltan migraciones versionadas (Flyway/Liquibase,
  pendiente conocido).
- **`TrabajoService` gana tres dependencias** (`EvidenciaRepository`,
  `PostulacionRepository`, `ReporteRepository`). Son repositorios, no
  servicios: no se crea ningún ciclo de beans con `PostulacionService` →
  `TrabajoService`, que sigue siendo la única dirección entre servicios.
- **Aparece un caso de negocio que necesita un `ADMIN` de verdad.** Hasta
  ahora el panel era opcional; ahora hay dinero que solo un `ADMIN` puede
  desbloquear. Si un despliegue arranca sin ningún ADMIN (que es el valor por
  defecto desde ADR-0005), un trabajo en disputa se queda congelado
  indefinidamente. Hay que aprovisionar el ADMIN antes de abrir esto a
  usuarios reales.
- **Queda pendiente** (no es alcance de esta tarea): plazos y auto-resolución,
  notificar a las partes cuando se abre/resuelve una disputa, y que el ADMIN
  que resuelve quede registrado (hoy se guarda la resolución en el trabajo y
  en el reporte, pero no el id del administrador).

---

## ADR-0008 — Un único formato de error y un código HTTP correcto por cada tipo de fallo, con el 500 siempre logueado

**Fecha:** 2026-08-26
**Estado:** Aceptado (implementado en la tarea 009).
**Aplica a:** el backend Spring Boot (`backend/`) —
`common/exception/GlobalExceptionHandler`, `common/exception/RespuestaError`,
`common/exception/ManejadoresSeguridadHttp`, `config/SecurityConfig` y los
`@RequestBody` de todos los controllers. **No** aplica a Firestore, que es
donde vive el flujo real de la app hoy (ADR-0002).

**Contexto:** `GlobalExceptionHandler` solo declaraba cuatro handlers
(`ApiException`, `BadCredentialsException`, `AccessDeniedException`,
`MethodArgumentNotValidException`). Todo lo demás caía en
`@ExceptionHandler(Exception.class)` → **500 "Error interno del servidor"**,
incluidas las excepciones que Spring MVC lanza precisamente para distinguir
los errores de cliente: `NoResourceFoundException` (ruta inexistente),
`HttpRequestMethodNotSupportedException` (método no permitido),
`HttpMessageNotReadableException` (JSON malformado) y
`MethodArgumentTypeMismatchException` (UUID inválido en la ruta). Verificado
contra el servidor real en la tarea 006: 8 comprobaciones del script de
regresión devolvían el código equivocado. Dos agravantes:

1. **Ese handler no logueaba nada.** Tras provocar varios 500,
   `docker compose logs api --since 5m` devolvía 0 líneas. Un 500 en
   producción era invisible: ni stacktrace, ni ruta, ni hora.
2. **11 de los 15 `@RequestBody` no llevaban `@Valid`**, así que los
   `@NotNull`/`@Positive`/`@Min` declarados en los records de request eran
   código muerto y un campo obligatorio ausente llegaba como `null` hasta el
   servicio o hasta el `INSERT`.

Aparte, sin `AuthenticationEntryPoint` propio, una petición **sin token** a un
endpoint protegido salía por el `Http403ForbiddenEntryPoint` por defecto:
**403 con el cuerpo vacío**. El cliente no podía distinguir "no has iniciado
sesión" (reautenticar) de "esto no es tuyo" (reintentar no sirve de nada).

**Decisión:**

1. **Un solo formato de error en toda la API**, ya venga del controller o de
   la cadena de filtros de Spring Security:
   `{timestamp, status, error, message, fields?}`. Se extrae a
   `RespuestaError` para que los dos productores escriban lo mismo.
2. **Un handler explícito por familia de fallo**, en vez de extender
   `ResponseEntityExceptionHandler`: 400 (cuerpo ilegible, tipo inválido,
   validación, parámetro ausente), 401 (autenticación), 403 (autorización),
   404 (ruta inexistente), 405 (método), 406/415 (negociación de contenido),
   409 (integridad de BD), 413 (subida), 500 (el resto).
3. **`@Valid` en todos los `@RequestBody`** y las anotaciones de Bean
   Validation que faltaban en los records de request, en particular donde la
   columna de la BD es `NOT NULL`.
4. **Todo error se loguea**: 5xx en `ERROR` con stacktrace, 4xx en `DEBUG` en
   una línea, fallos de autenticación en `INFO`. El cuerpo de la respuesta
   sigue sin exponer nada del detalle interno.
5. **Una cuenta suspendida responde el mismo 401 y el mismo mensaje que una
   contraseña incorrecta.** El motivo real (`DisabledException` /
   `LockedException`, con el correo) se escribe en el log del servidor.

**Alternativas descartadas:**

- *Extender `ResponseEntityExceptionHandler`* (la vía estándar). Habría
  bastado con sobreescribir `handleExceptionInternal`, pero su cuerpo por
  defecto es `ProblemDetail` (RFC 7807: `type`/`title`/`detail`/`instance`),
  distinto del que ya publica `docs/api.md`. Cambiar el formato de error de
  toda la API no es alcance de esta tarea; si algún día se adopta RFC 7807,
  será su propio ADR.
- *Devolver el motivo real al login de una cuenta suspendida* ("tu cuenta fue
  suspendida"). Es más amable, pero convierte un endpoint público en un
  oráculo de qué correos existen y cuáles están sancionados. Decisión de
  `security-agent` al cerrar la tarea 008: mismo mensaje, detalle en el log.
- *Validar los `null` a mano en cada servicio.* Es lo que ya pasaba a medias
  (`MontoDinero.normalizar`) y deja el 400 dependiendo de que alguien se
  acuerde. Bean Validation lo hace en el borde y de forma declarativa.
- *Silenciar los 4xx en el log.* Se descartó: en `DEBUG` no molestan y son la
  única pista cuando un cliente insiste en enviar algo mal.

**Consecuencias:**

- **Cambian códigos de respuesta que antes eran 500** (ningún cliente los
  consume hoy, ADR-0002): ruta inexistente → 404, método no permitido → 405
  (+ cabecera `Allow`), JSON malformado o tipo imposible → 400, UUID inválido
  en la ruta → 400, campo obligatorio ausente → 400 con `fields`,
  `Content-Type` no soportado → 415, choque contra una restricción de la BD →
  409, login de cuenta suspendida → 401.
- **Sin token es 401, ya no 403.** Un 403 ahora significa siempre "estás
  autenticado pero no puedes". Toca `SecurityConfig`: cualquier cambio
  posterior ahí sigue necesitando revisión de `security-agent`.
- **Endpoints con validación nueva**: `POST /api/postulaciones`
  (`trabajoId`), `POST /api/reportes` (`motivo`),
  `POST /api/trabajos/{id}/evidencias` (`texto`), `POST /api/chats/{id}/mensajes`
  (`contenido`) y las propuestas de pago/tiempo del chat. Son campos `NOT NULL`
  en la BD: antes reventaban en el `INSERT`.
- **El log del servidor pasa a contener correos** en las líneas de login
  rechazado (INFO/WARN). Es intencionado —hace falta para dar soporte— pero
  convierte los logs en datos personales: quien los exporte o los suba a un
  servicio externo debe tenerlo en cuenta.
- **Aparece el primer test de la capa HTTP del backend**
  (`MapeoErroresHttpTest`, MockMvc + H2). Hasta ahora todos los tests eran
  unitarios con Mockito y por eso ninguno detectó nada de esto.
- **Queda pendiente**: unificar los mensajes en español (los de Bean
  Validation siguen saliendo en inglés, `"must not be null"`, cuando el
  record no declara `message`), y decidir si algún día se adopta
  `ProblemDetail`/RFC 7807.

---

## ADR-0009 — Sí se migra: Trabajito abandona Firebase y pasa a su propio backend

**Fecha:** 2026-08-26
**Estado:** Aceptado. **Reemplaza a ADR-0002**, que quedaba abierto desde el
2026-08-19.

**Contexto:** ADR-0002 dejó la decisión sin tomar a propósito, porque faltaba
saber si el backend propio era digno de confianza. Ya se sabe:

- Corre de verdad en un servidor Ubuntu contra PostgreSQL 16 (tarea 005).
- Los flujos de negocio se ejercitaron de punta a punta contra esa base de
  datos real, con el dinero cuadrando al céntimo (tarea 006).
- Los **cuatro fallos graves** que encontró esa prueba están cerrados:
  creación de dinero por concurrencia (007), escalada a ADMIN desde el
  registro público (008), errores 500 sin loguear (009) y cancelación
  unilateral tras la entrega (010).
- El script `backend/scripts/prueba-flujo-negocio.sh` pasa con **155
  comprobaciones OK y 0 fallos conocidos**.

**Decisión (del dueño del proyecto, textual):** *"si, los datos de firebase
solo son de prueba, no reales, asi que no tienen importancia, vamos a
independizarnos de firebase, y tener nuestra propia base de datos"*.

Dos consecuencias que simplifican mucho el trabajo, y que conviene dejar
escritas porque cambian el tamaño del proyecto:

1. **No hay migración de datos.** Lo que hay en Firestore es de prueba y se
   descarta. No hace falta script de exportación, ni reconciliación, ni
   ventana de mantenimiento. Esto elimina la parte más cara y arriesgada de
   una migración normal.
2. **El destino es Firebase = cero.** No es una arquitectura híbrida: se va
   Firestore **y** Firebase Authentication. La autenticación pasa a ser la
   del backend (JWT propio), que ya existe y está probada.

**Alcance de lo que hay que hacer** (el plan detallado, por fases, vive en
`docs/agent-tasks/014-migracion-de-firebase-al-backend.md`):

- Reescribir los 6 `lib/services/*_service.dart` para hablar HTTP contra
  `/api/**` en vez de usar el SDK de Firestore.
- Sustituir `firebase_auth` por el login/registro del backend, con
  almacenamiento seguro del token en el dispositivo.
- Añadir un cliente HTTP a `pubspec.yaml` (hoy no hay ninguno) y quitar
  `firebase_core`, `firebase_auth`, `cloud_firestore` cuando ya no se usen.
- Adaptar los modelos: hoy tienen `desdeFirestore()`/`aFirestore()`; pasarán
  a `desdeJson()`/`aJson()`.
- Reconciliar las diferencias de modelado ya detectadas en
  `docs/database.md` (el `saldo` suelto de Firestore vs. el libro
  `MovimientoCartera` de Postgres; `Notificacion` y `Reporte`, que existen
  en el backend y no en la app).
- Retirar `firestore.rules` y `firestore.indexes.json` **solo al final**,
  cuando nada los use.

**Consecuencias:**

- Se levanta la prohibición de ADR-0002: `flutter-agent` **ya puede** cablear
  la app contra `/api/**`, pero siempre dentro de una tarea de la fase que
  corresponda, no "de paso" dentro de otra cosa.
- Las tareas pendientes que existían **solo** para proteger Firestore pierden
  urgencia. En concreto, la tarea 004 (endurecer `soloMetricas()` en
  `firestore.rules`) deja de ser prioritaria: si Firestore se va, blindarlo
  es trabajo que se tira. Se mantiene abierta porque la app en Firestore
  sigue siendo lo único que funciona hasta que la migración avance, pero
  baja de prioridad.
- Los **refresh tokens** pasan a ser urgentes y previos: el contrato de
  autenticación del backend hay que cerrarlo **antes** de reescribir el
  login de Flutter, o se escribe dos veces.
- **Flyway/Liquibase** sube de prioridad: cuando esa base de datos guarde lo
  único que existe, un esquema improvisado por Hibernate deja de ser
  aceptable. Ya causó dos incidentes (ver ADR-0006 y ADR-0007).
- El backend deja de ser "código sin consumidor" y pasa a ser el sistema
  crítico. Todo lo que hoy es un fallo teórico ahí, pasa a ser un fallo real.

---

## ADR-0010 — Login exigente: freno de fuerza bruta por IP + cuenta (en PostgreSQL, sin lockout), y sesión revocable con refresh tokens rotativos

**Fecha:** 2026-08-26
**Estado:** Aceptado (implementado en la tarea 015).
**Aplica a:** el backend Spring Boot (`backend/`) — módulo `modules/auth`,
`security/JwtService`, `config/SecurityConfig`, `common/exception`. **No**
aplica a Firebase Authentication (que se retira, ADR-0009). Con ADR-0009 el
backend pasa a ser el sistema de autenticación real de la app, así que lo que
aquí era un fallo teórico pasa a ser producción.

**Contexto.** El login del backend tenía tres agujeros, anotados al cerrar la
tarea 009 y confirmados contra el servidor real el 2026-08-26:

1. **Sin freno a la fuerza bruta.** 20 intentos con contraseña incorrecta
   contra `/api/auth/login` tardaron 2.0 s (~10/s en un bucle secuencial
   trivial, mucho más con concurrencia) y la 21.ª petición con la contraseña
   correcta seguía dando 200. Nada distinguía un atacante de un usuario.
2. **JWT de 7 días irrevocable.** `JWT_EXPIRATION_MS=604800000`. Si se roba el
   token hay acceso durante una semana y **cerrar sesión no lo invalida**: no
   había forma de revocar nada.
3. **Política de contraseñas floja.** El registro exigía solo 8 caracteres
   (`@Size(min=8)`) y no había tope máximo — BCrypt ignora en silencio los
   bytes más allá del 72, así que una contraseña larguísima daba una falsa
   sensación de fortaleza.

### Decisión 1 — Freno a la fuerza bruta en dos capas, ninguna con lockout de cuenta

Se cuentan los **intentos fallidos** en una tabla PostgreSQL (`intentos_login`:
`ip`, `correo`, `exito`, `creado_en`) sobre una ventana deslizante (por defecto
15 min). Dos límites independientes:

- **Por IP (`max-por-ip`, 20/ventana).** Al superarlo, la IP recibe **429**
  con `Retry-After` **antes de ejecutar BCrypt**. Es la defensa dura: frena al
  atacante de una sola fuente y **acota el coste de CPU de BCrypt** (una IP no
  puede forzar más de 20 hashes por ventana). No puede usarse para dejar fuera
  a una persona porque **se indexa por la IP del propio atacante**, no por la
  víctima: bloquea al que ataca, no a quien intenta entrar desde otro sitio.

- **Por cuenta (`max-por-cuenta`, 5/ventana).** Al superarlo, la cuenta entra
  en estado "con fricción", pero **NO se bloquea**: se sigue verificando la
  contraseña en cada intento. Un intento **con la contraseña correcta siempre
  devuelve 200** (y limpia el contador), incluso con la cuenta bajo ataque; un
  intento **con la contraseña incorrecta** devuelve **429** en vez de 401.

**Por qué esto frena la fuerza bruta SIN abrir un vector de denegación de
servicio contra una persona** (la trampa que el encargo pedía evitar
explícitamente): el clásico "bloqueo tras N fallos" deja que cualquiera que
sepa tu correo te deje fuera a voluntad. Aquí eso no puede pasar porque **no
existe ningún estado en el que la contraseña correcta sea rechazada**. El
atacante, por definición, no conoce la contraseña: todos sus intentos son
"fallidos con contraseña incorrecta", y son justo esos los que se frenan (429
por cuenta, 429 por IP tras 20). El dueño legítimo presenta la contraseña
correcta y entra sin importar cuántos fallos acumuló el atacante. La víctima y
el atacante son indistinguibles solo mientras ambos fallan; en el momento en
que alguien acierta, deja de estarlo — y solo el dueño acierta.

**Límite honesto y asumido:** una botnet distribuida (muchas IPs, cada una por
debajo de `max-por-ip`) puede seguir probando contra una cuenta a ritmo bajo,
porque para no bloquear al dueño hay que ejecutar BCrypt en cada intento. El
freno por cuenta ahí aporta **detección/alerta y fricción** (429 + log), no un
tope duro. El tope duro contra un origen distribuido pertenece a la capa de
infraestructura (WAF / rate-limit en el proxy) o a un reto tipo CAPTCHA /
step-up; queda como tarea aparte (016), no se resuelve en la capa de
aplicación.

### Decisión 2 — Los intentos se cuentan en PostgreSQL, no en Redis

Redis está en el stack objetivo pero **no existe en el repo** (CLAUDE.md §2).
Se resuelve en PostgreSQL, que ya está y es transaccional:

- El volumen de logins es bajo (una app de oficios, no un IdP masivo). Una
  tabla con índices en `(correo, creado_en)` y `(ip, creado_en)` sobra.
- Añadir Redis es alcance de infraestructura (coordinar con `devops-agent`,
  nuevo servicio en compose, nueva dependencia): desproporcionado para un
  contador. La regla 5 de CLAUDE.md pide justificar dependencias nuevas.
- El rastro de intentos es además auditable y consultable para soporte.

Se descartó **Bucket4j en memoria**: se pierde al reiniciar y no sirve con más
de una instancia. Si algún día el login escala a varios nodos con mucho
tráfico, mover el contador a Redis es una optimización con su propio ADR; el
`IntentoLoginRepository` deja la puerta abierta a cambiar el almacén sin tocar
la lógica.

### Decisión 3 — Sesión revocable: access token corto + refresh token rotativo

- **Access token (JWT)**: baja de 7 días a **15 min** (`access-expiration-ms`).
  Sigue siendo sin estado; su corta vida es lo que acota la ventana de un token
  robado sin tener que consultar la BD en cada petición.
- **Refresh token**: cadena **opaca** aleatoria (32 bytes, `SecureRandom`), NO
  un JWT. Se guarda en la tabla `refresh_tokens` **solo su hash SHA-256**, para
  que una fuga de la BD no entregue sesiones utilizables. Es revocable porque
  su validez depende de una fila, no de una firma.
- **`POST /api/auth/refresh`** cambia un refresh válido por un **par nuevo**
  (rotación): revoca el usado y emite otro de la misma "familia". Si se
  presenta un refresh **ya usado/revocado**, se interpreta como robo y se
  **revoca toda la familia** (detección de reutilización) → 401.
- **`POST /api/auth/logout`** revoca el refresh presentado. A partir de ahí el
  refresh viejo da 401 y el access muere en ≤15 min: **cerrar sesión invalida
  la sesión de verdad**, que antes era imposible.

Se descartó **lista negra de JWT de acceso**: obligaría a consultar la BD en
cada petición y a mantener la lista hasta que cada token caduque; con access de
15 min el beneficio no compensa. La revocación vive en el refresh, no en el
access.

**Preparado para varios roles sin implementarlos (tarea 012).** El JWT sigue
llevando un único claim `rol` como hoy, para no romper nada. La generación del
token está aislada en `JwtService`; cuando la tarea 012 decida el modelo de
doble perfil, pasará a un claim `roles` (lista) sin tocar el resto. **No** se
decide aquí cómo se representan los roles.

### Decisión 4 — Política de contraseñas razonable (no hostil)

Registro: **mínimo 10, máximo 72 caracteres** (antes 8, sin tope). El máximo 72
no es cosmético: BCrypt trunca en 72 bytes, así que aceptar más da una falsa
sensación de seguridad. Se sigue el criterio NIST 800-63B (**longitud sobre
complejidad**): no se exige mezcla obligatoria de mayúsculas/dígitos/símbolos,
que empuja a patrones predecibles y molesta al usuario. En su lugar, y
siguiendo la misma norma, se aplican dos filtros que sí correlacionan con
contraseñas realmente adivinables:

- **Lista de bloqueo** de contraseñas comunes y del propio nombre de la app
  (`password`, `contrasena`, `12345678`, `qwerty`, `trabajito`…).
- **Ni todo dígitos ni un solo carácter repetido**: en Honduras la elección
  débil típica es el teléfono o la fecha de nacimiento, y son justo las que un
  ataque dirigido prueba primero.

Mensajes en español, uno por regla, para que el usuario sepa qué corregir.
El ADMIN inicial mantiene su mínimo de 12 (ADR-0005): es la cuenta con más
poder.

### Extracción de la IP del cliente

`getRemoteAddr()` por defecto. Detrás de un proxy inverso esa IP es la del
proxy; para esos despliegues hay un flag `login.confiar-en-forwarded-for`
(**por defecto `false`**, porque `X-Forwarded-For` es falsificable si nadie de
confianza lo fija). En este servidor de pruebas no hay proxy, así que el valor
seguro es `false` y el conteo por IP usa la IP real de la conexión.

**Qué se loguea de cada intento fallido:** método, ruta, motivo
(`BadCredentialsException` / `DisabledException`…) y el correo, en el nivel ya
fijado por ADR-0008 (auth en INFO/WARN). El correo ya estaba en esos logs desde
la tarea 009; no se añade ningún dato personal nuevo. **Nunca** se loguea la
contraseña ni el token. La tabla `intentos_login` guarda correo + IP + sello de
tiempo: son datos personales, misma salvedad que ADR-0008 para quien exporte
los logs.

### Consecuencias

- **`AuthResponse` gana campos** (`refreshToken`, `tokenType`, `expiraEnSegundos`)
  y **conserva** `token` y `usuario`, así que no rompe el contrato que ya lee el
  script de regresión. Ningún cliente lo consume aún (ADR-0002/0009).
- **Nuevos endpoints públicos** `POST /api/auth/refresh` y `POST /api/auth/logout`
  (van bajo `/api/auth/**`, ya `permitAll`). Documentados en `docs/api.md`.
- **Nuevo código HTTP en la API: 429** (Too Many Requests) con `Retry-After`.
  Se añade su fila a la tabla de errores de `docs/api.md`.
- **Dos tablas nuevas** (`intentos_login`, `refresh_tokens`), creadas por
  Hibernate `ddl-auto=update`. Refuerza la urgencia de Flyway/Liquibase que ya
  señaló ADR-0009: cuando esa BD guarde lo único que existe, el esquema no puede
  seguir saliendo de un `update` improvisado.
- **El default de expiración del access token baja a 15 min.** El despliegue
  debe dejar de fijar `JWT_EXPIRATION_MS=604800000`; se sustituye por
  `JWT_ACCESS_EXPIRATION_MS` / `JWT_REFRESH_EXPIRATION_MS` en `.env.example` y
  `docker-compose.yml`.
- **Queda pendiente (tarea 016):** el tope duro contra fuerza bruta distribuida
  (WAF/CAPTCHA/step-up) y la limpieza periódica de filas viejas de
  `intentos_login` / `refresh_tokens` (un job o `DELETE` por antigüedad).
- **2FA** no se implementa: si se decide, es su propia tarea (fuera de alcance).

---

## ADR-0011 — El CV del trabajador va en tres tablas con clave ajena, y la reputación se parte en dos: una por rol

**Fecha:** 2026-08-27
**Estado:** Aceptado (implementado en la tarea 019).
**Aplica a:** el backend Spring Boot (`backend/`) — entidad `Usuario`, módulo
`modules/usuarios` (nuevo: `Experiencia`, `Estudio`, `Habilidad`,
`PerfilService`), `modules/calificaciones` y `modules/postulaciones`. **No**
toca `lib/**`: la app sigue leyendo Firestore hasta la fase 2 de ADR-0009.

**Contexto.** Al cerrar la fase 1 de la migración (tarea 018) `flutter-agent`
encontró, y el `tech-lead` confirmó comparando ambos modelos, que **el backend
no guardaba el perfil del trabajador**. La entidad `Usuario` de Spring tenía 21
campos; el modelo de Flutter maneja ~40 más experiencia y estudios. Faltaba
justo lo que llena el registro de 5 pasos y lo que se ve en el perfil público:
`habilidades`, `experiencia`, `estudios`, `telefonoEmergencia`,
`fechaNacimiento`, `genero`, `viveEnHonduras`, `codigoPostal`, `pais`, `urlCV`,
`registroCompleto`, `cargoContacto` y `descripcionEmpresa`. Migrar el perfil en
esas condiciones **perdía datos que el usuario ve en pantalla**, así que
bloqueaba la fase 2.

En el mismo cambio entran dos decisiones de producto del dueño (2026-08-26),
porque tocan la misma entidad y la misma migración de esquema: *"dos
[reputaciones] diferentes para cada rol"* y *"bloquea los postulamientos a
propios trabajos"*.

**Decisión.**

1. **`habilidades`, `experiencia` y `estudios` son tres tablas con FK a
   `usuarios`** (`habilidades`, `experiencias`, `estudios`), no columnas JSON ni
   listas embebidas como en Firestore. Motivos, por orden de peso:
   - El feed tiene que poder **filtrar por habilidad**. Una fila por etiqueta con
     índice es un `WHERE` normal; una cadena separada por comas obliga a un
     `LIKE` con comodín por delante, que ningún índice ayuda.
   - Editar un puesto del CV **no debe reescribir la fila del usuario**, que
     lleva el `saldo` y depende de `@DynamicUpdate` para no pisar una recarga
     concurrente (ADR-0006).
   - Son datos con ciclo de vida propio (alta, edición y baja uno a uno), que es
     justo lo que la app hace en los pasos 4 y 5 del registro.

   Las tres tablas usan `@ManyToOne` hacia `Usuario`, **la primera relación JPA
   real del proyecto**: el resto del esquema referencia por UUID suelto y por
   tanto no tiene integridad referencial. Aquí sí la hay
   (`fk_experiencias_usuario`, `fk_estudios_usuario`, `fk_habilidades_usuario`),
   porque son tablas nuevas y no cuesta nada crearlas bien. La relación se
   declara solo en el hijo: el `Usuario` **no** tiene colecciones, para no
   arrastrar cargas perezosas a los caminos que bloquean su fila con
   `SELECT ... FOR UPDATE` (ADR-0006).

2. **Las fechas del CV se guardan como texto; la de nacimiento, como fecha.** El
   formulario pide `MM/AAAA` para experiencia y estudios: son fechas *parciales*
   y convertirlas a `LocalDate` obligaría a inventar un día, así que se guardan
   tal cual llegan y la migración desde Firestore no cambia ni un carácter.
   `fechaNacimiento` sí es `LocalDate` porque de ella depende una regla de
   negocio: **la edad mínima de 18 años, que hasta ahora solo comprobaba la
   pantalla de Flutter** —es decir, no se comprobaba—. Entra en `dd/MM/yyyy` o
   ISO y **sale siempre en ISO**.

3. **Dos reputaciones, no una.** `Usuario` gana
   `calificacionComoTrabajador`/`totalCalificacionesComoTrabajador` y
   `calificacionComoEmpleador`/`totalCalificacionesComoEmpleador`, y
   `Calificacion` gana `rolCalificado` (`TRABAJADOR`|`EMPLEADOR`). Quién suma
   dónde lo decide el papel que tenía **el receptor en ese trabajo**, nunca su
   rol de cuenta: con el doble perfil (tarea 012) la misma cuenta será las dos
   cosas. Se **conserva** `calificacionPromedio`/`totalCalificaciones` como media
   global: ya tenía datos y quitarla habría sido perder historial.

4. **El perfil ajeno deja de ser un buscador de datos personales.**
   `UsuarioResponse` pasa a tener dos vistas: la del dueño y la pública. Añadir
   el perfil completo a `GET /api/usuarios/{id}` sin esto habría hecho legibles
   para cualquier cuenta el teléfono de emergencia y la fecha de nacimiento de
   cualquier persona. La vista pública oculta correo, DNI, teléfonos, fecha de
   nacimiento, género, código postal, RTN y **saldo** (este último ya se exponía
   antes: era un agujero previo, aquí se cierra de paso).

5. **Postularse al propio trabajo responde 409, no 400.** La comprobación ya
   existía —al contrario de lo que decía el enunciado de la tarea— pero devolvía
   `400`. Es un conflicto con el estado del recurso (quien pide *es* el dueño),
   no un cuerpo mal formado, así que va con el mismo `409` que "ya te postulaste".

**Alternativas descartadas.**

- *Una columna `jsonb` con el CV entero.* Más parecido a Firestore y con menos
  tablas, pero deja el filtrado por habilidad sin índice usable, obliga a
  reescribir la fila del usuario (la del `saldo`) en cada edición, y renuncia a
  validar la forma de los datos en la base.
- *`@ElementCollection` para las habilidades.* Habría metido una colección en
  `Usuario` y, siendo `EAGER`, se cargaría también en las transacciones que
  bloquean la fila para mover dinero; siendo `LAZY`, reventaría al serializar
  fuera de transacción (`open-in-view: false`). Una tabla propia evita las dos
  cosas.
- *Sustituir `calificacionPromedio` por las dos nuevas.* Habría dejado sin
  reputación visible a las cuentas que ya tenían reseñas, y obligaría al cliente
  a decidir cuál enseñar antes de que exista el doble perfil (tarea 012).
- *Meter Flyway ahora.* Es lo correcto y hace falta, pero es otra tarea: ver más
  abajo.

**Consecuencias.**

- **Tres tablas nuevas** (`habilidades`, `experiencias`, `estudios`) y **14
  columnas nuevas** en `usuarios`, más `rol_calificado` en `calificaciones`.
  Todo creado por `ddl-auto=update` y **verificado contra el PostgreSQL real**,
  no solo contra H2.
- **Las columnas nuevas de una tabla que ya existe no pueden ser `NOT NULL`.**
  PostgreSQL rechaza `ADD COLUMN ... NOT NULL` sin `DEFAULT` sobre una tabla con
  filas, y con `ddl-auto=update` ese fallo se traga en un WARN: la columna
  simplemente no existiría. Por eso las nuevas llevan `@ColumnDefault` y no
  `nullable = false`. Es la tercera vez que `ddl-auto=update` condiciona un
  diseño (ADR-0006 y ADR-0007 fueron las otras dos).
- **Nuevo componente de arranque `RellenoPerfilYReputacion`**, hermano de
  `RestriccionSaldoNoNegativo` y `RestriccionEstadoTrabajo`: deduce el
  `rol_calificado` de las reseñas anteriores (del trabajo: si el receptor era el
  trabajador asignado, la recibió como trabajador) y recalcula las dos medias.
  En el servidor de pruebas clasificó **20 reseñas** y recalculó **10 + 10**
  usuarios. Es idempotente y se borra el día que entren migraciones versionadas.
- **Propuesta explícita, no implementada: ya toca Flyway.** Van tres parches de
  arranque haciendo de sistema de migraciones y este último ya no es sobre
  constraints, sino sobre **datos**. Mientras el esquema salga de un `update`,
  ni se puede revisar en PR ni se puede reproducir. Debe ser su propia tarea,
  con ADR propio, antes de que la fase 2 ponga datos reales de usuarios ahí.
- **Contratos que cambian** (ningún cliente los consume todavía, ADR-0002/0009):
  `GET /api/usuarios/{id}` devuelve la vista pública —con el CV, sin datos
  personales—, `GET /api/auth/yo` devuelve el perfil completo,
  `PUT /api/usuarios/me` acepta 23 campos y devuelve el perfil completo, y
  `/api/calificaciones` devuelve `CalificacionResponse` en vez de la entidad.
  `POST /api/auth/login` y `/registro` siguen devolviendo el usuario **sin** las
  tres listas (`null` = "no viene en esta respuesta", no "no tiene").

---

## ADR-0012 — Cerrar sesión revoca la familia entera de refresh tokens (este dispositivo), y hay un endpoint aparte para cerrarla en todos

**Fecha:** 2026-08-30
**Estado:** Aceptado (implementado en la tarea 024).
**Aplica a:** el backend Spring Boot (`backend/`) — `modules/auth`
(`RefreshTokenService`, `AuthService`, `AuthController`) y
`config/SecurityConfig`. **Corrige** la Decisión 3 de ADR-0010, que no cambia
en lo demás (acceso de 15 min + refresh opaco rotativo de 30 días con
revocación de familia por reutilización). **No** aplica a Firebase
Authentication, que ya no se usa (ADR-0009).

**Contexto.** ADR-0010 dejó escrito que *"`POST /api/auth/logout` revoca el
refresh presentado"*, y eso es literalmente lo que hacía
`RefreshTokenService.revocar()`: marcaba **una fila**. Cualquier otro token
vivo de la misma familia seguía siendo aceptado.

Que eso no es una sutileza teórica lo demostró la revisión de QA de la tarea
022, reproduciéndolo en un emulador contra el backend real: si el usuario
cerraba sesión **mientras había una renovación de token en vuelo**, el refresco
terminaba después y guardaba en el dispositivo un par recién emitido —de la
misma familia, y por tanto **no revocado**—. Al siguiente arranque la app
entraba sola en una sesión que el usuario creía cerrada. El `qa-agent` lo tapó
en el cliente (tercer candado de `ApiClient`, que comprueba que la sesión sigue
siendo la misma al terminar el refresco) y ese caso concreto ya no ocurre; esta
decisión arregla la causa en el servidor.

Lo llamativo es que la capacidad ya estaba construida: el mismo servicio revoca
familias enteras cuando detecta la reutilización de un token rotado
(`RevocadorDeFamilias`, ADR-0010). El `logout` simplemente no la usaba.

### Decisión 1 — `logout` revoca la familia del token presentado, no la fila

`POST /api/auth/logout` revoca **todos** los refresh tokens de la familia a la
que pertenece el token recibido. Sigue respondiendo `204` siempre que el cuerpo
sea válido, también con un token desconocido (no puede servir de oráculo de
tokens).

Un detalle que sí es una decisión, no un descuido: se revoca la familia
**aunque la fila presentada ya esté revocada o caducada**. Ese es justo el caso
de la renovación en vuelo —el cliente manda el token que tenía guardado, que
para entonces ya fue rotado—, así que exigir que el token esté vigente dejaría
el agujero abierto. Presentar un token conocido basta como prueba de haber
tenido esa sesión, y el peor efecto posible de equivocarse aquí es cerrar una
sesión de más, nunca dejar una abierta. Es además coherente con la detección de
reutilización, que ante un token revocado ya tumba la familia entera.

### Decisión 2 — `logout` cierra **este** dispositivo; cerrar todos es una acción aparte y explícita

Una familia = una sesión = un dispositivo. Cerrar sesión en el móvil **no**
cierra la de la tablet: lo contrario sería un efecto sorpresa desproporcionado
para una acción tan cotidiana, y empujaría a la gente a no cerrar sesión nunca.

Pero "creo que alguien entró en mi cuenta" es una necesidad real y distinta, y
merece su propia acción explícita: **`POST /api/auth/logout-todos`**, que revoca
todas las familias del usuario, **incluida aquella desde la que se pide**. Se
incluye la propia a propósito: quien pulsa eso quiere el estado limpio, y dejar
viva justo la sesión que hace la llamada obligaría al cliente a razonar sobre un
caso especial para ganar cero seguridad. La consecuencia para el cliente está en
`docs/api.md`: tras llamarlo debe borrar su sesión local y volver a entrar.

Se descartó de momento un "cerrar las **demás** sesiones, menos esta": es una
comodidad, no una necesidad de seguridad, y añade una variante más que probar.

### Decisión 3 — `logout-todos` exige token de acceso; `logout` no

`/api/auth/**` es `permitAll`, así que `logout-todos` lleva una regla explícita
**antes** del `permitAll` en `SecurityConfig` (en Spring Security gana la
primera regla que casa) y es la única ruta de ese prefijo que exige
autenticación.

Por qué la asimetría:

- **`logout` no puede exigir token de acceso.** Quien cierra sesión suele tener
  el access token caducado (dura 15 min), y el refresh token que presenta ya es
  una credencial de esa sesión. Exigir un access válido convertiría "cerrar
  sesión" en algo que a veces falla, y el fallo dejaría la sesión **abierta**:
  justo al revés de lo que interesa.
- **`logout-todos` sí.** Es destructivo sobre todas las sesiones del usuario.
  Se pide a quien demuestra tener la cuenta **ahora mismo**, no a quien tenga
  suelto un refresh token viejo. No supone una barrera real para un atacante que
  ya haya robado un refresh (podría canjearlo por un access), pero evita que un
  token filtrado y caducado sirva para echar al dueño de todos sus dispositivos,
  y deja la acción atada a una identidad en el log.

No se pide la contraseña otra vez: hoy no existe ningún endpoint de
verificación de contraseña suelto (la tarea 017 sigue abierta) y la posesión de
un access token vivo ya es la prueba que el resto de la API acepta.

### Consecuencias

- **Endpoint nuevo:** `POST /api/auth/logout-todos` (`204`, sin cuerpo). El
  único de `/api/auth/**` que responde `401` sin token. Documentado en
  `docs/api.md`.
- **Cambia el comportamiento observable de `logout`**, no su contrato HTTP
  (mismo cuerpo, mismo `204`). Ningún cliente tiene que cambiar nada.
- **El tercer candado del cliente** (`ApiClient._esLaSesionActual`, tarea 022)
  **se queda**. Ya no es la única defensa, pero sigue evitando que el
  dispositivo *guarde* tokens de una sesión cerrada y que una renovación en
  vuelo pise una sesión nueva —un caso que el servidor no puede ver—. Defensa en
  profundidad: el servidor no debería depender de que el cliente se comporte, y
  el cliente tampoco de que el servidor le tape los descuidos.
- **El access token ya emitido sigue vivo hasta 15 min** después de cualquiera
  de los dos logouts. Es la consecuencia asumida de ADR-0010 (sin lista negra de
  JWT) y queda fijada en un test para que se vea que es una decisión, no un
  olvido. Si algún día hace falta corte inmediato —y para "me robaron la cuenta"
  es discutible que no haga falta—, es un ADR nuevo con su coste: consultar la
  BD en cada petición o llevar un `tokenVersion` por usuario.
- **Sin cambios de esquema.** Se reutilizan `revocarFamilia` y
  `revocarTodosDeUsuario`, que ya existían en `RefreshTokenRepository`, y los
  índices de `refresh_tokens` (`idx_refresh_familia`, `idx_refresh_usuario`) ya
  estaban creados. Nada que temer de `ddl-auto=update` en esta tarea.
- **Queda pendiente y se anota como tarea aparte (025):** la app no tiene
  todavía botón de "cerrar sesión en todos los dispositivos", así que el
  endpoint existe pero ningún usuario puede llegar a él. Y cuando la tarea 017
  traiga el **cambio de contraseña**, tiene que llamar a
  `cerrarTodasLasSesiones` del usuario: cambiar la contraseña sin echar a las
  sesiones abiertas no sirve para expulsar a quien ya está dentro.
- **La baja de cuenta ya corta el acceso, pero no limpia las filas.**
  `DELETE /api/usuarios/me` pone `activo = false`, y tanto `JwtAuthFilter` como
  el `refresh` rechazan a un usuario inactivo, así que las sesiones dejan de
  funcionar. Sus refresh tokens, en cambio, se quedan **sin revocar** en la
  tabla: si alguna vez se reactiva la cuenta a mano, esas sesiones reviven.
  Conviene que la baja llame también a `cerrarTodasLasSesiones` (recogido en la
  tarea 025).
