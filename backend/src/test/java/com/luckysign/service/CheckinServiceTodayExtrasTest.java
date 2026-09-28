package com.luckysign.service;

import com.luckysign.domain.DrawStatus;
import com.luckysign.domain.FortuneLevel;
import com.luckysign.domain.UserTag;
import com.luckysign.dto.CheckinDtos;
import com.luckysign.entity.CircleMember;
import com.luckysign.entity.DailyDraw;
import com.luckysign.entity.User;
import com.luckysign.repository.CheckinRecordRepository;
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

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class CheckinServiceTodayExtrasTest {

    @Mock
    private UserRepository userRepository;
    @Mock
    private DailyDrawRepository dailyDrawRepository;
    @Mock
    private CheckinRecordRepository checkinRecordRepository;
    @Mock
    private PointsService pointsService;
    @Mock
    private DrawService drawService;
    @Mock
    private TitleService titleService;
    @Mock
    private ChatService chatService;
    @Mock
    private FileStorageService fileStorageService;
    @Mock
    private RatingService ratingService;
    @Mock
    private CircleMemberRepository circleMemberRepository;

    private CheckinService checkinService;

    @BeforeEach
    void setUp() {
        checkinService = new CheckinService(
                userRepository, dailyDrawRepository, checkinRecordRepository,
                pointsService, drawService, titleService, chatService,
                fileStorageService, ratingService, circleMemberRepository);
    }

    @Test
    void todayIncludesWeekAndCircleProgress() {
        LocalDate today = LocalDate.of(2026, 9, 28);
        User me = user(1L, "我");
        User peer = user(2L, "圈友");
        DailyDraw myDraw = draw(10L, 1L, today, DrawStatus.VIEWED);
        DailyDraw peerDraw = draw(11L, 2L, today, DrawStatus.COMPLETED);

        when(drawService.today()).thenReturn(today);
        when(userRepository.findById(1L)).thenReturn(Optional.of(me));
        when(drawService.ensureDraw(9L, 1L, today)).thenReturn(myDraw);
        when(drawService.rewardPoints(myDraw)).thenReturn(10);
        when(titleService.nextTitle(anyInt())).thenReturn("每日行者");
        when(titleService.daysToNextTitle(anyInt())).thenReturn(3);
        when(titleService.nextTitleAt(anyInt())).thenReturn(4);
        when(dailyDrawRepository.findByUserIdAndDrawDateGreaterThanEqualOrderByDrawDateDesc(1L, today.minusDays(6)))
                .thenReturn(List.of(myDraw));
        when(circleMemberRepository.findByCircleId(9L)).thenReturn(List.of(member(1L), member(2L)));
        when(userRepository.findAllById(List.of(1L, 2L))).thenReturn(List.of(me, peer));
        when(dailyDrawRepository.findByDrawDate(today)).thenReturn(List.of(myDraw, peerDraw));

        CheckinDtos.TodayResponse res = checkinService.today(9L, 1L);

        assertEquals(7, res.weekDays().size());
        assertEquals("PENDING", res.weekDays().get(6).status());
        assertEquals(1, res.circleProgress().checkedCount());
        assertEquals(2, res.circleProgress().memberCount());
        assertTrue(res.circleProgress().onlyMeLeft());
        assertTrue(res.circleProgress().pendingNicknames().isEmpty());
        assertEquals(DrawStatus.VIEWED, res.status());
    }

    private static User user(Long id, String nickname) {
        User u = new User();
        u.setId(id);
        u.setNickname(nickname);
        u.setTag(UserTag.NONE);
        u.setPoints(12);
        u.setStreakDays(2);
        u.setTotalCompletedDays(1);
        u.setTitle("签到萌新");
        return u;
    }

    private static DailyDraw draw(Long id, Long userId, LocalDate date, DrawStatus status) {
        DailyDraw d = new DailyDraw();
        d.setId(id);
        d.setUserId(userId);
        d.setDrawDate(date);
        d.setLevel(FortuneLevel.A);
        d.setFortuneText("好运");
        d.setTaskContent("散步");
        d.setBasePoints(10);
        d.setLuckyStar(false);
        d.setStatus(status);
        return d;
    }

    private static CircleMember member(Long userId) {
        CircleMember m = new CircleMember();
        m.setCircleId(9L);
        m.setUserId(userId);
        return m;
    }
}
