package com.trabajito.modules.usuarios;

import com.trabajito.common.enums.Rol;
import com.trabajito.common.exception.ApiException;
import com.trabajito.modules.usuarios.dto.ActualizarPerfilRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.UUID;

@Service
public class UsuarioService {

    private final UsuarioRepository usuarios;

    public UsuarioService(UsuarioRepository usuarios) {
        this.usuarios = usuarios;
    }

    public Usuario porId(UUID id) {
        return usuarios.findById(id)
                .orElseThrow(() -> ApiException.noEncontrado("Usuario no encontrado"));
    }

    @Transactional
    public Usuario actualizarPerfil(UUID id, ActualizarPerfilRequest req) {
        Usuario u = porId(id);
        if (req.nombres() != null) u.setNombres(req.nombres().trim());
        if (req.apellidos() != null) u.setApellidos(req.apellidos().trim());
        if (req.telefono() != null) u.setTelefono(req.telefono());
        if (req.presentacion() != null) u.setPresentacion(req.presentacion());
        if (req.departamento() != null) u.setDepartamento(req.departamento());
        if (req.ciudad() != null) u.setCiudad(req.ciudad());
        if (req.fotoUrl() != null) u.setFotoUrl(req.fotoUrl());
        if (req.tipoEmpleador() != null) u.setTipoEmpleador(req.tipoEmpleador());
        if (req.nombreEmpresa() != null) u.setNombreEmpresa(req.nombreEmpresa());
        if (req.sectorEmpresa() != null) u.setSectorEmpresa(req.sectorEmpresa());
        if (req.tamanoEmpresa() != null) u.setTamanoEmpresa(req.tamanoEmpresa());
        if (req.sitioWeb() != null) u.setSitioWeb(req.sitioWeb());
        return usuarios.save(u);
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
