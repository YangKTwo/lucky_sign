package com.luckysign.service;

import com.luckysign.common.BizException;
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
import org.springframework.dao.DataIntegrityViolationException;

import java.time.LocalDate;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class CheckinServiceRaceTest {

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

    private CheckinService checkinService;

    @BeforeEach
    void setUp() {
        checkinService = new CheckinService(
                userRepository, dailyDrawRepository, checkinRecordRepository,
                pointsService, drawService, titleService, chatService,
                fileStorageService, ratingService);
    }

    @Test
    void completeRejectsAlreadyCompleted() {
        LocalDate today = LocalDate.now();
        Long circleId = 5L;
        User user = createTestUser(1L);
        DailyDraw draw = createTestDraw(1L, 1L, today, DrawStatus.COMPLETED);

        when(drawService.today()).thenReturn(today);
        when(userRepository.findById(1L)).thenReturn(Optional.of(user));
        when(drawService.ensureDraw(circleId, 1L, today)).thenReturn(draw);

        BizException ex = assertThrows(BizException.class,
                () -> checkinService.complete(circleId, 1L, "test content", null));
        assertEquals("今日已打卡", ex.getMessage());
        verify(checkinRecordRepository, never()).save(any());
    }

    @Test
    void completeRejectsExpiredDraw() {
        LocalDate today = LocalDate.now();
        Long circleId = 5L;
        User user = createTestUser(1L);
        DailyDraw draw = createTestDraw(1L, 1L, today, DrawStatus.EXPIRED);

        when(drawService.today()).thenReturn(today);
        when(userRepository.findById(1L)).thenReturn(Optional.of(user));
        when(drawService.ensureDraw(circleId, 1L, today)).thenReturn(draw);

        BizException ex = assertThrows(BizException.class,
                () -> checkinService.complete(circleId, 1L, "test content", null));
        assertEquals("今日任务已过期", ex.getMessage());
    }

    @Test
    void completeSucceedsWithValidDraw() {
        LocalDate today = LocalDate.now();
        Long circleId = 5L;
        User user = createTestUser(1L);
        user.setLastCheckinDate(today.minusDays(1));
        DailyDraw draw = createTestDraw(1L, 1L, today, DrawStatus.VIEWED);

        when(drawService.today()).thenReturn(today);
        when(userRepository.findById(1L)).thenReturn(Optional.of(user));
        when(drawService.ensureDraw(circleId, 1L, today)).thenReturn(draw);
        when(drawService.rewardPoints(draw)).thenReturn(10);
        when(titleService.resolve(anyInt())).thenReturn("签到达人");
        when(checkinRecordRepository.save(any(CheckinRecord.class))).thenAnswer(inv -> {
            CheckinRecord r = inv.getArgument(0);
            r.setId(100L);
            return r;
        });

        var response = checkinService.complete(circleId, 1L, "完成任务", null);

        assertNotNull(response);
        verify(dailyDrawRepository).save(argThat(d -> d.getStatus() == DrawStatus.COMPLETED));
        verify(checkinRecordRepository).save(any(CheckinRecord.class));
        verify(userRepository).save(any(User.class));
    }

    @Test
    void duplicateCheckinRecordThrowsDataIntegrityViolation() {
        LocalDate today = LocalDate.now();
        Long circleId = 5L;
        User user = createTestUser(1L);
        user.setLastCheckinDate(today.minusDays(1));
        DailyDraw draw = createTestDraw(1L, 1L, today, DrawStatus.VIEWED);

        when(drawService.today()).thenReturn(today);
        when(userRepository.findById(1L)).thenReturn(Optional.of(user));
        when(drawService.ensureDraw(circleId, 1L, today)).thenReturn(draw);
        when(drawService.rewardPoints(draw)).thenReturn(10);
        when(titleService.resolve(anyInt())).thenReturn("签到达人");
        when(checkinRecordRepository.save(any(CheckinRecord.class)))
                .thenThrow(new DataIntegrityViolationException("Duplicate entry for key 'uk_user_checkin_date'"));

        assertThrows(DataIntegrityViolationException.class,
                () -> checkinService.complete(circleId, 1L, "完成任务", null));
    }

    private User createTestUser(Long id) {
        User user = new User();
        user.setId(id);
        user.setEmail("test@test.com");
        user.setNickname("测试用户");
        user.setTag(UserTag.NONE);
        user.setPoints(100);
        user.setStreakDays(5);
        user.setTotalCompletedDays(10);
        user.setTitle("签到萌新");
        return user;
    }

    private DailyDraw createTestDraw(Long id, Long userId, LocalDate date, DrawStatus status) {
        DailyDraw draw = new DailyDraw();
        draw.setId(id);
        draw.setUserId(userId);
        draw.setDrawDate(date);
        draw.setLevel(FortuneLevel.A);
        draw.setFortuneText("好运来");
        draw.setTaskId(1L);
        draw.setTaskContent("测试任务");
        draw.setBasePoints(10);
        draw.setLuckyStar(false);
        draw.setStatus(status);
        draw.setVersion(0L);
        return draw;
    }
}
