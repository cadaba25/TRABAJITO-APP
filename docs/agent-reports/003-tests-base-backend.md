---
id: 003
tarea: docs/agent-tasks/003-tests-base-backend.md
agente: qa-agent
fecha: 2026-08-19
---

## Objetivo (copiado de la tarea)

`backend/pom.xml` ya declara `spring-boot-starter-test` y
`spring-security-test`, pero `backend/src/test` no existía — cero tests en
todo el backend. Se necesita al menos un test de contexto
(`@SpringBootTest`) y un test real de un módulo con lógica no trivial
(`AuthService` o `TrabajoService`), documentando si se usó Postgres real,
H2 o mocks, y por qué.

## Cambios realizados

- `backend/pom.xml`: se agregó `com.h2database:h2` con `scope=test`
  (única dependencia nueva de esta tarea; justificación abajo).
- `backend/src/test/resources/application-test.yml` (nuevo): perfil
  `test`, datasource H2 en memoria en modo compatibilidad Postgres
  (`MODE=PostgreSQL`), `ddl-auto=create-drop`, secreto JWT de prueba,
  puerto de servidor aleatorio (`server.port: 0`).
- `backend/src/test/java/com/trabajito/TrabajitoApplicationTests.java`
  (nuevo): test de contexto (`@SpringBootTest`, perfil `test`,
  `WebEnvironment.RANDOM_PORT`). Confirma que toda la app Spring levanta
  (todos los beans, seguridad, WebSocket, JPA) sin el perfil `dev` (así que
  `DataSeeder` no corre).
- `backend/src/test/java/com/trabajito/modules/auth/AuthServiceTest.java`
  (nuevo): 6 tests unitarios de `AuthService` con Mockito puro.
- `backend/src/test/java/com/trabajito/modules/trabajos/TrabajoServiceTest.java`
  (nuevo): 15 tests unitarios de `TrabajoService` (la máquina de estados
  del ciclo de vida del trabajo, incluido el escrow) con Mockito puro.

