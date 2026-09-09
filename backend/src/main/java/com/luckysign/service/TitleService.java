package com.luckysign.service;

import org.springframework.stereotype.Service;

@Service
public class TitleService {
    public String resolve(int totalCompletedDays) {
        if (totalCompletedDays >= 365) {
            return "传奇天命人";
        }
        if (totalCompletedDays >= 101) {
            return "命运大师";
        }
        if (totalCompletedDays >= 31) {
            return "运气主宰";
        }
        if (totalCompletedDays >= 11) {
            return "坚持勇士";
        }
        if (totalCompletedDays >= 4) {
            return "每日行者";
        }
        return "签到萌新";
    }
}
