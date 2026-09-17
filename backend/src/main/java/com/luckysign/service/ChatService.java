package com.luckysign.service;

import com.luckysign.common.BizException;
import com.luckysign.domain.ChatDeleteReason;
import com.luckysign.domain.ChatMessageType;
import com.luckysign.domain.UserTag;
import com.luckysign.dto.ChatDtos;
import com.luckysign.dto.RatingDtos;
import com.luckysign.entity.ChatMessage;
import com.luckysign.entity.CheckinRecord;
import com.luckysign.entity.DailyDraw;
import com.luckysign.entity.User;
import com.luckysign.event.AssistantRequestedEvent;
import com.luckysign.repository.ChatMessageRepository;
import com.luckysign.repository.CircleRepository;
import com.luckysign.repository.UserRepository;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.data.domain.PageRequest;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Duration;
import java.time.Instant;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.function.Function;
import java.util.stream.Collectors;

@Service
public class ChatService {
    public static final String ASSISTANT_LOADING = "正在回复…";

    private final ChatMessageRepository chatMessageRepository;
    private final CircleRepository circleRepository;
    private final UserRepository userRepository;
    private final SimpMessagingTemplate messagingTemplate;
    private final RatingService ratingService;
    private final AiAssistantService aiAssistantService;
    private final MentionService mentionService;
    private final ApplicationEventPublisher eventPublisher;

    public ChatService(ChatMessageRepository chatMessageRepository,
                       CircleRepository circleRepository,
                       UserRepository userRepository,
                       SimpMessagingTemplate messagingTemplate,
                       RatingService ratingService,
                       AiAssistantService aiAssistantService,
                       MentionService mentionService,
                       ApplicationEventPublisher eventPublisher) {
        this.chatMessageRepository = chatMessageRepository;
        this.circleRepository = circleRepository;
        this.userRepository = userRepository;
        this.messagingTemplate = messagingTemplate;
        this.ratingService = ratingService;
        this.aiAssistantService = aiAssistantService;
        this.mentionService = mentionService;
        this.eventPublisher = eventPublisher;
    }

    public ChatDtos.HistoryResponse history(Long circleId, Long viewerUserId, Long beforeId, int size) {
        int limit = Math.min(Math.max(size, 1), 50);
        List<ChatMessage> fetched;
        if (beforeId == null) {
            fetched = chatMessageRepository.findByCircleIdOrderByIdDesc(circleId, PageRequest.of(0, limit + 1));
        } else {
            fetched = chatMessageRepository.findByCircleIdAndIdLessThanOrderByIdDesc(
                    circleId, beforeId, PageRequest.of(0, limit + 1));
        }
        boolean hasMore = fetched.size() > limit;
        List<ChatMessage> list = hasMore ? fetched.subList(0, limit) : fetched;
        List<Long> checkinIds = list.stream().map(ChatMessage::getCheckinId).filter(Objects::nonNull).toList();
        Map<Long, RatingDtos.RatingSummary> ratings = ratingService.summaries(circleId, checkinIds, viewerUserId);
        Map<Long, User> users = loadUsers(list);
        List<ChatDtos.MessageView> views = new ArrayList<>(list.stream()
                .map(m -> toView(m, users.get(m.getUserId()), ratings.get(m.getCheckinId())))
                .toList());
        Collections.reverse(views);
        return new ChatDtos.HistoryResponse(views, hasMore);
    }

