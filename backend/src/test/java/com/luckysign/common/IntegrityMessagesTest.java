package com.luckysign.common;

import org.junit.jupiter.api.Test;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.HttpStatus;

import static org.junit.jupiter.api.Assertions.assertEquals;

class IntegrityMessagesTest {
    private final GlobalExceptionHandler handler = new GlobalExceptionHandler();

    @Test
    void duplicateCheckinMapsToFriendlyMessage() {
        var ex = new DataIntegrityViolationException("Duplicate entry for key 'uk_user_checkin_date'");
        var res = handler.handleDataIntegrity(ex);
        assertEquals(HttpStatus.CONFLICT, res.getStatusCode());
        assertEquals("今日已打卡", res.getBody().message());
    }

    @Test
    void otherDuplicateKeepsGenericMessage() {
        var ex = new DataIntegrityViolationException("Duplicate entry for key 'uk_users_email'");
        var res = handler.handleDataIntegrity(ex);
        assertEquals(HttpStatus.CONFLICT, res.getStatusCode());
        assertEquals("数据已存在，请勿重复操作", res.getBody().message());
    }
}
