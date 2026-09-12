package com.luckysign.service;

import com.luckysign.common.BizException;
import com.luckysign.domain.MemberRole;
import com.luckysign.domain.UserRole;
import com.luckysign.domain.UserTag;
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

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.*;

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

        AuthDtos.RegisterRequest req = new AuthDtos.RegisterRequest("小明", "a@b.com", "12345678", "abcdef");
        BizException ex = assertThrows(BizException.class, () -> authService.register(req));
        assertEquals("邀请码无效", ex.getMessage());
        verify(userRepository, never()).save(any());
    }

    @Test
    void registerRejectsShortPassword() {
        AuthDtos.RegisterRequest req = new AuthDtos.RegisterRequest("小明", "a@b.com", "1234567", "abcdef");
        BizException ex = assertThrows(BizException.class, () -> authService.register(req));
        assertEquals("密码至少 8 位", ex.getMessage());
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

        AuthDtos.RegisterRequest req = new AuthDtos.RegisterRequest("小明", "a@b.com", "12345678", "ABCDEF");
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
        User saved = createTestUser(9L);

        when(userRepository.existsByEmail("a@b.com")).thenReturn(false);
        when(circleRepository.findByInviteCode("ABCDEF")).thenReturn(Optional.of(circle));
        when(titleService.resolve(0)).thenReturn("签到萌新");
        when(passwordEncoder.encode("12345678")).thenReturn("hash");
        when(userRepository.save(any(User.class))).thenReturn(saved);
        when(circleMemberRepository.existsByCircleIdAndUserId(1L, 9L)).thenReturn(false);
        when(circleRepository.incrementMemberCount(1L)).thenReturn(1);
        when(jwtService.generateAccessToken(eq(9L), eq("a@b.com"), eq(0L))).thenReturn("access-token");
        when(jwtService.generateRefreshToken(eq(9L), eq(0L))).thenReturn("refresh-token");

        AuthDtos.RegisterRequest req = new AuthDtos.RegisterRequest("小明", "a@b.com", "12345678", "ab cdef");
        AuthDtos.AuthResponse res = authService.register(req);
        assertEquals("access-token", res.token());
        assertEquals("refresh-token", res.refreshToken());
        assertEquals(1L, res.circleId());

        ArgumentCaptor<CircleMember> member = ArgumentCaptor.forClass(CircleMember.class);
        verify(circleMemberRepository).save(member.capture());
        assertEquals(MemberRole.MEMBER, member.getValue().getRole());
        verify(circleRepository).incrementMemberCount(1L);
    }

    @Test
    void loginRejectsDisabledUser() {
        User user = createTestUser(1L);
        user.setEnabled(false);
        when(userRepository.findByEmail("a@b.com")).thenReturn(Optional.of(user));

        AuthDtos.LoginRequest req = new AuthDtos.LoginRequest("a@b.com", "12345678");
        BizException ex = assertThrows(BizException.class, () -> authService.login(req));
        assertEquals("账号已禁用", ex.getMessage());
    }

    @Test
    void changePasswordRequiresOldPassword() {
        User user = createTestUser(1L);
        when(userRepository.findById(1L)).thenReturn(Optional.of(user));
        when(passwordEncoder.matches("old", "hash")).thenReturn(false);

        BizException ex = assertThrows(BizException.class,
                () -> authService.changePassword(1L, "old", "newpass12"));
        assertEquals("当前密码不正确", ex.getMessage());
        verify(passwordEncoder, never()).encode(anyString());
    }

    @Test
    void changePasswordIncrementsTokenVersion() {
        User user = createTestUser(1L);
        user.setTokenVersion(5L);
        when(userRepository.findById(1L)).thenReturn(Optional.of(user));
        when(passwordEncoder.matches("oldpass1", "hash")).thenReturn(true);
        when(passwordEncoder.encode("newpass12")).thenReturn("newhash");
        when(userRepository.save(any(User.class))).thenAnswer(inv -> inv.getArgument(0));
        when(circleMemberRepository.findFirstCircleIdByUserId(1L)).thenReturn(Optional.of(2L));
        when(jwtService.generateAccessToken(eq(1L), eq("a@b.com"), eq(6L))).thenReturn("new-access");
        when(jwtService.generateRefreshToken(eq(1L), eq(6L))).thenReturn("new-refresh");

        AuthDtos.AuthResponse response = authService.changePassword(1L, "oldpass1", "newpass12");

        ArgumentCaptor<User> userCaptor = ArgumentCaptor.forClass(User.class);
        verify(userRepository).save(userCaptor.capture());
        assertEquals(6L, userCaptor.getValue().getTokenVersion());
        assertEquals("newhash", userCaptor.getValue().getPasswordHash());
        assertEquals("new-access", response.token());
        assertEquals("new-refresh", response.refreshToken());
        assertEquals(2L, response.circleId());
    }

    @Test
    void invalidateTokensIncrementsVersion() {
        when(userRepository.incrementTokenVersion(1L)).thenReturn(1);

        authService.invalidateTokens(1L);

        verify(userRepository).incrementTokenVersion(1L);
    }

    private User createTestUser(Long id) {
        User user = new User();
        user.setId(id);
        user.setEmail("a@b.com");
        user.setNickname("小明");
        user.setPasswordHash("hash");
        user.setRole(UserRole.USER);
        user.setTag(UserTag.NONE);
        user.setPoints(0);
        user.setTitle("签到萌新");
        user.setStreakDays(0);
        user.setTotalCompletedDays(0);
        user.setTokenVersion(0L);
        user.setEnabled(true);
        return user;
    }
}
