package com.luckysign.entity;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;

import java.time.Instant;

@Getter
@Setter
@Entity
@Table(name = "circles")
public class Circle {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, length = 64)
    private String name;

    @Column(nullable = false)
    private Long ownerId;

    @Column(nullable = false)
    private Integer maxMembers = 10;

    @Column(nullable = false)
    private Integer memberCount = 0;

    @Column(length = 16, unique = true)
    private String inviteCode;

    @Column(nullable = false, length = 16)
    private String status = "ACTIVE";

    @Column(nullable = false)
    private Instant createdAt = Instant.now();
}
