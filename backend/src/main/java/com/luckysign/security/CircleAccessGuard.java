package com.luckysign.security;

import com.luckysign.common.BizException;
import com.luckysign.repository.CircleMemberRepository;
import org.springframework.stereotype.Component;

@Component
public class CircleAccessGuard {

    private final CircleMemberRepository circleMemberRepository;
    private final CircleContext circleContext;

    public CircleAccessGuard(CircleMemberRepository circleMemberRepository, CircleContext circleContext) {
        this.circleMemberRepository = circleMemberRepository;
        this.circleContext = circleContext;
    }

    public void requireMember(Long circleId, Long userId) {
        if (userId == null) {
            throw new BizException("未登录");
        }
        if (circleId == null) {
            throw new BizException("请指定圈子");
        }
        if (!circleMemberRepository.existsByCircleIdAndUserId(circleId, userId)) {
            throw new BizException("你不在这个圈子里");
        }
    }

    public Long requireMemberAndResolve(Long requestCircleId, Long userId) {
        if (userId == null) {
            throw new BizException("未登录");
        }
        Long circleId = circleContext.resolveCircleId(requestCircleId, userId);
        requireMember(circleId, userId);
        return circleId;
    }

    public boolean isMember(Long circleId, Long userId) {
        if (userId == null || circleId == null) {
            return false;
        }
        return circleMemberRepository.existsByCircleIdAndUserId(circleId, userId);
    }

    public Long getUserCircleId(Long userId) {
        return circleContext.getUserCircleId(userId);
    }
}
