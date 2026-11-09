package com.luckysign.service;

import com.luckysign.common.IsolatedTx;
import com.luckysign.domain.DrawStatus;
import com.luckysign.domain.FortuneLevel;
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
import org.mockito.junit.jupiter.MockitoSettings;
import org.mockito.quality.Strictness;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;
import java.util.concurrent.atomic.AtomicInteger;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
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
    @Mock
    private IsolatedTx isolatedTx;

    private SettlementService settlementService;

    @BeforeEach
    void setUp() {
        settlementService = new SettlementService(
                dailyDrawRepository, userRepository, circleMemberRepository, pointsService,
                drawService, titleService, mailNotifyService, chatService, isolatedTx);
        doAnswer(inv -> {
            inv.getArgument(0, Runnable.class).run();
            return null;
        }).when(isolatedTx).run(any());
    }

    @Test
    void skipsCompletedAndExpired() {
        LocalDate today = LocalDate.of(2026, 11, 9);
        when(drawService.today()).thenReturn(today);
        DailyDraw done = draw(1L, 11L, today.minusDays(1), DrawStatus.COMPLETED);
        DailyDraw expired = draw(2L, 12L, today.minusDays(1), DrawStatus.EXPIRED);
        when(dailyDrawRepository.findByDrawDate(today.minusDays(1))).thenReturn(List.of(done, expired));

        settlementService.settleYesterday();

        verify(isolatedTx, never()).run(any());
        verify(dailyDrawRepository, never()).findById(any());
        verify(pointsService, never()).apply(any(), anyInt(), any(), any());
        verify(userRepository, never()).save(any());
    }

    @Test
    void expiresPendingMissAndResetsStreak() {
        LocalDate today = LocalDate.of(2026, 11, 9);
        LocalDate yesterday = today.minusDays(1);
        when(drawService.today()).thenReturn(today);
        DailyDraw pending = draw(3L, 13L, yesterday, DrawStatus.VIEWED);
        when(dailyDrawRepository.findByDrawDate(yesterday)).thenReturn(List.of(pending));
        when(dailyDrawRepository.findById(3L)).thenReturn(Optional.of(pending));
        User user = user(13L, 2);
        when(userRepository.findById(13L)).thenReturn(Optional.of(user));
        when(drawService.rewardPoints(pending)).thenReturn(10);
        when(titleService.resolve(anyInt())).thenReturn("签到萌新");

        settlementService.settleYesterday();

        verify(pointsService).apply(user, -5, com.luckysign.domain.PointChangeType.PENALTY, 3L);
        verify(userRepository).save(argThat(u -> u.getStreakDays() == 0 && u.getMissStreakDays() == 3));
        verify(dailyDrawRepository).save(argThat(d -> d.getStatus() == DrawStatus.EXPIRED));
    }

    @Test
    void continuesWhenOneUserFails() {
        LocalDate today = LocalDate.of(2026, 11, 9);
        LocalDate yesterday = today.minusDays(1);
        when(drawService.today()).thenReturn(today);
        DailyDraw first = draw(4L, 14L, yesterday, DrawStatus.PENDING);
        DailyDraw second = draw(5L, 15L, yesterday, DrawStatus.PENDING);
        when(dailyDrawRepository.findByDrawDate(yesterday)).thenReturn(List.of(first, second));
        AtomicInteger calls = new AtomicInteger();
        doAnswer(inv -> {
            if (calls.getAndIncrement() == 0) {
                throw new RuntimeException("boom");
            }
            inv.getArgument(0, Runnable.class).run();
            return null;
        }).when(isolatedTx).run(any());
        when(dailyDrawRepository.findById(5L)).thenReturn(Optional.of(second));
        User user = user(15L, 0);
        when(userRepository.findById(15L)).thenReturn(Optional.of(user));
        when(drawService.rewardPoints(second)).thenReturn(8);
        when(titleService.resolve(anyInt())).thenReturn("签到萌新");

        settlementService.settleYesterday();

        verify(dailyDrawRepository).findById(5L);
        verify(userRepository).save(any(User.class));
    }

    private static DailyDraw draw(Long id, Long userId, LocalDate date, DrawStatus status) {
        DailyDraw d = new DailyDraw();
        d.setId(id);
        d.setUserId(userId);
        d.setDrawDate(date);
        d.setLevel(FortuneLevel.B);
        d.setFortuneText("x");
        d.setTaskId(1L);
        d.setTaskContent("task");
        d.setBasePoints(8);
        d.setLuckyStar(false);
        d.setStatus(status);
        return d;
    }

    private static User user(Long id, int missStreak) {
        User u = new User();
        u.setId(id);
        u.setEmail("u" + id + "@t.local");
        u.setNickname("u" + id);
        u.setTag(UserTag.NONE);
        u.setPoints(20);
        u.setStreakDays(4);
        u.setMissStreakDays(missStreak);
        u.setTotalCompletedDays(4);
        u.setTitle("签到萌新");
        return u;
    }
}
