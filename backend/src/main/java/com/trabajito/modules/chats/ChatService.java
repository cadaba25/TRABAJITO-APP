package com.trabajito.modules.chats;

import com.trabajito.common.enums.TipoMensaje;
import com.trabajito.common.exception.ApiException;
import com.trabajito.modules.trabajos.Trabajo;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

/**
 * Chat y negociación (pago/tiempo). La primera propuesta siempre la hace el
 * trabajador; luego cualquiera puede contraproponer hasta que la otra parte
 * acepte.
 */
@Service
public class ChatService {

    private final ChatRoomRepository salas;
    private final MensajeRepository mensajes;
    private final PropuestaRepository propuestas;
    private final SimpMessagingTemplate ws; // para empujar mensajes por WebSocket

    public ChatService(ChatRoomRepository salas, MensajeRepository mensajes,
                       PropuestaRepository propuestas, SimpMessagingTemplate ws) {
        this.salas = salas;
        this.mensajes = mensajes;
        this.propuestas = propuestas;
        this.ws = ws;
    }

    // ── Creación (al asignar el trabajo) ──────────────────────
    @Transactional
    public ChatRoom crearParaTrabajo(Trabajo t) {
        return salas.findByTrabajoId(t.getId()).orElseGet(() -> {
            ChatRoom sala = ChatRoom.builder()
                    .trabajoId(t.getId())
                    .tituloTrabajo(t.getTitulo())
                    .empleadorId(t.getEmpleadorId())
                    .empleadorNombre(t.getAutorNombre())
                    .trabajadorId(t.getTrabajadorAsignadoId())
                    .trabajadorNombre(t.getTrabajadorAsignadoNombre())
                    .ultimoMensaje("Chat iniciado. ¡Acuerden el pago y el tiempo!")
                    .fechaUltimoMensaje(Instant.now())
                    .build();
            return salas.save(sala);
        });
    }

    // ── Lectura ───────────────────────────────────────────────
    public ChatRoom porId(UUID chatId, UUID solicitante) {
        ChatRoom sala = salas.findById(chatId)
                .orElseThrow(() -> ApiException.noEncontrado("El chat no existe"));
        if (!sala.esParticipante(solicitante)) {
            throw ApiException.prohibido("No participas en este chat");
        }
        return sala;
    }

    public List<ChatRoom> misChats(UUID uid) {
        return salas.findByEmpleadorIdOrTrabajadorIdOrderByFechaUltimoMensajeDesc(uid, uid);
    }

    public List<Mensaje> mensajes(UUID chatId, UUID solicitante) {
        porId(chatId, solicitante); // valida participación
        return mensajes.findByChatIdOrderByCreadoEnAsc(chatId);
    }

    // ── Envío de mensajes ─────────────────────────────────────
    @Transactional
    public Mensaje enviar(UUID chatId, UUID deUid, String contenido, TipoMensaje tipo) {
        ChatRoom sala = porId(chatId, deUid);
        Mensaje m = mensajes.save(Mensaje.builder()
                .chatId(chatId).deUid(deUid)
                .tipo(tipo == null ? TipoMensaje.TEXTO : tipo)
                .contenido(contenido).build());
        sala.setUltimoMensaje(contenido);
        sala.setFechaUltimoMensaje(m.getCreadoEn());
        salas.save(sala);
        // Empuja el mensaje a los suscriptores del chat por WebSocket.
        ws.convertAndSend("/topic/chats/" + chatId, m);
        return m;
    }

    @Transactional
    public void marcarLeido(UUID chatId, UUID uid) {
        for (Mensaje m : mensajes.findByChatIdOrderByCreadoEnAsc(chatId)) {
            if (!m.getDeUid().equals(uid) && !m.isLeido()) {
                m.setLeido(true);
                mensajes.save(m);
            }
        }
    }

    // ── Negociación ───────────────────────────────────────────
    /** Propone un pago por hora. La primera propuesta debe hacerla el trabajador. */
    @Transactional
    public ChatRoom proponerPago(UUID chatId, UUID deUid, BigDecimal monto) {
        ChatRoom sala = porId(chatId, deUid);
        if (sala.getPagoPropuestoPor() == null && !deUid.equals(sala.getTrabajadorId())) {
            throw ApiException.solicitudInvalida("La primera propuesta la hace el trabajador");
        }
        sala.setPagoMonto(monto);
        sala.setPagoPropuestoPor(deUid);
        sala.setPagoAcordado(false);
        salas.save(sala);
        propuestas.save(Propuesta.builder().chatId(chatId).creadaPor(deUid).precio(monto).build());
        enviar(chatId, deUid, "Propuesta de pago: L. " + monto + " / hora",
                TipoMensaje.PROPUESTA_PAGO);
        return sala;
    }

    /** La otra parte acepta el pago propuesto. */
    @Transactional
    public ChatRoom aceptarPago(UUID chatId, UUID deUid) {
        ChatRoom sala = porId(chatId, deUid);
        if (sala.getPagoPropuestoPor() == null || sala.getPagoPropuestoPor().equals(deUid)) {
            throw ApiException.solicitudInvalida("No hay una propuesta de pago de la otra parte");
        }
        sala.setPagoAcordado(true);
        salas.save(sala);
        enviar(chatId, deUid, "Pago acordado: L. " + sala.getPagoMonto() + " / hora",
                TipoMensaje.SISTEMA);
        return sala;
    }

    /** Propone un plazo/tiempo. */
    @Transactional
    public ChatRoom proponerTiempo(UUID chatId, UUID deUid, String tiempo) {
        ChatRoom sala = porId(chatId, deUid);
        sala.setTiempoValor(tiempo);
        sala.setTiempoPropuestoPor(deUid);
        sala.setTiempoAcordado(false);
        salas.save(sala);
        propuestas.save(Propuesta.builder().chatId(chatId).creadaPor(deUid).tiempo(tiempo).build());
        enviar(chatId, deUid, "Propuesta de tiempo: " + tiempo, TipoMensaje.PROPUESTA_TIEMPO);
        return sala;
    }

    /** La otra parte acepta el tiempo propuesto. */
    @Transactional
    public ChatRoom aceptarTiempo(UUID chatId, UUID deUid) {
        ChatRoom sala = porId(chatId, deUid);
        if (sala.getTiempoPropuestoPor() == null || sala.getTiempoPropuestoPor().equals(deUid)) {
            throw ApiException.solicitudInvalida("No hay una propuesta de tiempo de la otra parte");
        }
        sala.setTiempoAcordado(true);
        salas.save(sala);
        enviar(chatId, deUid, "Tiempo acordado: " + sala.getTiempoValor(), TipoMensaje.SISTEMA);
        return sala;
    }
}
