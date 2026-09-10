package com.luckysign.event;

public record AssistantRequestedEvent(String nickname, String question, Long messageId) {
}
