package com.luckysign.service;

import com.luckysign.common.BizException;
import com.luckysign.domain.DrawStatus;
import com.luckysign.domain.PointChangeType;
import com.luckysign.domain.UserTag;
import com.luckysign.dto.CheckinDtos;
import com.luckysign.dto.RatingDtos;
import com.luckysign.entity.CheckinRecord;
import com.luckysign.entity.CircleMember;
import com.luckysign.entity.DailyDraw;
import com.luckysign.entity.User;
import com.luckysign.repository.CheckinRecordRepository;
import com.luckysign.repository.CircleMemberRepository;
import com.luckysign.repository.DailyDrawRepository;
import com.luckysign.repository.UserRepository;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

import java.time.Instant;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.stream.Collectors;

@Service
public class CheckinService {
    private final UserRepository userRepository;
    private final DailyDrawRepository dailyDrawRepository;
    private final CheckinRecordRepository checkinRecordRepository;
    private final CircleMemberRepository circleMemberRepository;
    private final PointsService pointsService;
    private final DrawService drawService;
    private final TitleService titleService;
    private final ChatService chatService;
    private final FileStorageService fileStorageService;
    private final RatingService ratingService;

    public CheckinService(UserRepository userRepository,
                          DailyDrawRepository dailyDrawRepository,
                          CheckinRecordRepository checkinRecordRepository,
                          CircleMemberRepository circleMemberRepository,
                          PointsService pointsService,
                          DrawService drawService,
                          TitleService titleService,
                          ChatService chatService,
                          FileStorageService fileStorageService,
                          RatingService ratingService) {
        this.userRepository = userRepository;
        this.dailyDrawRepository = dailyDrawRepository;
        this.checkinRecordRepository = checkinRecordRepository;
        this.circleMemberRepository = circleMemberRepository;
        this.pointsService = pointsService;
        this.drawService = drawService;
        this.titleService = titleService;
        this.chatService = chatService;
        this.fileStorageService = fileStorageService;
        this.ratingService = ratingService;
    }

    @Transactional
    public CheckinDtos.TodayResponse today(Long circleId, Long userId) {
        LocalDate date = drawService.today();
        User user = userRepository.findById(userId).orElseThrow(() -> new BizException("用户不存在"));
        if (user.getTag() == UserTag.DORMANT) {
            throw new BizException("账号已休眠，请联系管理员解锁");
        }
        DailyDraw draw = drawService.ensureDraw(circleId, userId, date);
        if (draw.getStatus() == DrawStatus.PENDING) {
            draw.setStatus(DrawStatus.VIEWED);
            dailyDrawRepository.save(draw);
        }
        return toToday(circleId, user, draw);
    }

