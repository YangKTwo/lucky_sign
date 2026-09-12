package com.luckysign.controller;

import com.luckysign.common.ApiResponse;
import com.luckysign.dto.CircleDtos;
import com.luckysign.security.AuthSupport;
import com.luckysign.security.CircleAccessGuard;
import com.luckysign.service.CircleService;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
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
    public ApiResponse<CircleDtos.MembersResponse> members(@RequestParam(required = false) Long circleId) {
        Long userId = AuthSupport.currentUserId();
        Long resolvedCircleId = circleAccessGuard.requireMemberAndResolve(circleId, userId);
        return ApiResponse.ok(circleService.mentionCandidates(resolvedCircleId, userId));
    }

    @GetMapping("/me")
    public ApiResponse<CircleDtos.CircleMeResponse> me(@RequestParam(required = false) Long circleId) {
        Long userId = AuthSupport.currentUserId();
        Long resolvedCircleId = circleAccessGuard.requireMemberAndResolve(circleId, userId);
        return ApiResponse.ok(circleService.me(resolvedCircleId, userId));
    }
}
