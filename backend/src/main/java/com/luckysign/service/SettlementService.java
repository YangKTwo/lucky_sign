package com.luckysign.service;

import com.luckysign.domain.DrawStatus;
import com.luckysign.domain.PointChangeType;
import com.luckysign.domain.UserTag;
import com.luckysign.entity.DailyDraw;
import com.luckysign.entity.User;
import com.luckysign.repository.DailyDrawRepository;
import com.luckysign.repository.UserRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.util.List;

@Service
public class SettlementService {
    private static final Logger log = LoggerFactory.getLogger(SettlementService.class);

    private final DailyDrawRepository dailyDrawRepository;
    private final UserRepository userRepository;
    private final PointsService pointsService;
    private final DrawService drawService;
    private final TitleService titleService;
    private final MailNotifyService mailNotifyService;
    private final ChatService chatService;

    public SettlementService(DailyDrawRepository dailyDrawRepository,
                             UserRepository userRepository,
                             PointsService pointsService,
                             DrawService drawService,
                             TitleService titleService,
                             MailNotifyService mailNotifyService,
                             ChatService chatService) {
        this.dailyDrawRepository = dailyDrawRepository;
        this.userRepository = userRepository;
        this.pointsService = pointsService;
        this.drawService = drawService;
        this.titleService = titleService;
        this.mailNotifyService = mailNotifyService;
        this.chatService = chatService;
    }

    @Transactional
    public void settleYesterday() {
        LocalDate yesterday = drawService.today().minusDays(1);
        List<DailyDraw> draws = dailyDrawRepository.findByDrawDate(yesterday);
        for (DailyDraw draw : draws) {
            if (draw.getStatus() == DrawStatus.COMPLETED) {
                continue;
            }
            User user = userRepository.findById(draw.getUserId()).orElse(null);
            if (user == null || user.getTag() == UserTag.DORMANT) {
                draw.setStatus(DrawStatus.EXPIRED);
                dailyDrawRepository.save(draw);
                continue;
            }

            int penalty = drawService.rewardPoints(draw) / 2;
            if (penalty > 0) {
                pointsService.apply(user, -penalty, PointChangeType.PENALTY, draw.getId());
            }

            user.setStreakDays(0);
            user.setMissStreakDays(user.getMissStreakDays() + 1);

            if (user.getMissStreakDays() >= 7) {
                user.setTag(UserTag.DORMANT);
                mailNotifyService.sendWarning(user.getEmail(), "账号已休眠",
                        "你已连续7天未完成任务，账号进入休眠并禁言，请联系管理员解锁。");
                chatService.postSystem(user.getNickname() + " 因连续7天未完成进入休眠");
            } else if (user.getMissStreakDays() >= 3) {
                pointsService.resetToZero(user, PointChangeType.RESET_ZERO, draw.getId());
                user.setTag(UserTag.DROPPED);
                mailNotifyService.sendWarning(user.getEmail(), "掉签警告",
                        "你已连续3天未完成任务，积分已清零并标记为掉签。");
            }

            user.setTitle(titleService.resolve(user.getTotalCompletedDays()));
            userRepository.save(user);
            draw.setStatus(DrawStatus.EXPIRED);
            dailyDrawRepository.save(draw);
            log.info("Settled miss userId={} date={} missStreak={}", user.getId(), yesterday, user.getMissStreakDays());
        }
    }
}
