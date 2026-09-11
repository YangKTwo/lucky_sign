package com.luckysign.controller;

import com.luckysign.common.ApiResponse;
import com.luckysign.common.BizException;
import com.luckysign.dto.AuthDtos;
import com.luckysign.security.AuthSupport;
import com.luckysign.service.AuthService;
import com.luckysign.service.FileStorageService;
import jakarta.validation.Valid;
import org.springframework.http.MediaType;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

@RestController
@RequestMapping("/api")
public class AuthController {
    private final AuthService authService;
    private final FileStorageService fileStorageService;

    public AuthController(AuthService authService, FileStorageService fileStorageService) {
        this.authService = authService;
        this.fileStorageService = fileStorageService;
    }

    @PostMapping("/auth/register")
    public ApiResponse<AuthDtos.AuthResponse> register(@Valid @RequestBody AuthDtos.RegisterRequest request) {
        return ApiResponse.ok(authService.register(request));
    }

    @PostMapping("/auth/login")
    public ApiResponse<AuthDtos.AuthResponse> login(@Valid @RequestBody AuthDtos.LoginRequest request) {
        return ApiResponse.ok(authService.login(request));
    }

    @PostMapping("/auth/refresh")
    public ApiResponse<AuthDtos.AuthResponse> refresh(@RequestBody AuthDtos.RefreshRequest request) {
        return ApiResponse.ok(authService.refresh(request.refreshToken()));
    }

    @GetMapping("/user/profile")
    public ApiResponse<AuthDtos.UserProfileResponse> profile() {
        return ApiResponse.ok(authService.profile(AuthSupport.currentUserId()));
    }

    @PutMapping("/user/profile")
    public ApiResponse<AuthDtos.UserProfileResponse> update(@Valid @RequestBody AuthDtos.UpdateProfileRequest request) {
        return ApiResponse.ok(authService.updateProfile(AuthSupport.currentUserId(), request));
    }

    @PutMapping("/user/password")
    public ApiResponse<AuthDtos.AuthResponse> changePassword(@Valid @RequestBody AuthDtos.ChangePasswordRequest request) {
        AuthDtos.AuthResponse response = authService.changePassword(
                AuthSupport.currentUserId(), request.oldPassword(), request.newPassword());
        return ApiResponse.ok(response);
    }

    @PostMapping(value = "/user/avatar", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public ApiResponse<AuthDtos.UserProfileResponse> avatar(@RequestParam("image") MultipartFile image) {
        if (image == null || image.isEmpty()) {
            throw new BizException("请选择头像图片");
        }
        String url = fileStorageService.save(image);
        return ApiResponse.ok(authService.updateAvatar(AuthSupport.currentUserId(), url));
    }
}
