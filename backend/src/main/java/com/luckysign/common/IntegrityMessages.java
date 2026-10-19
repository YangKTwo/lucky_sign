package com.luckysign.common;

import org.springframework.dao.DataIntegrityViolationException;

public final class IntegrityMessages {
    private IntegrityMessages() {
    }

    public static String of(DataIntegrityViolationException e) {
        Throwable cause = e.getMostSpecificCause();
        String message = cause != null && cause.getMessage() != null ? cause.getMessage() : e.getMessage();
        if (message == null) {
            return "数据处理错误";
        }
        String lower = message.toLowerCase();
        if (lower.contains("uk_user_checkin_date")
                || (lower.contains("duplicate") && lower.contains("checkin"))) {
            return "今日已打卡";
        }
        if (lower.contains("duplicate") || lower.contains("unique")) {
            return "数据已存在，请勿重复操作";
        }
        return "数据处理错误";
    }
}
