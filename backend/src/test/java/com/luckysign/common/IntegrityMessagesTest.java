package com.luckysign.common;

import org.junit.jupiter.api.Test;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.HttpStatus;

import static org.junit.jupiter.api.Assertions.assertEquals;

class IntegrityMessagesTest {
    @Test
    void duplicateCheckinConstraintIsTodayAlreadyDone() {
        DataIntegrityViolationException ex = new DataIntegrityViolationException(
                "Duplicate entry for key 'uk_user_checkin_date'");
        assertEquals("今日已打卡", IntegrityMessages.of(ex));
    }

    @Test
    void otherUniqueConflictIsGeneric() {
        DataIntegrityViolationException ex = new DataIntegrityViolationException(
                "Duplicate entry for key 'uk_circle_user'");
        assertEquals("数据已存在，请勿重复操作", IntegrityMessages.of(ex));
    }

    @Test
    void handlerMapsDuplicateCheckinToConflict() {
        GlobalExceptionHandler handler = new GlobalExceptionHandler();
        var res = handler.handleDataIntegrity(
                new DataIntegrityViolationException("Duplicate entry for key 'uk_user_checkin_date'"));
        assertEquals(HttpStatus.CONFLICT, res.getStatusCode());
        assertEquals("今日已打卡", res.getBody().message());
    }
}
