package com.luckysign.entity;

import com.luckysign.domain.DrawStatus;
import com.luckysign.domain.FortuneLevel;
import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;

import java.time.Instant;
import java.time.LocalDate;

@Getter
@Setter
@Entity
@Table(name = "daily_draws", uniqueConstraints = {
        @UniqueConstraint(columnNames = {"userId", "drawDate"})
})
public class DailyDraw {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private Long userId;

    @Column(nullable = false)
    private LocalDate drawDate;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 8)
    private FortuneLevel level;

    @Column(nullable = false, length = 128)
    private String fortuneText;

    @Column(nullable = false)
    private Long taskId;

    @Column(nullable = false, length = 255)
    private String taskContent;

    @Column(nullable = false)
    private Integer basePoints;

    @Column(nullable = false)
    private Boolean luckyStar = false;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 16)
    private DrawStatus status = DrawStatus.PENDING;

    @Version
    private Long version;

    @Column(nullable = false)
    private Instant createdAt = Instant.now();
}
