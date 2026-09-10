package com.luckysign.service;

import com.luckysign.common.BizException;
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

    public CircleDtos.MembersResponse mentionCandidates(Long viewerUserId) {
        Circle circle = circleRepository.findFirstByOrderByIdAsc()
                .orElseThrow(() -> new BizException("默认圈子未初始化"));
        List<CircleMember> members = circleMemberRepository.findByCircleId(circle.getId());
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
}
