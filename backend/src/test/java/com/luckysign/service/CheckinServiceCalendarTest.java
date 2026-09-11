package com.luckysign.service;

import com.luckysign.domain.DrawStatus;
import com.luckysign.dto.CheckinDtos;
import com.luckysign.entity.DailyDraw;
import com.luckysign.repository.CheckinRecordRepository;
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
                pointsService, drawService, titleService, chatService,
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
}
