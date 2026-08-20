---
id: 003
titulo: "Crear la base de tests del backend (hoy no existe ninguno)"
estado: hecho
agente: qa-agent
creada: 2026-08-19
rama: "fix/qa-widget-test-and-backend-tests"
---

## Objetivo

`backend/pom.xml` ya declara `spring-boot-starter-test` y
`spring-security-test`, pero `backend/src/test` **no existe** — cero tests
en todo el backend. No hay forma de cumplir el checklist de "tarea
terminada" (`docs/development.md`) del lado backend sin al menos una base
mínima de tests que sirva de ejemplo para las tareas siguientes.

## Contexto relevante

`docs/development.md` (estado verificado: `mvn compile` da `BUILD SUCCESS`,
confirma que el entorno con Maven+JDK ya funciona). `docs/api.md` para el
mapa de endpoints. `backend/README.md` para cómo correr el backend
localmente (Docker Compose para Postgres).

## Criterios de aceptación

- [x] Al menos un test de contexto (`@SpringBootTest`) que confirme que la
      aplicación levanta correctamente.
- [x] Al menos un test real de un módulo con lógica no trivial — buen
      candidato: `AuthService` (registro/login) o `TrabajoService` (máquina
      de estados del ciclo de vida del trabajo), usando mocks donde
      corresponda para no depender de una base de datos real corriendo.
- [x] `mvn test` corre y pasa.
- [x] Se documenta en el reporte si los tests requieren Postgres real
      (Testcontainers, H2 en memoria, o mocks) y por qué se eligió ese
      enfoque — es una decisión que afecta a todas las tareas de backend
      futuras, no solo a esta.

## Notas del agente que la ejecuta

Se hicieron los dos: `AuthService` **y** `TrabajoService` (este último por
ser la máquina de estados que mueve el escrow/dinero — prioridad explícita
del rol de QA), más el test de contexto.

- `TrabajitoApplicationTests` (`@SpringBootTest`, perfil `test`): usa H2 en
  memoria (`spring.datasource.url=jdbc:h2:mem:...;MODE=PostgreSQL`),
  configurado en `src/test/resources/application-test.yml`. Se eligió H2 en
  vez de Testcontainers para el test de contexto: no requiere Docker
  corriendo cada vez que alguien ejecuta `mvn test` (Docker sí está
  disponible en esta máquina, pero no se puede asumir que lo esté en todos
  los entornos donde corran los agentes o un futuro CI), arranca en
  segundos, y para un test de contexto (¿levanta el ApplicationContext?)
  no hace falta fidelidad total con Postgres. Se agregó `com.h2database:h2`
  como dependencia `test`-scope en `pom.xml` (justificación: única forma
  práctica de tener un test de contexto rápido sin infraestructura externa).
  El perfil `dev` (que activa `DataSeeder`) NO está activo en los tests.
- `AuthServiceTest` y `TrabajoServiceTest`: unitarios con Mockito puro
  (`@ExtendWith(MockitoExtension.class)`), sin Spring context ni base de
  datos en absoluto — mockeando `UsuarioRepository`/`TrabajoRepository`/
  `PagoService`/`AuthenticationManager`. `PasswordEncoder` (BCrypt real) y
  `JwtService` (real, con secreto de prueba) se instancian de verdad en vez
  de mockearse, porque son objetos baratos de construir y probar su
  comportamiento real (hash/verify, firma/parseo de JWT) da más confianza
  que mockearlos.
- **Decisión para futuras tareas de backend**: usar Mockito puro para
  lógica de servicio (rápido, aislado, no requiere nada externo) y reservar
  H2/`@SpringBootTest` solo para tests de contexto o de integración ligera.
  Si en el futuro se necesita probar queries JPA reales (`@Query`,
  comportamiento específico de Postgres), evaluar Testcontainers en ese
  momento — no se necesitó para esta tarea base.
- Edge cases cubiertos en `TrabajoServiceTest` (con foco en dinero/escrow,
  según el mandato de este agente): doble asignación de trabajador (evita
  pisar al trabajador ya asignado — clase de bug relacionada con el
  histórico "doble-submit"), `reservarPago`/`aceptar` idempotentes (un
  segundo llamado no vuelve a mover dinero), saldo insuficiente al retener
  no dejar el trabajo en estado inconsistente, cancelación con escrow ya
  liberado (debe rechazarse), y rechazo de asignación cuando el escrow ya
  está retenido (no se puede "salir" dejando dinero huérfano).
- Edge cases en `AuthServiceTest`: registro con correo duplicado (no debe
  llegar a `save`), normalización de correo (mayúsculas/espacios),
  autenticación exitosa en Spring Security pero usuario ya no existe en la
  tabla (no debe explotar con NPE, debe dar 404 controlado), y que un mock
  de `save()` sin comportamiento explícito no genera un `id` — hubo que
  simular ese comportamiento a mano porque `AuthService.registrar()` confía
  en que JPA asigna el id al guardar (ver comentario en el test).

`mvn test` → **22/22 tests pasan**, `BUILD SUCCESS` (corrido dos veces para
descartar flaky). Ver comando exacto en
`docs/agent-reports/003-tests-base-backend.md`.
