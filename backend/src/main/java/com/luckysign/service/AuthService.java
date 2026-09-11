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
        if (req.password() == null || req.password().length() < 6) {
            throw new BizException("密码至少 6 位");
        }
        if (userRepository.existsByEmail(email)) {
            throw new BizException("邮箱已注册");
        }
        Circle circle = circleRepository.findFirstByOrderByIdAsc()
                .orElseThrow(() -> new BizException("默认圈子未初始化"));

        User user = new User();
        user.setNickname(nickname);
        user.setEmail(email);
        user.setPasswordHash(passwordEncoder.encode(req.password()));
        user.setTitle(titleService.resolve(0));
        user.setRole(UserRole.USER);
        user.setTag(UserTag.NONE);
        user = userRepository.save(user);

        if (!circleMemberRepository.existsByCircleIdAndUserId(circle.getId(), user.getId())) {
            CircleMember member = new CircleMember();
            member.setCircleId(circle.getId());
            member.setUserId(user.getId());
            member.setRole(MemberRole.MEMBER);
            circleMemberRepository.save(member);
            circle.setMemberCount(circle.getMemberCount() + 1);
            circleRepository.save(circle);
        }

        String token = jwtService.generateToken(user.getId(), user.getEmail(), user.getRole().name());
        return new AuthDtos.AuthResponse(token, toProfile(user));
    }

    public AuthDtos.AuthResponse login(AuthDtos.LoginRequest req) {
        String email = normalizeEmail(req.email());
        if (email.isEmpty() || req.password() == null || req.password().isEmpty()) {
            throw new BizException("请填写邮箱和密码");
        }
        User user = userRepository.findByEmail(email)
                .orElseThrow(() -> new BizException("邮箱或密码错误"));
        if (!passwordEncoder.matches(req.password(), user.getPasswordHash())) {
            throw new BizException("邮箱或密码错误");
        }
        String token = jwtService.generateToken(user.getId(), user.getEmail(), user.getRole().name());
        return new AuthDtos.AuthResponse(token, toProfile(user));
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
        if (req.password() != null && !req.password().isBlank()) {
            user.setPasswordHash(passwordEncoder.encode(req.password()));
        }
        return toProfile(userRepository.save(user));
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
