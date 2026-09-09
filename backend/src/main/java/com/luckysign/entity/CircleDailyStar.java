package com.luckysign.entity;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;

import java.time.Instant;
import java.time.LocalDate;

@Getter
@Setter
@Entity
@Table(name = "circle_daily_stars", uniqueConstraints = {
        @UniqueConstraint(columnNames = {"circleId", "starDate"})
})
public class CircleDailyStar {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private Long circleId;

    @Column(nullable = false)
    private Long userId;

    @Column(nullable = false)
    private LocalDate starDate;

    @Column(nullable = false)
    private Instant createdAt = Instant.now();
}
