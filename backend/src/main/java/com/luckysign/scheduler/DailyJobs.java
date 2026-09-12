package com.luckysign.scheduler;

import com.luckysign.entity.Circle;
import com.luckysign.repository.CircleRepository;
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
    private final CircleRepository circleRepository;

    public DailyJobs(DrawService drawService,
                     SettlementService settlementService,
                     MailNotifyService mailNotifyService,
                     CircleRepository circleRepository) {
        this.drawService = drawService;
        this.settlementService = settlementService;
        this.mailNotifyService = mailNotifyService;
        this.circleRepository = circleRepository;
    }

    @Scheduled(cron = "0 5 0 * * *", zone = "Asia/Shanghai")
    public void generateDraws() {
        log.info("Generating daily draws for all circles...");
        for (Circle circle : circleRepository.findAll()) {
            drawService.generateForAllActiveUsers(circle.getId());
        }
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

    @Scheduled(cron = "0 0 20 * * *", zone = "Asia/Shanghai")
    public void eveningIncompleteMail() {
        log.info("Sending evening incomplete reminders...");
        mailNotifyService.sendIncompleteReminders(drawService.today());
    }
}
