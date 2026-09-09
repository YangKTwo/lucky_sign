package com.luckysign.scheduler;

import com.luckysign.service.DrawService;
import com.luckysign.service.MailNotifyService;
import com.luckysign.service.SettlementService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

@Component
public class DailyJobs {
    private static final Logger log = LoggerFactory.getLogger(DailyJobs.class);

    private final DrawService drawService;
    private final SettlementService settlementService;
    private final MailNotifyService mailNotifyService;

    public DailyJobs(DrawService drawService,
                     SettlementService settlementService,
                     MailNotifyService mailNotifyService) {
        this.drawService = drawService;
        this.settlementService = settlementService;
        this.mailNotifyService = mailNotifyService;
    }

    @Scheduled(cron = "0 5 0 * * *", zone = "Asia/Shanghai")
    public void generateDraws() {
        log.info("Generating daily draws...");
        drawService.ensureLuckyStar(drawService.today());
        drawService.generateForAllActiveUsers();
    }

    @Scheduled(cron = "0 10 0 * * *", zone = "Asia/Shanghai")
    public void settle() {
        log.info("Settling yesterday misses...");
        settlementService.settleYesterday();
    }

    @Scheduled(cron = "0 0 8 * * *", zone = "Asia/Shanghai")
    public void morningMail() {
        log.info("Sending morning mails...");
        mailNotifyService.sendDailyReminders();
    }
}
