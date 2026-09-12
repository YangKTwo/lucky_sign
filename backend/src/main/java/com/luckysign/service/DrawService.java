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
import java.util.Set;
import java.util.concurrent.ThreadLocalRandom;
import java.util.stream.Collectors;

@Service
public class DrawService {
    private final UserRepository userRepository;
    private final DailyDrawRepository dailyDrawRepository;
    private final TaskItemRepository taskItemRepository;
    private final FortuneCopyRepository fortuneCopyRepository;
    private final CircleRepository circleRepository;
    private final CircleMemberRepository circleMemberRepository;
    private final CircleDailyStarRepository circleDailyStarRepository;
    private final ZoneId zoneId = ZoneId.of("Asia/Shanghai");

    public DrawService(UserRepository userRepository,
                       DailyDrawRepository dailyDrawRepository,
                       TaskItemRepository taskItemRepository,
                       FortuneCopyRepository fortuneCopyRepository,
                       CircleRepository circleRepository,
                       CircleMemberRepository circleMemberRepository,
                       CircleDailyStarRepository circleDailyStarRepository) {
        this.userRepository = userRepository;
        this.dailyDrawRepository = dailyDrawRepository;
        this.taskItemRepository = taskItemRepository;
        this.fortuneCopyRepository = fortuneCopyRepository;
        this.circleRepository = circleRepository;
        this.circleMemberRepository = circleMemberRepository;
        this.circleDailyStarRepository = circleDailyStarRepository;
    }

    public LocalDate today() {
        return LocalDate.now(zoneId);
    }

    @Transactional
    public void generateForAllActiveUsers(Long circleId) {
        LocalDate date = today();
        ensureLuckyStar(circleId, date);
        Set<Long> memberUserIds = circleMemberRepository.findByCircleId(circleId).stream()
                .map(CircleMember::getUserId)
                .collect(Collectors.toSet());
        List<User> users = userRepository.findByTagNot(UserTag.DORMANT).stream()
                .filter(u -> memberUserIds.contains(u.getId()))
                .toList();
        for (User user : users) {
            ensureDraw(circleId, user.getId(), date);
        }
    }

    @Transactional
    public DailyDraw ensureDraw(Long circleId, Long userId, LocalDate date) {
        ensureLuckyStar(circleId, date);
        return dailyDrawRepository.findByUserIdAndDrawDate(userId, date)
                .orElseGet(() -> createDraw(circleId, userId, date));
    }

    private DailyDraw createDraw(Long circleId, Long userId, LocalDate date) {
        User user = userRepository.findById(userId).orElseThrow(() -> new BizException("用户不存在"));
        if (user.getTag() == UserTag.DORMANT) {
            throw new BizException("账号已休眠，请联系管理员解锁");
        }

        FortuneLevel level = randomLevel();
        String fortuneText = pickFortuneText(level);
        TaskItem task = pickTask(level, userId, date);
        boolean lucky = isLuckyStar(circleId, userId, date);

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
    public void ensureLuckyStar(Long circleId, LocalDate date) {
        if (circleDailyStarRepository.findByCircleIdAndStarDate(circleId, date).isPresent()) {
            return;
        }
        Set<Long> memberUserIds = circleMemberRepository.findByCircleId(circleId).stream()
                .map(CircleMember::getUserId)
                .collect(Collectors.toSet());
        List<User> candidates = userRepository.findByTagNot(UserTag.DORMANT).stream()
                .filter(u -> memberUserIds.contains(u.getId()))
                .toList();
        if (candidates.isEmpty()) {
            return;
        }
        User picked = candidates.get(ThreadLocalRandom.current().nextInt(candidates.size()));
        CircleDailyStar star = new CircleDailyStar();
        star.setCircleId(circleId);
        star.setUserId(picked.getId());
        star.setStarDate(date);
        circleDailyStarRepository.save(star);
    }

    private boolean isLuckyStar(Long circleId, Long userId, LocalDate date) {
        return circleDailyStarRepository.findByCircleIdAndStarDate(circleId, date)
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
