package com.luckysign.service;

import com.luckysign.domain.DrawStatus;
import com.luckysign.domain.UserTag;
import com.luckysign.dto.CheckinDtos;
import com.luckysign.entity.CircleMember;
import com.luckysign.entity.DailyDraw;
import com.luckysign.entity.User;
import com.luckysign.repository.CheckinRecordRepository;
import com.luckysign.repository.CircleMemberRepository;
import com.luckysign.repository.DailyDrawRepository;
import com.luckysign.repository.UserRepository;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.LocalDate;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class CheckinServiceCalendarTest {
    @Mock
    private UserRepository userRepository;
    @Mock
    private DailyDrawRepository dailyDrawRepository;
    @Mock
    private CheckinRecordRepository checkinRecordRepository;
    @Mock
    private CircleMemberRepository circleMemberRepository;
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

    @Test
    void calendarMarksCompletedMissedAndPending() {
        CheckinService service = new CheckinService(
                userRepository, dailyDrawRepository, checkinRecordRepository,
                circleMemberRepository, pointsService, drawService, titleService, chatService,
                fileStorageService, ratingService);
        LocalDate today = LocalDate.of(2026, 9, 11);
        when(drawService.today()).thenReturn(today);

        DailyDraw done = new DailyDraw();
        done.setDrawDate(today.minusDays(1));
        done.setStatus(DrawStatus.COMPLETED);
        DailyDraw pending = new DailyDraw();
        pending.setDrawDate(today);
        pending.setStatus(DrawStatus.VIEWED);
        when(dailyDrawRepository.findByUserIdAndDrawDateGreaterThanEqualOrderByDrawDateDesc(
                1L, today.minusDays(6)))
                .thenReturn(List.of(pending, done));

        CheckinDtos.CalendarResponse cal = service.calendar(1L, 7);
        assertEquals(7, cal.days().size());
        assertEquals("COMPLETED", cal.days().get(5).status());
        assertEquals("PENDING", cal.days().get(6).status());
        assertEquals("NONE", cal.days().get(0).status());
    }

    @Test
    void circleTodayCountsActiveMembersAndWaitingNames() {
        CheckinService service = new CheckinService(
                userRepository, dailyDrawRepository, checkinRecordRepository,
                circleMemberRepository, pointsService, drawService, titleService, chatService,
                fileStorageService, ratingService);
        LocalDate today = LocalDate.of(2026, 10, 19);

        CircleMember me = new CircleMember();
        me.setUserId(1L);
        CircleMember peer = new CircleMember();
        peer.setUserId(2L);
        CircleMember dormant = new CircleMember();
        dormant.setUserId(3L);
        when(circleMemberRepository.findByCircleId(8L)).thenReturn(List.of(me, peer, dormant));

        User u1 = new User();
        u1.setId(1L);
        u1.setNickname("我");
        u1.setTag(UserTag.NONE);
        User u2 = new User();
        u2.setId(2L);
        u2.setNickname("小明");
        u2.setTag(UserTag.NONE);
        User u3 = new User();
        u3.setId(3L);
        u3.setNickname("休眠");
        u3.setTag(UserTag.DORMANT);
        when(userRepository.findAllById(List.of(1L, 2L, 3L))).thenReturn(List.of(u1, u2, u3));

        DailyDraw mine = new DailyDraw();
        mine.setUserId(1L);
        mine.setStatus(DrawStatus.VIEWED);
        DailyDraw peerDraw = new DailyDraw();
        peerDraw.setUserId(2L);
        peerDraw.setStatus(DrawStatus.COMPLETED);
        when(dailyDrawRepository.findByDrawDate(today)).thenReturn(List.of(mine, peerDraw));

        CheckinDtos.CircleTodayProgress progress = service.circleToday(8L, 1L, today);
        assertEquals(1, progress.completedCount());
        assertEquals(2, progress.memberCount());
        assertEquals(List.of(), progress.waitingNicknames());
        assertEquals(false, progress.meCompleted());
    }

    @Test
    void streakBonusOnFullWeekAndMonth() {
        assertEquals(10, CheckinService.streakBonusPoints(7));
        assertEquals("连续满周 +10 分", CheckinService.streakBonusLabel(7));
        assertEquals(50, CheckinService.streakBonusPoints(30));
        assertEquals("连续满月 +50 分", CheckinService.streakBonusLabel(30));
        assertEquals(0, CheckinService.streakBonusPoints(6));
    }
}
