package com.luckysign.service;

import com.luckysign.dto.ChatDtos;
import com.luckysign.entity.ChatMessage;
import com.luckysign.entity.Circle;
import com.luckysign.repository.ChatMessageRepository;
import com.luckysign.repository.CircleRepository;
import com.luckysign.repository.UserRepository;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.data.domain.PageRequest;
import org.springframework.messaging.simp.SimpMessagingTemplate;

import java.util.List;
import java.util.Optional;
import java.util.stream.IntStream;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class ChatServiceHistoryTest {
    @Mock
    private ChatMessageRepository chatMessageRepository;
    @Mock
    private CircleRepository circleRepository;
    @Mock
    private UserRepository userRepository;
    @Mock
    private SimpMessagingTemplate messagingTemplate;
    @Mock
    private RatingService ratingService;
    @Mock
    private AiAssistantService aiAssistantService;
    @Mock
    private MentionService mentionService;
    @Mock
    private ApplicationEventPublisher eventPublisher;

    @Test
    void historySetsHasMoreWhenExtraRowExists() {
        ChatService service = new ChatService(
                chatMessageRepository, circleRepository, userRepository, messagingTemplate,
                ratingService, aiAssistantService, mentionService, eventPublisher);
        Long circleId = 3L;
        List<ChatMessage> extra = IntStream.rangeClosed(1, 3).mapToObj(i -> {
            ChatMessage m = new ChatMessage();
            m.setId((long) i);
            m.setUserId(1L);
            m.setType(com.luckysign.domain.ChatMessageType.TEXT);
            m.setContent("hi");
            return m;
        }).toList();
        when(chatMessageRepository.findByCircleIdOrderByIdDesc(eq(circleId), any(PageRequest.class))).thenReturn(extra);
        when(ratingService.summaries(eq(circleId), any(), eq(9L))).thenReturn(new java.util.HashMap<>());
        when(userRepository.findAllById(any())).thenReturn(List.of());
        when(mentionService.deserializeMentionIds(any())).thenReturn(List.of());

        ChatDtos.HistoryResponse page = service.history(circleId, 9L, null, 2);
        assertTrue(page.hasMore());
        assertFalse(page.messages().isEmpty());
    }
}
