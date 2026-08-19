---
id: 003
titulo: "Crear la base de tests del backend (hoy no existe ninguno)"
estado: en-progreso
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

- [ ] Al menos un test de contexto (`@SpringBootTest`) que confirme que la
      aplicación levanta correctamente.
- [ ] Al menos un test real de un módulo con lógica no trivial — buen
      candidato: `AuthService` (registro/login) o `TrabajoService` (máquina
      de estados del ciclo de vida del trabajo), usando mocks donde
      corresponda para no depender de una base de datos real corriendo.
- [ ] `mvn test` corre y pasa.
- [ ] Se documenta en el reporte si los tests requieren Postgres real
      (Testcontainers, H2 en memoria, o mocks) y por qué se eligió ese
      enfoque — es una decisión que afecta a todas las tareas de backend
      futuras, no solo a esta.

## Notas del agente que la ejecuta

(vacío — tarea en progreso, ver reporte al cerrar)
