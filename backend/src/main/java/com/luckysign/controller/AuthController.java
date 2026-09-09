package com.luckysign.controller;

import com.luckysign.common.ApiResponse;
import com.luckysign.dto.AuthDtos;
import com.luckysign.security.AuthSupport;
import com.luckysign.service.AuthService;
import jakarta.validation.Valid;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api")
public class AuthController {
    private final AuthService authService;

    public AuthController(AuthService authService) {
        this.authService = authService;
    }

    @PostMapping("/auth/register")
    public ApiResponse<AuthDtos.AuthResponse> register(@Valid @RequestBody AuthDtos.RegisterRequest request) {
        return ApiResponse.ok(authService.register(request));
    }

    @PostMapping("/auth/login")
    public ApiResponse<AuthDtos.AuthResponse> login(@Valid @RequestBody AuthDtos.LoginRequest request) {
        return ApiResponse.ok(authService.login(request));
    }

    @GetMapping("/user/profile")
    public ApiResponse<AuthDtos.UserProfileResponse> profile() {
        return ApiResponse.ok(authService.profile(AuthSupport.currentUserId()));
    }

    @PutMapping("/user/profile")
    public ApiResponse<AuthDtos.UserProfileResponse> update(@RequestBody AuthDtos.UpdateProfileRequest request) {
        return ApiResponse.ok(authService.updateProfile(AuthSupport.currentUserId(), request));
    }
}
