package com.luckysign.security;

import com.luckysign.common.BizException;
import com.luckysign.repository.CircleMemberRepository;
import com.luckysign.repository.CircleRepository;
import org.springframework.stereotype.Component;

@Component
public class CircleAccessGuard {

    private final CircleRepository circleRepository;
    private final CircleMemberRepository circleMemberRepository;

    public CircleAccessGuard(CircleRepository circleRepository, CircleMemberRepository circleMemberRepository) {
        this.circleRepository = circleRepository;
        this.circleMemberRepository = circleMemberRepository;
    }

    public Long getDefaultCircleId() {
        return circleRepository.findFirstByOrderByIdAsc()
                .orElseThrow(() -> new BizException("默认圈子未初始化"))
                .getId();
    }

    public void requireMember(Long userId) {
        Long circleId = getDefaultCircleId();
        requireMember(circleId, userId);
    }

    public void requireMember(Long circleId, Long userId) {
        if (userId == null) {
            throw new BizException("未登录");
        }
        if (!circleMemberRepository.existsByCircleIdAndUserId(circleId, userId)) {
            throw new BizException("你不在这个圈子里");
        }
    }

    public boolean isMember(Long userId) {
        if (userId == null) {
            return false;
        }
        Long circleId = getDefaultCircleId();
        return circleMemberRepository.existsByCircleIdAndUserId(circleId, userId);
    }

    public boolean isMember(Long circleId, Long userId) {
        if (userId == null || circleId == null) {
            return false;
        }
        return circleMemberRepository.existsByCircleIdAndUserId(circleId, userId);
    }
}
