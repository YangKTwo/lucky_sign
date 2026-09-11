package com.luckysign.service;

import com.luckysign.common.BizException;
import com.luckysign.common.InviteCodes;
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
import io.jsonwebtoken.Claims;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class AuthService {
    private final UserRepository userRepository;
    private final CircleRepository circleRepository;
    private final CircleMemberRepository circleMemberRepository;
    private final PasswordEncoder passwordEncoder;
    private final JwtService jwtService;
    private final TitleService titleService;

    public AuthService(UserRepository userRepository,
                       CircleRepository circleRepository,
                       CircleMemberRepository circleMemberRepository,
                       PasswordEncoder passwordEncoder,
                       JwtService jwtService,
                       TitleService titleService) {
        this.userRepository = userRepository;
        this.circleRepository = circleRepository;
        this.circleMemberRepository = circleMemberRepository;
        this.passwordEncoder = passwordEncoder;
        this.jwtService = jwtService;
        this.titleService = titleService;
    }

    @Transactional
    public AuthDtos.AuthResponse register(AuthDtos.RegisterRequest req) {
        String email = normalizeEmail(req.email());
        String nickname = req.nickname() == null ? "" : req.nickname().trim();
        if (nickname.isEmpty()) {
            throw new BizException("请填写昵称");
        }
        if (req.password() == null || req.password().length() < 8) {
            throw new BizException("密码至少 8 位");
        }
        if (userRepository.existsByEmail(email)) {
            throw new BizException("邮箱已注册");
        }
        String inviteCode = InviteCodes.normalize(req.inviteCode());
        if (inviteCode.isEmpty()) {
            throw new BizException("请填写邀请码");
        }
        Circle circle = circleRepository.findByInviteCode(inviteCode)
                .orElseThrow(() -> new BizException("邀请码无效"));
        if (circle.getMemberCount() != null && circle.getMaxMembers() != null
                && circle.getMemberCount() >= circle.getMaxMembers()) {
            throw new BizException("圈子已满员");
        }

        User user = new User();
        user.setNickname(nickname);
        user.setEmail(email);
        user.setPasswordHash(passwordEncoder.encode(req.password()));
        user.setTitle(titleService.resolve(0));
        user.setRole(UserRole.USER);
        user.setTag(UserTag.NONE);
        user.setTokenVersion(0L);
        user.setEnabled(true);
        user = userRepository.save(user);

        boolean membershipCreated = false;
        try {
            if (!circleMemberRepository.existsByCircleIdAndUserId(circle.getId(), user.getId())) {
                int updated = circleRepository.incrementMemberCount(circle.getId());
                if (updated == 0) {
                    throw new BizException("圈子已满员");
                }
                CircleMember member = new CircleMember();
                member.setCircleId(circle.getId());
                member.setUserId(user.getId());
                member.setRole(MemberRole.MEMBER);
                circleMemberRepository.save(member);
                membershipCreated = true;
            } else {
                membershipCreated = true;
            }
        } catch (org.springframework.dao.DataIntegrityViolationException e) {
            circleRepository.decrementMemberCount(circle.getId());
            if (circleMemberRepository.existsByCircleIdAndUserId(circle.getId(), user.getId())) {
                membershipCreated = true;
            }
        }

        if (!membershipCreated) {
            throw new BizException("加入圈子失败，请稍后重试");
        }

        return generateAuthResponse(user);
    }

    public AuthDtos.AuthResponse login(AuthDtos.LoginRequest req) {
        String email = normalizeEmail(req.email());
        if (email.isEmpty() || req.password() == null || req.password().isEmpty()) {
            throw new BizException("请填写邮箱和密码");
        }
        User user = userRepository.findByEmail(email)
                .orElseThrow(() -> new BizException("邮箱或密码错误"));
        if (!Boolean.TRUE.equals(user.getEnabled())) {
            throw new BizException("账号已禁用");
        }
        if (!passwordEncoder.matches(req.password(), user.getPasswordHash())) {
            throw new BizException("邮箱或密码错误");
        }
        return generateAuthResponse(user);
    }

    @Transactional
    public AuthDtos.AuthResponse refresh(String refreshToken) {
        Claims claims;
        try {
            claims = jwtService.parse(refreshToken);
        } catch (Exception e) {
            throw new BizException("刷新令牌无效");
        }

        String tokenType = jwtService.getTokenType(claims);
        if (!"refresh".equals(tokenType)) {
            throw new BizException("刷新令牌无效");
        }

        Long userId = Long.valueOf(claims.getSubject());
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new BizException("用户不存在"));

        if (!Boolean.TRUE.equals(user.getEnabled())) {
            throw new BizException("账号已禁用");
        }

        Long tokenVer = jwtService.getTokenVersion(claims);
        if (tokenVer != null && !tokenVer.equals(user.getTokenVersion())) {
            throw new BizException("令牌已失效，请重新登录");
        }

        return generateAuthResponse(user);
    }

    private AuthDtos.AuthResponse generateAuthResponse(User user) {
        String accessToken = jwtService.generateAccessToken(user.getId(), user.getEmail(), user.getTokenVersion());
        String refreshToken = jwtService.generateRefreshToken(user.getId(), user.getTokenVersion());
        return new AuthDtos.AuthResponse(accessToken, refreshToken, toProfile(user));
    }

    private static String normalizeEmail(String email) {
        return email == null ? "" : email.trim().toLowerCase();
    }

    public AuthDtos.UserProfileResponse profile(Long userId) {
        User user = userRepository.findById(userId).orElseThrow(() -> new BizException("用户不存在"));
        return toProfile(user);
    }

    @Transactional
    public AuthDtos.UserProfileResponse updateProfile(Long userId, AuthDtos.UpdateProfileRequest req) {
        User user = userRepository.findById(userId).orElseThrow(() -> new BizException("用户不存在"));
        if (req.nickname() != null && !req.nickname().isBlank()) {
            user.setNickname(req.nickname().trim());
        }
        return toProfile(userRepository.save(user));
    }

    @Transactional
    public AuthDtos.AuthResponse changePassword(Long userId, String oldPassword, String newPassword) {
        User user = userRepository.findById(userId).orElseThrow(() -> new BizException("用户不存在"));
        if (oldPassword == null || oldPassword.isBlank()
                || !passwordEncoder.matches(oldPassword, user.getPasswordHash())) {
            throw new BizException("当前密码不正确");
        }
        if (newPassword == null || newPassword.length() < 8) {
            throw new BizException("新密码至少 8 位");
        }
        user.setPasswordHash(passwordEncoder.encode(newPassword));
        user.setTokenVersion(user.getTokenVersion() + 1);
        user = userRepository.save(user);
        return generateAuthResponse(user);
    }

    @Transactional
    public void invalidateTokens(Long userId) {
        userRepository.incrementTokenVersion(userId);
    }

    @Transactional
    public AuthDtos.UserProfileResponse updateAvatar(Long userId, String avatarUrl) {
        User user = userRepository.findById(userId).orElseThrow(() -> new BizException("用户不存在"));
        user.setAvatarUrl(avatarUrl);
        return toProfile(userRepository.save(user));
    }

    public static AuthDtos.UserProfileResponse toProfile(User user) {
        return new AuthDtos.UserProfileResponse(
                user.getId(),
                user.getNickname(),
                user.getEmail(),
                user.getAvatarUrl(),
                user.getPoints(),
                user.getTitle(),
                user.getStreakDays(),
                user.getTotalCompletedDays(),
                user.getTag().name(),
                user.getRole().name()
        );
    }
}
