package com.luckysign.common;

import java.util.concurrent.ThreadLocalRandom;

public final class InviteCodes {
    private static final String ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
    public static final int LENGTH = 10;

    private InviteCodes() {
    }

    public static String random() {
        ThreadLocalRandom r = ThreadLocalRandom.current();
        StringBuilder sb = new StringBuilder(LENGTH);
        for (int i = 0; i < LENGTH; i++) {
            sb.append(ALPHABET.charAt(r.nextInt(ALPHABET.length())));
        }
        return sb.toString();
    }

    public static String normalize(String code) {
        return code == null ? "" : code.trim().toUpperCase().replace(" ", "");
    }
}