Se hicieron ambos servicios sugeridos (`AuthService` y `TrabajoService`),
no solo uno, porque `TrabajoService` es donde vive la lógica de
dinero/escrow (prioridad explícita del rol de QA de este agente: "prioriza
tests de los flujos con dinero o datos sensibles").

## Archivos modificados

- `backend/pom.xml`
- `backend/src/test/resources/application-test.yml` (nuevo)
- `backend/src/test/java/com/trabajito/TrabajitoApplicationTests.java` (nuevo)
- `backend/src/test/java/com/trabajito/modules/auth/AuthServiceTest.java` (nuevo)
- `backend/src/test/java/com/trabajito/modules/trabajos/TrabajoServiceTest.java` (nuevo)
- `docs/agent-tasks/003-tests-base-backend.md`

## Decisiones tomadas

**Estrategia de testing del backend (afecta a tareas futuras):**

1. **Tests de servicio (lógica de negocio): Mockito puro**, sin Spring
   context ni base de datos. `AuthServiceTest` y `TrabajoServiceTest`
   instancian el servicio directamente (`new AuthService(...)`,
   `new TrabajoService(...)`) con los repositorios/colaboradores mockeados
   vía `@Mock` + `MockitoExtension`. Es la opción más rápida (los 21 tests
   de ambos servicios corren en ~1 segundo combinados) y aísla
   completamente la lógica que se quiere probar de la infraestructura.
   `PasswordEncoder` (BCrypt real) y `JwtService` (real, con secreto de
   prueba) se usan como objetos reales en `AuthServiceTest` en vez de
   mocks, porque son baratos de construir sin dependencias externas y
   probar hash/verify y firma/parseo de JWT reales da más garantías que
   mockear su comportamiento.

2. **Test de contexto: H2 en memoria, no Testcontainers, no Postgres
   real.** Se evaluó explícitamente Testcontainers (más fiel a producción)
   contra H2 (más simple/rápido) y se eligió H2 porque:
   - El único test que necesita un datasource real es el test de
     contexto (¿levanta el `ApplicationContext`?), no lógica de queries
     específicas de Postgres — para eso, la fidelidad de Testcontainers no
     aporta aún.
   - Requerir Docker corriendo para que `mvn test` pase agrega una
     dependencia de entorno que no todos los agentes/entornos van a tener
     siempre disponible (aunque en esta máquina específica Docker Desktop
     sí está instalado y funcionando). Un test base que solo corre "si
     tienes Docker levantado" es frágil como punto de partida para las
     tareas de backend que vengan después.
   - H2 arranca en ~12 segundos dentro del `@SpringBootTest` (incluye
     todo Tomcat + Hibernate + Spring Security + WebSocket), sin pasos
     manuales previos.
   - Trade-off aceptado: H2 no es 100% compatible con Postgres (tipos,
     funciones específicas). Para este test de contexto no importa, porque
     no se ejercitan queries complejas. **Si una tarea futura necesita
     probar un `@Query` específico de Postgres o comportamiento de
     concurrencia/transacciones realista, se recomienda evaluar
     Testcontainers en ese momento**, no generalizar H2 a todo.

3. No se tocó `docker-compose.yml` ni se corrió Postgres real para esta
   tarea — no hizo falta con el enfoque elegido.

**Por qué H2 y no "todo con mocks" también para el test de contexto:** un
test de contexto con toda la configuración mockeada deja de probar lo que
se supone que prueba (que el `ApplicationContext` real, con el
`DataSource`/`EntityManagerFactory` reales, arma correctamente). Se
necesita *algún* datasource real para que el test tenga valor; H2 es el
mínimo viable sin infraestructura externa.

## Problemas encontrados

- **`UnnecessaryStubbingException` de Mockito** en la primera corrida: el
  stub genérico de `repositorio.save(...)` en `@BeforeEach` (para simular
  que JPA asigna un id al guardar) se marcaba como "unnecessary" en los
  tests que lanzan una excepción antes de llegar a `save()` (Mockito usa
  "strict stubs" por defecto con `MockitoExtension`). Se resolvió marcando
  ese stub específico como `lenient()` en vez de bajar la verificación
  estricta global — mantiene el resto de los tests con verificación
  estricta de stubs no usados.
- **`Usuario.builder().id(...)` no compila**: `Usuario` usa `@Builder`
  (Lombok), no `@SuperBuilder`, así que el builder generado no expone los
  campos heredados de `BaseEntity` (`id`, `creadoEn`, `actualizadoEn`). Se
  ajustó el test para asignar el `id` con `.setId(...)` después de
  construir el objeto con el builder, en vez de vía el builder.
- Ninguno de los dos fue bloqueante; ambos se detectaron y corrigieron
  corriendo `mvn test` de verdad, no fueron anticipados de antemano.

## Tests ejecutados

Comando exacto (dos corridas, para descartar flaky):

```bash
export JAVA_HOME="C:\Program Files\Android\Android Studio\jbr"
export PATH="$PATH:/c/Users/enigm/tools/apache-maven-3.9.16/bin"
cd backend && mvn test
```

Resultado real de la última corrida:

```
[INFO] Running com.trabajito.modules.auth.AuthServiceTest
[INFO] Tests run: 6, Failures: 0, Errors: 0, Skipped: 0, Time elapsed: 3.347 s
[INFO] Running com.trabajito.modules.trabajos.TrabajoServiceTest
[INFO] Tests run: 15, Failures: 0, Errors: 0, Skipped: 0, Time elapsed: 0.357 s
[INFO] Running com.trabajito.TrabajitoApplicationTests
[INFO] Tests run: 1, Failures: 0, Errors: 0, Skipped: 0, Time elapsed: 12.87 s
[INFO] Tests run: 22, Failures: 0, Errors: 0, Skipped: 0
[INFO] BUILD SUCCESS
```

Total: **22/22 tests pasan**, `BUILD SUCCESS`, corrido dos veces con el
mismo resultado (sin flakiness observado).

También se corrió `mvn -q -DskipTests compile` antes de escribir los
tests, para confirmar que el estado base seguía compilando: sin salida
(éxito).

## Pendientes

- **`PagoService` (movimientos de cartera/escrow) no tiene test unitario
  directo** — se cubrió indirectamente a través de `TrabajoServiceTest`
  (que verifica que `TrabajoService` llama a `pagoService.retener()` /
  `.liberar()` / `.reembolsar()` con los argumentos correctos, mockeando
  `PagoService`), pero la lógica interna de `PagoService` (por ejemplo,
  "saldo insuficiente al retener", "el saldo resultante se calcula bien
  con `BigDecimal`", "se registra un `MovimientoCartera` por cada
  operación") no tiene tests propios todavía. Dado que es dinero/escrow,
  se recomienda como siguiente tarea de `qa-agent` o `backend-agent`:
  `PagoServiceTest` unitario con Mockito, cubriendo saldo insuficiente,
  BigDecimal con decimales (redondeo/escala), y que cada operación registra
  el movimiento correcto en `MovimientoCarteraRepository`.
- No se probaron los controllers (`AuthController`, `TrabajoController`,
  etc.) con `MockMvc`/`@WebMvcTest` — quedó fuera del alcance de "base
  mínima de tests" de esta tarea. `spring-security-test` ya está en el
  `pom.xml` y listo para usarse (`@WithMockUser`, etc.) cuando se aborde
  esa tarea.
- No se probó `JwtAuthFilter`/`CustomUserDetailsService`/`SecurityConfig`
  de forma directa (solo indirectamente, al levantar el contexto completo
  en `TrabajitoApplicationTests`). Candidato a tarea futura de
  `security-agent` + `qa-agent`.
- El `firestore.rules` que permite a cualquier usuario autenticado escribir
  el `saldo` de otro usuario (mencionado en
  `docs/agent-context/repo-snapshot.md`) sigue sin resolverse — no es
  parte del alcance de esta tarea (es Flutter/Firestore, no backend), pero
  se reitera aquí porque es justo el tipo de riesgo de dinero que este
  agente prioriza. Ya está reportado en el snapshot; no se duplica como
  tarea nueva.
