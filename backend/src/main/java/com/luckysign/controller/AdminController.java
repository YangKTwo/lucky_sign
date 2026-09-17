package com.luckysign.controller;

import com.luckysign.common.ApiResponse;
import com.luckysign.dto.AdminDtos;
import com.luckysign.dto.AuthDtos;
import com.luckysign.dto.ChatDtos;
import com.luckysign.dto.FeedbackDtos;
import com.luckysign.security.AuthSupport;
import com.luckysign.service.AdminService;
import com.luckysign.service.ChatService;
import com.luckysign.service.FeedbackService;
import org.springframework.web.bind.annotation.DeleteMapping;
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
    private final ChatService chatService;

    public AdminController(AdminService adminService, FeedbackService feedbackService, ChatService chatService) {
        this.adminService = adminService;
        this.feedbackService = feedbackService;
        this.chatService = chatService;
    }

    @PostMapping("/users/{userId}/unlock")
    public ApiResponse<AuthDtos.UserProfileResponse> unlock(@PathVariable Long userId) {
        return ApiResponse.ok(adminService.unlock(userId));
    }

    @GetMapping("/registrations")
    public ApiResponse<AdminDtos.PendingListResponse> pendingRegistrations() {
        return ApiResponse.ok(adminService.pendingRegistrations());
    }

    @PostMapping("/registrations/{userId}/approve")
    public ApiResponse<AuthDtos.UserProfileResponse> approve(@PathVariable Long userId) {
        return ApiResponse.ok(adminService.approveRegistration(userId));
    }

    @PostMapping("/registrations/{userId}/reject")
    public ApiResponse<Void> reject(@PathVariable Long userId) {
        adminService.rejectRegistration(userId);
        return ApiResponse.okMessage("已拒绝该注册");
    }

    @GetMapping("/feedbacks")
    public ApiResponse<FeedbackDtos.ListResponse> feedbacks() {
        return ApiResponse.ok(feedbackService.listAll());
    }

    @DeleteMapping("/chat/messages/{messageId}")
    public ApiResponse<ChatDtos.MessageView> deleteChatMessage(@PathVariable Long messageId) {
        return ApiResponse.ok(chatService.adminRemove(AuthSupport.currentUserId(), messageId));
    }
}
