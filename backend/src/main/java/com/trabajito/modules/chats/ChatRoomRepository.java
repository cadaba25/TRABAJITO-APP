package com.trabajito.modules.chats;

import jakarta.persistence.LockModeType;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface ChatRoomRepository extends JpaRepository<ChatRoom, UUID> {

    Optional<ChatRoom> findByTrabajoId(UUID trabajoId);

    /** SELECT ... FOR UPDATE: serializa la negociacion y reservar-pago (tarea 056). */
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select c from ChatRoom c where c.id = :id")
    Optional<ChatRoom> findByIdParaActualizar(@Param("id") UUID id);

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select c from ChatRoom c where c.trabajoId = :trabajoId")
    Optional<ChatRoom> findByTrabajoIdParaActualizar(@Param("trabajoId") UUID trabajoId);

    List<ChatRoom> findByEmpleadorIdOrTrabajadorIdOrderByFechaUltimoMensajeDesc(
            UUID empleadorId, UUID trabajadorId);
}
