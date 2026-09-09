package com.luckysign.repository;

import com.luckysign.entity.ChatMessage;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface ChatMessageRepository extends JpaRepository<ChatMessage, Long> {
    List<ChatMessage> findByCircleIdAndIdLessThanOrderByIdDesc(Long circleId, Long beforeId, Pageable pageable);
    List<ChatMessage> findByCircleIdOrderByIdDesc(Long circleId, Pageable pageable);
}
