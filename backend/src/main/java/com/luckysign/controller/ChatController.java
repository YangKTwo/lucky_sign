package com.luckysign.controller;

import com.luckysign.common.ApiResponse;
import com.luckysign.dto.ChatDtos;
import com.luckysign.security.AuthSupport;
import com.luckysign.service.ChatService;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/chat")
public class ChatController {
    private final ChatService chatService;

    public ChatController(ChatService chatService) {
        this.chatService = chatService;
    }

    @GetMapping("/messages")
    public ApiResponse<ChatDtos.HistoryResponse> history(
            @RequestParam(required = false) Long beforeId,
            @RequestParam(defaultValue = "30") int size) {
        return ApiResponse.ok(chatService.history(AuthSupport.currentUserId(), beforeId, size));
    }

    @PostMapping("/messages")
    public ApiResponse<ChatDtos.MessageView> send(@RequestBody ChatDtos.SendTextRequest request) {
        return ApiResponse.ok(chatService.sendText(AuthSupport.currentUserId(), request.content()));
    }
}
