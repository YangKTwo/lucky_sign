package com.luckysign.security;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.luckysign.common.ApiResponse;
import io.github.bucket4j.Bandwidth;
import io.github.bucket4j.Bucket;
import io.github.bucket4j.Refill;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.time.Duration;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;

@Component
public class RateLimitFilter extends OncePerRequestFilter {
    private static final Logger log = LoggerFactory.getLogger(RateLimitFilter.class);

    private static final int AUTH_RATE_PER_MINUTE = 10;
    private static final int AUTH_BURST_CAPACITY = 15;
    private static final int GENERAL_RATE_PER_SECOND = 50;
    private static final int GENERAL_BURST_CAPACITY = 100;
    private static final int MAX_CACHE_SIZE = 10000;

    private static final Set<String> TRUSTED_PROXIES = Set.of(
            "127.0.0.1", "::1", "localhost"
    );

    private final Map<String, Bucket> authBuckets = new ConcurrentHashMap<>();
    private final Map<String, Bucket> generalBuckets = new ConcurrentHashMap<>();
    private final ObjectMapper objectMapper;
    private final boolean trustProxyHeaders;

    public RateLimitFilter(ObjectMapper objectMapper,
                           @Value("${app.rate-limit.trust-proxy-headers:false}") boolean trustProxyHeaders) {
        this.objectMapper = objectMapper;
        this.trustProxyHeaders = trustProxyHeaders;
    }

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain filterChain)
            throws ServletException, IOException {
        String path = request.getRequestURI();
        String clientKey = resolveClientKey(request);

        if (isAuthEndpoint(path)) {
            Bucket bucket = getOrCreateAuthBucket(clientKey);
            if (!bucket.tryConsume(1)) {
                log.warn("Rate limit exceeded for auth endpoint: ip={}, path={}", clientKey, path);
                sendRateLimitResponse(response, "请求过于频繁，请稍后再试");
                return;
            }
        } else {
            Bucket bucket = getOrCreateGeneralBucket(clientKey);
            if (!bucket.tryConsume(1)) {
                log.warn("Rate limit exceeded: ip={}, path={}", clientKey, path);
                sendRateLimitResponse(response, "请求过于频繁");
                return;
            }
        }

        filterChain.doFilter(request, response);
    }

    private boolean isAuthEndpoint(String path) {
        return path.startsWith("/api/auth/");
    }

    private String resolveClientKey(HttpServletRequest request) {
        String remoteAddr = request.getRemoteAddr();

        if (!trustProxyHeaders) {
            return remoteAddr;
        }

        if (!isTrustedProxy(remoteAddr)) {
            return remoteAddr;
        }

        String realIp = request.getHeader("X-Real-IP");
        if (realIp != null && !realIp.isBlank()) {
            String ip = realIp.trim();
            if (isValidIp(ip)) {
                return ip;
            }
        }

        String forwardedFor = request.getHeader("X-Forwarded-For");
        if (forwardedFor != null && !forwardedFor.isBlank()) {
            String[] ips = forwardedFor.split(",");
            for (int i = ips.length - 1; i >= 0; i--) {
                String ip = ips[i].trim();
                if (isValidIp(ip) && !isTrustedProxy(ip)) {
                    return ip;
                }
            }
            if (ips.length > 0) {
                String firstIp = ips[0].trim();
                if (isValidIp(firstIp)) {
                    return firstIp;
                }
            }
        }

        return remoteAddr;
    }

    private boolean isTrustedProxy(String ip) {
        return TRUSTED_PROXIES.contains(ip) || ip.startsWith("10.") || ip.startsWith("172.") || ip.startsWith("192.168.");
    }

    private boolean isValidIp(String ip) {
        if (ip == null || ip.isBlank()) {
            return false;
        }
        return ip.matches("^[0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3}$")
                || ip.matches("^[0-9a-fA-F:]+$");
    }

    private Bucket getOrCreateAuthBucket(String key) {
        cleanupIfNeeded(authBuckets);
        return authBuckets.computeIfAbsent(key, k -> Bucket.builder()
                .addLimit(Bandwidth.classic(AUTH_BURST_CAPACITY, Refill.greedy(AUTH_RATE_PER_MINUTE, Duration.ofMinutes(1))))
                .build());
    }

    private Bucket getOrCreateGeneralBucket(String key) {
        cleanupIfNeeded(generalBuckets);
        return generalBuckets.computeIfAbsent(key, k -> Bucket.builder()
                .addLimit(Bandwidth.classic(GENERAL_BURST_CAPACITY, Refill.greedy(GENERAL_RATE_PER_SECOND, Duration.ofSeconds(1))))
                .build());
    }

    private void cleanupIfNeeded(Map<String, Bucket> buckets) {
        if (buckets.size() > MAX_CACHE_SIZE) {
            int toRemove = MAX_CACHE_SIZE / 4;
            buckets.keySet().stream()
                    .limit(toRemove)
                    .toList()
                    .forEach(buckets::remove);
        }
    }

    private void sendRateLimitResponse(HttpServletResponse response, String message) throws IOException {
        response.setStatus(HttpStatus.TOO_MANY_REQUESTS.value());
        response.setContentType(MediaType.APPLICATION_JSON_VALUE);
        response.setCharacterEncoding("UTF-8");
        response.setHeader("Retry-After", "60");
        ApiResponse<Void> body = new ApiResponse<>(false, message, null);
        response.getWriter().write(objectMapper.writeValueAsString(body));
    }
}
