package com.luckysign.common;

import java.util.concurrent.ThreadLocalRandom;

public final class InviteCodes {
    private static final String ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";

    public static final int LENGTH = 10;
    public static final int MIN_LENGTH_NEW = 8;
    public static final int MIN_LENGTH_LEGACY = 4;
    public static final int MAX_LENGTH = 20;

    private InviteCodes() {
    }

    public static String random() {
        return random(LENGTH);
    }

    public static String random(int length) {
        if (length < MIN_LENGTH_NEW) {
            throw new IllegalArgumentException("New invite codes must be at least " + MIN_LENGTH_NEW + " characters");
        }
        ThreadLocalRandom r = ThreadLocalRandom.current();
        StringBuilder sb = new StringBuilder(length);
        for (int i = 0; i < length; i++) {
            sb.append(ALPHABET.charAt(r.nextInt(ALPHABET.length())));
        }
        return sb.toString();
    }

    public static String normalize(String code) {
        return code == null ? "" : code.trim().toUpperCase().replace(" ", "");
    }

    public static boolean isValidFormat(String code) {
        if (code == null || code.isEmpty()) {
            return false;
        }
        String normalized = normalize(code);
        if (normalized.length() < MIN_LENGTH_LEGACY || normalized.length() > MAX_LENGTH) {
            return false;
        }
        for (char c : normalized.toCharArray()) {
            if (ALPHABET.indexOf(c) < 0) {
                return false;
            }
        }
        return true;
    }

    public static boolean isNewCodeFormat(String code) {
        String normalized = normalize(code);
        return isValidFormat(code) && normalized.length() >= MIN_LENGTH_NEW;
    }
}
