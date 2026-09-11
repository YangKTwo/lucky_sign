package com.luckysign.service;

import com.luckysign.domain.PointChangeType;
import com.luckysign.entity.PointsLog;
import com.luckysign.entity.User;
import com.luckysign.repository.PointsLogRepository;
import org.springframework.stereotype.Service;

@Service
public class PointsService {
    private final PointsLogRepository pointsLogRepository;

    public PointsService(PointsLogRepository pointsLogRepository) {
        this.pointsLogRepository = pointsLogRepository;
    }

    /**
     * 调整积分并记账；余额不会低于 0。返回实际 delta（可能因下限截断而小于请求值）。
     */
    public int apply(User user, int delta, PointChangeType type, Long relatedId) {
        int next = Math.max(0, user.getPoints() + delta);
        int actual = next - user.getPoints();
        user.setPoints(next);
        PointsLog log = new PointsLog();
        log.setUserId(user.getId());
        log.setChangeType(type);
        log.setDelta(actual);
        log.setBalanceAfter(next);
        log.setRelatedId(relatedId);
        pointsLogRepository.save(log);
        return actual;
    }

    /** 将积分清零并记账。 */
    public void resetToZero(User user, PointChangeType type, Long relatedId) {
        apply(user, -user.getPoints(), type, relatedId);
    }
}
