package com.trabajito.modules.usuarios;

import com.trabajito.common.enums.Rol;
import com.trabajito.common.exception.ApiException;
import com.trabajito.modules.usuarios.dto.ActualizarPerfilRequest;
import com.trabajito.modules.usuarios.dto.UsuarioResponse;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.time.Period;
import java.time.format.DateTimeFormatter;
import java.time.format.DateTimeParseException;
import java.time.format.ResolverStyle;
import java.util.List;
import java.util.UUID;

@Service
public class UsuarioService {

    /** Formato del formulario de registro de Flutter. */
    private static final DateTimeFormatter DIA_MES_ANIO =
            DateTimeFormatter.ofPattern("dd/MM/uuuu").withResolverStyle(ResolverStyle.STRICT);

    /** Edad mínima para usar Trabajito (la app ya la pedía; ahora la exige el servidor). */
    static final int EDAD_MINIMA = 18;

    private final UsuarioRepository usuarios;
    private final PerfilService perfiles;

    public UsuarioService(UsuarioRepository usuarios, PerfilService perfiles) {
        this.usuarios = usuarios;
        this.perfiles = perfiles;
    }

    public Usuario porId(UUID id) {
        return usuarios.findById(id)
                .orElseThrow(() -> ApiException.noEncontrado("Usuario no encontrado"));
    }

    /** Perfil completo de otra persona: sin datos personales ni saldo. */
    @Transactional(readOnly = true)
    public UsuarioResponse perfilPublico(UUID id) {
        return perfiles.completo(porId(id), false);
    }

    /** Perfil completo propio: incluye todo. */
    @Transactional(readOnly = true)
    public UsuarioResponse perfilPropio(UUID id) {
        return perfiles.completo(porId(id), true);
    }

    /**
     * Edita el perfil propio. Devuelve el perfil COMPLETO para que el cliente
     * no tenga que pedirlo otra vez después de guardar.
     */
    @Transactional
    public UsuarioResponse actualizarPerfil(UUID id, ActualizarPerfilRequest req) {
        Usuario u = porId(id);

        if (req.nombres() != null) u.setNombres(exigirNoVacio(req.nombres(), "El nombre"));
        if (req.apellidos() != null) u.setApellidos(exigirNoVacio(req.apellidos(), "Los apellidos"));
        if (req.telefono() != null) u.setTelefono(req.telefono());
        if (req.telefonoEmergencia() != null) u.setTelefonoEmergencia(req.telefonoEmergencia());
        if (req.fechaNacimiento() != null) u.setFechaNacimiento(fechaDeNacimiento(req.fechaNacimiento()));
        if (req.genero() != null) u.setGenero(req.genero());
        if (req.presentacion() != null) u.setPresentacion(req.presentacion());
        if (req.urlCV() != null) u.setUrlCV(req.urlCV());
        if (req.departamento() != null) u.setDepartamento(req.departamento());
        if (req.ciudad() != null) u.setCiudad(req.ciudad());
        if (req.codigoPostal() != null) u.setCodigoPostal(req.codigoPostal());
        if (req.pais() != null) u.setPais(req.pais());
        if (req.viveEnHonduras() != null) u.setViveEnHonduras(req.viveEnHonduras());
        if (req.fotoUrl() != null) u.setFotoUrl(req.fotoUrl());
        if (req.registroCompleto() != null) u.setRegistroCompleto(req.registroCompleto());
        if (req.tipoEmpleador() != null) u.setTipoEmpleador(req.tipoEmpleador());
        if (req.nombreEmpresa() != null) u.setNombreEmpresa(req.nombreEmpresa());
        if (req.rtn() != null) u.setRtn(req.rtn());
        if (req.cargoContacto() != null) u.setCargoContacto(req.cargoContacto());
        if (req.sectorEmpresa() != null) u.setSectorEmpresa(req.sectorEmpresa());
        if (req.tamanoEmpresa() != null) u.setTamanoEmpresa(req.tamanoEmpresa());
        if (req.sitioWeb() != null) u.setSitioWeb(req.sitioWeb());
        if (req.descripcionEmpresa() != null) u.setDescripcionEmpresa(req.descripcionEmpresa());

        usuarios.save(u);

        if (req.habilidades() != null) {
            perfiles.reemplazarHabilidades(id, req.habilidades());
        }
        return perfiles.completo(u, true);
    }

    private String exigirNoVacio(String valor, String que) {
        String limpio = valor.trim();
        if (limpio.isEmpty()) {
            throw ApiException.solicitudInvalida(que + " no puede quedar vacío");
        }
        return limpio;
    }

    /**
     * Acepta {@code dd/MM/yyyy} (lo que manda el formulario de la app) o ISO
     * {@code yyyy-MM-dd}, y exige ser mayor de {@value #EDAD_MINIMA}.
     *
     * <p>Hasta ahora la edad mínima solo la comprobaba la pantalla de registro
     * de Flutter, y una comprobación que vive en el cliente no es una
     * comprobación: cualquiera con curl se la salta.
     *
     * <p>Cadena vacía = borrar la fecha.
     */
    private LocalDate fechaDeNacimiento(String texto) {
        String s = texto.trim();
        if (s.isEmpty()) return null;

        LocalDate fecha;
        try {
            fecha = LocalDate.parse(s);
        } catch (DateTimeParseException e) {
            try {
                fecha = LocalDate.parse(s, DIA_MES_ANIO);
            } catch (DateTimeParseException e2) {
                throw ApiException.solicitudInvalida(
                        "La fecha de nacimiento debe ir como dd/MM/aaaa o aaaa-MM-dd");
            }
        }
        LocalDate hoy = LocalDate.now();
        if (fecha.isAfter(hoy)) {
            throw ApiException.solicitudInvalida(
                    "La fecha de nacimiento no puede estar en el futuro");
        }
        if (fecha.isBefore(hoy.minusYears(120))) {
            throw ApiException.solicitudInvalida("Esa fecha de nacimiento no es creíble");
        }
        if (Period.between(fecha, hoy).getYears() < EDAD_MINIMA) {
            throw ApiException.solicitudInvalida(
                    "Debes tener al menos " + EDAD_MINIMA + " años para usar Trabajito");
        }
        return fecha;
    }

    /** Ranking de trabajadores por trabajos completados. */
    public List<Usuario> ranking() {
        return usuarios.findTop50ByRolAndActivoTrueOrderByTrabajosCompletadosDesc(Rol.TRABAJADOR);
    }

    /** Baja lógica: desactiva la cuenta (no borra, para conservar historial). */
    @Transactional
    public void desactivar(UUID id) {
        Usuario u = porId(id);
        u.setActivo(false);
        usuarios.save(u);
    }
}
