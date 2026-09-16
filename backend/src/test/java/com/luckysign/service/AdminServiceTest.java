package com.luckysign.service;

import com.luckysign.common.BizException;
import com.luckysign.domain.AccountStatus;
import com.luckysign.domain.MemberRole;
import com.luckysign.domain.UserRole;
import com.luckysign.domain.UserTag;
import com.luckysign.dto.AdminDtos;
import com.luckysign.entity.Circle;
import com.luckysign.entity.CircleMember;
import com.luckysign.entity.User;
import com.luckysign.repository.CircleMemberRepository;
import com.luckysign.repository.CircleRepository;
import com.luckysign.repository.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.Instant;
import java.util.List;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class AdminServiceTest {
    @Mock
    private UserRepository userRepository;
    @Mock
    private CircleRepository circleRepository;
    @Mock
    private CircleMemberRepository circleMemberRepository;
    @Mock
    private ChatService chatService;
    @Mock
    private TitleService titleService;

    private AdminService adminService;

    @BeforeEach
    void setUp() {
        adminService = new AdminService(
                userRepository, circleRepository, circleMemberRepository, chatService, titleService);
    }

    @Test
    void listsPendingRegistrations() {
        User pending = pendingUser(9L);
        when(userRepository.findByApprovalStatusOrderByCreatedAtAsc(AccountStatus.PENDING))
                .thenReturn(List.of(pending));

        AdminDtos.PendingListResponse res = adminService.pendingRegistrations();
        assertEquals(1, res.users().size());
        assertEquals("小明", res.users().get(0).nickname());
        assertEquals("a@b.com", res.users().get(0).email());
    }

    @Test
    void approveJoinsCircleAndActivates() {
        User pending = pendingUser(9L);
        Circle circle = new Circle();
        circle.setId(1L);
        circle.setMaxMembers(10);
        circle.setMemberCount(3);

        when(userRepository.findById(9L)).thenReturn(Optional.of(pending));
        when(circleRepository.findById(1L)).thenReturn(Optional.of(circle));
        when(circleMemberRepository.existsByCircleIdAndUserId(1L, 9L)).thenReturn(false);
        when(circleRepository.incrementMemberCount(1L)).thenReturn(1);
        when(userRepository.save(any(User.class))).thenAnswer(inv -> inv.getArgument(0));

        adminService.approveRegistration(9L);

        assertEquals(AccountStatus.ACTIVE, pending.getApprovalStatus());
        assertEquals(Boolean.TRUE, pending.getEnabled());
        assertNull(pending.getPendingCircleId());

        ArgumentCaptor<CircleMember> member = ArgumentCaptor.forClass(CircleMember.class);
        verify(circleMemberRepository).save(member.capture());
        assertEquals(MemberRole.MEMBER, member.getValue().getRole());
        verify(chatService).postSystem(1L, "小明 加入了圈子");
    }

    @Test
    void rejectDeletesPendingUser() {
        User pending = pendingUser(9L);
        when(userRepository.findById(9L)).thenReturn(Optional.of(pending));

        adminService.rejectRegistration(9L);

        verify(userRepository).delete(pending);
        verify(circleMemberRepository, never()).save(any());
    }

    @Test
    void approveRejectsAlreadyActiveUser() {
        User user = pendingUser(9L);
        user.setApprovalStatus(AccountStatus.ACTIVE);
        user.setEnabled(true);
        when(userRepository.findById(9L)).thenReturn(Optional.of(user));

        BizException ex = assertThrows(BizException.class, () -> adminService.approveRegistration(9L));
        assertEquals("该用户无需审批", ex.getMessage());
    }

    private User pendingUser(Long id) {
        User user = new User();
        user.setId(id);
        user.setEmail("a@b.com");
        user.setNickname("小明");
        user.setPasswordHash("hash");
        user.setRole(UserRole.USER);
        user.setTag(UserTag.NONE);
        user.setEnabled(false);
        user.setApprovalStatus(AccountStatus.PENDING);
        user.setPendingCircleId(1L);
        user.setCreatedAt(Instant.parse("2026-09-16T00:00:00Z"));
        return user;
    }
}
