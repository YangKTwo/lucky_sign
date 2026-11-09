package com.luckysign.service;

import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;

class CheckinServiceExtrasTest {
    @Test
    void streakBonusOnWeekAndMonth() {
        assertEquals(0, CheckinService.streakBonusPoints(0));
        assertEquals(0, CheckinService.streakBonusPoints(6));
        assertEquals(10, CheckinService.streakBonusPoints(7));
        assertEquals(10, CheckinService.streakBonusPoints(14));
        assertEquals(50, CheckinService.streakBonusPoints(30));
    }
}
