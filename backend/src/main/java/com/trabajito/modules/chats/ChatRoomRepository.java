package com.trabajito.modules.chats;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface ChatRoomRepository extends JpaRepository<ChatRoom, UUID> {

    Optional<ChatRoom> findByTrabajoId(UUID trabajoId);

    List<ChatRoom> findByEmpleadorIdOrTrabajadorIdOrderByFechaUltimoMensajeDesc(
            UUID empleadorId, UUID trabajadorId);
}
