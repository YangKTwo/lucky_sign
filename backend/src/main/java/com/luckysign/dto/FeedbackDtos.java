package com.luckysign.dto;

import java.time.Instant;
import java.util.List;

public class FeedbackDtos {
    public record SubmitRequest(String content) {
    }

    public record FeedbackView(
            Long id,
            Long userId,
            String nickname,
            String content,
            Instant createdAt
    ) {
    }

    public record ListResponse(List<FeedbackView> items) {
    }
}
