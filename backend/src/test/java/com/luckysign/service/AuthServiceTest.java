package com.luckysign.service;

import com.luckysign.common.BizException;
import com.luckysign.domain.MemberRole;
import com.luckysign.dto.AuthDtos;
import com.luckysign.entity.Circle;
import com.luckysign.entity.CircleMember;
import com.luckysign.entity.User;
import com.luckysign.repository.CircleMemberRepository;
import com.luckysign.repository.CircleRepository;
import com.luckysign.repository.UserRepository;
import com.luckysign.security.JwtService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.security.crypto.password.PasswordEncoder;

import java.util.Optional;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class AuthServiceTest {
    @Mock
    private UserRepository userRepository;
    @Mock
    private CircleRepository circleRepository;
    @Mock
    private CircleMemberRepository circleMemberRepository;
    @Mock
    private PasswordEncoder passwordEncoder;
    @Mock
    private JwtService jwtService;
    @Mock
    private TitleService titleService;

    private AuthService authService;

    @BeforeEach
    void setUp() {
        authService = new AuthService(
                userRepository, circleRepository, circleMemberRepository,
                passwordEncoder, jwtService, titleService);
    }

    @Test
    void registerRejectsInvalidInvite() {
        when(userRepository.existsByEmail("a@b.com")).thenReturn(false);
        when(circleRepository.findByInviteCode("ABCDEF")).thenReturn(Optional.empty());

        AuthDtos.RegisterRequest req = new AuthDtos.RegisterRequest("小明", "a@b.com", "123456", "abcdef");
        BizException ex = assertThrows(BizException.class, () -> authService.register(req));
        assertEquals("邀请码无效", ex.getMessage());
        verify(userRepository, never()).save(any());
    }

    @Test
    void registerRejectsFullCircle() {
        Circle circle = new Circle();
        circle.setId(1L);
        circle.setInviteCode("ABCDEF");
        circle.setMaxMembers(2);
        circle.setMemberCount(2);
        when(userRepository.existsByEmail("a@b.com")).thenReturn(false);
        when(circleRepository.findByInviteCode("ABCDEF")).thenReturn(Optional.of(circle));

        AuthDtos.RegisterRequest req = new AuthDtos.RegisterRequest("小明", "a@b.com", "123456", "ABCDEF");
        BizException ex = assertThrows(BizException.class, () -> authService.register(req));
        assertEquals("圈子已满员", ex.getMessage());
    }

    @Test
    void registerJoinsCircleWithInvite() {
        Circle circle = new Circle();
        circle.setId(1L);
        circle.setInviteCode("ABCDEF");
        circle.setMaxMembers(10);
        circle.setMemberCount(3);
        User saved = new User();
        saved.setId(9L);
        saved.setEmail("a@b.com");
        saved.setNickname("小明");
        saved.setRole(com.luckysign.domain.UserRole.USER);
        saved.setTag(com.luckysign.domain.UserTag.NONE);
        saved.setPoints(0);
        saved.setTitle("签到萌新");
        saved.setStreakDays(0);
        saved.setTotalCompletedDays(0);

        when(userRepository.existsByEmail("a@b.com")).thenReturn(false);
        when(circleRepository.findByInviteCode("ABCDEF")).thenReturn(Optional.of(circle));
        when(titleService.resolve(0)).thenReturn("签到萌新");
        when(passwordEncoder.encode("123456")).thenReturn("hash");
        when(userRepository.save(any(User.class))).thenReturn(saved);
        when(circleMemberRepository.existsByCircleIdAndUserId(1L, 9L)).thenReturn(false);
        when(jwtService.generateToken(9L, "a@b.com", "USER")).thenReturn("token");

        AuthDtos.RegisterRequest req = new AuthDtos.RegisterRequest("小明", "a@b.com", "123456", "ab cdef");
        AuthDtos.AuthResponse res = authService.register(req);
        assertEquals("token", res.token());

        ArgumentCaptor<CircleMember> member = ArgumentCaptor.forClass(CircleMember.class);
        verify(circleMemberRepository).save(member.capture());
        assertEquals(MemberRole.MEMBER, member.getValue().getRole());
        assertEquals(4, circle.getMemberCount());
    }

    @Test
    void changePasswordRequiresOldPassword() {
        User user = new User();
        user.setId(1L);
        user.setPasswordHash("hash");
        when(userRepository.findById(1L)).thenReturn(Optional.of(user));
        when(passwordEncoder.matches("old", "hash")).thenReturn(false);

        BizException ex = assertThrows(BizException.class,
                () -> authService.changePassword(1L, "old", "newpass"));
        assertEquals("当前密码不正确", ex.getMessage());
        verify(passwordEncoder, never()).encode(anyString());
    }
}
