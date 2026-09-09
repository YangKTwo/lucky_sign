package com.luckysign.controller;

import com.luckysign.common.ApiResponse;
import com.luckysign.dto.AuthDtos;
import com.luckysign.service.AdminService;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/admin")
public class AdminController {
    private final AdminService adminService;

    public AdminController(AdminService adminService) {
        this.adminService = adminService;
    }

    @PostMapping("/users/{userId}/unlock")
    public ApiResponse<AuthDtos.UserProfileResponse> unlock(@PathVariable Long userId) {
        return ApiResponse.ok(adminService.unlock(userId));
    }
}
