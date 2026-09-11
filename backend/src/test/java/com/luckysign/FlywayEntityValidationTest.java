package com.luckysign;

import com.luckysign.entity.*;
import com.luckysign.repository.*;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;

import static org.junit.jupiter.api.Assertions.*;

/**
 * Verifies JPA entities match expected schema structure.
 * Uses H2 in MySQL mode with ddl-auto=create to test entity definitions.
 * 
 * For full Flyway migration verification with MySQL:
 * 1. Start MySQL: docker run -d -e MYSQL_ROOT_PASSWORD=test -e MYSQL_DATABASE=lucky_sign -p 3306:3306 mysql:8
 * 2. Run: MYSQL_PASSWORD=test JWT_SECRET=test-key-32-chars-minimum-required mvn spring-boot:run
 * 3. Check logs for "Flyway ... Successfully applied X migrations"
 * 4. Verify no Hibernate validation errors
 */
@SpringBootTest
@ActiveProfiles("h2test")
class FlywayEntityValidationTest {

    @Autowired
    private UserRepository userRepository;

    @Test
    void contextLoads() {
        assertNotNull(userRepository);
    }

    @Test
    void entitySchemaMatchesExpectations() {
        User user = new User();
        user.setEmail("test@example.com");
        user.setNickname("TestUser");
        user.setPasswordHash("hash");
        
        User saved = userRepository.save(user);
        assertNotNull(saved.getId());
        assertEquals(0L, saved.getTokenVersion());
        assertTrue(saved.getEnabled());
    }
}
