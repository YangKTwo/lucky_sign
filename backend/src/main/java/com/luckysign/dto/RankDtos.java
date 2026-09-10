package com.luckysign.dto;

import java.util.List;

public class RankDtos {
    public record MemberStatus(
            Long userId,
            String nickname,
            String avatarUrl,
            String title,
            Integer points,
            Double peerAvgScore,
            Integer compositeScore,
            Integer streakDays,
            String tag,
            String todayStatus,
            boolean luckyStar
    ) {
    }

    public record RankingResponse(
            List<MemberStatus> byComposite,
            List<MemberStatus> byPoints,
            List<MemberStatus> byStreak,
            LuckyStarInfo luckyStar
    ) {
    }

    public record LuckyStarInfo(Long userId, String nickname) {
    }
}
