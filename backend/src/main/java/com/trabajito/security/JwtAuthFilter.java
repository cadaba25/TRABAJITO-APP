package com.trabajito.security;

import com.trabajito.modules.usuarios.Usuario;
import com.trabajito.modules.usuarios.UsuarioRepository;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.lang.NonNull;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.web.authentication.WebAuthenticationDetailsSource;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.util.Optional;
import java.util.UUID;

/**
 * Intercepta cada petición, valida el token JWT del header Authorization y,
 * si es válido, coloca al usuario en el contexto de seguridad.
 */
@Component
public class JwtAuthFilter extends OncePerRequestFilter {

    private static final String PREFIJO = "Bearer ";

    private final JwtService jwtService;
    private final UsuarioRepository usuarios;

    public JwtAuthFilter(JwtService jwtService, UsuarioRepository usuarios) {
        this.jwtService = jwtService;
        this.usuarios = usuarios;
    }

    @Override
    protected void doFilterInternal(@NonNull HttpServletRequest request,
                                    @NonNull HttpServletResponse response,
                                    @NonNull FilterChain chain)
            throws ServletException, IOException {

        String header = request.getHeader("Authorization");
        if (header != null && header.startsWith(PREFIJO)) {
            String token = header.substring(PREFIJO.length());
            if (jwtService.esValido(token)
                    && SecurityContextHolder.getContext().getAuthentication() == null) {
                try {
                    UUID id = UUID.fromString(jwtService.extraerUsuarioId(token));
                    Optional<Usuario> u = usuarios.findById(id);
                    if (u.isPresent() && u.get().isActivo()) {
                        UsuarioPrincipal principal = new UsuarioPrincipal(u.get());
                        var auth = new UsernamePasswordAuthenticationToken(
                                principal, null, principal.getAuthorities());
                        auth.setDetails(new WebAuthenticationDetailsSource().buildDetails(request));
                        SecurityContextHolder.getContext().setAuthentication(auth);
                    }
                } catch (IllegalArgumentException ignored) {
                    // token con subject inválido -> se ignora, queda sin autenticar
                }
            }
        }
        chain.doFilter(request, response);
    }
}
