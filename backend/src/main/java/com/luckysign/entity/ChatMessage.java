package com.luckysign.entity;

import com.luckysign.domain.ChatMessageType;
import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;

import java.time.Instant;

@Getter
@Setter
@Entity
@Table(name = "chat_messages")
public class ChatMessage {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private Long circleId;

    private Long userId;

    @Column(length = 64)
    private String nickname;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 16)
    private ChatMessageType type;

    @Column(length = 1000)
    private String content;

    @Column(length = 512)
    private String imageUrl;

    private Long checkinId;

    @Column(nullable = false)
    private Instant createdAt = Instant.now();
}
