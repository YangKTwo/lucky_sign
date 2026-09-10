package com.luckysign.service;

import com.luckysign.common.BizException;
import com.luckysign.dto.FeedbackDtos;
import com.luckysign.entity.Feedback;
import com.luckysign.entity.User;
import com.luckysign.repository.FeedbackRepository;
import com.luckysign.repository.UserRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Service
public class FeedbackService {
    private final FeedbackRepository feedbackRepository;
    private final UserRepository userRepository;

    public FeedbackService(FeedbackRepository feedbackRepository, UserRepository userRepository) {
        this.feedbackRepository = feedbackRepository;
        this.userRepository = userRepository;
    }

    @Transactional
    public FeedbackDtos.FeedbackView submit(Long userId, String content) {
        if (content == null || content.isBlank()) {
            throw new BizException("请填写意见内容");
        }
        String text = content.trim();
        if (text.length() > 1000) {
            throw new BizException("内容过长，最多 1000 字");
        }
        User user = userRepository.findById(userId).orElseThrow(() -> new BizException("用户不存在"));
        Feedback fb = new Feedback();
        fb.setUserId(user.getId());
        fb.setNickname(user.getNickname());
        fb.setContent(text);
        fb = feedbackRepository.save(fb);
        return toView(fb);
    }

    public FeedbackDtos.ListResponse listAll() {
        List<FeedbackDtos.FeedbackView> items = feedbackRepository.findAllByOrderByCreatedAtDesc()
                .stream()
                .map(this::toView)
                .toList();
        return new FeedbackDtos.ListResponse(items);
    }

    private FeedbackDtos.FeedbackView toView(Feedback fb) {
        return new FeedbackDtos.FeedbackView(
                fb.getId(),
                fb.getUserId(),
                fb.getNickname(),
                fb.getContent(),
                fb.getCreatedAt()
        );
    }
}
