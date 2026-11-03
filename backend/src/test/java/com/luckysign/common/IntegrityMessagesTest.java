package com.luckysign.common;

import org.junit.jupiter.api.Test;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.HttpStatus;

import static org.junit.jupiter.api.Assertions.assertEquals;

class IntegrityMessagesTest {
    private final GlobalExceptionHandler handler = new GlobalExceptionHandler();

    @Test
    void duplicateCheckinConstraintReturnsAlreadyCheckedIn() {
        DataIntegrityViolationException ex = new DataIntegrityViolationException(
                "Duplicate entry '1-2026-11-03' for key 'uk_user_checkin_date'");
        assertEquals("今日已打卡", IntegrityMessages.of(ex));
        var resp = handler.handleDataIntegrity(ex);
        assertEquals(HttpStatus.CONFLICT, resp.getStatusCode());
        assertEquals("今日已打卡", resp.getBody().message());
    }

    @Test
    void duplicateDrawConstraintReturnsRefreshCopy() {
        DataIntegrityViolationException ex = new DataIntegrityViolationException(
                "Duplicate entry for key 'uk_user_date' on daily_draws");
        assertEquals("今日签已生成，请刷新", IntegrityMessages.of(ex));
    }

    @Test
    void unauthenticatedReturns401() {
        var resp = handler.handleUnauthorized(new UnauthorizedException());
        assertEquals(HttpStatus.UNAUTHORIZED, resp.getStatusCode());
        assertEquals("未登录", resp.getBody().message());
    }

    @Test
    void genericUniqueReturnsDuplicateCopy() {
        DataIntegrityViolationException ex = new DataIntegrityViolationException(
                "Duplicate entry for key 'uk_users_email'");
        assertEquals("数据已存在，请勿重复操作", IntegrityMessages.of(ex));
    }
}
