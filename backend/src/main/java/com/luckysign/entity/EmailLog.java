package com.luckysign.entity;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;

import java.time.Instant;

@Getter
@Setter
@Entity
@Table(name = "email_logs")
public class EmailLog {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, length = 64)
    private String toEmail;

    @Column(nullable = false, length = 128)
    private String subject;

    @Column(nullable = false, length = 1000)
    private String content;

    @Column(nullable = false, length = 16)
    private String status;

    @Column(length = 500)
    private String errorMessage;

    @Column(nullable = false)
    private Instant createdAt = Instant.now();
}
