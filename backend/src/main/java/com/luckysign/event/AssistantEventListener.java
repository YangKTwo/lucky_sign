package com.luckysign.event;

import com.luckysign.service.AiAssistantService;
import com.luckysign.service.ChatService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.context.event.EventListener;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Component;

@Component
public class AssistantEventListener {
    private static final Logger log = LoggerFactory.getLogger(AssistantEventListener.class);

    private final AiAssistantService aiAssistantService;
    private final ChatService chatService;

    public AssistantEventListener(AiAssistantService aiAssistantService, ChatService chatService) {
        this.aiAssistantService = aiAssistantService;
        this.chatService = chatService;
    }

    @Async
    @EventListener
    public void onAssistantRequested(AssistantRequestedEvent event) {
        try {
            String reply = aiAssistantService.ask(event.nickname(), event.question());
            chatService.postAssistant(reply);
        } catch (Exception e) {
            log.warn("assistant reply failed: {}", e.getMessage());
            try {
                chatService.postAssistant("（助手暂时忙碌，请稍后再 @助手 试试）");
            } catch (Exception ignored) {
                // ignore
            }
        }
    }
}
