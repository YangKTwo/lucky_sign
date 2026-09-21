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

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class DrawMissSettlerTest {

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

    private DrawMissSettler settler;

    @BeforeEach
    void setUp() {
        settler = new DrawMissSettler(
                dailyDrawRepository, userRepository, circleMemberRepository,
                pointsService, drawService, titleService, mailNotifyService, chatService);
    }

    @Test
    void skipsAlreadyExpiredDrawToAvoidDoublePenalty() {
        DailyDraw draw = draw(1L, 8L, DrawStatus.EXPIRED);
        when(dailyDrawRepository.findById(1L)).thenReturn(Optional.of(draw));

        settler.settleDraw(1L);

        verify(pointsService, never()).apply(any(), anyInt(), any(), any());
        verify(userRepository, never()).save(any());
        verify(dailyDrawRepository, never()).save(any());
    }

    @Test
    void skipsCompletedDraw() {
        DailyDraw draw = draw(2L, 8L, DrawStatus.COMPLETED);
        when(dailyDrawRepository.findById(2L)).thenReturn(Optional.of(draw));

        settler.settleDraw(2L);

        verify(pointsService, never()).apply(any(), anyInt(), any(), any());
        verify(userRepository, never()).save(any());
    }

    @Test
    void expiresDormantUserWithoutPenalty() {
        DailyDraw draw = draw(3L, 9L, DrawStatus.VIEWED);
        User user = user(9L, UserTag.DORMANT, 0);
        when(dailyDrawRepository.findById(3L)).thenReturn(Optional.of(draw));
        when(userRepository.findById(9L)).thenReturn(Optional.of(user));

        settler.settleDraw(3L);

        verify(pointsService, never()).apply(any(), anyInt(), any(), any());
        verify(dailyDrawRepository).save(org.mockito.ArgumentMatchers.argThat(d -> d.getStatus() == DrawStatus.EXPIRED));
    }

    @Test
    void firstMissResetsStreakAndAppliesHalfPenalty() {
        DailyDraw draw = draw(4L, 10L, DrawStatus.PENDING);
        User user = user(10L, UserTag.NONE, 0);
        user.setStreakDays(5);
        when(dailyDrawRepository.findById(4L)).thenReturn(Optional.of(draw));
        when(userRepository.findById(10L)).thenReturn(Optional.of(user));
        when(drawService.rewardPoints(draw)).thenReturn(10);
        when(titleService.resolve(anyInt())).thenReturn("签到萌新");

        settler.settleDraw(4L);

        verify(pointsService).apply(user, -5, PointChangeType.PENALTY, 4L);
        assertEquals(0, user.getStreakDays());
        assertEquals(1, user.getMissStreakDays());
        assertEquals(UserTag.NONE, user.getTag());
        verify(dailyDrawRepository).save(org.mockito.ArgumentMatchers.argThat(d -> d.getStatus() == DrawStatus.EXPIRED));
    }

    @Test
    void thirdMissMarksDroppedAndResetsPoints() {
        DailyDraw draw = draw(5L, 11L, DrawStatus.VIEWED);
        User user = user(11L, UserTag.NONE, 2);
        when(dailyDrawRepository.findById(5L)).thenReturn(Optional.of(draw));
        when(userRepository.findById(11L)).thenReturn(Optional.of(user));
        when(drawService.rewardPoints(draw)).thenReturn(8);
        when(titleService.resolve(anyInt())).thenReturn("签到萌新");

        settler.settleDraw(5L);

        verify(pointsService).resetToZero(user, PointChangeType.RESET_ZERO, 5L);
        assertEquals(UserTag.DROPPED, user.getTag());
        assertEquals(3, user.getMissStreakDays());
        verify(mailNotifyService).sendWarning(eq("u11@test.com"), eq("掉签警告"), any());
    }

    @Test
    void seventhMissMarksDormantAndPostsSystem() {
        DailyDraw draw = draw(6L, 12L, DrawStatus.PENDING);
        User user = user(12L, UserTag.DROPPED, 6);
        when(dailyDrawRepository.findById(6L)).thenReturn(Optional.of(draw));
        when(userRepository.findById(12L)).thenReturn(Optional.of(user));
        when(drawService.rewardPoints(draw)).thenReturn(4);
        when(titleService.resolve(anyInt())).thenReturn("签到萌新");
        when(circleMemberRepository.findCircleIdsByUserId(12L)).thenReturn(List.of(99L));

        settler.settleDraw(6L);

        assertEquals(UserTag.DORMANT, user.getTag());
        assertEquals(7, user.getMissStreakDays());
        verify(chatService).postSystem(99L, "小七 因连续7天未完成进入休眠");
        verify(mailNotifyService).sendWarning(eq("u12@test.com"), eq("账号已休眠"), any());
    }

    private DailyDraw draw(Long id, Long userId, DrawStatus status) {
        DailyDraw d = new DailyDraw();
        d.setId(id);
        d.setUserId(userId);
        d.setDrawDate(LocalDate.of(2026, 9, 13));
        d.setLevel(FortuneLevel.B);
        d.setFortuneText("签");
        d.setTaskId(1L);
        d.setTaskContent("任务");
        d.setBasePoints(10);
        d.setLuckyStar(false);
        d.setStatus(status);
        return d;
    }

    private User user(Long id, UserTag tag, int missStreak) {
        User u = new User();
        u.setId(id);
        u.setEmail("u" + id + "@test.com");
        u.setNickname(id == 12L ? "小七" : "用户" + id);
        u.setTag(tag);
        u.setMissStreakDays(missStreak);
        u.setStreakDays(2);
        u.setTotalCompletedDays(4);
        u.setPoints(20);
        return u;
    }
}
