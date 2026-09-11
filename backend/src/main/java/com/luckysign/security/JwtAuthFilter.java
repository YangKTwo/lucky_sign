package com.luckysign.security;

import com.luckysign.domain.UserRole;
import com.luckysign.repository.UserRepository;
import io.jsonwebtoken.Claims;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpHeaders;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.util.Optional;

@Component
public class JwtAuthFilter extends OncePerRequestFilter {
    private static final Logger log = LoggerFactory.getLogger(JwtAuthFilter.class);

    private final JwtService jwtService;
    private final UserRepository userRepository;

    public JwtAuthFilter(JwtService jwtService, UserRepository userRepository) {
        this.jwtService = jwtService;
        this.userRepository = userRepository;
    }

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain filterChain)
            throws ServletException, IOException {
        String header = request.getHeader(HttpHeaders.AUTHORIZATION);
        if (header != null && header.startsWith("Bearer ")) {
            String token = header.substring(7);
            try {
                Claims claims = jwtService.parse(token);
                Long userId = Long.valueOf(claims.getSubject());

                if (!validateToken(claims, userId)) {
                    SecurityContextHolder.clearContext();
                    filterChain.doFilter(request, response);
                    return;
                }

                String email = claims.get("email", String.class);
                Optional<UserRole> dbRole = userRepository.findRoleById(userId);
                String role = dbRole.map(Enum::name).orElse("USER");

                SecurityContextHolder.getContext().setAuthentication(new UserPrincipal(userId, email, role));
            } catch (Exception e) {
                log.debug("JWT validation failed: {}", e.getMessage());
                SecurityContextHolder.clearContext();
            }
        }
        filterChain.doFilter(request, response);
    }

    private boolean validateToken(Claims claims, Long userId) {
        Optional<Boolean> enabled = userRepository.findEnabledById(userId);
        if (enabled.isEmpty() || !enabled.get()) {
            log.debug("User {} is disabled or not found", userId);
            return false;
        }

        Long tokenVer = jwtService.getTokenVersion(claims);
        if (tokenVer != null) {
            Optional<Long> dbVersion = userRepository.findTokenVersionById(userId);
            if (dbVersion.isPresent() && !dbVersion.get().equals(tokenVer)) {
                log.debug("Token version mismatch for user {}: token={}, db={}", userId, tokenVer, dbVersion.get());
                return false;
            }
        }

        String tokenType = jwtService.getTokenType(claims);
        if ("refresh".equals(tokenType)) {
            log.debug("Refresh token cannot be used for API access");
            return false;
        }

        return true;
    }
}
