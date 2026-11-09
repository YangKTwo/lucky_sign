package com.luckysign.service;

import com.luckysign.common.IsolatedTx;
import com.luckysign.domain.UserTag;
import com.luckysign.entity.CircleMember;
import com.luckysign.entity.User;
import com.luckysign.repository.CircleDailyStarRepository;
import com.luckysign.repository.CircleMemberRepository;
import com.luckysign.repository.CircleRepository;
import com.luckysign.repository.DailyDrawRepository;
import com.luckysign.repository.FortuneCopyRepository;
import com.luckysign.repository.TaskItemRepository;
import com.luckysign.repository.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.List;
import java.util.Optional;
import java.util.concurrent.atomic.AtomicInteger;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.doAnswer;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class DrawServiceGenerateTest {
    @Mock
    private UserRepository userRepository;
    @Mock
    private DailyDrawRepository dailyDrawRepository;
    @Mock
    private TaskItemRepository taskItemRepository;
    @Mock
    private FortuneCopyRepository fortuneCopyRepository;
    @Mock
    private CircleRepository circleRepository;
    @Mock
    private CircleMemberRepository circleMemberRepository;
    @Mock
    private CircleDailyStarRepository circleDailyStarRepository;
    @Mock
    private IsolatedTx isolatedTx;

    private DrawService drawService;

    @BeforeEach
    void setUp() {
        drawService = new DrawService(
                userRepository, dailyDrawRepository, taskItemRepository, fortuneCopyRepository,
                circleRepository, circleMemberRepository, circleDailyStarRepository, isolatedTx);
    }

    @Test
    void generateContinuesAfterOneUserFails() {
        CircleMember m1 = member(1L);
        CircleMember m2 = member(2L);
        when(circleMemberRepository.findByCircleId(9L)).thenReturn(List.of(m1, m2));
        User u1 = user(1L);
        User u2 = user(2L);
        when(userRepository.findByTagNot(UserTag.DORMANT)).thenReturn(List.of(u1, u2));
        when(circleDailyStarRepository.findByCircleIdAndStarDate(any(), any())).thenReturn(Optional.empty());
        when(userRepository.findByTagNot(UserTag.DORMANT)).thenReturn(List.of(u1, u2));
        AtomicInteger runs = new AtomicInteger();
        doAnswer(inv -> {
            int n = runs.getAndIncrement();
            if (n == 1) {
                throw new RuntimeException("user boom");
            }
            inv.getArgument(0, Runnable.class).run();
            return null;
        }).when(isolatedTx).run(any());
        when(dailyDrawRepository.findByUserIdAndDrawDate(2L, drawService.today()))
                .thenReturn(Optional.of(new com.luckysign.entity.DailyDraw()));

        drawService.generateForAllActiveUsers(9L);

        verify(isolatedTx, times(3)).run(any());
    }

    private static CircleMember member(Long userId) {
        CircleMember m = new CircleMember();
        m.setCircleId(9L);
        m.setUserId(userId);
        return m;
    }

    private static User user(Long id) {
        User u = new User();
        u.setId(id);
        u.setTag(UserTag.NONE);
        return u;
    }
}
