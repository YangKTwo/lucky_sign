package com.luckysign.service;

import com.luckysign.common.BizException;
import com.luckysign.dto.RatingDtos;
import com.luckysign.entity.CheckinRating;
import com.luckysign.entity.CheckinRecord;
import com.luckysign.repository.CheckinRatingRepository;
import com.luckysign.repository.CheckinRecordRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

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

    public RatingService(CheckinRatingRepository checkinRatingRepository,
                         CheckinRecordRepository checkinRecordRepository) {
        this.checkinRatingRepository = checkinRatingRepository;
        this.checkinRecordRepository = checkinRecordRepository;
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

    public RatingDtos.RatingSummary summary(Long checkinId, Long viewerUserId) {
        List<CheckinRating> list = checkinRatingRepository.findByCheckinId(checkinId);
        return toSummary(checkinId, list, viewerUserId);
    }

    public Map<Long, RatingDtos.RatingSummary> summaries(Collection<Long> checkinIds, Long viewerUserId) {
        if (checkinIds == null || checkinIds.isEmpty()) {
            return Map.of();
        }
        Map<Long, List<CheckinRating>> grouped = checkinRatingRepository.findByCheckinIdIn(checkinIds).stream()
                .collect(Collectors.groupingBy(CheckinRating::getCheckinId));
        Map<Long, RatingDtos.RatingSummary> map = new HashMap<>();
        for (Long id : checkinIds) {
            map.put(id, toSummary(id, grouped.getOrDefault(id, List.of()), viewerUserId));
        }
        return map;
    }

    /** 每位用户收到的平均互评分。 */
    public Map<Long, Double> avgScoreByUser() {
        Map<Long, Double> map = new HashMap<>();
        for (Object[] row : checkinRatingRepository.avgByTargetUser()) {
            Long userId = (Long) row[0];
            Double avg = row[1] == null ? null : ((Number) row[1]).doubleValue();
            if (userId != null && avg != null) {
                map.put(userId, avg);
            }
        }
        return map;
    }

    private RatingDtos.RatingSummary toSummary(Long checkinId, List<CheckinRating> list, Long viewerUserId) {
        if (list.isEmpty()) {
            return new RatingDtos.RatingSummary(checkinId, null, 0, null);
        }
        double avg = list.stream().mapToInt(CheckinRating::getScore).average().orElse(0);
        Integer my = null;
        if (viewerUserId != null) {
            Optional<CheckinRating> mine = list.stream()
                    .filter(r -> r.getRaterUserId().equals(viewerUserId))
                    .findFirst();
            my = mine.map(CheckinRating::getScore).orElse(null);
        }
        return new RatingDtos.RatingSummary(checkinId, Math.round(avg * 10) / 10.0, list.size(), my);
    }
}
