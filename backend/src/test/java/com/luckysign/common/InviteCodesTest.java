package com.luckysign.common;

import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

class InviteCodesTest {
    @Test
    void normalizeUppercasesAndTrims() {
        assertEquals("AB12CD", InviteCodes.normalize(" ab12cd "));
        assertEquals("", InviteCodes.normalize(null));
        assertEquals("", InviteCodes.normalize("  "));
    }

    @Test
    void randomHasFixedLength() {
        String code = InviteCodes.random();
        assertEquals(InviteCodes.LENGTH, code.length());
        assertTrue(code.chars().allMatch(c -> Character.isLetterOrDigit(c)));
    }
}
