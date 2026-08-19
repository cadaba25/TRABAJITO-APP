---
id: 001
titulo: "Arreglar test/widget_test.dart (referencia MyApp inexistente)"
estado: en-progreso
agente: qa-agent
creada: 2026-08-19
rama: "fix/qa-widget-test-and-backend-tests"
---

## Objetivo

`flutter test` no compila hoy porque `test/widget_test.dart` es el test por
defecto del template de Flutter y referencia una clase `MyApp` que nunca
existió en este proyecto (la app raíz se llama `TrabajitApp`, en
`lib/main.dart`). Es el bloqueador más obvio para que el checklist de
"tarea terminada" (`docs/development.md`) sea cumplible por cualquier otro
agente que toque Flutter.

## Contexto relevante

`docs/development.md` sección "Estado conocido al 2026-08-19".
`lib/main.dart` — `TrabajitApp`, `PantallaInicial`.

## Criterios de aceptación

- [ ] `flutter test` compila y corre sin el error `MyApp isn't a class`.
- [ ] El test resultante prueba algo real de arranque de la app (por ejemplo,
      que `PantallaInicial` decide entre `LoginScreen` e `InicioScreen` según
      el estado de auth), no solo un smoke test vacío para que compile.
- [ ] No se requiere Firebase real corriendo para que el test pase (mockear
      `FirebaseAuth`/`Firestore` si hace falta, o aislar el widget que se
      prueba).

## Notas del agente que la ejecuta

(vacío — tarea aún no iniciada)
