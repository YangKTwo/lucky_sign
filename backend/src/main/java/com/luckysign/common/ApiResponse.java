package com.luckysign.common;

import java.util.Map;

public record ApiResponse<T>(boolean success, String message, T data) {
    public static <T> ApiResponse<T> ok(T data) {
        return new ApiResponse<>(true, "ok", data);
    }

    public static ApiResponse<Void> okMessage(String message) {
        return new ApiResponse<>(true, message, null);
    }

    public static ApiResponse<Map<String, Object>> fail(String message) {
        return new ApiResponse<>(false, message, null);
    }
}
