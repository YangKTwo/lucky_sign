package com.luckysign.entity;

import com.luckysign.domain.FortuneLevel;
import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;

import java.time.Instant;
import java.time.LocalDate;

@Getter
@Setter
@Entity
@Table(name = "checkin_records")
public class CheckinRecord {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private Long userId;

    @Column(nullable = false)
    private Long drawId;

    @Column(nullable = false)
    private LocalDate checkinDate;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 8)
    private FortuneLevel level;

    @Column(nullable = false, length = 255)
    private String taskContent;

    @Column(length = 500)
    private String textContent;

    @Column(length = 512)
    private String imageUrl;

    @Column(nullable = false)
    private Integer pointsEarned;

    @Column(nullable = false)
    private Integer streakSnapshot;

    @Column(nullable = false)
    private Instant createdAt = Instant.now();
}
