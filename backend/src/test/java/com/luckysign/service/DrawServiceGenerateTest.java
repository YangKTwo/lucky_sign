package com.luckysign.service;

import com.luckysign.config.IsolatedTx;
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
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.atomic.AtomicInteger;

import static org.junit.jupiter.api.Assertions.assertEquals;
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

    @Test
    void generateContinuesAfterOneUserFails() {
        List<Long> attemptedUserIds = new ArrayList<>();
        IsolatedTx tx = new IsolatedTx() {
            final AtomicInteger n = new AtomicInteger();

            @Override
            public void run(Runnable work) {
                int i = n.incrementAndGet();
                if (i == 1) {
                    work.run();
                    return;
                }
                try {
                    work.run();
                } catch (RuntimeException e) {
                    if (i == 2) {
                        throw e;
                    }
                    throw e;
                }
            }
        };

        DrawService service = new DrawService(
                userRepository, dailyDrawRepository, taskItemRepository, fortuneCopyRepository,
                circleRepository, circleMemberRepository, circleDailyStarRepository, tx) {
            @Override
            public LocalDate today() {
                return LocalDate.of(2026, 10, 19);
            }

            @Override
            public void ensureLuckyStar(Long circleId, LocalDate date) {
                attemptedUserIds.add(-1L);
            }

            @Override
            public com.luckysign.entity.DailyDraw ensureDraw(Long circleId, Long userId, LocalDate date) {
                attemptedUserIds.add(userId);
                if (userId == 2L) {
                    throw new RuntimeException("task pool empty");
                }
                return new com.luckysign.entity.DailyDraw();
            }
        };

        User u1 = user(1L);
        User u2 = user(2L);
        User u3 = user(3L);
        CircleMember m1 = member(1L);
        CircleMember m2 = member(2L);
        CircleMember m3 = member(3L);

        when(circleMemberRepository.findByCircleId(9L)).thenReturn(List.of(m1, m2, m3));
        when(userRepository.findByTagNot(UserTag.DORMANT)).thenReturn(List.of(u1, u2, u3));

        service.generateForAllActiveUsers(9L);

        assertEquals(List.of(-1L, 1L, 2L, 3L), attemptedUserIds);
    }

    @Test
    void generateDoesNotAbortWhenLuckyStarFails() {
        List<Long> attempted = new ArrayList<>();
        IsolatedTx tx = new IsolatedTx() {
            @Override
            public void run(Runnable work) {
                work.run();
            }
        };
        DrawService service = new DrawService(
                userRepository, dailyDrawRepository, taskItemRepository, fortuneCopyRepository,
                circleRepository, circleMemberRepository, circleDailyStarRepository, tx) {
            @Override
            public LocalDate today() {
                return LocalDate.of(2026, 10, 19);
            }

            @Override
            public void ensureLuckyStar(Long circleId, LocalDate date) {
                throw new RuntimeException("star failed");
            }

            @Override
            public com.luckysign.entity.DailyDraw ensureDraw(Long circleId, Long userId, LocalDate date) {
                attempted.add(userId);
                return new com.luckysign.entity.DailyDraw();
            }
        };

        User u1 = user(1L);
        when(circleMemberRepository.findByCircleId(9L)).thenReturn(List.of(member(1L)));
        when(userRepository.findByTagNot(UserTag.DORMANT)).thenReturn(List.of(u1));

        service.generateForAllActiveUsers(9L);

        assertEquals(List.of(1L), attempted);
    }

    private static User user(Long id) {
        User u = new User();
        u.setId(id);
        u.setTag(UserTag.NONE);
        return u;
    }

    private static CircleMember member(Long userId) {
        CircleMember m = new CircleMember();
        m.setCircleId(9L);
        m.setUserId(userId);
        return m;
    }
}
