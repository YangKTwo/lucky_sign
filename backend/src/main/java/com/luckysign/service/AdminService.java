package com.luckysign.service;

import com.luckysign.common.BizException;
import com.luckysign.domain.UserTag;
import com.luckysign.dto.AuthDtos;
import com.luckysign.entity.User;
import com.luckysign.repository.CircleMemberRepository;
import com.luckysign.repository.UserRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Service
public class AdminService {
    private final UserRepository userRepository;
    private final CircleMemberRepository circleMemberRepository;
    private final ChatService chatService;
    private final TitleService titleService;

    public AdminService(UserRepository userRepository,
                        CircleMemberRepository circleMemberRepository,
                        ChatService chatService,
                        TitleService titleService) {
        this.userRepository = userRepository;
        this.circleMemberRepository = circleMemberRepository;
        this.chatService = chatService;
        this.titleService = titleService;
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
