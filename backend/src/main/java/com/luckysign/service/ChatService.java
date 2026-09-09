package com.luckysign.service;

import com.luckysign.common.BizException;
import com.luckysign.domain.ChatMessageType;
import com.luckysign.domain.UserTag;
import com.luckysign.dto.ChatDtos;
import com.luckysign.entity.ChatMessage;
import com.luckysign.entity.CheckinRecord;
import com.luckysign.entity.Circle;
import com.luckysign.entity.DailyDraw;
import com.luckysign.entity.User;
import com.luckysign.repository.ChatMessageRepository;
import com.luckysign.repository.CircleRepository;
import com.luckysign.repository.UserRepository;
import org.springframework.data.domain.PageRequest;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

@Service
public class ChatService {
    private final ChatMessageRepository chatMessageRepository;
    private final CircleRepository circleRepository;
    private final UserRepository userRepository;
    private final SimpMessagingTemplate messagingTemplate;

    public ChatService(ChatMessageRepository chatMessageRepository,
                       CircleRepository circleRepository,
                       UserRepository userRepository,
                       SimpMessagingTemplate messagingTemplate) {
        this.chatMessageRepository = chatMessageRepository;
        this.circleRepository = circleRepository;
        this.userRepository = userRepository;
        this.messagingTemplate = messagingTemplate;
    }

    public Circle defaultCircle() {
        return circleRepository.findFirstByOrderByIdAsc()
                .orElseThrow(() -> new BizException("默认圈子未初始化"));
    }

    public ChatDtos.HistoryResponse history(Long beforeId, int size) {
        Circle circle = defaultCircle();
        int limit = Math.min(Math.max(size, 1), 50);
        List<ChatMessage> list;
        if (beforeId == null) {
            list = chatMessageRepository.findByCircleIdOrderByIdDesc(circle.getId(), PageRequest.of(0, limit));
        } else {
            list = chatMessageRepository.findByCircleIdAndIdLessThanOrderByIdDesc(circle.getId(), beforeId, PageRequest.of(0, limit));
        }
        List<ChatDtos.MessageView> views = new ArrayList<>(list.stream().map(this::toView).toList());
        Collections.reverse(views);
        return new ChatDtos.HistoryResponse(views);
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
        ChatMessage msg = new ChatMessage();
        msg.setCircleId(circle.getId());
        msg.setUserId(user.getId());
        msg.setNickname(user.getNickname());
        msg.setType(ChatMessageType.TEXT);
        msg.setContent(content.trim());
        msg = chatMessageRepository.save(msg);
        ChatDtos.MessageView view = toView(msg);
        messagingTemplate.convertAndSend("/topic/chat", view);
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
        messagingTemplate.convertAndSend("/topic/chat", toView(msg));
    }

    @Transactional
    public void postSystem(String content) {
        Circle circle = defaultCircle();
        ChatMessage msg = new ChatMessage();
        msg.setCircleId(circle.getId());
        msg.setType(ChatMessageType.SYSTEM);
        msg.setContent(content);
        msg = chatMessageRepository.save(msg);
        messagingTemplate.convertAndSend("/topic/chat", toView(msg));
    }

    private ChatDtos.MessageView toView(ChatMessage msg) {
        return new ChatDtos.MessageView(
                msg.getId(),
                msg.getUserId(),
                msg.getNickname(),
                msg.getType(),
                msg.getContent(),
                msg.getImageUrl(),
                msg.getCheckinId(),
                msg.getCreatedAt()
        );
    }
}
