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
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

@Service
public class AiAssistantService {
    private static final Logger log = LoggerFactory.getLogger(AiAssistantService.class);

    private final AppProperties appProperties;
    private final ObjectMapper objectMapper;
    private final HttpClient httpClient = HttpClient.newBuilder()
            .connectTimeout(Duration.ofSeconds(10))
            .build();

    public AiAssistantService(AppProperties appProperties, ObjectMapper objectMapper) {
        this.appProperties = appProperties;
        this.objectMapper = objectMapper;
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

    public String ask(String userNickname, String question) {
        if (!isReady()) {
            throw new BizException("社区助手未启用，请配置 AI_API_KEY");
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
                    .timeout(Duration.ofSeconds(45))
                    .header("Authorization", "Bearer " + ai.getApiKey())
                    .header("Content-Type", "application/json")
                    .POST(HttpRequest.BodyPublishers.ofString(json, StandardCharsets.UTF_8))
                    .build();
            HttpResponse<String> response = httpClient.send(request, HttpResponse.BodyHandlers.ofString(StandardCharsets.UTF_8));
            if (response.statusCode() >= 400) {
                log.warn("AI request failed status={} body={}", response.statusCode(), response.body());
                throw new BizException("助手暂时无法回复，请稍后再试");
            }
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
        } catch (BizException e) {
            throw e;
        } catch (Exception e) {
            log.warn("AI request error", e);
            throw new BizException("助手调用失败：" + e.getMessage());
        }
    }

    private static String trimSlash(String s) {
        if (s == null || s.isBlank()) {
            return "https://dashscope.aliyuncs.com/compatible-mode/v1";
        }
        return s.endsWith("/") ? s.substring(0, s.length() - 1) : s;
    }
}
