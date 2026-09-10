package com.luckysign.controller;

import com.luckysign.common.ApiResponse;
import com.luckysign.dto.AuthDtos;
import com.luckysign.dto.FeedbackDtos;
import com.luckysign.service.AdminService;
import com.luckysign.service.FeedbackService;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/admin")
public class AdminController {
    private final AdminService adminService;
    private final FeedbackService feedbackService;

    public AdminController(AdminService adminService, FeedbackService feedbackService) {
        this.adminService = adminService;
        this.feedbackService = feedbackService;
    }

    @PostMapping("/users/{userId}/unlock")
    public ApiResponse<AuthDtos.UserProfileResponse> unlock(@PathVariable Long userId) {
        return ApiResponse.ok(adminService.unlock(userId));
    }

    @GetMapping("/feedbacks")
    public ApiResponse<FeedbackDtos.ListResponse> feedbacks() {
        return ApiResponse.ok(feedbackService.listAll());
    }
}
