package com.trabajito.config;

import com.trabajito.modules.auth.AuthService;
import com.trabajito.modules.auth.dto.AuthResponse;
import com.trabajito.modules.auth.dto.RegistroRequest;
import com.trabajito.modules.auth.dto.RolPublico;
import com.trabajito.modules.usuarios.Usuario;
import com.trabajito.modules.usuarios.UsuarioRepository;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.web.server.LocalServerPort;
import org.springframework.messaging.converter.StringMessageConverter;
import org.springframework.messaging.simp.stomp.StompHeaders;
import org.springframework.messaging.simp.stomp.StompSession;
import org.springframework.messaging.simp.stomp.StompSessionHandlerAdapter;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.web.socket.client.standard.StandardWebSocketClient;
import org.springframework.web.socket.messaging.WebSocketStompClient;
import org.springframework.web.socket.sockjs.client.SockJsClient;
import org.springframework.web.socket.sockjs.client.Transport;
import org.springframework.web.socket.sockjs.client.WebSocketTransport;

import java.util.List;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Tarea 030 (parte B) — el CONNECT de STOMP ahora exige un JWT válido.
 *
 * <p>Antes del arreglo, los tres escenarios "rechazado" de este test fallaban
 * (la conexión se aceptaba igual, sin token o con uno de un usuario inactivo).
 * Levanta un servidor real en un puerto aleatorio ({@code webEnvironment =
 * RANDOM_PORT}) porque validar un handshake WebSocket de verdad no se puede
 * simular con MockMvc.
 *
 * <p>Se conecta con un cliente STOMP sobre SockJS ({@code WebSocketStompClient}
 * + {@code SockJsClient} + {@code WebSocketTransport}/{@code StandardWebSocketClient}),
 * el mismo protocolo que registra {@code WebSocketConfig}
 * ({@code .withSockJS()}) — todo ya en el classpath vía
 * {@code spring-boot-starter-websocket}, sin dependencias nuevas. Para
 * correrlo aparte: {@code mvn test -Dtest=WebSocketAuthTest}.
 */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@ActiveProfiles("test")
class WebSocketAuthTest {

    private static final String PASSWORD = "Prueba1234";
    private static final long TIMEOUT_SEGUNDOS = 5;

    @LocalServerPort
    private int puerto;

    @Autowired
    private AuthService authService;

    @Autowired
    private UsuarioRepository usuarios;

    @Test
    @DisplayName("CONNECT sin token: rechazado")
    void sinTokenRechazado() throws Exception {
        Resultado r = conectar(null);
        assertThat(r.rechazado.await(TIMEOUT_SEGUNDOS, TimeUnit.SECONDS)).isTrue();
        assertThat(r.conectado.getCount()).isEqualTo(1);
    }

    @Test
    @DisplayName("CONNECT con token válido: aceptado")
    void conTokenValidoAceptado() throws Exception {
        String token = registrarYObtenerToken().token();

        Resultado r = conectar(token);
        assertThat(r.conectado.await(TIMEOUT_SEGUNDOS, TimeUnit.SECONDS)).isTrue();
    }

    @Test
    @DisplayName("CONNECT con token de un usuario inactivo: rechazado")
    void usuarioInactivoRechazado() throws Exception {
        AuthResponse registro = registrarYObtenerToken();
        Usuario u = usuarios.findById(registro.usuario().id()).orElseThrow();
        u.setActivo(false);
        usuarios.save(u);

        Resultado r = conectar(registro.token());
        assertThat(r.rechazado.await(TIMEOUT_SEGUNDOS, TimeUnit.SECONDS)).isTrue();
        assertThat(r.conectado.getCount()).isEqualTo(1);
    }

    // ── Utilidades ───────────────────────────────────────────────────

    private AuthResponse registrarYObtenerToken() {
        String correo = "ws." + System.nanoTime() + "@trabajito.local";
        return authService.registrar(new RegistroRequest(
                correo, PASSWORD, "WebSocket", "Prueba", null, null,
                RolPublico.TRABAJADOR, null, null));
    }

    private Resultado conectar(String token) throws Exception {
        // El endpoint está registrado con .withSockJS() (WebSocketConfig): hay
        // que negociar el protocolo SockJS, un StandardWebSocketClient a secas
        // no completa el handshake contra ese endpoint.
        List<Transport> transports = List.of(new WebSocketTransport(new StandardWebSocketClient()));
        WebSocketStompClient stompClient = new WebSocketStompClient(new SockJsClient(transports));
        stompClient.setMessageConverter(new StringMessageConverter());

        StompHeaders connectHeaders = new StompHeaders();
        if (token != null) {
            connectHeaders.add("Authorization", "Bearer " + token);
        }

        Resultado r = new Resultado();
        stompClient.connectAsync(
                "http://localhost:" + puerto + "/ws",
                (org.springframework.web.socket.WebSocketHttpHeaders) null,
                connectHeaders,
                new StompSessionHandlerAdapter() {
                    @Override
                    public void afterConnected(StompSession session, StompHeaders headers) {
                        r.conectado.countDown();
                    }

                    @Override
                    public void handleTransportError(StompSession session, Throwable exception) {
                        r.rechazado.countDown();
                    }
                });
        return r;
    }

    /** Deliberadamente sin usar el resultado de {@code connectAsync} como future:
     *  cuando el CONNECT se rechaza, el future puede no completar nunca (el
     *  servidor cierra el socket sin CONNECTED ni excepción local), así que la
     *  señal fiable es el callback {@code handleTransportError} del handler. */
    private static final class Resultado {
        final CountDownLatch conectado = new CountDownLatch(1);
        final CountDownLatch rechazado = new CountDownLatch(1);
    }
}
