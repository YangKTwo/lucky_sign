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
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.TransactionDefinition;
import org.springframework.transaction.TransactionStatus;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

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
    @Mock
    private PlatformTransactionManager transactionManager;
    @Mock
    private TransactionStatus transactionStatus;

    private SettlementService settlementService;

    @BeforeEach
    void setUp() {
        lenient().when(transactionManager.getTransaction(any(TransactionDefinition.class))).thenReturn(transactionStatus);
        settlementService = new SettlementService(
                dailyDrawRepository, userRepository, circleMemberRepository,
                pointsService, drawService, titleService, mailNotifyService,
                chatService, transactionManager);
    }

    @Test
    void settleYesterdaySkipsCompletedAndExpired() {
        LocalDate yesterday = LocalDate.of(2026, 9, 27);
        when(drawService.today()).thenReturn(yesterday.plusDays(1));

        DailyDraw completed = draw(1L, 11L, yesterday, DrawStatus.COMPLETED);
        DailyDraw expired = draw(2L, 12L, yesterday, DrawStatus.EXPIRED);
        when(dailyDrawRepository.findByDrawDate(yesterday)).thenReturn(List.of(completed, expired));

        settlementService.settleYesterday();

        verify(pointsService, never()).apply(any(), anyInt(), any(), any());
        verify(userRepository, never()).save(any());
        verify(dailyDrawRepository, never()).findById(any());
    }

    @Test
    void settleYesterdayDoesNotRePenalizeAlreadyExpiredOnReload() {
        LocalDate yesterday = LocalDate.of(2026, 9, 27);
        when(drawService.today()).thenReturn(yesterday.plusDays(1));

        DailyDraw pending = draw(3L, 13L, yesterday, DrawStatus.VIEWED);
        DailyDraw alreadyExpired = draw(3L, 13L, yesterday, DrawStatus.EXPIRED);
        when(dailyDrawRepository.findByDrawDate(yesterday)).thenReturn(List.of(pending));
        when(dailyDrawRepository.findById(3L)).thenReturn(Optional.of(alreadyExpired));

        settlementService.settleYesterday();

        verify(pointsService, never()).apply(any(), anyInt(), any(), any());
        verify(userRepository, never()).save(any());
    }

    @Test
    void settleYesterdayIsolatesSingleFailure() {
        LocalDate yesterday = LocalDate.of(2026, 9, 27);
        when(drawService.today()).thenReturn(yesterday.plusDays(1));

        DailyDraw broken = draw(4L, 14L, yesterday, DrawStatus.VIEWED);
        DailyDraw ok = draw(5L, 15L, yesterday, DrawStatus.VIEWED);
        when(dailyDrawRepository.findByDrawDate(yesterday)).thenReturn(List.of(broken, ok));
        when(dailyDrawRepository.findById(4L)).thenThrow(new RuntimeException("db down"));
        when(dailyDrawRepository.findById(5L)).thenReturn(Optional.of(ok));

        User user = user(15L, UserTag.NONE, 1);
        when(userRepository.findById(15L)).thenReturn(Optional.of(user));
        when(drawService.rewardPoints(ok)).thenReturn(10);
        when(titleService.resolve(anyInt())).thenReturn("签到萌新");

        settlementService.settleYesterday();

        verify(pointsService).apply(user, -5, PointChangeType.PENALTY, 5L);
        verify(userRepository).save(user);
        verify(dailyDrawRepository).save(argThat(d -> d.getId().equals(5L) && d.getStatus() == DrawStatus.EXPIRED));
    }

    private static DailyDraw draw(Long id, Long userId, LocalDate date, DrawStatus status) {
        DailyDraw d = new DailyDraw();
        d.setId(id);
        d.setUserId(userId);
        d.setDrawDate(date);
        d.setLevel(FortuneLevel.A);
        d.setStatus(status);
        d.setBasePoints(10);
        d.setLuckyStar(false);
        return d;
    }

    private static User user(Long id, UserTag tag, int missStreak) {
        User u = new User();
        u.setId(id);
        u.setEmail("u" + id + "@test.com");
        u.setNickname("用户" + id);
        u.setTag(tag);
        u.setPoints(20);
        u.setStreakDays(4);
        u.setMissStreakDays(missStreak);
        u.setTotalCompletedDays(8);
        u.setTitle("每日行者");
        return u;
    }
}
