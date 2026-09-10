package com.luckysign.entity;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;

import java.time.Instant;

@Getter
@Setter
@Entity
@Table(
        name = "checkin_ratings",
        uniqueConstraints = @UniqueConstraint(columnNames = {"checkinId", "raterUserId"})
)
public class CheckinRating {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private Long checkinId;

    @Column(nullable = false)
    private Long targetUserId;

    @Column(nullable = false)
    private Long raterUserId;

    /** 1-5 分 */
    @Column(nullable = false)
    private Integer score;

    @Column(nullable = false)
    private Instant createdAt = Instant.now();
}
