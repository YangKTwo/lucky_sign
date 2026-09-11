package com.luckysign.event;

public record AssistantRequestedEvent(Long userId, String nickname, String question, Long messageId) {
}
