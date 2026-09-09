package com.luckysign.dto;

import java.util.List;

public class RankDtos {
    public record MemberStatus(
            Long userId,
            String nickname,
            String title,
            Integer points,
            Integer streakDays,
            String tag,
            String todayStatus,
            boolean luckyStar
    ) {
    }

    public record RankingResponse(
            List<MemberStatus> byPoints,
            List<MemberStatus> byStreak,
            LuckyStarInfo luckyStar
    ) {
    }

    public record LuckyStarInfo(Long userId, String nickname) {
    }
}
