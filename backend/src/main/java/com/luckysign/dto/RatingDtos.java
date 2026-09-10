package com.luckysign.dto;

public class RatingDtos {
    public record RateRequest(Integer score) {
    }

    public record RatingSummary(
            Long checkinId,
            Double avgScore,
            Integer ratingCount,
            Integer myScore
    ) {
    }
}
