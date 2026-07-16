package com.trabajito.security;

import com.trabajito.modules.usuarios.UsuarioRepository;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.security.core.userdetails.UsernameNotFoundException;
import org.springframework.stereotype.Service;

/** Carga usuarios desde la BD para la autenticación de Spring Security. */
@Service
public class CustomUserDetailsService implements UserDetailsService {

    private final UsuarioRepository usuarios;

    public CustomUserDetailsService(UsuarioRepository usuarios) {
        this.usuarios = usuarios;
    }

    @Override
    public UserDetails loadUserByUsername(String correo) throws UsernameNotFoundException {
        return usuarios.findByCorreo(correo)
                .map(UsuarioPrincipal::new)
                .orElseThrow(() -> new UsernameNotFoundException("Usuario no encontrado"));
    }
}
