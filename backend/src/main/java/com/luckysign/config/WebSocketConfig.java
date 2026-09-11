package com.luckysign.config;

import com.luckysign.security.JwtService;
import com.luckysign.security.UserPrincipal;
import io.jsonwebtoken.Claims;
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

@Configuration
@EnableWebSocketMessageBroker
public class WebSocketConfig implements WebSocketMessageBrokerConfigurer {
    private final JwtService jwtService;

    public WebSocketConfig(JwtService jwtService) {
        this.jwtService = jwtService;
    }

    @Override
    public void configureMessageBroker(MessageBrokerRegistry registry) {
        registry.enableSimpleBroker("/topic");
        registry.setApplicationDestinationPrefixes("/app");
    }

    @Override
    public void registerStompEndpoints(StompEndpointRegistry registry) {
        registry.addEndpoint("/ws")
                .setAllowedOriginPatterns("*");
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
            String email = claims.get("email", String.class);
            String role = claims.get("role", String.class);
            accessor.setUser(new UserPrincipal(userId, email, role));
        } catch (MessagingException e) {
            throw e;
        } catch (Exception e) {
            throw new MessagingException("Invalid token", e);
        }
    }

    private static boolean requiresAuthenticatedUser(StompCommand command) {
        return StompCommand.SEND.equals(command)
                || StompCommand.SUBSCRIBE.equals(command)
                || StompCommand.UNSUBSCRIBE.equals(command);
    }
}
