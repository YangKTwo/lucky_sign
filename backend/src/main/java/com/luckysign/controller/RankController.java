package com.luckysign.controller;

import com.luckysign.common.ApiResponse;
import com.luckysign.dto.RankDtos;
import com.luckysign.service.RankService;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/rank")
public class RankController {
    private final RankService rankService;

    public RankController(RankService rankService) {
        this.rankService = rankService;
    }

    @GetMapping
    public ApiResponse<RankDtos.RankingResponse> ranking() {
        return ApiResponse.ok(rankService.ranking());
    }
}
