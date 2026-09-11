package com.luckysign.service;

import com.luckysign.common.BizException;
import com.luckysign.domain.ChatMessageType;
import com.luckysign.domain.UserTag;
import com.luckysign.dto.ChatDtos;
import com.luckysign.dto.RatingDtos;
import com.luckysign.entity.ChatMessage;
import com.luckysign.entity.CheckinRecord;
import com.luckysign.entity.Circle;
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

    public Circle defaultCircle() {
        return circleRepository.findFirstByOrderByIdAsc()
                .orElseThrow(() -> new BizException("默认圈子未初始化"));
    }

    public ChatDtos.HistoryResponse history(Long viewerUserId, Long beforeId, int size) {
        Circle circle = defaultCircle();
        int limit = Math.min(Math.max(size, 1), 50);
        List<ChatMessage> fetched;
        if (beforeId == null) {
            fetched = chatMessageRepository.findByCircleIdOrderByIdDesc(circle.getId(), PageRequest.of(0, limit + 1));
        } else {
            fetched = chatMessageRepository.findByCircleIdAndIdLessThanOrderByIdDesc(
                    circle.getId(), beforeId, PageRequest.of(0, limit + 1));
        }
        boolean hasMore = fetched.size() > limit;
        List<ChatMessage> list = hasMore ? fetched.subList(0, limit) : fetched;
        List<Long> checkinIds = list.stream().map(ChatMessage::getCheckinId).filter(Objects::nonNull).toList();
        Map<Long, RatingDtos.RatingSummary> ratings = ratingService.summaries(checkinIds, viewerUserId);
        Map<Long, User> users = loadUsers(list);
        List<ChatDtos.MessageView> views = new ArrayList<>(list.stream()
                .map(m -> toView(m, users.get(m.getUserId()), ratings.get(m.getCheckinId())))
                .toList());
        Collections.reverse(views);
        return new ChatDtos.HistoryResponse(views, hasMore);
    }

    @Transactional
    public ChatDtos.MessageView sendText(Long userId, String content) {
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
        Circle circle = defaultCircle();
        String text = content.trim();
        List<Long> mentioned = mentionService.parseMentionedUserIds(text, circle.getId(), user.getId());
        ChatMessage msg = new ChatMessage();
        msg.setCircleId(circle.getId());
        msg.setUserId(user.getId());
        msg.setNickname(user.getNickname());
        msg.setType(ChatMessageType.TEXT);
        msg.setContent(text);
        msg.setMentionedUserIds(mentionService.serializeMentionIds(mentioned));
        msg = chatMessageRepository.save(msg);
        ChatDtos.MessageView view = toView(msg, user, null);
        messagingTemplate.convertAndSend("/topic/chat", view);
        if (aiAssistantService.isReady() && mentionService.mentionsAssistant(text)) {
            Long pendingId = postAssistant(ASSISTANT_LOADING);
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
    public void postCheckin(User user, CheckinRecord record, DailyDraw draw) {
        Circle circle = defaultCircle();
        String content = String.format("完成了%s任务：%s（+%d分%s）",
                draw.getLevel().getDisplayName(),
                draw.getTaskContent(),
                record.getPointsEarned(),
                Boolean.TRUE.equals(draw.getLuckyStar()) ? "，幸运星翻倍" : "");
        ChatMessage msg = new ChatMessage();
        msg.setCircleId(circle.getId());
        msg.setUserId(user.getId());
        msg.setNickname(user.getNickname());
        msg.setType(ChatMessageType.CHECKIN);
        msg.setContent(content);
        msg.setImageUrl(record.getImageUrl());
        msg.setCheckinId(record.getId());
        msg = chatMessageRepository.save(msg);
        messagingTemplate.convertAndSend("/topic/chat", toView(msg, user, null));
    }

    @Transactional
    public void postSystem(String content) {
        Circle circle = defaultCircle();
        ChatMessage msg = new ChatMessage();
        msg.setCircleId(circle.getId());
        msg.setType(ChatMessageType.SYSTEM);
        msg.setContent(content);
        msg = chatMessageRepository.save(msg);
        messagingTemplate.convertAndSend("/topic/chat", toView(msg, null, null));
    }

    @Transactional
    public Long postAssistant(String content) {
        Circle circle = defaultCircle();
        ChatMessage msg = new ChatMessage();
        msg.setCircleId(circle.getId());
        msg.setNickname(MentionService.ASSISTANT_DISPLAY_NAME);
        msg.setType(ChatMessageType.ASSISTANT);
        msg.setContent(content);
        msg = chatMessageRepository.save(msg);
        messagingTemplate.convertAndSend("/topic/chat", toView(msg, null, null));
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
        msg.setContent(content);
        chatMessageRepository.save(msg);
        messagingTemplate.convertAndSend("/topic/chat", toView(msg, null, null));
    }

    private Map<Long, User> loadUsers(List<ChatMessage> list) {
        List<Long> ids = list.stream().map(ChatMessage::getUserId).filter(Objects::nonNull).distinct().toList();
        if (ids.isEmpty()) {
            return Map.of();
        }
        return userRepository.findAllById(ids).stream().collect(Collectors.toMap(User::getId, Function.identity()));
    }

    private ChatDtos.MessageView toView(ChatMessage msg, User user, RatingDtos.RatingSummary rating) {
        return new ChatDtos.MessageView(
                msg.getId(),
                msg.getUserId(),
                msg.getNickname(),
                user == null ? null : user.getAvatarUrl(),
                msg.getType(),
                msg.getContent(),
                msg.getImageUrl(),
                msg.getCheckinId(),
                msg.getCreatedAt(),
                rating == null ? null : rating.avgScore(),
                rating == null ? 0 : rating.ratingCount(),
                rating == null ? 0 : rating.expectedRaterCount(),
                rating != null && rating.ratingComplete(),
                rating == null ? null : rating.myScore(),
                mentionService.deserializeMentionIds(msg.getMentionedUserIds())
        );
    }
}
