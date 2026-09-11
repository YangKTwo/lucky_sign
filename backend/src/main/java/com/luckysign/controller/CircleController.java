package com.luckysign.controller;

import com.luckysign.common.ApiResponse;
import com.luckysign.dto.CircleDtos;
import com.luckysign.security.AuthSupport;
import com.luckysign.security.CircleAccessGuard;
import com.luckysign.service.CircleService;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/circle")
public class CircleController {
    private final CircleService circleService;
    private final CircleAccessGuard circleAccessGuard;

    public CircleController(CircleService circleService, CircleAccessGuard circleAccessGuard) {
        this.circleService = circleService;
        this.circleAccessGuard = circleAccessGuard;
    }

    @GetMapping("/members")
    public ApiResponse<CircleDtos.MembersResponse> members() {
        Long userId = AuthSupport.currentUserId();
        circleAccessGuard.requireMember(userId);
        return ApiResponse.ok(circleService.mentionCandidates(userId));
    }

    @GetMapping("/me")
    public ApiResponse<CircleDtos.CircleMeResponse> me() {
        Long userId = AuthSupport.currentUserId();
        circleAccessGuard.requireMember(userId);
        return ApiResponse.ok(circleService.me(userId));
    }
}
