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
        int fail = 0;
        for (Circle circle : circleRepository.findAll()) {
            try {
                drawService.generateForAllActiveUsers(circle.getId());
            } catch (Exception e) {
                fail++;
                log.error("Generate draws failed circleId={}", circle.getId(), e);
            }
        }
        log.info("Daily draws finished fail={}", fail);
    }

    @Scheduled(cron = "0 10 0 * * *", zone = "Asia/Shanghai")
    public void settle() {
        log.info("Settling yesterday misses...");
        try {
            settlementService.settleYesterday();
        } catch (Exception e) {
            log.error("Settlement job failed", e);
        }
    }

    @Scheduled(cron = "0 0 8 * * *", zone = "Asia/Shanghai")
    public void morningMail() {
        log.info("Sending morning mails...");
        try {
            mailNotifyService.sendDailyReminders();
        } catch (Exception e) {
            log.error("Morning mail job failed", e);
        }
    }

    @Scheduled(cron = "0 0 20 * * *", zone = "Asia/Shanghai")
    public void eveningIncompleteMail() {
        log.info("Sending evening incomplete reminders...");
        try {
            mailNotifyService.sendIncompleteReminders(drawService.today());
        } catch (Exception e) {
            log.error("Evening reminder job failed", e);
        }
    }
}
