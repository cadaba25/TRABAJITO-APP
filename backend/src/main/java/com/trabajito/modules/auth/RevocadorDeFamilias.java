package com.trabajito.modules.auth;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

import java.util.UUID;

/**
 * Revoca familias enteras de refresh tokens en su PROPIA transaccion.
 *
 * <p>Existe por un motivo concreto (lo cazo el test {@code refreshRota}):
 * cuando se detecta la reutilizacion de un refresh token ya rotado hay que
 * hacer dos cosas seguidas — revocar toda la familia y responder 401. Si ambas
 * ocurrieran en la misma transaccion, la excepcion del 401 provocaria un
 * <b>rollback que deshace la revocacion</b>, y el token robado seguiria vivo:
 * justo lo contrario de lo que se pretende.
 *
 * <p>Con {@code REQUIRES_NEW} en un bean aparte (la anotacion no funciona en
 * auto-invocacion dentro de la misma clase), la revocacion se confirma antes de
 * que el 401 tire la transaccion exterior.
 */
@Service
public class RevocadorDeFamilias {

    private static final Logger log = LoggerFactory.getLogger(RevocadorDeFamilias.class);

    private final RefreshTokenRepository repo;

    public RevocadorDeFamilias(RefreshTokenRepository repo) {
        this.repo = repo;
    }

    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public int revocarFamilia(UUID familia) {
        int revocados = repo.revocarFamilia(familia);
        log.warn("Reutilizacion de refresh token detectada (familia {}): "
                + "revocados {} tokens de esa sesion", familia, revocados);
        return revocados;
    }
}
