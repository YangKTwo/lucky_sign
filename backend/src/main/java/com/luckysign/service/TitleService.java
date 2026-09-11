package com.luckysign.service;

import org.springframework.stereotype.Service;

@Service
public class TitleService {
    public static final int[] THRESHOLDS = {0, 4, 11, 31, 101, 365};
    public static final String[] TITLES = {
            "签到萌新", "每日行者", "坚持勇士", "运气主宰", "命运大师", "传奇天命人"
    };

    public String resolve(int totalCompletedDays) {
        String title = TITLES[0];
        for (int i = 0; i < THRESHOLDS.length; i++) {
            if (totalCompletedDays >= THRESHOLDS[i]) {
                title = TITLES[i];
            }
        }
        return title;
    }

    public String nextTitle(int totalCompletedDays) {
        for (int i = 1; i < THRESHOLDS.length; i++) {
            if (totalCompletedDays < THRESHOLDS[i]) {
                return TITLES[i];
            }
        }
        return null;
    }

    public int daysToNextTitle(int totalCompletedDays) {
        for (int i = 1; i < THRESHOLDS.length; i++) {
            if (totalCompletedDays < THRESHOLDS[i]) {
                return THRESHOLDS[i] - totalCompletedDays;
            }
        }
        return 0;
    }

    public Integer nextTitleAt(int totalCompletedDays) {
        for (int i = 1; i < THRESHOLDS.length; i++) {
            if (totalCompletedDays < THRESHOLDS[i]) {
                return THRESHOLDS[i];
            }
        }
        return null;
    }
}
