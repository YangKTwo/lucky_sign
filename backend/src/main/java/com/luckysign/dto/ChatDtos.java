package com.luckysign.dto;

import com.luckysign.domain.ChatMessageType;

import java.time.Instant;
import java.util.List;

public class ChatDtos {
    public record MessageView(
            Long id,
            Long userId,
            String nickname,
            String avatarUrl,
            ChatMessageType type,
            String content,
            String imageUrl,
            Long checkinId,
            Instant createdAt,
            Double avgScore,
            Integer ratingCount,
            Integer myScore
    ) {
    }

    public record HistoryResponse(List<MessageView> messages) {
    }

    public record SendTextRequest(String content) {
    }
}
