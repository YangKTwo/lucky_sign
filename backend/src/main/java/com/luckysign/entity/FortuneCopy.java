package com.luckysign.entity;

import com.luckysign.domain.FortuneLevel;
import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;

@Getter
@Setter
@Entity
@Table(name = "fortune_copies")
public class FortuneCopy {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 8)
    private FortuneLevel level;

    @Column(nullable = false, length = 128)
    private String content;

    @Column(nullable = false)
    private Boolean enabled = true;
}
