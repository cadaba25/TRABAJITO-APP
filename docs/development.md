# Desarrollo local

## Flutter (frontend — lo único que corre en producción hoy)

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

Requiere el `google-services.json` de Android (ya está commiteado en
`android/app/`) y, si se agrega soporte iOS, un `GoogleService-Info.plist`
que **hoy no existe en el repo**.

### Estado conocido al 2026-08-19

- `flutter analyze`: sin errores en `lib/`. Hay warnings/info menores
  (mayormente `withOpacity` deprecado, `use_build_context_synchronously`,
  un import y un campo sin usar) — no bloquean, pero cualquier agente que
  toque uno de esos archivos debería limpiarlo de paso.
- `flutter test`: **falla al compilar**. `test/widget_test.dart` es el test
  por defecto del template de Flutter y referencia una clase `MyApp` que ya
  no existe (la app se llama `TrabajitApp`). Es la primera tarea obvia para
  `qa-agent`.

## Backend (Spring Boot — no conectado a producción, ver `docs/architecture.md`)

Instrucciones completas en [`backend/README.md`](../backend/README.md).
Resumen:

```bash
cd backend
cp .env.example .env
docker compose up -d db          # PostgreSQL en localhost:5432
SPRING_PROFILES_ACTIVE=dev mvn spring-boot:run
```

Swagger UI en `http://localhost:8080/swagger-ui.html`.

### Estado verificado al 2026-08-19 (entorno de desarrollo de este equipo)

- **Docker Desktop**: instalado y funcionando (motor corriendo, `docker
  compose` disponible). Requirió WSL2 (Windows 11 Home no tiene Hyper-V).
- **Maven 3.9.16**: no está disponible vía `winget` — se instaló manualmente
  desde el binario oficial (`dlcdn.apache.org`, checksum SHA-512 verificado)
  en `%USERPROFILE%\tools\apache-maven-3.9.16`, agregado al `PATH` de
  usuario (no de sistema — no requirió permisos de administrador).
- **`JAVA_HOME`**: apunta al JDK 21 que ya trae Android Studio instalado
  (`C:\Program Files\Android\Android Studio\jbr`), en vez de instalar un JDK
  aparte. El `pom.xml` declara Java 17 como versión de proyecto — un JDK 21
  compila igual (Maven usa el flag `--release` para el bytecode objetivo),
  así que no hace falta un JDK 17 exacto.
- **Confirmado con `mvn compile`: `BUILD SUCCESS`.** El backend sí compila.

Si alguien más monta el entorno desde cero, necesita: JDK 17+ en el `PATH`
(o `JAVA_HOME` apuntando a uno), Maven (no viene con `winget`, hay que
bajarlo del sitio oficial), y Docker Desktop con WSL2 en Windows Home. Todo
esto son variables de entorno de **usuario**, no cambios a nivel de sistema.

## Checklist de "tarea terminada" (todo agente, antes de pedir revisión)

- [ ] El código relacionado con la tarea fue leído antes de modificarlo (no
      se asumió su comportamiento).
- [ ] `docs/agent-tasks/<tarea>.md` existe y refleja lo que realmente se hizo
      (no solo lo planeado).
- [ ] Si tocaste Flutter: `flutter analyze` no introduce errores nuevos,
      `flutter test` pasa (o el fallo preexistente de `widget_test.dart` fue
      justo lo que arreglaste).
- [ ] Si tocaste el backend: compila y los tests del módulo pasan, o se
      documentó explícitamente por qué no se pudo verificar.
- [ ] No se agregaron secretos, tokens ni credenciales al diff.
- [ ] No se borró funcionalidad existente sin autorización.
- [ ] Se creó/actualizó el reporte en `docs/agent-reports/<tarea>.md`.
- [ ] Si el cambio es arquitectónico (nuevo patrón, nueva dependencia grande,
      cambio de contrato de API o de modelo de datos), hay un ADR en
      `docs/decisions.md`.
