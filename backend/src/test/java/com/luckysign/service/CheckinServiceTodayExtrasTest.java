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

import java.time.DayOfWeek;
import java.time.LocalDate;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;
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

    private CheckinService service;

    @BeforeEach
    void setUp() {
        service = new CheckinService(
                userRepository, dailyDrawRepository, checkinRecordRepository,
                pointsService, drawService, titleService, chatService,
                fileStorageService, ratingService, circleMemberRepository);
    }

    @Test
    void weekDaysCoversMondayToSunday() {
        LocalDate today = LocalDate.of(2026, 10, 5); // Monday
        DailyDraw done = new DailyDraw();
        done.setDrawDate(today);
        done.setStatus(DrawStatus.COMPLETED);
        when(dailyDrawRepository.findByUserIdAndDrawDateGreaterThanEqualOrderByDrawDateDesc(1L, today))
                .thenReturn(List.of(done));

        List<CheckinDtos.CalendarDay> week = service.weekDays(1L, today);
        assertEquals(7, week.size());
        assertEquals(DayOfWeek.MONDAY, week.get(0).date().getDayOfWeek());
        assertEquals(DayOfWeek.SUNDAY, week.get(6).date().getDayOfWeek());
        assertEquals("COMPLETED", week.get(0).status());
        assertEquals("NONE", week.get(1).status());
    }

    @Test
    void circleProgressMarksJustYou() {
        LocalDate today = LocalDate.of(2026, 10, 5);
        CircleMember me = member(1L);
        CircleMember other = member(2L);
        User u1 = user(1L, "我");
        User u2 = user(2L, "小明");
        DailyDraw otherDone = new DailyDraw();
        otherDone.setUserId(2L);
        otherDone.setStatus(DrawStatus.COMPLETED);

        when(circleMemberRepository.findByCircleId(9L)).thenReturn(List.of(me, other));
        when(userRepository.findAllById(List.of(1L, 2L))).thenReturn(List.of(u1, u2));
        when(dailyDrawRepository.findByDrawDate(today)).thenReturn(List.of(otherDone));

        CheckinDtos.CircleProgress progress = service.circleProgress(9L, 1L, today);
        assertEquals(1, progress.completed());
        assertEquals(2, progress.total());
        assertTrue(progress.justYou());
        assertTrue(progress.pendingNicknames().isEmpty());
    }

    private static CircleMember member(Long userId) {
        CircleMember m = new CircleMember();
        m.setCircleId(9L);
        m.setUserId(userId);
        return m;
    }

    private static User user(Long id, String nickname) {
        User user = new User();
        user.setId(id);
        user.setNickname(nickname);
        user.setTag(UserTag.NONE);
        user.setEmail(id + "@t.com");
        return user;
    }
}
