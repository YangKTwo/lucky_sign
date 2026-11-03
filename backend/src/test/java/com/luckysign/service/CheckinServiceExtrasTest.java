package com.luckysign.service;

import com.luckysign.domain.DrawStatus;
import com.luckysign.domain.FortuneLevel;
import com.luckysign.domain.UserTag;
import com.luckysign.entity.CheckinRecord;
import com.luckysign.entity.DailyDraw;
import com.luckysign.entity.User;
import com.luckysign.repository.CheckinRecordRepository;
import com.luckysign.repository.DailyDrawRepository;
import com.luckysign.repository.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.Instant;
import java.time.LocalDate;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class CheckinServiceExtrasTest {
    @Mock private UserRepository userRepository;
    @Mock private DailyDrawRepository dailyDrawRepository;
    @Mock private CheckinRecordRepository checkinRecordRepository;
    @Mock private PointsService pointsService;
    @Mock private DrawService drawService;
    @Mock private TitleService titleService;
    @Mock private ChatService chatService;
    @Mock private FileStorageService fileStorageService;
    @Mock private RatingService ratingService;

    private CheckinService checkinService;

    @BeforeEach
    void setUp() {
        checkinService = new CheckinService(
                userRepository, dailyDrawRepository, checkinRecordRepository,
                pointsService, drawService, titleService, chatService,
                fileStorageService, ratingService);
    }

    @Test
    void completeIncludesCompletionTimeAndWeekBonus() {
        LocalDate today = LocalDate.of(2026, 11, 3);
        User user = new User();
        user.setId(1L);
        user.setTag(UserTag.NONE);
        user.setPoints(20);
        user.setStreakDays(6);
        user.setTotalCompletedDays(12);
        user.setLastCheckinDate(today.minusDays(1));
        user.setTitle("每日行者");
        DailyDraw draw = new DailyDraw();
        draw.setId(8L);
        draw.setUserId(1L);
        draw.setDrawDate(today);
        draw.setLevel(FortuneLevel.A);
        draw.setFortuneText("好运");
        draw.setTaskId(1L);
        draw.setTaskContent("散步");
        draw.setBasePoints(10);
        draw.setLuckyStar(false);
        draw.setStatus(DrawStatus.VIEWED);

        when(drawService.today()).thenReturn(today);
        when(userRepository.findById(1L)).thenReturn(Optional.of(user));
        when(drawService.ensureDraw(5L, 1L, today)).thenReturn(draw);
        when(drawService.rewardPoints(draw)).thenReturn(10);
        when(titleService.resolve(anyInt())).thenReturn("每日行者");
        when(checkinRecordRepository.save(any(CheckinRecord.class))).thenAnswer(inv -> {
            CheckinRecord r = inv.getArgument(0);
            r.setId(99L);
            r.setCreatedAt(Instant.parse("2026-11-03T06:32:00Z"));
            return r;
        });

        var response = checkinService.complete(5L, 1L, "走完了", null);

        assertEquals(10, response.streakBonusPoints());
        assertNotNull(response.completedAt());
        assertEquals("2026-11-03T14:32:00+08:00", response.completedAt());
        assertEquals(7, response.streakDays());
    }

    @Test
    void streakDaysReadsProfileWithoutOpeningToday() {
        User user = new User();
        user.setId(2L);
        user.setStreakDays(4);
        when(userRepository.findById(2L)).thenReturn(Optional.of(user));
        assertEquals(4, checkinService.streakDays(2L));
    }

    @Test
    void streakBonusRules() {
        assertEquals(0, CheckinService.streakBonusOf(6, DrawStatus.COMPLETED));
        assertEquals(10, CheckinService.streakBonusOf(7, DrawStatus.COMPLETED));
        assertEquals(50, CheckinService.streakBonusOf(30, DrawStatus.COMPLETED));
        assertEquals(0, CheckinService.streakBonusOf(7, DrawStatus.VIEWED));
    }
}
