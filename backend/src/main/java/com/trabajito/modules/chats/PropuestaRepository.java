package com.trabajito.modules.chats;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.UUID;

public interface PropuestaRepository extends JpaRepository<Propuesta, UUID> {

    List<Propuesta> findByChatIdOrderByCreadoEnAsc(UUID chatId);
}
