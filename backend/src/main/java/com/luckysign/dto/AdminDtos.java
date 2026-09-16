package com.luckysign.dto;

import java.time.Instant;
import java.util.List;

public class AdminDtos {
    public record PendingRegistration(
            Long id,
            String nickname,
            String email,
            Instant createdAt,
            Long pendingCircleId
    ) {
    }

    public record PendingListResponse(List<PendingRegistration> users) {
    }
}
