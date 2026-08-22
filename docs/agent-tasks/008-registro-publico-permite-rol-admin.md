---
id: 008
titulo: "El registro público permite crear cuentas con rol ADMIN (escalada de privilegios)"
estado: en-progreso
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

- [ ] `POST /api/auth/registro` con `"rol":"ADMIN"` responde 400/403 y **no**
      crea ningún usuario. Con `TRABAJADOR` y `EMPLEADOR` sigue funcionando
      igual que hoy.
- [ ] Un rol desconocido (`"rol":"SUPERJEFE"`) responde 400, no 500 — se
      solapa con la tarea 009; coordinar para no pisarse.
- [ ] No existe ninguna otra ruta pública por la que un usuario pueda
      cambiarse el rol a sí mismo (revisar `PUT /api/usuarios/perfil` y
      `ActualizarPerfilRequest`, no verificado en la tarea 006).
- [ ] Queda documentado cómo se crea un ADMIN legítimamente (seeder con
      perfil, script de operación, o SQL manual) — hoy no está escrito en
      ningún lado.
- [ ] `bash backend/scripts/prueba-flujo-negocio.sh` deja de reportar
      `BUG-008`.

## Notas del agente que la ejecuta

Al decidir el arreglo, ten en cuenta que este backend **también** carece de
cualquier verificación de rol en los flujos de negocio (un `TRABAJADOR` puede
publicar trabajos, un `EMPLEADOR` puede postularse como trabajador —
comprobado, ambos 200). Eso puede ser deliberado (una persona puede ser las
dos cosas) o un olvido, pero es una decisión de producto que corresponde al
`tech-lead`, **no** la resuelvas de paso dentro de esta tarea.
