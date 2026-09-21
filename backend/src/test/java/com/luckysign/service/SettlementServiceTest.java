package com.luckysign.service;

import com.luckysign.entity.DailyDraw;
import com.luckysign.repository.DailyDrawRepository;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.LocalDate;
import java.util.List;

import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class SettlementServiceTest {

    @Mock
    private DailyDrawRepository dailyDrawRepository;
    @Mock
    private DrawService drawService;
    @Mock
    private DrawMissSettler drawMissSettler;

    @InjectMocks
    private SettlementService settlementService;

    @Test
    void continuesAfterOneDrawFails() {
        LocalDate today = LocalDate.of(2026, 9, 14);
        when(drawService.today()).thenReturn(today);
        DailyDraw a = new DailyDraw();
        a.setId(1L);
        a.setUserId(11L);
        DailyDraw b = new DailyDraw();
        b.setId(2L);
        b.setUserId(22L);
        when(dailyDrawRepository.findByDrawDate(today.minusDays(1))).thenReturn(List.of(a, b));
        doThrow(new RuntimeException("boom")).when(drawMissSettler).settleDraw(1L);

        settlementService.settleYesterday();

        verify(drawMissSettler).settleDraw(1L);
        verify(drawMissSettler).settleDraw(2L);
    }
}
