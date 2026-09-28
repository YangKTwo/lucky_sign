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

import java.util.List;

import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class DailyJobsTest {

    @Mock
    private DrawService drawService;
    @Mock
    private SettlementService settlementService;
    @Mock
    private MailNotifyService mailNotifyService;
    @Mock
    private CircleRepository circleRepository;

    private DailyJobs dailyJobs;

    @BeforeEach
    void setUp() {
        dailyJobs = new DailyJobs(drawService, settlementService, mailNotifyService, circleRepository);
    }

    @Test
    void generateDrawsContinuesWhenOneCircleFails() {
        Circle a = new Circle();
        a.setId(1L);
        Circle b = new Circle();
        b.setId(2L);
        when(circleRepository.findAll()).thenReturn(List.of(a, b));
        doThrow(new RuntimeException("circle 1 boom")).when(drawService).generateForAllActiveUsers(1L);

        dailyJobs.generateDraws();

        verify(drawService).generateForAllActiveUsers(1L);
        verify(drawService).generateForAllActiveUsers(2L);
    }
}
