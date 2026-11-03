package com.luckysign.common;

public class UnauthorizedException extends RuntimeException {
    public UnauthorizedException() {
        super("未登录");
    }

    public UnauthorizedException(String message) {
        super(message);
    }
}
