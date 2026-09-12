package com.luckysign.config;

import org.junit.jupiter.api.Test;

import java.util.List;

import static org.junit.jupiter.api.Assertions.*;

class CorsPropertiesTest {

    @Test
    void productionModeFailsWithEmptyOrigins() {
        CorsProperties props = new CorsProperties("", true);
        assertThrows(IllegalStateException.class, props::init);
    }

    @Test
    void productionModeFailsWithWildcard() {
        CorsProperties props = new CorsProperties("*", true);
        assertThrows(IllegalStateException.class, props::init);
    }

    @Test
    void productionModeAcceptsExplicitOrigins() {
        CorsProperties props = new CorsProperties("https://example.com,https://app.example.com", true);
        assertDoesNotThrow(props::init);
        assertEquals(List.of("https://example.com", "https://app.example.com"), props.getAllowedOrigins());
        assertTrue(props.hasExplicitOrigins());
    }

    @Test
    void developmentModeFallsBackToLocalhost() {
        CorsProperties props = new CorsProperties("", false);
        props.init();
        assertTrue(props.getAllowedOrigins().isEmpty());
        assertFalse(props.hasExplicitOrigins());
        assertEquals(List.of("http://localhost:*", "https://localhost:*"), props.getEffectiveOrigins());
    }

    @Test
    void wildcardIsStrippedFromOrigins() {
        CorsProperties props = new CorsProperties("https://example.com,*,https://other.com", false);
        props.init();
        assertEquals(List.of("https://example.com", "https://other.com"), props.getAllowedOrigins());
    }

    @Test
    void effectiveOriginsUsesExplicitWhenConfigured() {
        CorsProperties props = new CorsProperties("https://119-23-45-226.sslip.io", false);
        props.init();
        assertEquals(List.of("https://119-23-45-226.sslip.io"), props.getEffectiveOrigins());
        assertTrue(props.hasExplicitOrigins());
    }

    @Test
    void trimsAndFiltersEmptyOrigins() {
        CorsProperties props = new CorsProperties("  https://a.com , , https://b.com  ", false);
        props.init();
        assertEquals(List.of("https://a.com", "https://b.com"), props.getAllowedOrigins());
    }
}
