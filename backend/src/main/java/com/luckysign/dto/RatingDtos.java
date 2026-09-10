package com.luckysign.dto;

public class RatingDtos {
    public record RateRequest(Integer score) {
    }

    public record RatingSummary(
            Long checkinId,
            Double avgScore,
            Integer ratingCount,
            Integer expectedRaterCount,
            boolean ratingComplete,
            Integer myScore
    ) {
    }

    public record CheckinDetail(
            Long checkinId,
            Long userId,
            String nickname,
            String avatarUrl,
            String taskContent,
            String textContent,
            String imageUrl,
            Integer pointsEarned,
            String level,
            String checkinDate,
            RatingSummary rating
    ) {
    }
}
