package com.trabajito.modules.chats;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.UUID;

public interface MensajeRepository extends JpaRepository<Mensaje, UUID> {

    List<Mensaje> findByChatIdOrderByCreadoEnAsc(UUID chatId);

    long countByChatIdAndDeUidNotAndLeidoFalse(UUID chatId, UUID uid);
}
