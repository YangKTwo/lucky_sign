package com.luckysign.dto;

import com.luckysign.domain.DrawStatus;
import com.luckysign.domain.FortuneLevel;

import java.time.Instant;
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
            Integer totalCompletedDays,
            String nextTitle,
            Integer daysToNextTitle,
            Integer nextTitleAt,
            String tag,
            String imageUrl,
            String textContent,
            Instant checkedInAt,
            Integer weekCompletedDays,
            Integer circleMemberCount,
            Integer circleCompletedCount,
            List<String> circleDoneNicknames,
            List<String> weekStatuses
    ) {
    }

    public record HistoryItem(
            LocalDate date,
            FortuneLevel level,
            String taskContent,
            Integer pointsEarned,
            String textContent,
            String imageUrl,
            Double avgScore,
            Integer ratingCount
    ) {
    }

    public record HistoryResponse(List<HistoryItem> items) {
    }

    public record CalendarDay(LocalDate date, String status) {
    }

    public record CalendarResponse(List<CalendarDay> days) {
    }
}
