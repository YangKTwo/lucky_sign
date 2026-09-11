package com.luckysign.controller;

import com.luckysign.common.ApiResponse;
import com.luckysign.dto.ChatDtos;
import com.luckysign.security.AuthSupport;
import com.luckysign.security.CircleAccessGuard;
import com.luckysign.service.ChatService;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/chat")
public class ChatController {
    private final ChatService chatService;
    private final CircleAccessGuard circleAccessGuard;

    public ChatController(ChatService chatService, CircleAccessGuard circleAccessGuard) {
        this.chatService = chatService;
        this.circleAccessGuard = circleAccessGuard;
    }

    @GetMapping("/messages")
    public ApiResponse<ChatDtos.HistoryResponse> history(
            @RequestParam(required = false) Long beforeId,
            @RequestParam(defaultValue = "30") int size) {
        Long userId = AuthSupport.currentUserId();
        circleAccessGuard.requireMember(userId);
        return ApiResponse.ok(chatService.history(userId, beforeId, size));
    }

    @PostMapping("/messages")
    public ApiResponse<ChatDtos.MessageView> send(@RequestBody ChatDtos.SendTextRequest request) {
        Long userId = AuthSupport.currentUserId();
        circleAccessGuard.requireMember(userId);
        return ApiResponse.ok(chatService.sendText(userId, request.content()));
    }
}
