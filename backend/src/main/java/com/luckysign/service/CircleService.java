package com.luckysign.service;

import com.luckysign.common.BizException;
import com.luckysign.common.InviteCodes;
import com.luckysign.dto.CircleDtos;
import com.luckysign.entity.Circle;
import com.luckysign.entity.CircleMember;
import com.luckysign.entity.User;
import com.luckysign.repository.CircleMemberRepository;
import com.luckysign.repository.CircleRepository;
import com.luckysign.repository.UserRepository;
import org.springframework.stereotype.Service;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.function.Function;
import java.util.stream.Collectors;

@Service
public class CircleService {
    private final CircleRepository circleRepository;
    private final CircleMemberRepository circleMemberRepository;
    private final UserRepository userRepository;

    public CircleService(CircleRepository circleRepository,
                         CircleMemberRepository circleMemberRepository,
                         UserRepository userRepository) {
        this.circleRepository = circleRepository;
        this.circleMemberRepository = circleMemberRepository;
        this.userRepository = userRepository;
    }

    public CircleDtos.MembersResponse mentionCandidates(Long circleId, Long viewerUserId) {
        List<CircleMember> members = circleMemberRepository.findByCircleId(circleId);
        Map<Long, User> users = userRepository.findAllById(members.stream().map(CircleMember::getUserId).toList())
                .stream()
                .collect(Collectors.toMap(User::getId, Function.identity()));
        List<CircleDtos.MemberBrief> list = new ArrayList<>();
        list.add(new CircleDtos.MemberBrief(
                null,
                MentionService.ASSISTANT_DISPLAY_NAME,
                null,
                true));
        for (CircleMember m : members) {
            User u = users.get(m.getUserId());
            if (u == null) {
                continue;
            }
            if (viewerUserId != null && viewerUserId.equals(u.getId())) {
                continue;
            }
            list.add(new CircleDtos.MemberBrief(u.getId(), u.getNickname(), u.getAvatarUrl(), false));
        }
        return new CircleDtos.MembersResponse(list);
    }

    public CircleDtos.CircleMeResponse me(Long circleId, Long userId) {
        Circle circle = circleRepository.findById(circleId)
                .orElseThrow(() -> new BizException("圈子不存在"));
        if (userId == null || !circleMemberRepository.existsByCircleIdAndUserId(circle.getId(), userId)) {
            throw new BizException("你不在这个圈子里");
        }
        if (circle.getInviteCode() == null || circle.getInviteCode().isBlank()) {
            circle.setInviteCode(uniqueInviteCode());
            circle = circleRepository.save(circle);
        }
        return new CircleDtos.CircleMeResponse(
                circle.getId(),
                circle.getName(),
                circle.getInviteCode(),
                circle.getMemberCount(),
                circle.getMaxMembers());
    }

    public String uniqueInviteCode() {
        for (int i = 0; i < 30; i++) {
            String code = InviteCodes.random();
            if (!circleRepository.existsByInviteCode(code)) {
                return code;
            }
        }
        throw new BizException("无法生成邀请码，请稍后重试");
    }
}
