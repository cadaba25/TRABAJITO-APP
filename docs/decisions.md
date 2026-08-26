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
**Estado:** Abierto — no decidido

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
