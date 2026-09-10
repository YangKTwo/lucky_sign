package com.luckysign.controller;

import com.luckysign.common.ApiResponse;
import com.luckysign.dto.FeedbackDtos;
import com.luckysign.security.AuthSupport;
import com.luckysign.service.FeedbackService;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/feedback")
public class FeedbackController {
    private final FeedbackService feedbackService;

    public FeedbackController(FeedbackService feedbackService) {
        this.feedbackService = feedbackService;
    }

    @PostMapping
    public ApiResponse<FeedbackDtos.FeedbackView> submit(@RequestBody FeedbackDtos.SubmitRequest request) {
        return ApiResponse.ok(feedbackService.submit(AuthSupport.currentUserId(), request.content()));
    }
}
