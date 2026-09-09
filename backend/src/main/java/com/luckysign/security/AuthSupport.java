package com.luckysign.security;

import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;

public final class AuthSupport {
    private AuthSupport() {
    }

    public static Long currentUserId() {
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        if (auth instanceof UserPrincipal principal) {
            return principal.getUserId();
        }
        throw new IllegalStateException("未登录");
    }
}
