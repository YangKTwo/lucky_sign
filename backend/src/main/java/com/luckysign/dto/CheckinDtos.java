package com.luckysign.dto;

import com.luckysign.domain.DrawStatus;
import com.luckysign.domain.FortuneLevel;

import java.time.LocalDate;
import java.util.List;

public class CheckinDtos {
    public record TodayResponse(
            LocalDate date,
            FortuneLevel level,
            String levelName,
            String fortuneText,
            String taskContent,
            Integer basePoints,
            Integer rewardPoints,
            boolean luckyStar,
            DrawStatus status,
            Integer points,
            String title,
            Integer streakDays,
            String tag
    ) {
    }

    public record HistoryItem(
            LocalDate date,
            FortuneLevel level,
            String taskContent,
            Integer pointsEarned,
            String textContent,
            String imageUrl
    ) {
    }

    public record HistoryResponse(List<HistoryItem> items) {
    }
}
