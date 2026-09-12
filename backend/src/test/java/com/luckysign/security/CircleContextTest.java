package com.luckysign.security;

import com.luckysign.common.BizException;
import com.luckysign.repository.CircleMemberRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.List;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class CircleContextTest {

    @Mock
    private CircleMemberRepository circleMemberRepository;

    private CircleContext circleContext;

    @BeforeEach
    void setUp() {
        circleContext = new CircleContext(circleMemberRepository);
    }

    @Test
    void resolveCircleIdReturnsRequestCircleIdWhenProvided() {
        Long result = circleContext.resolveCircleId(5L, 1L);
        assertEquals(5L, result);
        verifyNoInteractions(circleMemberRepository);
    }

    @Test
    void resolveCircleIdUsesUserMembershipWhenRequestCircleIdIsNull() {
        when(circleMemberRepository.findFirstCircleIdByUserId(1L)).thenReturn(Optional.of(3L));
        
        Long result = circleContext.resolveCircleId(null, 1L);
        assertEquals(3L, result);
    }

    @Test
    void resolveCircleIdThrowsWhenUserIdIsNull() {
        BizException ex = assertThrows(BizException.class, 
            () -> circleContext.resolveCircleId(null, null));
        assertEquals("未登录", ex.getMessage());
    }

    @Test
    void getUserCircleIdThrowsWhenUserNotInAnyCircle() {
        when(circleMemberRepository.findFirstCircleIdByUserId(1L)).thenReturn(Optional.empty());
        
        BizException ex = assertThrows(BizException.class, 
            () -> circleContext.getUserCircleId(1L));
        assertEquals("你还没有加入任何圈子", ex.getMessage());
    }

    @Test
    void getUserCircleIdsReturnsAllCircles() {
        when(circleMemberRepository.findCircleIdsByUserId(1L)).thenReturn(List.of(2L, 5L, 8L));
        
        List<Long> result = circleContext.getUserCircleIds(1L);
        assertEquals(List.of(2L, 5L, 8L), result);
    }

    @Test
    void getUserCircleIdsReturnsEmptyForNullUser() {
        List<Long> result = circleContext.getUserCircleIds(null);
        assertTrue(result.isEmpty());
    }

    @Test
    void isUserInCircleReturnsTrueWhenMember() {
        when(circleMemberRepository.existsByCircleIdAndUserId(3L, 1L)).thenReturn(true);
        assertTrue(circleContext.isUserInCircle(1L, 3L));
    }

    @Test
    void isUserInCircleReturnsFalseWhenNotMember() {
        when(circleMemberRepository.existsByCircleIdAndUserId(3L, 1L)).thenReturn(false);
        assertFalse(circleContext.isUserInCircle(1L, 3L));
    }

    @Test
    void isUserInCircleReturnsFalseForNullInputs() {
        assertFalse(circleContext.isUserInCircle(null, 3L));
        assertFalse(circleContext.isUserInCircle(1L, null));
        assertFalse(circleContext.isUserInCircle(null, null));
    }
}