    @Transactional
    public ChatDtos.MessageView sendText(Long circleId, Long userId, String content) {
        if (content == null || content.isBlank()) {
            throw new BizException("消息不能为空");
        }
        if (content.length() > 1000) {
            throw new BizException("消息过长");
        }
        User user = userRepository.findById(userId).orElseThrow(() -> new BizException("用户不存在"));
        if (user.getTag() == UserTag.DORMANT) {
            throw new BizException("休眠账号禁言，请联系管理员解锁");
        }
        String text = content.trim();
        List<Long> mentioned = mentionService.parseMentionedUserIds(text, circleId, user.getId());
        ChatMessage msg = new ChatMessage();
        msg.setCircleId(circleId);
        msg.setUserId(user.getId());
        msg.setNickname(user.getNickname());
        msg.setType(ChatMessageType.TEXT);
        msg.setContent(text);
        msg.setMentionedUserIds(mentionService.serializeMentionIds(mentioned));
        msg = chatMessageRepository.save(msg);
        ChatDtos.MessageView view = toView(msg, user, null);
        messagingTemplate.convertAndSend("/topic/chat/" + circleId, view);
        if (aiAssistantService.isReady() && mentionService.mentionsAssistant(text)) {
            Long pendingId = postAssistant(circleId, ASSISTANT_LOADING);
            String question = mentionService.stripAssistantMentions(text);
            if (question.isBlank()) {
                question = "你好，请简单介绍一下你自己，并说明你可以怎么帮助这个打卡小圈子。";
            }
            eventPublisher.publishEvent(new AssistantRequestedEvent(
                    user.getId(),
                    user.getNickname(),
                    question,
                    pendingId));
        }
        return view;
    }

    @Transactional
    public void postCheckin(Long circleId, User user, CheckinRecord record, DailyDraw draw) {
        String content = String.format("完成了%s任务：%s（+%d分%s）",
                draw.getLevel().getDisplayName(),
                draw.getTaskContent(),
                record.getPointsEarned(),
                Boolean.TRUE.equals(draw.getLuckyStar()) ? "，幸运星翻倍" : "");
        ChatMessage msg = new ChatMessage();
        msg.setCircleId(circleId);
        msg.setUserId(user.getId());
        msg.setNickname(user.getNickname());
        msg.setType(ChatMessageType.CHECKIN);
        msg.setContent(content);
        msg.setImageUrl(record.getImageUrl());
        msg.setCheckinId(record.getId());
        msg = chatMessageRepository.save(msg);
        messagingTemplate.convertAndSend("/topic/chat/" + circleId, toView(msg, user, null));
    }

    @Transactional
    public void postSystem(Long circleId, String content) {
        ChatMessage msg = new ChatMessage();
        msg.setCircleId(circleId);
        msg.setType(ChatMessageType.SYSTEM);
        msg.setContent(content);
        msg = chatMessageRepository.save(msg);
        messagingTemplate.convertAndSend("/topic/chat/" + circleId, toView(msg, null, null));
    }

    @Transactional
    public Long postAssistant(Long circleId, String content) {
        return postAssistant(circleId, content, List.of());
    }

    @Transactional
    public Long postAssistant(Long circleId, String content, List<Long> mentionedUserIds) {
        ChatMessage msg = new ChatMessage();
        msg.setCircleId(circleId);
        msg.setNickname(MentionService.ASSISTANT_DISPLAY_NAME);
        msg.setType(ChatMessageType.ASSISTANT);
        msg.setContent(content);
        if (mentionedUserIds != null && !mentionedUserIds.isEmpty()) {
            msg.setMentionedUserIds(mentionService.serializeMentionIds(mentionedUserIds));
        }
        msg = chatMessageRepository.save(msg);
        messagingTemplate.convertAndSend("/topic/chat/" + circleId, toView(msg, null, null));
        return msg.getId();
    }

    @Transactional
    public void updateAssistant(Long messageId, String content) {
        if (messageId == null) {
            return;
        }
        ChatMessage msg = chatMessageRepository.findById(messageId).orElse(null);
        if (msg == null || msg.getType() != ChatMessageType.ASSISTANT) {
            return;
        }
        if (msg.getDeletedAt() != null) {
            return;
        }
        msg.setContent(content);
        chatMessageRepository.save(msg);
        messagingTemplate.convertAndSend("/topic/chat/" + msg.getCircleId(), toView(msg, null, null));
    }

