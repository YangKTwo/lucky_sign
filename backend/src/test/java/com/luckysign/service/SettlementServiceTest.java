package com.luckysign.service;

import com.luckysign.domain.DrawStatus;
import com.luckysign.domain.FortuneLevel;
import com.luckysign.domain.PointChangeType;
import com.luckysign.domain.UserTag;
import com.luckysign.entity.DailyDraw;
import com.luckysign.entity.User;
import com.luckysign.repository.CircleMemberRepository;
import com.luckysign.repository.DailyDrawRepository;
import com.luckysign.repository.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class SettlementServiceTest {
    @Mock
    private DailyDrawRepository dailyDrawRepository;
    @Mock
    private UserRepository userRepository;
    @Mock
    private CircleMemberRepository circleMemberRepository;
    @Mock
    private PointsService pointsService;
    @Mock
    private DrawService drawService;
    @Mock
    private TitleService titleService;
    @Mock
    private MailNotifyService mailNotifyService;
    @Mock
    private ChatService chatService;

    private SettlementService service;

    @BeforeEach
    void setUp() {
        service = new SettlementService(
                dailyDrawRepository, userRepository, circleMemberRepository,
                pointsService, drawService, titleService, mailNotifyService, chatService, null);
    }

    @Test
    void settleOneSkipsCompletedAndExpired() {
        DailyDraw completed = draw(1L, 11L, DrawStatus.COMPLETED);
        DailyDraw expired = draw(2L, 12L, DrawStatus.EXPIRED);
        when(dailyDrawRepository.findById(1L)).thenReturn(Optional.of(completed));
        when(dailyDrawRepository.findById(2L)).thenReturn(Optional.of(expired));

        service.settleOne(1L);
        service.settleOne(2L);

        verify(pointsService, never()).apply(any(), anyInt(), any(), any());
        verify(userRepository, never()).save(any());
        verify(dailyDrawRepository, never()).save(any());
    }

    @Test
    void settleOnePenalizesPending() {
        LocalDate yesterday = LocalDate.of(2026, 10, 4);
        DailyDraw pending = draw(3L, 21L, DrawStatus.VIEWED);
        pending.setDrawDate(yesterday);
        User user = user(21L);
        when(dailyDrawRepository.findById(3L)).thenReturn(Optional.of(pending));
        when(userRepository.findById(21L)).thenReturn(Optional.of(user));
        when(drawService.rewardPoints(pending)).thenReturn(10);
        when(titleService.resolve(anyInt())).thenReturn("签到萌新");

        service.settleOne(3L);

        verify(pointsService).apply(user, -5, PointChangeType.PENALTY, 3L);
        verify(userRepository).save(user);
        verify(dailyDrawRepository).save(pending);
        org.junit.jupiter.api.Assertions.assertEquals(DrawStatus.EXPIRED, pending.getStatus());
        org.junit.jupiter.api.Assertions.assertEquals(0, user.getStreakDays());
        org.junit.jupiter.api.Assertions.assertEquals(1, user.getMissStreakDays());
    }

    @Test
    void settleYesterdayContinuesAfterOneFailure() {
        LocalDate today = LocalDate.of(2026, 10, 5);
        DailyDraw boom = draw(1L, 1L, DrawStatus.PENDING);
        DailyDraw ok = draw(2L, 2L, DrawStatus.PENDING);
        User user = user(2L);
        when(drawService.today()).thenReturn(today);
        when(dailyDrawRepository.findByDrawDate(today.minusDays(1))).thenReturn(List.of(boom, ok));
        when(dailyDrawRepository.findById(1L)).thenThrow(new RuntimeException("boom"));
        when(dailyDrawRepository.findById(2L)).thenReturn(Optional.of(ok));
        when(userRepository.findById(2L)).thenReturn(Optional.of(user));
        when(drawService.rewardPoints(ok)).thenReturn(8);
        when(titleService.resolve(anyInt())).thenReturn("签到萌新");

        service.settleYesterday();

        verify(dailyDrawRepository).save(ok);
        verify(pointsService).apply(eq(user), eq(-4), eq(PointChangeType.PENALTY), eq(2L));
    }

    private static DailyDraw draw(Long id, Long userId, DrawStatus status) {
        DailyDraw draw = new DailyDraw();
        draw.setId(id);
        draw.setUserId(userId);
        draw.setDrawDate(LocalDate.of(2026, 10, 4));
        draw.setLevel(FortuneLevel.B);
        draw.setFortuneText("签");
        draw.setTaskId(1L);
        draw.setTaskContent("任务");
        draw.setBasePoints(8);
        draw.setLuckyStar(false);
        draw.setStatus(status);
        return draw;
    }

    private static User user(Long id) {
        User user = new User();
        user.setId(id);
        user.setEmail("u" + id + "@test.com");
        user.setNickname("用户" + id);
        user.setTag(UserTag.NONE);
        user.setPoints(20);
        user.setStreakDays(4);
        user.setMissStreakDays(0);
        user.setTotalCompletedDays(4);
        user.setTitle("签到萌新");
        return user;
    }
}
