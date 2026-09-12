package com.luckysign.controller;

import com.luckysign.dto.ChatDtos;
import com.luckysign.security.CircleAccessGuard;
import com.luckysign.security.UserPrincipal;
import com.luckysign.service.ChatService;
import org.springframework.messaging.handler.annotation.DestinationVariable;
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

    @MessageMapping("/chat.send/{circleId}")
    public void send(@DestinationVariable Long circleId,
                     @Payload ChatDtos.SendTextRequest request,
                     Principal principal) {
        Long userId = resolveUserId(principal);
        if (userId == null) {
            throw new IllegalStateException("Unauthorized");
        }
        circleAccessGuard.requireMember(circleId, userId);
        chatService.sendText(circleId, userId, request.content());
    }

    @MessageMapping("/chat.send")
    public void sendDefault(@Payload ChatDtos.SendTextRequest request, Principal principal) {
        Long userId = resolveUserId(principal);
        if (userId == null) {
            throw new IllegalStateException("Unauthorized");
        }
        Long circleId = circleAccessGuard.getUserCircleId(userId);
        circleAccessGuard.requireMember(circleId, userId);
        chatService.sendText(circleId, userId, request.content());
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
