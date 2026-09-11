package com.luckysign.entity;

import com.luckysign.domain.UserRole;
import com.luckysign.domain.UserTag;
import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;

import java.time.Instant;
import java.time.LocalDate;

@Getter
@Setter
@Entity
@Table(name = "users")
public class User {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, unique = true, length = 64)
    private String email;

    @Column(nullable = false, length = 32)
    private String nickname;

    @Column(nullable = false, length = 100)
    private String passwordHash;

    @Column(nullable = false)
    private Integer points = 0;

    @Column(nullable = false, length = 32)
    private String title = "签到萌新";

    @Column(nullable = false)
    private Integer streakDays = 0;

    @Column(nullable = false)
    private Integer totalCompletedDays = 0;

    @Column(nullable = false)
    private Integer missStreakDays = 0;

    @Column(length = 512)
    private String avatarUrl;

    private LocalDate lastCheckinDate;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 16)
    private UserTag tag = UserTag.NONE;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 16)
    private UserRole role = UserRole.USER;

    @Column(nullable = false)
    private Long tokenVersion = 0L;

    @Column(nullable = false)
    private Boolean enabled = true;

    @Column(nullable = false)
    private Instant createdAt = Instant.now();

    @Column(nullable = false)
    private Instant updatedAt = Instant.now();

    @Version
    private Long version;

    @PreUpdate
    public void preUpdate() {
        updatedAt = Instant.now();
    }
}
