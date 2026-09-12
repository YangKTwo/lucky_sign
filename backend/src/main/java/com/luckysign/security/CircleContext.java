package com.luckysign.security;

import com.luckysign.common.BizException;
import com.luckysign.repository.CircleMemberRepository;
import org.springframework.stereotype.Component;

import java.util.List;

@Component
public class CircleContext {
    private final CircleMemberRepository circleMemberRepository;

    public CircleContext(CircleMemberRepository circleMemberRepository) {
        this.circleMemberRepository = circleMemberRepository;
    }

    public Long resolveCircleId(Long requestCircleId, Long userId) {
        if (requestCircleId != null) {
            return requestCircleId;
        }
        if (userId == null) {
            throw new BizException("未登录");
        }
        return getUserCircleId(userId);
    }

    public Long getUserCircleId(Long userId) {
        if (userId == null) {
            throw new BizException("未登录");
        }
        return circleMemberRepository.findFirstCircleIdByUserId(userId)
                .orElseThrow(() -> new BizException("你还没有加入任何圈子"));
    }

    public List<Long> getUserCircleIds(Long userId) {
        if (userId == null) {
            return List.of();
        }
        return circleMemberRepository.findCircleIdsByUserId(userId);
    }

    public boolean isUserInCircle(Long userId, Long circleId) {
        if (userId == null || circleId == null) {
            return false;
        }
        return circleMemberRepository.existsByCircleIdAndUserId(circleId, userId);
    }
}
