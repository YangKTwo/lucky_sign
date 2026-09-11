package com.luckysign.service;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.luckysign.common.BizException;
import com.luckysign.config.AppProperties;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.net.http.HttpTimeoutException;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.time.LocalDate;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.concurrent.atomic.AtomicLong;

@Service
public class AiAssistantService {
    private static final Logger log = LoggerFactory.getLogger(AiAssistantService.class);

    private static final int DAILY_QUOTA_PER_USER = 20;
    private static final int CIRCUIT_BREAKER_THRESHOLD = 5;
    private static final long CIRCUIT_BREAKER_RESET_MS = 60_000;
    private static final Duration REQUEST_TIMEOUT = Duration.ofSeconds(30);

    private final AppProperties appProperties;
    private final ObjectMapper objectMapper;
    private final HttpClient httpClient;

    private final Map<String, DailyCounter> userQuotas = new ConcurrentHashMap<>();

    private final AtomicInteger consecutiveFailures = new AtomicInteger(0);
    private final AtomicLong circuitOpenUntil = new AtomicLong(0);

    public AiAssistantService(AppProperties appProperties, ObjectMapper objectMapper) {
        this.appProperties = appProperties;
        this.objectMapper = objectMapper;
        this.httpClient = HttpClient.newBuilder()
                .connectTimeout(Duration.ofSeconds(10))
                .build();
    }

    public boolean isReady() {
        AppProperties.Ai ai = appProperties.getAi();
        return ai.isEnabled() && ai.getApiKey() != null && !ai.getApiKey().isBlank();
    }

    public boolean isMentioned(String content) {
        if (content == null || content.isBlank()) {
            return false;
        }
        String mention = mentionToken();
        return content.contains(mention);
    }

    public String extractQuestion(String content) {
        String mention = mentionToken();
        String q = content.replace(mention, " ").trim().replaceAll("\\s+", " ");
        if (q.isBlank()) {
            return "你好，请简单介绍一下你自己，并说明你可以怎么帮助这个打卡小圈子。";
        }
        return q;
    }

    public String mentionToken() {
        String m = appProperties.getAi().getMention();
        return (m == null || m.isBlank()) ? "@助手" : m.trim();
    }

    public String ask(Long userId, String userNickname, String question) {
        if (!isReady()) {
            throw new BizException("社区助手未启用");
        }

        if (isCircuitOpen()) {
            throw new BizException("助手暂时休息中，请稍后再试");
        }

        if (!checkAndConsumeQuota(userId)) {
            throw new BizException("今日提问次数已用完，明天再来吧");
        }

        AppProperties.Ai ai = appProperties.getAi();
        try {
            Map<String, Object> body = new LinkedHashMap<>();
            body.put("model", ai.getModel());
            body.put("messages", List.of(
                    Map.of("role", "system", "content", ai.getSystemPrompt()),
                    Map.of("role", "user", "content", "用户「" + userNickname + "」问：" + question)
            ));
            String json = objectMapper.writeValueAsString(body);
            String url = trimSlash(ai.getBaseUrl()) + "/chat/completions";

            HttpRequest request = HttpRequest.newBuilder()
                    .uri(URI.create(url))
                    .timeout(REQUEST_TIMEOUT)
                    .header("Authorization", "Bearer " + ai.getApiKey())
                    .header("Content-Type", "application/json")
                    .POST(HttpRequest.BodyPublishers.ofString(json, StandardCharsets.UTF_8))
                    .build();

            HttpResponse<String> response = httpClient.send(request, HttpResponse.BodyHandlers.ofString(StandardCharsets.UTF_8));

            if (response.statusCode() >= 500) {
                recordFailure();
                log.warn("AI server error status={}", response.statusCode());
                throw new BizException("助手服务暂时不可用");
            }
            if (response.statusCode() >= 400) {
                log.warn("AI request failed status={} body={}", response.statusCode(), response.body());
                throw new BizException("助手暂时无法回复");
            }

            recordSuccess();

            JsonNode root = objectMapper.readTree(response.body());
            JsonNode content = root.path("choices").path(0).path("message").path("content");
            if (content.isMissingNode() || content.asText().isBlank()) {
                throw new BizException("助手没有返回内容");
            }
            String text = content.asText().trim();
            if (text.length() > 2000) {
                text = text.substring(0, 2000) + "…";
            }
            return text;
        } catch (HttpTimeoutException e) {
            recordFailure();
            log.warn("AI request timeout");
            throw new BizException("助手响应超时，请稍后再试");
        } catch (BizException e) {
            throw e;
        } catch (Exception e) {
            recordFailure();
            log.warn("AI request error", e);
            throw new BizException("助手调用失败");
        }
    }

    @Deprecated
    public String ask(String userNickname, String question) {
        throw new UnsupportedOperationException(
                "Deprecated ask(String, String) is blocked. Use ask(Long userId, String, String) to enforce quota.");
    }

    private boolean checkAndConsumeQuota(Long userId) {
        if (userId == null) {
            return true;
        }
        String key = userId + ":" + LocalDate.now();
        DailyCounter counter = userQuotas.compute(key, (k, v) -> {
            if (v == null || !v.date.equals(LocalDate.now())) {
                return new DailyCounter(LocalDate.now());
            }
            return v;
        });
        return counter.tryConsume();
    }

    private boolean isCircuitOpen() {
        long openUntil = circuitOpenUntil.get();
        if (openUntil == 0) {
            return false;
        }
        if (System.currentTimeMillis() >= openUntil) {
            circuitOpenUntil.compareAndSet(openUntil, 0);
            consecutiveFailures.set(0);
            return false;
        }
        return true;
    }

    private void recordFailure() {
        int failures = consecutiveFailures.incrementAndGet();
        if (failures >= CIRCUIT_BREAKER_THRESHOLD) {
            circuitOpenUntil.set(System.currentTimeMillis() + CIRCUIT_BREAKER_RESET_MS);
            log.warn("Circuit breaker opened after {} consecutive failures", failures);
        }
    }

    private void recordSuccess() {
        consecutiveFailures.set(0);
    }

    private static String trimSlash(String s) {
        if (s == null || s.isBlank()) {
            return "https://dashscope.aliyuncs.com/compatible-mode/v1";
        }
        return s.endsWith("/") ? s.substring(0, s.length() - 1) : s;
    }

    private static class DailyCounter {
        final LocalDate date;
        final AtomicInteger count = new AtomicInteger(0);

        DailyCounter(LocalDate date) {
            this.date = date;
        }

        boolean tryConsume() {
            return count.incrementAndGet() <= DAILY_QUOTA_PER_USER;
        }
    }
}
