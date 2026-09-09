package com.luckysign.domain;

public enum FortuneLevel {
    SS(5, 3, TaskDifficulty.SIMPLE, "传说级", "今日欧皇附体！"),
    S(15, 3, TaskDifficulty.SIMPLE, "史诗级", "运气爆棚！"),
    A(30, 5, TaskDifficulty.MEDIUM, "稀有级", "不错，挺顺"),
    B(35, 8, TaskDifficulty.MEDIUM_HARD, "普通级", "平平无奇的一天"),
    C(15, 15, TaskDifficulty.HARD, "破烂级", "今日非酋认证…");

    private final int weight;
    private final int basePoints;
    private final TaskDifficulty difficulty;
    private final String displayName;
    private final String defaultCopy;

    FortuneLevel(int weight, int basePoints, TaskDifficulty difficulty, String displayName, String defaultCopy) {
        this.weight = weight;
        this.basePoints = basePoints;
        this.difficulty = difficulty;
        this.displayName = displayName;
        this.defaultCopy = defaultCopy;
    }

    public int getWeight() {
        return weight;
    }

    public int getBasePoints() {
        return basePoints;
    }

    public TaskDifficulty getDifficulty() {
        return difficulty;
    }

    public String getDisplayName() {
        return displayName;
    }

    public String getDefaultCopy() {
        return defaultCopy;
    }

    public int penaltyPoints() {
        return basePoints / 2;
    }
}
