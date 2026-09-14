package com.luckysign.service;

import com.luckysign.entity.DailyDraw;
import com.luckysign.repository.DailyDrawRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

import java.time.LocalDate;
import java.util.List;

@Service
public class SettlementService {
    private static final Logger log = LoggerFactory.getLogger(SettlementService.class);

    private final DailyDrawRepository dailyDrawRepository;
    private final DrawService drawService;
    private final DrawMissSettler drawMissSettler;

    public SettlementService(DailyDrawRepository dailyDrawRepository,
                             DrawService drawService,
                             DrawMissSettler drawMissSettler) {
        this.dailyDrawRepository = dailyDrawRepository;
        this.drawService = drawService;
        this.drawMissSettler = drawMissSettler;
    }

    public void settleYesterday() {
        LocalDate yesterday = drawService.today().minusDays(1);
        List<DailyDraw> draws = dailyDrawRepository.findByDrawDate(yesterday);
        int fail = 0;
        for (DailyDraw draw : draws) {
            try {
                drawMissSettler.settleDraw(draw.getId());
            } catch (Exception e) {
                fail++;
                log.error("Settle failed drawId={} userId={} date={}",
                        draw.getId(), draw.getUserId(), yesterday, e);
            }
        }
        log.info("Settlement finished date={} attempted={} fail={}", yesterday, draws.size(), fail);
    }
}
