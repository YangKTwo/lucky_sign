package com.luckysign.service;

import com.luckysign.common.BizException;
import com.luckysign.dto.RatingDtos;
import com.luckysign.entity.CheckinRating;
import com.luckysign.entity.CheckinRecord;
import com.luckysign.entity.Circle;
import com.luckysign.entity.User;
import com.luckysign.repository.CheckinRatingRepository;
import com.luckysign.repository.CheckinRecordRepository;
import com.luckysign.repository.CircleMemberRepository;
import com.luckysign.repository.CircleRepository;
import com.luckysign.repository.UserRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.ArrayList;
import java.util.Collection;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.stream.Collectors;

@Service
public class RatingService {
    private final CheckinRatingRepository checkinRatingRepository;
    private final CheckinRecordRepository checkinRecordRepository;
    private final CircleRepository circleRepository;
    private final CircleMemberRepository circleMemberRepository;
    private final UserRepository userRepository;

    public RatingService(CheckinRatingRepository checkinRatingRepository,
                         CheckinRecordRepository checkinRecordRepository,
                         CircleRepository circleRepository,
                         CircleMemberRepository circleMemberRepository,
                         UserRepository userRepository) {
        this.checkinRatingRepository = checkinRatingRepository;
        this.checkinRecordRepository = checkinRecordRepository;
        this.circleRepository = circleRepository;
        this.circleMemberRepository = circleMemberRepository;
        this.userRepository = userRepository;
    }

    @Transactional
    public RatingDtos.RatingSummary rate(Long raterUserId, Long checkinId, Integer score) {
        if (score == null || score < 1 || score > 5) {
            throw new BizException("请选择 1-5 分");
        }
        CheckinRecord record = checkinRecordRepository.findById(checkinId)
                .orElseThrow(() -> new BizException("打卡记录不存在"));
        if (record.getUserId().equals(raterUserId)) {
            throw new BizException("不能给自己打分");
        }
        CheckinRating rating = checkinRatingRepository.findByCheckinIdAndRaterUserId(checkinId, raterUserId)
                .orElseGet(CheckinRating::new);
        rating.setCheckinId(checkinId);
        rating.setTargetUserId(record.getUserId());
        rating.setRaterUserId(raterUserId);
        rating.setScore(score);
        checkinRatingRepository.save(rating);
        return summary(checkinId, raterUserId);
    }

    public RatingDtos.CheckinDetail detail(Long checkinId, Long viewerUserId) {
        CheckinRecord record = checkinRecordRepository.findById(checkinId)
                .orElseThrow(() -> new BizException("打卡记录不存在"));
        User user = userRepository.findById(record.getUserId()).orElse(null);
        RatingDtos.RatingSummary rating = summary(checkinId, viewerUserId);
        return new RatingDtos.CheckinDetail(
                record.getId(),
                record.getUserId(),
                user == null ? "" : user.getNickname(),
                user == null ? null : user.getAvatarUrl(),
                record.getTaskContent(),
                record.getTextContent(),
                record.getImageUrl(),
                record.getPointsEarned(),
                record.getLevel() == null ? null : record.getLevel().name(),
                record.getCheckinDate() == null ? null : record.getCheckinDate().toString(),
                rating
        );
    }

    public RatingDtos.RatingSummary summary(Long checkinId, Long viewerUserId) {
        List<CheckinRating> list = checkinRatingRepository.findByCheckinId(checkinId);
        return toSummary(checkinId, list, viewerUserId, expectedRaterCount());
    }

    public Map<Long, RatingDtos.RatingSummary> summaries(Collection<Long> checkinIds, Long viewerUserId) {
        if (checkinIds == null || checkinIds.isEmpty()) {
            return new HashMap<>();
        }
        int expected = expectedRaterCount();
        Map<Long, List<CheckinRating>> grouped = checkinRatingRepository.findByCheckinIdIn(checkinIds).stream()
                .collect(Collectors.groupingBy(CheckinRating::getCheckinId));
        Map<Long, RatingDtos.RatingSummary> map = new HashMap<>();
        for (Long id : checkinIds) {
            map.put(id, toSummary(id, grouped.getOrDefault(id, List.of()), viewerUserId, expected));
        }
        return map;
    }

    /**
     * 仅统计「全员评完」的打卡均分，再按用户求平均。
     * 综合分 = 任务积分 + 该均分 × 2。
     */
    public Map<Long, Double> finalizedAvgScoreByUser() {
        int expected = expectedRaterCount();
        if (expected <= 0) {
            return Map.of();
        }
        List<CheckinRating> all = checkinRatingRepository.findAll();
        Map<Long, List<CheckinRating>> byCheckin = all.stream()
                .collect(Collectors.groupingBy(CheckinRating::getCheckinId));
        Map<Long, List<Double>> avgs = new HashMap<>();
        for (Map.Entry<Long, List<CheckinRating>> e : byCheckin.entrySet()) {
            List<CheckinRating> list = e.getValue();
            if (list.size() < expected) {
                continue;
            }
            double avg = list.stream().mapToInt(CheckinRating::getScore).average().orElse(0);
            Long target = list.get(0).getTargetUserId();
            avgs.computeIfAbsent(target, k -> new ArrayList<>()).add(avg);
        }
        Map<Long, Double> result = new HashMap<>();
        for (Map.Entry<Long, List<Double>> e : avgs.entrySet()) {
            double mean = e.getValue().stream().mapToDouble(Double::doubleValue).average().orElse(0);
            result.put(e.getKey(), Math.round(mean * 10) / 10.0);
        }
        return result;
    }

    public int expectedRaterCount() {
        Circle circle = circleRepository.findFirstByOrderByIdAsc().orElse(null);
        if (circle == null) {
            return 0;
        }
        int members = circleMemberRepository.findByCircleId(circle.getId()).size();
        return Math.max(0, members - 1);
    }

    private RatingDtos.RatingSummary toSummary(Long checkinId, List<CheckinRating> list, Long viewerUserId, int expected) {
        Integer my = null;
        if (viewerUserId != null) {
            Optional<CheckinRating> mine = list.stream()
                    .filter(r -> r.getRaterUserId().equals(viewerUserId))
                    .findFirst();
            my = mine.map(CheckinRating::getScore).orElse(null);
        }
        boolean complete = expected > 0 && list.size() >= expected;
        Double avg = null;
        if (!list.isEmpty() && (complete || expected == 0)) {
            avg = Math.round(list.stream().mapToInt(CheckinRating::getScore).average().orElse(0) * 10) / 10.0;
        } else if (!list.isEmpty() && !complete) {
            // 未完成时不公开均分，避免半成品分数干扰
            avg = null;
        }
        if (expected == 0) {
            complete = true;
        }
        return new RatingDtos.RatingSummary(checkinId, avg, list.size(), expected, complete, my);
    }
}
