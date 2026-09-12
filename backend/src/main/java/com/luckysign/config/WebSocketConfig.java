package com.luckysign.config;

import com.luckysign.repository.CircleMemberRepository;
import com.luckysign.repository.UserRepository;
import com.luckysign.security.JwtService;
import com.luckysign.security.UserPrincipal;
import io.jsonwebtoken.Claims;
import io.jsonwebtoken.ExpiredJwtException;
import io.jsonwebtoken.MalformedJwtException;
import io.jsonwebtoken.security.SignatureException;
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
import java.util.regex.Matcher;
import java.util.regex.Pattern;

@Configuration
@EnableWebSocketMessageBroker
public class WebSocketConfig implements WebSocketMessageBrokerConfigurer {
    private static final Logger log = LoggerFactory.getLogger(WebSocketConfig.class);
    private static final Pattern CIRCLE_TOPIC_PATTERN = Pattern.compile("^/topic/chat/(\\d+)$");

    private final JwtService jwtService;
    private final UserRepository userRepository;
    private final CircleMemberRepository circleMemberRepository;
    private final CorsProperties corsProperties;

    public WebSocketConfig(JwtService jwtService, UserRepository userRepository,
                           CircleMemberRepository circleMemberRepository,
                           CorsProperties corsProperties) {
        this.jwtService = jwtService;
        this.userRepository = userRepository;
        this.circleMemberRepository = circleMemberRepository;
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
                } else if (requiresAuthenticatedUser(command)) {
                    if (accessor.getUser() == null) {
                        log.warn("WebSocket {}: no authenticated user", command);
                        throw new MessagingException("Authentication required - please CONNECT first");
                    }
                    if (StompCommand.SUBSCRIBE.equals(command)) {
                        validateSubscription(accessor);
                    }
                }
                return message;
            }
        });
    }

    private void authenticateConnect(StompHeaderAccessor accessor) {
        String auth = accessor.getFirstNativeHeader("Authorization");
        if (auth == null) {
            log.warn("WebSocket CONNECT: missing Authorization header");
            throw new MessagingException("Missing Authorization header - send 'Authorization: Bearer <token>'");
        }
        if (!auth.startsWith("Bearer ")) {
            log.warn("WebSocket CONNECT: Authorization header does not start with 'Bearer '");
            throw new MessagingException("Invalid Authorization format - expected 'Bearer <token>'");
        }
        String token = auth.substring(7).trim();
        if (token.isEmpty()) {
            log.warn("WebSocket CONNECT: empty token after 'Bearer '");
            throw new MessagingException("Empty token - provide a valid JWT");
        }
        try {
            Claims claims = jwtService.parse(token);
            Long userId = Long.valueOf(claims.getSubject());

            String validationError = validateTokenWithReason(claims, userId);
            if (validationError != null) {
                log.warn("WebSocket CONNECT: token validation failed for user {}: {}", userId, validationError);
                throw new MessagingException(validationError);
            }

            String email = claims.get("email", String.class);
            Optional<com.luckysign.domain.UserRole> dbRole = userRepository.findRoleById(userId);
            String role = dbRole.map(Enum::name).orElse("USER");
            accessor.setUser(new UserPrincipal(userId, email, role));
            log.debug("WebSocket CONNECT: authenticated user {} ({})", userId, email);
        } catch (MessagingException e) {
            throw e;
        } catch (ExpiredJwtException e) {
            log.warn("WebSocket CONNECT: token expired at {}", e.getClaims().getExpiration());
            throw new MessagingException("Token expired - please login again");
        } catch (SignatureException e) {
            log.warn("WebSocket CONNECT: invalid token signature");
            throw new MessagingException("Invalid token signature");
        } catch (MalformedJwtException e) {
            log.warn("WebSocket CONNECT: malformed token");
            throw new MessagingException("Malformed token");
        } catch (NumberFormatException e) {
            log.warn("WebSocket CONNECT: invalid user ID in token subject");
            throw new MessagingException("Invalid token - bad user ID");
        } catch (Exception e) {
            log.warn("WebSocket CONNECT: unexpected error parsing token: {} - {}", e.getClass().getSimpleName(), e.getMessage());
            throw new MessagingException("Token validation failed");
        }
    }

    private String validateTokenWithReason(Claims claims, Long userId) {
        Optional<Boolean> enabled = userRepository.findEnabledById(userId);
        if (enabled.isEmpty()) {
            return "User not found";
        }
        if (!enabled.get()) {
            return "Account is disabled";
        }

        Long tokenVer = jwtService.getTokenVersion(claims);
        if (tokenVer != null) {
            Optional<Long> dbVersion = userRepository.findTokenVersionById(userId);
            if (dbVersion.isPresent() && !dbVersion.get().equals(tokenVer)) {
                return "Token has been revoked (logged out elsewhere)";
            }
        }

        String tokenType = jwtService.getTokenType(claims);
        if ("refresh".equals(tokenType)) {
            return "Refresh token cannot be used for WebSocket - use access token";
        }

        return null;
    }

    private void validateSubscription(StompHeaderAccessor accessor) {
        String destination = accessor.getDestination();
        if (destination == null) {
            return;
        }

        Matcher matcher = CIRCLE_TOPIC_PATTERN.matcher(destination);
        if (matcher.matches()) {
            Long circleId = Long.valueOf(matcher.group(1));
            Long userId = getUserId(accessor);
            if (userId == null) {
                throw new MessagingException("Authentication required to subscribe");
            }
            if (!circleMemberRepository.existsByCircleIdAndUserId(circleId, userId)) {
                log.warn("WebSocket SUBSCRIBE denied: user {} is not a member of circle {}", userId, circleId);
                throw new MessagingException("You are not a member of this circle");
            }
            log.debug("WebSocket SUBSCRIBE: user {} subscribed to circle {}", userId, circleId);
        }
    }

    private Long getUserId(StompHeaderAccessor accessor) {
        if (accessor.getUser() instanceof UserPrincipal up) {
            return up.getUserId();
        }
        return null;
    }

    private static boolean requiresAuthenticatedUser(StompCommand command) {
        return StompCommand.SEND.equals(command)
                || StompCommand.SUBSCRIBE.equals(command)
                || StompCommand.UNSUBSCRIBE.equals(command);
    }
}
