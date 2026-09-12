package com.luckysign.config;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import jakarta.annotation.PostConstruct;
import java.util.Arrays;
import java.util.List;

@Component
public class CorsProperties {
    private static final Logger log = LoggerFactory.getLogger(CorsProperties.class);

    private final String corsOriginsRaw;
    private final boolean productionMode;
    private List<String> allowedOrigins;

    public CorsProperties(
            @Value("${app.cors.allowed-origins:}") String corsOriginsRaw,
            @Value("${app.cors.production:false}") boolean productionMode) {
        this.corsOriginsRaw = corsOriginsRaw;
        this.productionMode = productionMode;
    }

    @PostConstruct
    public void init() {
        this.allowedOrigins = parseOrigins(corsOriginsRaw);
        validate();
    }

    private List<String> parseOrigins(String raw) {
        if (raw == null || raw.isBlank()) {
            return List.of();
        }
        return Arrays.stream(raw.split(","))
                .map(String::trim)
                .filter(s -> !s.isEmpty())
                .filter(s -> !s.equals("*"))
                .toList();
    }

    private void validate() {
        if (productionMode) {
            if (allowedOrigins.isEmpty()) {
                throw new IllegalStateException(
                    "CORS_ORIGINS must be explicitly set in production mode. " +
                    "Set app.cors.allowed-origins to your frontend domain(s), e.g. https://119-23-45-226.sslip.io. " +
                    "Wildcard '*' is not allowed in production.");
            }
            for (String origin : allowedOrigins) {
                if (!origin.startsWith("https://")) {
                    log.warn("CORS origin '{}' is not HTTPS - consider using HTTPS in production", origin);
                }
            }
            log.info("Production CORS configured with origins: {}", allowedOrigins);
        } else {
            if (allowedOrigins.isEmpty()) {
                log.warn("CORS: No origins configured. Using localhost fallback for development only.");
            }
        }
    }

    public List<String> getAllowedOrigins() {
        return allowedOrigins;
    }

    public List<String> getEffectiveOrigins() {
        if (allowedOrigins.isEmpty() && !productionMode) {
            return List.of("http://localhost:*", "https://localhost:*");
        }
        return allowedOrigins;
    }

    public boolean isProductionMode() {
        return productionMode;
    }

    public boolean hasExplicitOrigins() {
        return !allowedOrigins.isEmpty();
    }
}