    @Transactional
    public CheckinDtos.TodayResponse complete(Long circleId, Long userId, String text, MultipartFile image) {
        LocalDate date = drawService.today();
        User user = userRepository.findById(userId).orElseThrow(() -> new BizException("用户不存在"));
        if (user.getTag() == UserTag.DORMANT) {
            throw new BizException("账号已休眠，请联系管理员解锁");
        }
        DailyDraw draw = drawService.ensureDraw(circleId, userId, date);
        if (draw.getStatus() == DrawStatus.COMPLETED) {
            throw new BizException("今日已打卡");
        }
        if (draw.getStatus() == DrawStatus.EXPIRED) {
            throw new BizException("今日任务已过期");
        }

        boolean hasText = text != null && !text.trim().isEmpty();
        boolean hasImage = image != null && !image.isEmpty();
        if (!hasText && !hasImage) {
            throw new BizException("请输入打卡内容或上传图片");
        }
        String textContent = hasText ? text.trim() : null;
        if (textContent != null && textContent.length() > 500) {
            throw new BizException("打卡内容不能超过 500 字");
        }

        String imageUrl = null;
        if (hasImage) {
            imageUrl = fileStorageService.save(image);
        }

        int reward = drawService.rewardPoints(draw);
        applyPoints(user, reward, Boolean.TRUE.equals(draw.getLuckyStar()) ? PointChangeType.LUCKY_STAR : PointChangeType.TASK, draw.getId());

        int newStreak = calcNewStreak(user, date);
        user.setStreakDays(newStreak);
        user.setTotalCompletedDays(user.getTotalCompletedDays() + 1);
        user.setLastCheckinDate(date);
        user.setMissStreakDays(0);
        if (user.getTag() == UserTag.DROPPED && newStreak >= 3) {
            user.setTag(UserTag.NONE);
        }
        user.setTitle(titleService.resolve(user.getTotalCompletedDays()));

        if (newStreak > 0 && newStreak % 7 == 0) {
            applyPoints(user, 10, PointChangeType.STREAK_7, draw.getId());
        }
        if (newStreak > 0 && newStreak % 30 == 0) {
            applyPoints(user, 50, PointChangeType.STREAK_30, draw.getId());
        }
        userRepository.save(user);

        draw.setStatus(DrawStatus.COMPLETED);
        dailyDrawRepository.save(draw);

        CheckinRecord record = new CheckinRecord();
        record.setUserId(userId);
        record.setDrawId(draw.getId());
        record.setCheckinDate(date);
        record.setLevel(draw.getLevel());
        record.setTaskContent(draw.getTaskContent());
        record.setTextContent(textContent);
        record.setImageUrl(imageUrl);
        record.setPointsEarned(reward);
        record.setStreakSnapshot(newStreak);
        try {
            record = checkinRecordRepository.save(record);
        } catch (DataIntegrityViolationException e) {
            throw new BizException("今日已打卡");
        }

        chatService.postCheckin(circleId, user, record, draw);
        return toToday(circleId, user, draw, record.getImageUrl(), record.getTextContent(), record);
    }

    public int streak(Long userId) {
        User user = userRepository.findById(userId).orElseThrow(() -> new BizException("用户不存在"));
        return user.getStreakDays() == null ? 0 : user.getStreakDays();
    }

    public CheckinDtos.HistoryResponse history(Long circleId, Long userId) {
        List<CheckinRecord> records = checkinRecordRepository.findByUserIdOrderByCheckinDateDesc(userId);
        Map<Long, RatingDtos.RatingSummary> ratings = ratingService.summaries(
                circleId, records.stream().map(CheckinRecord::getId).toList(), userId);
        List<CheckinDtos.HistoryItem> items = records.stream()
                .map(r -> {
                    RatingDtos.RatingSummary s = ratings.get(r.getId());
                    return new CheckinDtos.HistoryItem(
                            r.getCheckinDate(),
                            r.getLevel(),
                            r.getTaskContent(),
                            r.getPointsEarned(),
                            r.getTextContent(),
                            r.getImageUrl(),
                            s == null || !s.ratingComplete() ? null : s.avgScore(),
                            s == null ? 0 : s.ratingCount());
                })
                .toList();
        return new CheckinDtos.HistoryResponse(items);
    }

    public CheckinDtos.CalendarResponse calendar(Long userId, int days) {
        int span = Math.min(Math.max(days, 7), 180);
        LocalDate today = drawService.today();
        LocalDate from = today.minusDays(span - 1L);
        List<DailyDraw> draws = dailyDrawRepository.findByUserIdAndDrawDateGreaterThanEqualOrderByDrawDateDesc(userId, from);
        java.util.Map<LocalDate, DailyDraw> byDate = draws.stream()
                .collect(java.util.stream.Collectors.toMap(DailyDraw::getDrawDate, d -> d, (a, b) -> a));
        List<CheckinDtos.CalendarDay> items = new java.util.ArrayList<>(span);
        for (LocalDate d = from; !d.isAfter(today); d = d.plusDays(1)) {
            DailyDraw draw = byDate.get(d);
            String status;
            if (draw == null) {
                status = "NONE";
            } else if (draw.getStatus() == DrawStatus.COMPLETED) {
                status = "COMPLETED";
            } else if (d.equals(today)) {
                status = "PENDING";
            } else {
                status = "MISSED";
            }
            items.add(new CheckinDtos.CalendarDay(d, status));
        }
        return new CheckinDtos.CalendarResponse(items);
    }

    private int calcNewStreak(User user, LocalDate date) {
        if (user.getLastCheckinDate() != null && user.getLastCheckinDate().plusDays(1).equals(date)) {
            return user.getStreakDays() + 1;
        }
        return 1;
    }