    @Transactional
    public ChatDtos.MessageView recall(Long circleId, Long userId, Long messageId) {
        ChatMessage msg = chatMessageRepository.findById(messageId)
                .orElseThrow(() -> new BizException("消息不存在"));
        if (!Objects.equals(msg.getCircleId(), circleId)) {
            throw new BizException("消息不在当前圈子");
        }
        if (msg.getDeletedAt() != null) {
            throw new BizException("消息已删除");
        }
        if (msg.getType() != ChatMessageType.TEXT) {
            throw new BizException("该类消息不可撤回");
        }
        if (!Objects.equals(msg.getUserId(), userId)) {
            throw new BizException("只能撤回自己的消息");
        }
        if (msg.getCreatedAt() == null
                || msg.getCreatedAt().isBefore(Instant.now().minus(Duration.ofMinutes(2)))) {
            throw new BizException("超过 2 分钟，无法撤回");
        }
        return softDelete(msg, userId, ChatDeleteReason.RECALL);
    }

    @Transactional
    public ChatDtos.MessageView adminRemove(Long adminUserId, Long messageId) {
        ChatMessage msg = chatMessageRepository.findById(messageId)
                .orElseThrow(() -> new BizException("消息不存在"));
        if (msg.getDeletedAt() != null) {
            throw new BizException("消息已删除");
        }
        if (msg.getType() == ChatMessageType.CHECKIN || msg.getType() == ChatMessageType.SYSTEM) {
            throw new BizException("该类消息不可删除");
        }
        return softDelete(msg, adminUserId, ChatDeleteReason.ADMIN_REMOVE);
    }

    private ChatDtos.MessageView softDelete(ChatMessage msg, Long actorId, ChatDeleteReason reason) {
        msg.setDeletedAt(Instant.now());
        msg.setDeletedBy(actorId);
        msg.setDeleteReason(reason);
        chatMessageRepository.save(msg);
        User user = msg.getUserId() == null ? null : userRepository.findById(msg.getUserId()).orElse(null);
        ChatDtos.MessageView view = toView(msg, user, null);
        messagingTemplate.convertAndSend("/topic/chat/" + msg.getCircleId(), view);
        return view;
    }

    private Map<Long, User> loadUsers(List<ChatMessage> list) {
        List<Long> ids = list.stream().map(ChatMessage::getUserId).filter(Objects::nonNull).distinct().toList();
        if (ids.isEmpty()) {
            return Map.of();
        }
        return userRepository.findAllById(ids).stream().collect(Collectors.toMap(User::getId, Function.identity()));
    }

    private ChatDtos.MessageView toView(ChatMessage msg, User user, RatingDtos.RatingSummary rating) {
        boolean deleted = msg.getDeletedAt() != null;
        String content = msg.getContent();
        String imageUrl = msg.getImageUrl();
        List<Long> mentions = mentionService.deserializeMentionIds(msg.getMentionedUserIds());
        String deleteReason = msg.getDeleteReason() == null ? null : msg.getDeleteReason().name();
        if (deleted) {
            content = msg.getDeleteReason() == ChatDeleteReason.RECALL ? "已撤回" : "管理员已删除";
            imageUrl = null;
            mentions = List.of();
        }
        return new ChatDtos.MessageView(
                msg.getId(),
                msg.getUserId(),
                msg.getNickname(),
                user == null ? null : user.getAvatarUrl(),
                msg.getType(),
                content,
                imageUrl,
                deleted ? null : msg.getCheckinId(),
                msg.getCreatedAt(),
                rating == null || deleted ? null : rating.avgScore(),
                rating == null || deleted ? 0 : rating.ratingCount(),
                rating == null || deleted ? 0 : rating.expectedRaterCount(),
                !deleted && rating != null && rating.ratingComplete(),
                rating == null || deleted ? null : rating.myScore(),
                mentions,
                deleted,
                deleteReason
        );
    }
}
