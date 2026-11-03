package com.luckysign.common;

import org.springframework.dao.DataIntegrityViolationException;

public final class IntegrityMessages {
    public static final String ALREADY_CHECKED_IN = "今日已打卡";
    public static final String DRAW_ALREADY_EXISTS = "今日签已生成，请刷新";
    public static final String DUPLICATE = "数据已存在，请勿重复操作";
    public static final String DATA_ERROR = "数据处理错误";

    private IntegrityMessages() {
    }

    public static String of(DataIntegrityViolationException e) {
        String message = joinMessages(e);
        if (!looksLikeDuplicate(message)) {
            return DATA_ERROR;
        }
        if (isCheckinDuplicate(message)) {
            return ALREADY_CHECKED_IN;
        }
        if (isDrawDuplicate(message)) {
            return DRAW_ALREADY_EXISTS;
        }
        return DUPLICATE;
    }

    static boolean looksLikeDuplicate(String message) {
        String m = message.toLowerCase();
        return m.contains("duplicate")
                || m.contains("unique")
                || m.contains("uk_")
                || m.contains("constraint");
    }

    static boolean isCheckinDuplicate(String message) {
        String m = message.toLowerCase();
        return m.contains("uk_user_checkin_date")
                || m.contains("checkin_records")
                || (m.contains("checkin") && (m.contains("user_id") || m.contains("userid")));
    }

    static boolean isDrawDuplicate(String message) {
        String m = message.toLowerCase();
        return m.contains("uk_user_date")
                || m.contains("daily_draws")
                || (m.contains("draw_date") && (m.contains("user_id") || m.contains("userid")));
    }

    static String joinMessages(Throwable error) {
        StringBuilder sb = new StringBuilder();
        Throwable cur = error;
        int depth = 0;
        while (cur != null && depth < 8) {
            if (cur.getMessage() != null) {
                if (sb.length() > 0) {
                    sb.append('\n');
                }
                sb.append(cur.getMessage());
            }
            cur = cur.getCause();
            depth++;
        }
        return sb.toString();
    }
}
