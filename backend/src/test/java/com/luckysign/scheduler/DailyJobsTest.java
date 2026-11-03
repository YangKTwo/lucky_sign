package com.luckysign.scheduler;

import com.luckysign.entity.Circle;
import com.luckysign.repository.CircleRepository;
import com.luckysign.service.DrawService;
import com.luckysign.service.MailNotifyService;
import com.luckysign.service.SettlementService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.LocalDate;
import java.util.List;

import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class DailyJobsTest {
    @Mock private DrawService drawService;
    @Mock private SettlementService settlementService;
    @Mock private MailNotifyService mailNotifyService;
    @Mock private CircleRepository circleRepository;

    private DailyJobs jobs;

    @BeforeEach
    void setUp() {
        jobs = new DailyJobs(drawService, settlementService, mailNotifyService, circleRepository);
    }

    @Test
    void generateDrawsContinuesAfterOneCircleFails() {
        Circle a = circle(1L);
        Circle b = circle(2L);
        when(circleRepository.findAll()).thenReturn(List.of(a, b));
        doThrow(new RuntimeException("circle A boom")).when(drawService).generateForAllActiveUsers(1L);

        jobs.generateDraws();

        verify(drawService).generateForAllActiveUsers(1L);
        verify(drawService).generateForAllActiveUsers(2L);
    }

    @Test
    void settleFailureDoesNotPropagate() {
        doThrow(new RuntimeException("settle boom")).when(settlementService).settleYesterday();
        jobs.settle();
        verify(settlementService).settleYesterday();
    }

    @Test
    void eveningRemindersUseToday() {
        LocalDate today = LocalDate.of(2026, 11, 3);
        when(drawService.today()).thenReturn(today);
        jobs.eveningIncompleteMail();
        verify(mailNotifyService).sendIncompleteReminders(today);
    }

    private static Circle circle(Long id) {
        Circle circle = new Circle();
        circle.setId(id);
        circle.setName("圈子" + id);
        return circle;
    }
}
