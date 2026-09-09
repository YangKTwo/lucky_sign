package com.luckysign.entity;

import com.luckysign.domain.PointChangeType;
import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;

import java.time.Instant;

@Getter
@Setter
@Entity
@Table(name = "points_log")
public class PointsLog {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private Long userId;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 16)
    private PointChangeType changeType;

    @Column(nullable = false)
    private Integer delta;

    @Column(nullable = false)
    private Integer balanceAfter;

    private Long relatedId;

    @Column(nullable = false)
    private Instant createdAt = Instant.now();
}
