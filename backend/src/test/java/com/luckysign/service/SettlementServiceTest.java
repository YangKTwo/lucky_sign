package com.luckysign.service;

import com.luckysign.common.IsolatedTx;
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
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class SettlementServiceTest {
    @Mock private DailyDrawRepository dailyDrawRepository;
    @Mock private UserRepository userRepository;
    @Mock private CircleMemberRepository circleMemberRepository;
    @Mock private PointsService pointsService;
    @Mock private DrawService drawService;
    @Mock private TitleService titleService;
    @Mock private MailNotifyService mailNotifyService;
    @Mock private ChatService chatService;
    @Mock private IsolatedTx isolatedTx;

    private SettlementService service;

    @BeforeEach
    void setUp() {
        service = new SettlementService(
                dailyDrawRepository, userRepository, circleMemberRepository,
                pointsService, drawService, titleService, mailNotifyService,
                chatService, isolatedTx);
        lenient().doAnswer(inv -> {
            inv.getArgument(0, Runnable.class).run();
            return null;
        }).when(isolatedTx).run(any());
    }

    @Test
    void skipsCompletedAndExpiredAndSettlesPendingOnce() {
        LocalDate today = LocalDate.of(2026, 11, 3);
        LocalDate yesterday = today.minusDays(1);
        DailyDraw completed = draw(1L, 11L, yesterday, DrawStatus.COMPLETED);
        DailyDraw expired = draw(2L, 12L, yesterday, DrawStatus.EXPIRED);
        DailyDraw pending = draw(3L, 13L, yesterday, DrawStatus.PENDING);
        User user = user(13L, UserTag.NONE, 1);

        when(drawService.today()).thenReturn(today);
        when(dailyDrawRepository.findByDrawDate(yesterday)).thenReturn(List.of(completed, expired, pending));
        when(dailyDrawRepository.findById(1L)).thenReturn(Optional.of(completed));
        when(dailyDrawRepository.findById(2L)).thenReturn(Optional.of(expired));
        when(dailyDrawRepository.findById(3L)).thenReturn(Optional.of(pending));
        when(userRepository.findById(13L)).thenReturn(Optional.of(user));
        when(drawService.rewardPoints(pending)).thenReturn(10);
        when(titleService.resolve(10)).thenReturn("签到达人");

        service.settleYesterday();

        verify(pointsService).apply(user, -5, PointChangeType.PENALTY, 3L);
        verify(pointsService, times(1)).apply(any(), anyInt(), any(), any());
        verify(dailyDrawRepository).save(argThat(d -> d.getId() == 3L && d.getStatus() == DrawStatus.EXPIRED));
        verify(dailyDrawRepository, never()).save(argThat(d -> d.getId() == 1L || d.getId() == 2L));
        assertEquals(0, user.getStreakDays());
        assertEquals(2, user.getMissStreakDays());
    }

    @Test
    void oneFailureDoesNotBlockRemainingDraws() {
        LocalDate today = LocalDate.of(2026, 11, 3);
        LocalDate yesterday = today.minusDays(1);
        DailyDraw boom = draw(1L, 11L, yesterday, DrawStatus.PENDING);
        DailyDraw pending = draw(2L, 12L, yesterday, DrawStatus.PENDING);
        User user = user(12L, UserTag.NONE, 0);

        AtomicInteger calls = new AtomicInteger();
        doAnswer(inv -> {
            Runnable work = inv.getArgument(0, Runnable.class);
            if (calls.getAndIncrement() == 0) {
                throw new RuntimeException("isolated failure");
            }
            work.run();
            return null;
        }).when(isolatedTx).run(any());

        when(drawService.today()).thenReturn(today);
        when(dailyDrawRepository.findByDrawDate(yesterday)).thenReturn(List.of(boom, pending));
        when(dailyDrawRepository.findById(2L)).thenReturn(Optional.of(pending));
        when(userRepository.findById(12L)).thenReturn(Optional.of(user));
        when(drawService.rewardPoints(pending)).thenReturn(8);
        when(titleService.resolve(anyInt())).thenReturn("签到萌新");

        service.settleYesterday();

        verify(pointsService).apply(user, -4, PointChangeType.PENALTY, 2L);
        verify(dailyDrawRepository).save(argThat(d -> d.getId() == 2L && d.getStatus() == DrawStatus.EXPIRED));
    }

    private static DailyDraw draw(Long id, Long userId, LocalDate date, DrawStatus status) {
        DailyDraw draw = new DailyDraw();
        draw.setId(id);
        draw.setUserId(userId);
        draw.setDrawDate(date);
        draw.setLevel(FortuneLevel.B);
        draw.setTaskContent("任务");
        draw.setBasePoints(8);
        draw.setLuckyStar(false);
        draw.setStatus(status);
        return draw;
    }

    private static User user(Long id, UserTag tag, int missStreak) {
        User user = new User();
        user.setId(id);
        user.setEmail("u" + id + "@test.com");
        user.setNickname("用户" + id);
        user.setTag(tag);
        user.setPoints(40);
        user.setStreakDays(4);
        user.setMissStreakDays(missStreak);
        user.setTotalCompletedDays(10);
        user.setTitle("签到萌新");
        return user;
    }
}
