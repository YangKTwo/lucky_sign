package com.luckysign.common;

import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.*;

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

    @Test
    void newCodesAreAtLeast8Characters() {
        assertTrue(InviteCodes.LENGTH >= InviteCodes.MIN_LENGTH_NEW,
            "Default code length should be at least MIN_LENGTH_NEW");
        
        String code = InviteCodes.random();
        assertTrue(code.length() >= 8, "New codes should be >= 8 characters");
        assertTrue(InviteCodes.isNewCodeFormat(code));
    }

    @Test
    void randomWithCustomLengthRejectsShortCodes() {
        assertThrows(IllegalArgumentException.class, () -> InviteCodes.random(7));
        assertDoesNotThrow(() -> InviteCodes.random(8));
        assertEquals(12, InviteCodes.random(12).length());
    }

    @Test
    void legacyCodesRemainValid() {
        assertTrue(InviteCodes.isValidFormat("HY3RX7"), "6-char legacy code should be valid");
        assertTrue(InviteCodes.isValidFormat("K5ACCEPT2X"), "10-char code should be valid");
        assertTrue(InviteCodes.isValidFormat("ABCD"), "4-char legacy code should be valid");
        
        assertFalse(InviteCodes.isNewCodeFormat("HY3RX7"), "6-char code is not new format");
        assertTrue(InviteCodes.isNewCodeFormat("K5ACCEPT2X"), "10-char code is new format");
    }

    @Test
    void invalidCodesRejected() {
        assertFalse(InviteCodes.isValidFormat(null));
        assertFalse(InviteCodes.isValidFormat(""));
        assertFalse(InviteCodes.isValidFormat("AB")); // too short
        assertFalse(InviteCodes.isValidFormat("ABCDEFGHIJKLMNOPQRSTUVWXYZ")); // too long (>20)
        assertFalse(InviteCodes.isValidFormat("ABC!@#")); // invalid characters
        assertFalse(InviteCodes.isValidFormat("ABCIO")); // I and O are not in alphabet
    }

    @Test
    void normalizeHandlesSpaces() {
        assertEquals("HY3RX7", InviteCodes.normalize("hy3 rx7"));
        assertEquals("K5ACCEPT2X", InviteCodes.normalize("  k5accept2x  "));
    }
}
