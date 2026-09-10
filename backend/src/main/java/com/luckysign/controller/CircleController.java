package com.luckysign.controller;

import com.luckysign.common.ApiResponse;
import com.luckysign.dto.CircleDtos;
import com.luckysign.security.AuthSupport;
import com.luckysign.service.CircleService;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/circle")
public class CircleController {
    private final CircleService circleService;

    public CircleController(CircleService circleService) {
        this.circleService = circleService;
    }

    @GetMapping("/members")
    public ApiResponse<CircleDtos.MembersResponse> members() {
        return ApiResponse.ok(circleService.mentionCandidates(AuthSupport.currentUserId()));
    }
}
