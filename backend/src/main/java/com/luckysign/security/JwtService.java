package com.luckysign.security;

import com.luckysign.config.AppProperties;
import io.jsonwebtoken.Claims;
import io.jsonwebtoken.JwtException;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;

import javax.crypto.SecretKey;
import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.Date;
import java.util.UUID;

@Component
public class JwtService {
    private static final Logger log = LoggerFactory.getLogger(JwtService.class);
    private static final int MIN_SECRET_LENGTH = 32;

    private final AppProperties appProperties;
    private final SecretKey primaryKey;
    private final SecretKey previousKey;

    public JwtService(AppProperties appProperties) {
        this.appProperties = appProperties;
        String secret = appProperties.getJwt().getSecret();

        if (secret == null || secret.isBlank()) {
            throw new IllegalStateException(
                    "JWT_SECRET is required. Set a secure random string of at least " + MIN_SECRET_LENGTH + " characters.");
        }
        if (secret.length() < MIN_SECRET_LENGTH) {
            throw new IllegalStateException(
                    "JWT_SECRET must be at least " + MIN_SECRET_LENGTH + " characters (current: " + secret.length() + ")");
        }
        if (secret.toLowerCase().contains("change-me") || secret.toLowerCase().contains("changeme")
                || secret.toLowerCase().contains("default") || secret.toLowerCase().contains("example")) {
            throw new IllegalStateException(
                    "JWT_SECRET contains unsafe placeholder text. Use a secure random value in production.");
        }

        this.primaryKey = Keys.hmacShaKeyFor(secret.getBytes(StandardCharsets.UTF_8));

        String prevSecret = appProperties.getJwt().getSecretPrevious();
        if (prevSecret != null && !prevSecret.isBlank() && prevSecret.length() >= MIN_SECRET_LENGTH) {
            this.previousKey = Keys.hmacShaKeyFor(prevSecret.getBytes(StandardCharsets.UTF_8));
            log.info("JWT key rotation enabled: previous key configured");
        } else {
            this.previousKey = null;
        }
    }

    public String generateAccessToken(Long userId, String email, Long tokenVersion) {
        Instant now = Instant.now();
        Instant exp = now.plus(appProperties.getJwt().getAccessTokenMinutes(), ChronoUnit.MINUTES);
        return Jwts.builder()
                .id(UUID.randomUUID().toString())
                .subject(String.valueOf(userId))
                .claim("email", email)
                .claim("type", "access")
                .claim("ver", tokenVersion)
                .issuedAt(Date.from(now))
                .expiration(Date.from(exp))
                .signWith(primaryKey)
                .compact();
    }

    public String generateRefreshToken(Long userId, Long tokenVersion) {
        Instant now = Instant.now();
        Instant exp = now.plus(appProperties.getJwt().getRefreshTokenDays(), ChronoUnit.DAYS);
        return Jwts.builder()
                .id(UUID.randomUUID().toString())
                .subject(String.valueOf(userId))
                .claim("type", "refresh")
                .claim("ver", tokenVersion)
                .issuedAt(Date.from(now))
                .expiration(Date.from(exp))
                .signWith(primaryKey)
                .compact();
    }

    @Deprecated
    public String generateToken(Long userId, String email, String role) {
        Instant now = Instant.now();
        Instant exp = now.plus(appProperties.getJwt().getExpireDays(), ChronoUnit.DAYS);
        return Jwts.builder()
                .id(UUID.randomUUID().toString())
                .subject(String.valueOf(userId))
                .claim("email", email)
                .claim("role", role)
                .claim("type", "legacy")
                .issuedAt(Date.from(now))
                .expiration(Date.from(exp))
                .signWith(primaryKey)
                .compact();
    }

    public Claims parse(String token) {
        try {
            return Jwts.parser()
                    .verifyWith(primaryKey)
                    .build()
                    .parseSignedClaims(token)
                    .getPayload();
        } catch (JwtException e) {
            if (previousKey != null) {
                return Jwts.parser()
                        .verifyWith(previousKey)
                        .build()
                        .parseSignedClaims(token)
                        .getPayload();
            }
            throw e;
        }
    }

    public String getTokenType(Claims claims) {
        String type = claims.get("type", String.class);
        return type == null ? "legacy" : type;
    }

    public Long getTokenVersion(Claims claims) {
        Object ver = claims.get("ver");
        if (ver == null) return null;
        if (ver instanceof Number) return ((Number) ver).longValue();
        try {
            return Long.parseLong(ver.toString());
        } catch (NumberFormatException e) {
            return null;
        }
    }
}
