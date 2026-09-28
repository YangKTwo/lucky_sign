package com.luckysign.service;

import com.luckysign.domain.UserTag;
import com.luckysign.entity.CircleMember;
import com.luckysign.entity.DailyDraw;
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

import java.time.LocalDate;
import java.time.ZoneId;
import java.util.List;
import java.util.Optional;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.*;

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

    private DrawService drawService;

    @BeforeEach
    void setUp() {
        drawService = new DrawService(
                userRepository, dailyDrawRepository, taskItemRepository,
                fortuneCopyRepository, circleRepository, circleMemberRepository,
                circleDailyStarRepository);
    }

    @Test
    void generateContinuesWhenOneUserFails() {
        LocalDate today = LocalDate.now(ZoneId.of("Asia/Shanghai"));
        CircleMember m1 = member(1L);
        CircleMember m2 = member(2L);
        User u1 = user(1L);
        User u2 = user(2L);
        DailyDraw existing = new DailyDraw();
        existing.setId(20L);
        existing.setUserId(2L);

        when(circleDailyStarRepository.findByCircleIdAndStarDate(eq(9L), any())).thenReturn(Optional.empty());
        when(circleMemberRepository.findByCircleId(9L)).thenReturn(List.of(m1, m2));
        when(userRepository.findByTagNot(UserTag.DORMANT)).thenReturn(List.of(u1, u2));
        when(dailyDrawRepository.findByUserIdAndDrawDate(1L, today)).thenThrow(new RuntimeException("user 1 boom"));
        when(dailyDrawRepository.findByUserIdAndDrawDate(2L, today)).thenReturn(Optional.of(existing));

        drawService.generateForAllActiveUsers(9L);

        verify(dailyDrawRepository).findByUserIdAndDrawDate(1L, today);
        verify(dailyDrawRepository).findByUserIdAndDrawDate(2L, today);
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
