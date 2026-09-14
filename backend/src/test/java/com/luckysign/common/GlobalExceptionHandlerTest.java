package com.luckysign.common;

import org.junit.jupiter.api.Test;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;

import static org.junit.jupiter.api.Assertions.assertEquals;

class GlobalExceptionHandlerTest {
    private final GlobalExceptionHandler handler = new GlobalExceptionHandler();

    @Test
    void duplicateCheckinReturnsFriendlyMessage() {
        DataIntegrityViolationException ex = new DataIntegrityViolationException(
                "Duplicate entry for key 'uk_user_checkin_date'");
        ResponseEntity<ApiResponse<Void>> res = handler.handleDataIntegrity(ex);
        assertEquals(HttpStatus.CONFLICT, res.getStatusCode());
        assertEquals("今日已打卡", res.getBody().message());
    }

    @Test
    void otherDuplicateKeepsGenericMessage() {
        DataIntegrityViolationException ex = new DataIntegrityViolationException(
                "Duplicate entry for key 'uk_circle_user'");
        ResponseEntity<ApiResponse<Void>> res = handler.handleDataIntegrity(ex);
        assertEquals("数据已存在，请勿重复操作", res.getBody().message());
    }
}
