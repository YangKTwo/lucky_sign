package com.luckysign.entity;

import com.luckysign.domain.MemberRole;
import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;

import java.time.Instant;

@Getter
@Setter
@Entity
@Table(name = "circle_members", uniqueConstraints = {
        @UniqueConstraint(columnNames = {"circleId", "userId"})
})
public class CircleMember {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private Long circleId;

    @Column(nullable = false)
    private Long userId;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 16)
    private MemberRole role = MemberRole.MEMBER;

    @Column(nullable = false)
    private Instant joinedAt = Instant.now();
}
