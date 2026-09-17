package com.luckysign.service;

import com.luckysign.common.BizException;
import com.luckysign.domain.AccountStatus;
import com.luckysign.domain.MemberRole;
import com.luckysign.domain.UserTag;
import com.luckysign.dto.AdminDtos;
import com.luckysign.dto.AuthDtos;
import com.luckysign.entity.Circle;
import com.luckysign.entity.CircleMember;
import com.luckysign.entity.User;
import com.luckysign.repository.CircleMemberRepository;
import com.luckysign.repository.CircleRepository;
import com.luckysign.repository.UserRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Service
public class AdminService {
    private final UserRepository userRepository;
    private final CircleRepository circleRepository;
    private final CircleMemberRepository circleMemberRepository;
    private final ChatService chatService;
    private final TitleService titleService;

    public AdminService(UserRepository userRepository,
                        CircleRepository circleRepository,
                        CircleMemberRepository circleMemberRepository,
                        ChatService chatService,
                        TitleService titleService) {
        this.userRepository = userRepository;
        this.circleRepository = circleRepository;
        this.circleMemberRepository = circleMemberRepository;
        this.chatService = chatService;
        this.titleService = titleService;
    }

    public AdminDtos.PendingListResponse pendingRegistrations() {
        List<AdminDtos.PendingRegistration> users = userRepository
                .findByApprovalStatusOrderByCreatedAtAsc(AccountStatus.PENDING)
                .stream()
                .map(u -> new AdminDtos.PendingRegistration(
                        u.getId(),
                        u.getNickname(),
                        u.getEmail(),
                        u.getCreatedAt(),
                        u.getPendingCircleId()))
                .toList();
        return new AdminDtos.PendingListResponse(users);
    }

    @Transactional
    public AuthDtos.UserProfileResponse approveRegistration(Long userId) {
        User user = userRepository.findById(userId).orElseThrow(() -> new BizException("用户不存在"));
        if (user.getApprovalStatus() != AccountStatus.PENDING) {
            throw new BizException("该用户无需审批");
        }
        Long circleId = user.getPendingCircleId();
        if (circleId == null) {
            throw new BizException("注册申请缺少圈子信息");
        }
        Circle circle = circleRepository.findById(circleId)
                .orElseThrow(() -> new BizException("圈子不存在"));

        joinCircle(user, circle);

        user.setApprovalStatus(AccountStatus.ACTIVE);
        user.setEnabled(true);
        user.setPendingCircleId(null);
        userRepository.save(user);

        chatService.postSystem(circle.getId(), user.getNickname() + " 加入了圈子");
        String welcome = "@" + user.getNickname() + " 欢迎加入圈子～有问题可以问我。";
        chatService.postAssistant(circle.getId(), welcome, List.of(user.getId()));
        return AuthService.toProfile(user);
    }

    @Transactional
    public void rejectRegistration(Long userId) {
        User user = userRepository.findById(userId).orElseThrow(() -> new BizException("用户不存在"));
        if (user.getApprovalStatus() != AccountStatus.PENDING) {
            throw new BizException("该用户无需审批");
        }
        userRepository.delete(user);
    }

    private void joinCircle(User user, Circle circle) {
        if (circleMemberRepository.existsByCircleIdAndUserId(circle.getId(), user.getId())) {
            return;
        }
        int updated = circleRepository.incrementMemberCount(circle.getId());
        if (updated == 0) {
            throw new BizException("圈子已满员");
        }
        try {
            CircleMember member = new CircleMember();
            member.setCircleId(circle.getId());
            member.setUserId(user.getId());
            member.setRole(MemberRole.MEMBER);
            circleMemberRepository.save(member);
        } catch (org.springframework.dao.DataIntegrityViolationException e) {
            circleRepository.decrementMemberCount(circle.getId());
            if (!circleMemberRepository.existsByCircleIdAndUserId(circle.getId(), user.getId())) {
                throw new BizException("加入圈子失败，请稍后重试");
            }
        }
    }

    @Transactional
    public AuthDtos.UserProfileResponse unlock(Long userId) {
        User user = userRepository.findById(userId).orElseThrow(() -> new BizException("用户不存在"));
        user.setTag(UserTag.NONE);
        user.setMissStreakDays(0);
        user.setTitle(titleService.resolve(user.getTotalCompletedDays()));
        userRepository.save(user);

        List<Long> circleIds = circleMemberRepository.findCircleIdsByUserId(userId);
        for (Long circleId : circleIds) {
            chatService.postSystem(circleId, user.getNickname() + " 已被管理员解除休眠");
        }
        return AuthService.toProfile(user);
    }
}
