package com.luckysign.service;

import com.luckysign.config.IsolatedTx;
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
import java.util.concurrent.atomic.AtomicInteger;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
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

    private IsolatedTx isolatedTx;
    private SettlementService settlementService;

    @BeforeEach
    void setUp() {
        isolatedTx = new IsolatedTx();
        settlementService = new SettlementService(
                dailyDrawRepository, userRepository, circleMemberRepository,
                pointsService, drawService, titleService, mailNotifyService, chatService,
                isolatedTx);
    }

    @Test
    void skipsCompletedAndExpiredSoRerunDoesNotDoublePenalize() {
        LocalDate yesterday = LocalDate.of(2026, 10, 18);
        DailyDraw expired = draw(1L, 1L, yesterday, DrawStatus.EXPIRED);
        DailyDraw completed = draw(2L, 2L, yesterday, DrawStatus.COMPLETED);

        when(drawService.today()).thenReturn(yesterday.plusDays(1));
        when(dailyDrawRepository.findByDrawDate(yesterday)).thenReturn(List.of(expired, completed));

        settlementService.settleYesterday();

        verify(pointsService, never()).apply(any(), any(Integer.class), any(), any());
        verify(userRepository, never()).save(any());
        verify(dailyDrawRepository, never()).findById(anyLong());
    }

    @Test
    void pendingDrawIsExpiredAndPenalizedOnce() {
        LocalDate yesterday = LocalDate.of(2026, 10, 18);
        DailyDraw pending = draw(11L, 7L, yesterday, DrawStatus.PENDING);
        User user = user(7L, 80, 4, 0);

        when(drawService.today()).thenReturn(yesterday.plusDays(1));
        when(dailyDrawRepository.findByDrawDate(yesterday)).thenReturn(List.of(pending));
        when(dailyDrawRepository.findById(11L)).thenReturn(Optional.of(pending));
        when(userRepository.findById(7L)).thenReturn(Optional.of(user));
        when(drawService.rewardPoints(pending)).thenReturn(10);
        when(titleService.resolve(10)).thenReturn("每日行者");

        settlementService.settleYesterday();

        verify(pointsService).apply(user, -5, PointChangeType.PENALTY, 11L);
        verify(userRepository).save(user);
        verify(dailyDrawRepository).save(pending);
        assertEquals(DrawStatus.EXPIRED, pending.getStatus());
        assertEquals(0, user.getStreakDays());
        assertEquals(1, user.getMissStreakDays());
    }

    @Test
    void oneFailureDoesNotBlockOtherDraws() {
        IsolatedTx failingSecond = new IsolatedTx() {
            final AtomicInteger n = new AtomicInteger();

            @Override
            public void run(Runnable work) {
                if (n.incrementAndGet() == 1) {
                    throw new RuntimeException("boom");
                }
                work.run();
            }
        };
        settlementService = new SettlementService(
                dailyDrawRepository, userRepository, circleMemberRepository,
                pointsService, drawService, titleService, mailNotifyService, chatService,
                failingSecond);

        LocalDate yesterday = LocalDate.of(2026, 10, 18);
        DailyDraw first = draw(1L, 1L, yesterday, DrawStatus.PENDING);
        DailyDraw second = draw(2L, 2L, yesterday, DrawStatus.VIEWED);
        User user2 = user(2L, 40, 2, 0);

        when(drawService.today()).thenReturn(yesterday.plusDays(1));
        when(dailyDrawRepository.findByDrawDate(yesterday)).thenReturn(List.of(first, second));
        when(dailyDrawRepository.findById(2L)).thenReturn(Optional.of(second));
        when(userRepository.findById(2L)).thenReturn(Optional.of(user2));
        when(drawService.rewardPoints(second)).thenReturn(8);
        when(titleService.resolve(10)).thenReturn("每日行者");

        settlementService.settleYesterday();

        verify(dailyDrawRepository, never()).findById(1L);
        verify(dailyDrawRepository, times(1)).findById(2L);
        verify(pointsService).apply(eq(user2), eq(-4), eq(PointChangeType.PENALTY), eq(2L));
        assertEquals(DrawStatus.EXPIRED, second.getStatus());
    }

    private static DailyDraw draw(Long id, Long userId, LocalDate date, DrawStatus status) {
        DailyDraw d = new DailyDraw();
        d.setId(id);
        d.setUserId(userId);
        d.setDrawDate(date);
        d.setLevel(FortuneLevel.B);
        d.setFortuneText("签");
        d.setTaskId(1L);
        d.setTaskContent("任务");
        d.setBasePoints(8);
        d.setLuckyStar(false);
        d.setStatus(status);
        return d;
    }

    private static User user(Long id, int points, int streak, int miss) {
        User u = new User();
        u.setId(id);
        u.setEmail("u" + id + "@t.local");
        u.setNickname("用户" + id);
        u.setTag(UserTag.NONE);
        u.setPoints(points);
        u.setStreakDays(streak);
        u.setMissStreakDays(miss);
        u.setTotalCompletedDays(10);
        u.setTitle("每日行者");
        return u;
    }
}
