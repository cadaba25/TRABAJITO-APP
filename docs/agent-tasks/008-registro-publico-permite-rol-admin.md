---
id: 008
titulo: "El registro público permite crear cuentas con rol ADMIN (escalada de privilegios)"
estado: hecho
agente: "security-agent"
creada: 2026-08-21
rama: "security/registro-no-permite-rol-admin"
---

## Objetivo

`POST /api/auth/registro` es un endpoint **público** (`permitAll` en
`SecurityConfig`) y acepta el campo `rol` tal cual viene del cliente,
incluyendo `ADMIN`. Cualquiera con acceso a la API puede crear una cuenta de
administrador y usar todo `/api/admin/**`.

Verificado contra el servidor real (tarea 006):

```
POST /api/auth/registro
{"correo":"escalada2@trabajito.local","password":"Prueba1234",
 "nombres":"N","apellidos":"A","rol":"ADMIN"}
-> HTTP 200
   usuario.rol = "ADMIN"
   JWT emitido con el claim  "rol":"ADMIN"

GET /api/admin/estadisticas   (con ese token)
-> HTTP 200  {"reportesAbiertos":0,"trabajos":7,"usuarios":17}
   (control: el mismo endpoint con un token TRABAJADOR -> 403)

POST /api/admin/usuarios/{id-de-otro}/suspender   (con ese token)
-> HTTP 200  y la victima queda con activo=false: su siguiente login falla.
```

O sea: no es teórico, se ejecutó y sirvió para **suspender la cuenta de otro
usuario**. `AdminController` también expone reportes de toda la plataforma y
la reactivación de cuentas.

El backend todavía no tiene consumidor (la app usa Firebase), así que el
impacto hoy es sobre el servidor de pruebas. Pero es exactamente el tipo de
agujero que no puede sobrevivir a la migración de ADR-0002, y el arreglo es
pequeño: mejor ahora que después.

## Contexto relevante

- `backend/src/main/java/com/trabajito/modules/auth/dto/RegistroRequest.java`
  — `@NotNull Rol rol` sin ninguna restricción de valor.
- `backend/src/main/java/com/trabajito/modules/auth/AuthService.java`
  — usa `req.rol()` directamente.
- `backend/src/main/java/com/trabajito/config/SecurityConfig.java`
  — `/api/auth/**` es `permitAll`; `/api/admin/**` es `hasRole("ADMIN")`
  (la regla está bien: el problema es de dónde sale el rol).
- `backend/src/main/java/com/trabajito/config/DataSeeder.java` — crea
  `admin@trabajito.local / Admin1234`. Está bien protegido con
  `@Profile("dev")` y en el servidor **no** se activó (comprobado: no hay
  ninguna fila con `rol='ADMIN'` sembrada y `SPRING_PROFILES_ACTIVE` está
  vacío). Aun así, revisar si esa contraseña por defecto debería seguir en el
  código.
- `docs/agent-reports/006-flujos-negocio-contra-postgres.md` — respuestas
  completas.

## Criterios de aceptación

- [x] `POST /api/auth/registro` con `"rol":"ADMIN"` responde 400/403 y **no**
      crea ningún usuario. Con `TRABAJADOR` y `EMPLEADOR` sigue funcionando
      igual que hoy.
- [x] Un rol desconocido (`"rol":"SUPERJEFE"`) responde 400, no 500 — se
      solapa con la tarea 009; coordinar para no pisarse.
- [x] No existe ninguna otra ruta pública por la que un usuario pueda
      cambiarse el rol a sí mismo (revisar `PUT /api/usuarios/perfil` y
      `ActualizarPerfilRequest`, no verificado en la tarea 006).
- [x] Queda documentado cómo se crea un ADMIN legítimamente (seeder con
      perfil, script de operación, o SQL manual) — hoy no está escrito en
      ningún lado.
- [x] `bash backend/scripts/prueba-flujo-negocio.sh` deja de reportar
      `BUG-008`.

## Notas del agente que la ejecuta

Al decidir el arreglo, ten en cuenta que este backend **también** carece de
cualquier verificación de rol en los flujos de negocio (un `TRABAJADOR` puede
publicar trabajos, un `EMPLEADOR` puede postularse como trabajador —
comprobado, ambos 200). Eso puede ser deliberado (una persona puede ser las
dos cosas) o un olvido, pero es una decisión de producto que corresponde al
`tech-lead`, **no** la resuelvas de paso dentro de esta tarea.

---

**Ejecutada por `security-agent` el 2026-08-21.** Reporte completo:
`docs/agent-reports/008-registro-publico-permite-rol-admin.md`.

Resumen de lo decidido mientras se trabajaba:

- El arreglo **no** es un `if (rol == ADMIN) throw` en `AuthService`, sino un
  enum propio del DTO, `RolPublico {TRABAJADOR, EMPLEADOR}`: ADMIN deja de ser
  expresable en la petición. Razonado en ADR-0005 (`docs/decisions.md`).
- El rol desconocido (`SUPERJEFE`) pasa a 400 **sin** tocar
  `GlobalExceptionHandler`: el `@JsonCreator` de `RolPublico` devuelve `null`
  y el `@NotNull` del DTO produce el 400 de validación normal. La tarea 009
  sigue siendo dueña del mapeo global de errores; se le dejó nota de este
  solape en su propio archivo.
- **Otras vías de escalada:** se auditaron todas las escrituras de `rol`
  (`grep setRol|.rol(` en `backend/src/main`): solo existían dos,
  `AuthService.registrar()` y el seeder. `ActualizarPerfilRequest` no tiene
  campo `rol` y Jackson ignora las propiedades desconocidas, así que
  `PUT /api/usuarios/me` con `{"rol":"ADMIN","saldo":99999}` no cambia nada
  (verificado contra el servidor, antes y después). Ningún controller acepta
  una entidad JPA como `@RequestBody`. La ruta `PUT /api/usuarios/perfil` que
  menciona esta tarea no existe: la real es `PUT /api/usuarios/me`.
- **Cómo se crea un ADMIN ahora:** `DataSeeder` (con `admin@trabajito.local /
  Admin1234` fijo en el código) se sustituye por `AdminInicialSeeder`,
  gobernado por `ADMIN_INICIAL_CORREO` / `ADMIN_INICIAL_PASSWORD`. Sin ambas
  variables no crea nada, en ningún perfil. Documentado en `backend/README.md`
  → "Cómo se crea un ADMIN", junto con el SQL para promover una cuenta
  existente.
- **Sobre la nota de esta tarea:** no se tocó nada de la verificación de rol
  en los flujos de negocio (un `TRABAJADOR` sigue pudiendo publicar y un
  `EMPLEADOR` postularse, ambos 200). El análisis está en el reporte, la
  decisión es del `tech-lead`.
- **Estado que se dejó en la BD de pruebas:** las 5 cuentas `rol='ADMIN'`
  auto-registradas siguen existiendo pero quedaron con `activo=false` (el
  arreglo cierra la puerta, no revoca lo ya concedido). Ver el reporte para
  el SQL exacto y cómo revertirlo. Hallazgo lateral abierto como tarea 011.