    private void applyPoints(User user, int delta, PointChangeType type, Long relatedId) {
        pointsService.apply(user, delta, type, relatedId);
    }

    static int streakBonusPoints(int streakDays) {
        int bonus = 0;
        if (streakDays > 0 && streakDays % 7 == 0) {
            bonus += 10;
        }
        if (streakDays > 0 && streakDays % 30 == 0) {
            bonus += 50;
        }
        return bonus;
    }

    private CheckinDtos.TodayResponse toToday(Long circleId, User user, DailyDraw draw) {
        CheckinRecord record = null;
        String imageUrl = null;
        String textContent = null;
        if (draw.getStatus() == DrawStatus.COMPLETED) {
            record = checkinRecordRepository.findByUserIdAndCheckinDate(user.getId(), draw.getDrawDate()).orElse(null);
            if (record != null) {
                imageUrl = record.getImageUrl();
                textContent = record.getTextContent();
            }
        }
        return toToday(circleId, user, draw, imageUrl, textContent, record);
    }

    private CheckinDtos.TodayResponse toToday(Long circleId, User user, DailyDraw draw,
                                              String imageUrl, String textContent, CheckinRecord record) {
        boolean completed = draw.getStatus() == DrawStatus.COMPLETED;
        int streakForBonus = completed
                ? user.getStreakDays()
                : calcNewStreak(user, draw.getDrawDate());
        Instant completedAt = record == null ? null : record.getCreatedAt();
        CirclePulse pulse = circlePulse(circleId, user.getId(), draw.getDrawDate());
        return new CheckinDtos.TodayResponse(
                draw.getDrawDate(),
                draw.getLevel(),
                draw.getLevel().getDisplayName(),
                draw.getFortuneText(),
                draw.getTaskContent(),
                draw.getBasePoints(),
                drawService.rewardPoints(draw),
                Boolean.TRUE.equals(draw.getLuckyStar()),
                draw.getStatus(),
                user.getPoints(),
                user.getTitle(),
                user.getStreakDays(),
                user.getTotalCompletedDays(),
                titleService.nextTitle(user.getTotalCompletedDays()),
                titleService.daysToNextTitle(user.getTotalCompletedDays()),
                titleService.nextTitleAt(user.getTotalCompletedDays()),
                user.getTag().name(),
                imageUrl,
                textContent,
                completedAt,
                streakBonusPoints(streakForBonus),
                calendar(user.getId(), 7).days(),
                pulse.memberCount(),
                pulse.completedCount(),
                pulse.pendingNicknames()
        );
    }

    private CirclePulse circlePulse(Long circleId, Long viewerUserId, LocalDate date) {
        List<CircleMember> members = circleMemberRepository.findByCircleId(circleId);
        Set<Long> memberIds = members.stream().map(CircleMember::getUserId).collect(Collectors.toSet());
        Map<Long, User> users = userRepository.findAllById(memberIds).stream()
                .collect(Collectors.toMap(User::getId, u -> u, (a, b) -> a));
        Map<Long, DailyDraw> draws = dailyDrawRepository.findByDrawDate(date).stream()
                .filter(d -> memberIds.contains(d.getUserId()))
                .collect(Collectors.toMap(DailyDraw::getUserId, d -> d, (a, b) -> a));

        int memberCount = 0;
        int completedCount = 0;
        List<String> pending = new ArrayList<>();
        for (Long id : memberIds) {
            User u = users.get(id);
            if (u == null || u.getTag() == UserTag.DORMANT) {
                continue;
            }
            memberCount++;
            DailyDraw d = draws.get(id);
            if (d != null && d.getStatus() == DrawStatus.COMPLETED) {
                completedCount++;
            } else if (!id.equals(viewerUserId)) {
                String nick = u.getNickname();
                if (nick != null && !nick.isBlank()) {
                    pending.add(nick);
                }
            }
        }
        if (pending.size() > 5) {
            pending = new ArrayList<>(pending.subList(0, 5));
        }
        return new CirclePulse(memberCount, completedCount, pending);
    }

    private record CirclePulse(int memberCount, int completedCount, List<String> pendingNicknames) {
    }
}
