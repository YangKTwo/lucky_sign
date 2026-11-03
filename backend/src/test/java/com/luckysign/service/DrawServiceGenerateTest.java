package com.luckysign.service;

import com.luckysign.common.IsolatedTx;
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
import java.util.List;
import java.util.Optional;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.function.Supplier;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class DrawServiceGenerateTest {
    @Mock private UserRepository userRepository;
    @Mock private DailyDrawRepository dailyDrawRepository;
    @Mock private TaskItemRepository taskItemRepository;
    @Mock private FortuneCopyRepository fortuneCopyRepository;
    @Mock private CircleRepository circleRepository;
    @Mock private CircleMemberRepository circleMemberRepository;
    @Mock private CircleDailyStarRepository circleDailyStarRepository;
    @Mock private IsolatedTx isolatedTx;

    private DrawService drawService;

    @BeforeEach
    void setUp() {
        drawService = new DrawService(
                userRepository, dailyDrawRepository, taskItemRepository, fortuneCopyRepository,
                circleRepository, circleMemberRepository, circleDailyStarRepository, isolatedTx);
        lenient().doAnswer(inv -> {
            inv.getArgument(0, Runnable.class).run();
            return null;
        }).when(isolatedTx).run(any());
        lenient().doAnswer(inv -> inv.getArgument(0, Supplier.class).get()).when(isolatedTx).call(any());
    }

    @Test
    void generateContinuesWhenOneUserFails() {
        LocalDate today = LocalDate.of(2026, 11, 3);
        DrawService spy = spy(drawService);
        doReturn(today).when(spy).today();

        CircleMember m1 = member(1L);
        CircleMember m2 = member(2L);
        User u1 = user(1L);
        User u2 = user(2L);
        when(circleMemberRepository.findByCircleId(9L)).thenReturn(List.of(m1, m2));
        when(userRepository.findByTagNot(UserTag.DORMANT)).thenReturn(List.of(u1, u2));
        when(circleDailyStarRepository.findByCircleIdAndStarDate(9L, today)).thenReturn(Optional.empty());
        when(circleDailyStarRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));

        AtomicInteger calls = new AtomicInteger();
        doAnswer(inv -> {
            Supplier<?> work = inv.getArgument(0, Supplier.class);
            if (calls.getAndIncrement() == 0) {
                throw new RuntimeException("user 1 boom");
            }
            return work.get();
        }).when(isolatedTx).call(any());

        DailyDraw existing = new DailyDraw();
        existing.setId(20L);
        when(dailyDrawRepository.findByUserIdAndDrawDate(2L, today)).thenReturn(Optional.of(existing));

        spy.generateForAllActiveUsers(9L);

        verify(dailyDrawRepository).findByUserIdAndDrawDate(2L, today);
    }

    private static CircleMember member(Long userId) {
        CircleMember m = new CircleMember();
        m.setCircleId(9L);
        m.setUserId(userId);
        return m;
    }

    private static User user(Long id) {
        User user = new User();
        user.setId(id);
        user.setNickname("u" + id);
        user.setTag(UserTag.NONE);
        return user;
    }
}
