package com.luckysign.service;

import com.luckysign.common.BizException;
import com.luckysign.domain.DrawStatus;
import com.luckysign.domain.FortuneLevel;
import com.luckysign.domain.UserTag;
import com.luckysign.entity.*;
import com.luckysign.repository.*;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.time.ZoneId;
import java.util.List;
import java.util.concurrent.ThreadLocalRandom;

@Service
public class DrawService {
    private final UserRepository userRepository;
    private final DailyDrawRepository dailyDrawRepository;
    private final TaskItemRepository taskItemRepository;
    private final FortuneCopyRepository fortuneCopyRepository;
    private final CircleRepository circleRepository;
    private final CircleDailyStarRepository circleDailyStarRepository;
    private final ZoneId zoneId = ZoneId.of("Asia/Shanghai");

    public DrawService(UserRepository userRepository,
                       DailyDrawRepository dailyDrawRepository,
                       TaskItemRepository taskItemRepository,
                       FortuneCopyRepository fortuneCopyRepository,
                       CircleRepository circleRepository,
                       CircleDailyStarRepository circleDailyStarRepository) {
        this.userRepository = userRepository;
        this.dailyDrawRepository = dailyDrawRepository;
        this.taskItemRepository = taskItemRepository;
        this.fortuneCopyRepository = fortuneCopyRepository;
        this.circleRepository = circleRepository;
        this.circleDailyStarRepository = circleDailyStarRepository;
    }

    public LocalDate today() {
        return LocalDate.now(zoneId);
    }

    @Transactional
    public void generateForAllActiveUsers() {
        LocalDate date = today();
        ensureLuckyStar(date);
        List<User> users = userRepository.findByTagNot(UserTag.DORMANT);
        for (User user : users) {
            ensureDraw(user.getId(), date);
        }
    }

    @Transactional
    public DailyDraw ensureDraw(Long userId, LocalDate date) {
        ensureLuckyStar(date);
        return dailyDrawRepository.findByUserIdAndDrawDate(userId, date)
                .orElseGet(() -> createDraw(userId, date));
    }

    private DailyDraw createDraw(Long userId, LocalDate date) {
        User user = userRepository.findById(userId).orElseThrow(() -> new BizException("用户不存在"));
        if (user.getTag() == UserTag.DORMANT) {
            throw new BizException("账号已休眠，请联系管理员解锁");
        }

        FortuneLevel level = randomLevel();
        String fortuneText = pickFortuneText(level);
        TaskItem task = pickTask(level, userId, date);
        boolean lucky = isLuckyStar(userId, date);

        DailyDraw draw = new DailyDraw();
        draw.setUserId(userId);
        draw.setDrawDate(date);
        draw.setLevel(level);
        draw.setFortuneText(fortuneText);
        draw.setTaskId(task.getId());
        draw.setTaskContent(task.getContent());
        draw.setBasePoints(level.getBasePoints());
        draw.setLuckyStar(lucky);
        draw.setStatus(DrawStatus.PENDING);
        return dailyDrawRepository.save(draw);
    }

    @Transactional
    public void ensureLuckyStar(LocalDate date) {
        Circle circle = circleRepository.findFirstByOrderByIdAsc()
                .orElseThrow(() -> new BizException("默认圈子未初始化"));
        if (circleDailyStarRepository.findByCircleIdAndStarDate(circle.getId(), date).isPresent()) {
            return;
        }
        List<User> candidates = userRepository.findByTagNot(UserTag.DORMANT);
        if (candidates.isEmpty()) {
            return;
        }
        User picked = candidates.get(ThreadLocalRandom.current().nextInt(candidates.size()));
        CircleDailyStar star = new CircleDailyStar();
        star.setCircleId(circle.getId());
        star.setUserId(picked.getId());
        star.setStarDate(date);
        circleDailyStarRepository.save(star);
    }

    private boolean isLuckyStar(Long userId, LocalDate date) {
        return circleRepository.findFirstByOrderByIdAsc()
                .flatMap(c -> circleDailyStarRepository.findByCircleIdAndStarDate(c.getId(), date))
                .map(s -> s.getUserId().equals(userId))
                .orElse(false);
    }

    private FortuneLevel randomLevel() {
        int roll = ThreadLocalRandom.current().nextInt(100);
        int acc = 0;
        for (FortuneLevel level : FortuneLevel.values()) {
            acc += level.getWeight();
            if (roll < acc) {
                return level;
            }
        }
        return FortuneLevel.B;
    }

    private String pickFortuneText(FortuneLevel level) {
        List<FortuneCopy> copies = fortuneCopyRepository.findByLevelAndEnabledTrue(level);
        if (copies.isEmpty()) {
            return level.getDefaultCopy();
        }
        return copies.get(ThreadLocalRandom.current().nextInt(copies.size())).getContent();
    }

    private TaskItem pickTask(FortuneLevel level, Long userId, LocalDate date) {
        List<TaskItem> tasks = taskItemRepository.findByDifficultyAndEnabledTrue(level.getDifficulty());
        if (tasks.isEmpty()) {
            throw new BizException("任务库为空，请先初始化");
        }
        LocalDate from = date.minusDays(6);
        List<Long> recentTaskIds = dailyDrawRepository
                .findByUserIdAndDrawDateGreaterThanEqualOrderByDrawDateDesc(userId, from)
                .stream()
                .map(DailyDraw::getTaskId)
                .toList();
        List<TaskItem> filtered = tasks.stream().filter(t -> !recentTaskIds.contains(t.getId())).toList();
        List<TaskItem> pool = filtered.isEmpty() ? tasks : filtered;
        return pool.get(ThreadLocalRandom.current().nextInt(pool.size()));
    }

    public int rewardPoints(DailyDraw draw) {
        int points = draw.getBasePoints();
        if (Boolean.TRUE.equals(draw.getLuckyStar())) {
            points *= 2;
        }
        return points;
    }
}
