package com.luckysign.config;

import com.luckysign.repository.UserRepository;
import com.luckysign.security.JwtService;
import com.luckysign.security.UserPrincipal;
import io.jsonwebtoken.Claims;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.context.annotation.Configuration;
import org.springframework.messaging.Message;
import org.springframework.messaging.MessageChannel;
import org.springframework.messaging.MessagingException;
import org.springframework.messaging.simp.config.ChannelRegistration;
import org.springframework.messaging.simp.config.MessageBrokerRegistry;
import org.springframework.messaging.simp.stomp.StompCommand;
import org.springframework.messaging.simp.stomp.StompHeaderAccessor;
import org.springframework.messaging.support.ChannelInterceptor;
import org.springframework.messaging.support.MessageHeaderAccessor;
import org.springframework.web.socket.config.annotation.EnableWebSocketMessageBroker;
import org.springframework.web.socket.config.annotation.StompEndpointRegistry;
import org.springframework.web.socket.config.annotation.WebSocketMessageBrokerConfigurer;

import java.util.List;
import java.util.Optional;

@Configuration
@EnableWebSocketMessageBroker
public class WebSocketConfig implements WebSocketMessageBrokerConfigurer {
    private static final Logger log = LoggerFactory.getLogger(WebSocketConfig.class);

    private final JwtService jwtService;
    private final UserRepository userRepository;
    private final CorsProperties corsProperties;

    public WebSocketConfig(JwtService jwtService, UserRepository userRepository,
                           CorsProperties corsProperties) {
        this.jwtService = jwtService;
        this.userRepository = userRepository;
        this.corsProperties = corsProperties;
    }

    @Override
    public void configureMessageBroker(MessageBrokerRegistry registry) {
        registry.enableSimpleBroker("/topic");
        registry.setApplicationDestinationPrefixes("/app");
    }

    @Override
    public void registerStompEndpoints(StompEndpointRegistry registry) {
        var endpoint = registry.addEndpoint("/ws");
        List<String> origins = corsProperties.getEffectiveOrigins();
        if (corsProperties.hasExplicitOrigins()) {
            endpoint.setAllowedOrigins(origins.toArray(new String[0]));
            log.info("WebSocket CORS configured with origins: {}", origins);
        } else if (!corsProperties.isProductionMode()) {
            endpoint.setAllowedOriginPatterns(origins.toArray(new String[0]));
            log.warn("WebSocket CORS: using localhost patterns for development");
        } else {
            log.error("WebSocket CORS: no origins configured in production mode - this should have failed at startup");
            endpoint.setAllowedOrigins();
        }
    }

    @Override
    public void configureClientInboundChannel(ChannelRegistration registration) {
        registration.interceptors(new ChannelInterceptor() {
            @Override
            public Message<?> preSend(Message<?> message, MessageChannel channel) {
                StompHeaderAccessor accessor = MessageHeaderAccessor.getAccessor(message, StompHeaderAccessor.class);
                if (accessor == null) {
                    return message;
                }
                StompCommand command = accessor.getCommand();
                if (StompCommand.CONNECT.equals(command)) {
                    authenticateConnect(accessor);
                } else if (requiresAuthenticatedUser(command) && accessor.getUser() == null) {
                    throw new MessagingException("Unauthorized");
                }
                return message;
            }
        });
    }

    private void authenticateConnect(StompHeaderAccessor accessor) {
        String auth = accessor.getFirstNativeHeader("Authorization");
        if (auth == null || !auth.startsWith("Bearer ")) {
            throw new MessagingException("Missing or invalid Authorization header");
        }
        try {
            Claims claims = jwtService.parse(auth.substring(7));
            Long userId = Long.valueOf(claims.getSubject());

            if (!validateToken(claims, userId)) {
                throw new MessagingException("Token validation failed");
            }

            String email = claims.get("email", String.class);
            Optional<com.luckysign.domain.UserRole> dbRole = userRepository.findRoleById(userId);
            String role = dbRole.map(Enum::name).orElse("USER");
            accessor.setUser(new UserPrincipal(userId, email, role));
        } catch (MessagingException e) {
            throw e;
        } catch (Exception e) {
            throw new MessagingException("Invalid token", e);
        }
    }

    private boolean validateToken(Claims claims, Long userId) {
        Optional<Boolean> enabled = userRepository.findEnabledById(userId);
        if (enabled.isEmpty() || !enabled.get()) {
            log.debug("WebSocket: User {} is disabled or not found", userId);
            return false;
        }

        Long tokenVer = jwtService.getTokenVersion(claims);
        if (tokenVer != null) {
            Optional<Long> dbVersion = userRepository.findTokenVersionById(userId);
            if (dbVersion.isPresent() && !dbVersion.get().equals(tokenVer)) {
                log.debug("WebSocket: Token version mismatch for user {}: token={}, db={}", userId, tokenVer, dbVersion.get());
                return false;
            }
        }

        String tokenType = jwtService.getTokenType(claims);
        if ("refresh".equals(tokenType)) {
            log.debug("WebSocket: Refresh token cannot be used for WebSocket connection");
            return false;
        }

        return true;
    }

    private static boolean requiresAuthenticatedUser(StompCommand command) {
        return StompCommand.SEND.equals(command)
                || StompCommand.SUBSCRIBE.equals(command)
                || StompCommand.UNSUBSCRIBE.equals(command);
    }
}
