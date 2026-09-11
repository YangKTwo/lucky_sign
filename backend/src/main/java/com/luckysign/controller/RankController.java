package com.luckysign.controller;

import com.luckysign.common.ApiResponse;
import com.luckysign.dto.RankDtos;
import com.luckysign.security.AuthSupport;
import com.luckysign.security.CircleAccessGuard;
import com.luckysign.service.RankService;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/rank")
public class RankController {
    private final RankService rankService;
    private final CircleAccessGuard circleAccessGuard;

    public RankController(RankService rankService, CircleAccessGuard circleAccessGuard) {
        this.rankService = rankService;
        this.circleAccessGuard = circleAccessGuard;
    }

    @GetMapping
    public ApiResponse<RankDtos.RankingResponse> ranking() {
        circleAccessGuard.requireMember(AuthSupport.currentUserId());
        return ApiResponse.ok(rankService.ranking());
    }
}
