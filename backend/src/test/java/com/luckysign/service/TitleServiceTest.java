package com.luckysign.service;

import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;

class TitleServiceTest {
    private final TitleService titles = new TitleService();

    @Test
    void resolveAndNextTitleProgress() {
        assertEquals("签到萌新", titles.resolve(0));
        assertEquals("每日行者", titles.nextTitle(0));
        assertEquals(4, titles.daysToNextTitle(0));
        assertEquals(4, titles.nextTitleAt(0));

        assertEquals("每日行者", titles.resolve(4));
        assertEquals("坚持勇士", titles.nextTitle(4));
        assertEquals(7, titles.daysToNextTitle(4));

        assertEquals("传奇天命人", titles.resolve(365));
        assertNull(titles.nextTitle(365));
        assertEquals(0, titles.daysToNextTitle(365));
        assertNull(titles.nextTitleAt(365));
    }
}
