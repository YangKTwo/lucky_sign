package com.luckysign.controller;

import com.luckysign.dto.ChatDtos;
import com.luckysign.security.CircleAccessGuard;
import com.luckysign.security.UserPrincipal;
import com.luckysign.service.ChatService;
import org.springframework.messaging.handler.annotation.MessageMapping;
import org.springframework.messaging.handler.annotation.Payload;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.stereotype.Controller;

import java.security.Principal;

@Controller
public class ChatWsController {
    private final ChatService chatService;
    private final CircleAccessGuard circleAccessGuard;

    public ChatWsController(ChatService chatService, CircleAccessGuard circleAccessGuard) {
        this.chatService = chatService;
        this.circleAccessGuard = circleAccessGuard;
    }

    @MessageMapping("/chat.send")
    public void send(@Payload ChatDtos.SendTextRequest request, Principal principal) {
        Long userId = resolveUserId(principal);
        if (userId == null) {
            throw new IllegalStateException("Unauthorized");
        }
        circleAccessGuard.requireMember(userId);
        chatService.sendText(userId, request.content());
    }

    private Long resolveUserId(Principal principal) {
        if (principal instanceof UserPrincipal up) {
            return up.getUserId();
        }
        if (principal instanceof UsernamePasswordAuthenticationToken token
                && token.getPrincipal() instanceof Long id) {
            return id;
        }
        if (principal != null && principal.getName() != null) {
            try {
                return Long.valueOf(principal.getName());
            } catch (NumberFormatException ignored) {
                return null;
            }
        }
        return null;
    }
}
